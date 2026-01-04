@tool
extends VBoxContainer

var selected_resources: Array = []

@onready var http: HTTPRequest = $HTTPRequest
@onready var resource_tree: Tree = $ResourceTree
@onready var export_button: Button = $HBoxContainer/ExportButton
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var refresh_button: Button = $HBoxContainer/Refresh


func _ready():
	_populate_tree()
	refresh_button.pressed.connect(_on_refresh_pressed)
	export_button.pressed.connect(_on_export_pressed)
	
	progress_bar.value = 0

# ------------------------
# Populate Tree with checkboxes + visible names
# ------------------------
func _populate_tree():
	resource_tree.clear()
	resource_tree.columns = 2
	resource_tree.hide_root = true
	var root = resource_tree.create_item()
	var files = list_files_recursive("res://")
	for f in files:
		if type(f.get_file()):
			var item = resource_tree.create_item(root)
	#
			## Column 0 = checkbox
			item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			item.set_editable(0, true)
			item.set_checked(0, false)
	#
			## Column 1 = file/folder name
			item.set_cell_mode(1, TreeItem.CELL_MODE_STRING)
			item.set_text(1, f.get_file())
			item.set_metadata(1, f)
			print(f)
	#_add_tree_recursive("res://", root)

#func _add_tree_recursive(path: String, parent_item: TreeItem) -> void:
	#var dir = DirAccess.open(path)
	#if not dir:
		#return
	#dir.list_dir_begin()
	#var name = dir.get_next()
	#while name != "":
		#if name != "." and name != "..":
			#if type(name):
				#var full_path = path.path_join(name)
				#var item = resource_tree.create_item(parent_item)
#
				## Column 0 = checkbox
				#item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
				#item.set_editable(0, true)
				#item.set_checked(0, false)
#
				## Column 1 = file/folder name
				#item.set_cell_mode(1, TreeItem.CELL_MODE_STRING)
				#item.set_text(1, name)
				#item.set_metadata(1, full_path)
#
				#if dir.current_is_dir():
					#_add_tree_recursive(full_path, item)
		#name = dir.get_next()
	#dir.list_dir_end()

func list_files_recursive(path: String, result := []):
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				list_files_recursive(path + "/" + file_name, result)
		else:
			result.append(path + "/" + file_name)
	
	dir.list_dir_end()
	return result

	

# ------------------------
# Handle checkbox click
# ------------------------
func _on_tree_button_pressed(item: TreeItem, column: int):
	if column == 0:
		item.set_checked(0, not item.is_checked(0))

# ------------------------
# Collect checked resources recursively
# ------------------------
func _collect_checked_resources(item: TreeItem) -> void:
	if not item:
		return
	if item.is_checked(0):
		selected_resources.append(item.get_metadata(1))
	var child = item.get_first_child()
	while child:
		_collect_checked_resources(child)
		child = child.get_next()

# ------------------------
# Pack & Upload
# ------------------------
func _on_export_pressed():
	selected_resources.clear()
	_collect_checked_resources(resource_tree.get_root())

	var editor_interface = get_editor_interface()
	if selected_resources.is_empty():
		editor_interface.show_warning("No resources selected")
		return
	var server_url = "http://localhost:8000/upload"
	if !server_url:
		editor_interface.show_warning("Enter a server URL")
		return

	# Pack selected resources
	var zip_path = "user://mod_pack.zip"
	_pack_resources(selected_resources, zip_path)

	# Upload ZIP
	_upload_zip(zip_path, server_url)

# ------------------------
# Pack resources + .import files
# ------------------------
func _pack_resources(input_paths: Array, zip_path: String) -> void:
	var to_pack: Dictionary = {}
	for res_path in input_paths:
		_collect_resource_and_dependencies(res_path, to_pack)

	var packer := ZIPPacker.new()
	if packer.open(zip_path) != OK:
		push_error("Cannot open ZIP: %s" % zip_path)
		return

	for full_path in to_pack.keys():
		var rel_path = to_pack[full_path]
		var bytes = FileAccess.get_file_as_bytes(full_path)
		packer.start_file(rel_path)
		packer.write_file(bytes)
		packer.close_file()
		print("Packed:", rel_path)

	packer.close()
	print("ZIP created at:", zip_path)

func _collect_resource_and_dependencies(res_path: String, out: Dictionary) -> void:
	if not FileAccess.file_exists(res_path):
		return
	out[res_path] = res_path.trim_prefix("res://")

	var import_path = res_path + ".import"
	if FileAccess.file_exists(import_path):
		out[import_path] = import_path.trim_prefix("res://")
		var cfg := ConfigFile.new()
		if cfg.load(import_path) == OK:
			var dest_files = cfg.get_value("deps", "dest_files", [])
			for f in dest_files:
				if FileAccess.file_exists(f):
					out[f] = f.trim_prefix("res://")

# ------------------------
# Upload ZIP using request_raw
# ------------------------
func _upload_zip(zip_path: String, server_url: String) -> void:
	var file := FileAccess.open(zip_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open ZIP for upload: %s" % zip_path)
		return

	var data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	var boundary = "----GodotFormBoundary123456789"
	var header_text = "--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\nContent-Type: application/zip\r\n\r\n" % [boundary, zip_path.get_file()]
	var footer_text = "\r\n--%s--\r\n" % boundary

	var body: PackedByteArray = header_text.to_utf8_buffer()
	body += data
	body += footer_text.to_utf8_buffer()

	progress_bar.value = 0
	print("upload in progress")
	var headers = ["Content-Type: multipart/form-data; boundary=%s" % boundary]
	http.request_raw(server_url, headers, HTTPClient.METHOD_POST, body)


func get_editor_interface() -> EditorInterface:
	var editor_plugin := get_parent()
	while editor_plugin and not editor_plugin is EditorPlugin:
		editor_plugin = editor_plugin.get_parent()
	if editor_plugin:
		return editor_plugin.get_editor_interface()
	return null


func _on_upload_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("reterned")
	var editor_interface = get_editor_interface()
	if response_code == OK:
		print("upload successful")
	else:
		print("upload failed:")
	progress_bar.value = 100

func type(item_name:String) -> bool:
	if item_name.ends_with(".png"):
		return true
	elif item_name.ends_with(".tres"):
		return true
	else:
		return false

func _on_refresh_pressed():
	_populate_tree()
