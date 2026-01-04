extends Node

const BASE_URL := "http://localhost:8000"

const ITEMS_DIR := "user://items/"
const TEXTURES_DIR := "user://textures/"
const SFX_DIR := "user://sfx/"
const SCENES_DIR := "user://scenes/"
const SCRIPTS_DIR := "user://scripts/"

var FOLDER_MAP := {
	"tres": ITEMS_DIR,
	"tscn": ITEMS_DIR,
	"png": TEXTURES_DIR,
	"jpg": TEXTURES_DIR,
	"jpeg": TEXTURES_DIR,
	"mp3": SFX_DIR,
	"wav": SFX_DIR,
	"ogg": SFX_DIR,
	"gd": SCRIPTS_DIR,
	"shader": SCRIPTS_DIR,
}

func _ready() -> void:
	for dir_path in FOLDER_MAP.values():
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	import_item("wood_oak")


func get_folder_from_name(file_name: String) -> String:
	var ext := file_name.get_extension().to_lower()
	return FOLDER_MAP.get(ext, SCENES_DIR)


func import_item(item_name: String) -> void:
	print("⏬ Importing item:", item_name)
	var json_url := "%s/item_json/%s" % [BASE_URL, item_name]
	print(json_url)
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_json_received.bind(item_name))
	http.request(json_url)


func _on_json_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, item_name: String) -> void:
	if response_code != 200:
		push_error("Failed to fetch JSON for %s (HTTP %d)" % [item_name, response_code])
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON format for %s" % item_name)
		return

	var deps: Dictionary = parsed.get("dependencies", {})
	var all_files := [item_name] + deps.keys()
	for file_name in all_files:
		_download_if_missing(file_name, item_name)


func _download_if_missing(file_name: String, root_item: String) -> void:
	var folder := get_folder_from_name(file_name)
	var local_path := folder + file_name

	if FileAccess.file_exists(local_path):
		print("✔️ Exists:", file_name)
		if file_name == root_item:
			_remap_resource_paths(local_path)
		return

	var remote_folder := _get_remote_folder(file_name)
	var url := "%s/download_file/%s/%s" % [BASE_URL, remote_folder, file_name]

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_file_downloaded.bind(local_path, file_name, root_item))
	http.request(url)


func _get_remote_folder(file_name: String) -> String:
	var ext := file_name.get_extension().to_lower()
	match ext:
		"tres", "tscn":
			return "items"
		"png", "jpg", "jpeg":
			return "textures"
		"wav", "ogg", "mp3":
			return "sfx"
		"gd", "shader":
			return "scripts"
		_:
			return "scenes"


func _on_file_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, local_path: String, file_name: String, root_item: String) -> void:
	if response_code != 200:
		push_error("Failed to download %s (HTTP %d)" % [file_name, response_code])
		return

	var file := FileAccess.open(local_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()
		print("💾 Saved:", local_path)

		# If it's the main item, remap res:// paths to user://
		if file_name == root_item or file_name.ends_with(".tres") or file_name.ends_with(".tscn"):
			_remap_resource_paths(local_path)
	else:
		push_error("Couldn't save file: %s" % local_path)


# 🧩 Patch the .tres or .tscn file to remap res:// → user://
func _remap_resource_paths(resource_path: String) -> void:
	if not resource_path.ends_with(".tres") and not resource_path.ends_with(".tscn"):
		return

	print("🔧 Remapping resource paths in:", resource_path)
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if not file:
		push_error("Failed to open for remap: %s" % resource_path)
		return

	var text := file.get_as_text()
	file.close()

	# Replace res:// paths with user:// equivalents based on known extensions
	for ext in FOLDER_MAP.keys():
		var res_dir = "res://"
		var repl_dir = FOLDER_MAP[ext]
		# regex-like search for e.g. res://sfx/xxx.wav
		var regex = "(res://[A-Za-z0-9_\\-/]+\\." + ext + ")"
		var result := RegEx.new()
		if result.compile(regex) == OK:
			var matches := result.search_all(text)
			for match in matches:
				var path := match.get_string()
				var filename := path.get_file()
				var new_path = repl_dir + filename
				text = text.replace(path, new_path)

	# Save remapped file back
	var file_out := FileAccess.open(resource_path, FileAccess.WRITE)
	if file_out:
		file_out.store_string(text)
		file_out.close()
		print("✅ Remapped and saved:", resource_path)
