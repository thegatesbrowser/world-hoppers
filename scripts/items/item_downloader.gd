extends Node

const itemLIB = preload("res://resources/items_library.tres")

#const BASE_URL := "http://188.245.188.59:8081"
const BASE_URL := "http://127.0.0.1:8000"

const ITEMS_DIR := "user://items/"
const TEXTURES_DIR := "user://textures/"
const SFX_DIR := "user://sfx/"
const SCRIPTS_DIR := "user://scripts/"  # ✅ new

var item_metadata := {}  # key: item filename, value: parsed JSON metadata

var pending_downloads := 0
var server_items := {}
var pending_resources := []

signal completed_download

func _ready():
	# Ensure directories exist
	for dir_path in [ITEMS_DIR, TEXTURES_DIR, SFX_DIR, SCRIPTS_DIR]:  # ✅ added scripts
		ensure_dir(dir_path)
	
	#download_item_with_dependencies("wood_oak.tres",get_folder_from_name("wood_oak.tres"))


# ------------------------
# Directory helper
# ------------------------
func ensure_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		return  # Folder exists
	var base = DirAccess.open("user://")
	if base:
		base.make_dir_recursive(path)

func get_server_folder_key(file_name: String) -> String:
	if file_name.ends_with(".tres") or file_name.ends_with(".tscn"):
		return "items"
	elif file_name.ends_with(".png") or file_name.ends_with(".jpg"):
		return "textures"
	elif file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3"):
		return "sfx"
	elif file_name.ends_with(".gd"):
		return "scripts"
	else:
		return "scenes"
# ------------------------
# Folder mapping
# ------------------------
func get_folder_from_name(file_name: String) -> String:
	if file_name.ends_with(".tres") or file_name.ends_with(".tscn"):
		return ITEMS_DIR
	elif file_name.ends_with(".png") or file_name.ends_with(".jpg"):
		return TEXTURES_DIR
	elif file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3"):
		return SFX_DIR
	elif file_name.ends_with(".gd"):
		return SCRIPTS_DIR  # ✅ new
	else:
		return ITEMS_DIR


# ------------------------
# Download item and dependencies
# ------------------------
func download_item_with_dependencies(item_name: String, folder_key: String) -> void:
	pending_resources.append(item_name)
	var json_url := "%s/download_file/%s/%s.json" % [BASE_URL, folder_key, item_name]
	var http := HTTPRequest.new()
	add_child(http)
	pending_downloads += 1
	http.request_completed.connect(Callable(self, "_on_json_request_completed").bind(folder_key))
	http.request(json_url)


func _on_json_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray, folder_key: String) -> void:
	pending_downloads -= 1
	if response_code != 200:
		print("❌ Failed to get JSON for folder:", folder_key)
		return

	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		print("❌ Failed to parse JSON for folder:", folder_key, json.get_error_message())
		return

	var data = json.data

	# Save metadata for patching
	item_metadata[data.name] = data

	# Download dependencies
	for dep_name in data.dependencies.keys():
		var dep = data.dependencies[dep_name]
		if dep.exists and "download_url" in dep:
			download_file(dep.path, dep_name, get_folder_from_name(dep_name))
		else:
			print("⚠️ Dependency not found on server:", dep_name)

	# Download the main item last
	download_file(data.path, data.name, get_folder_from_name(data.name))



func url_encode(text: String) -> String:
	var encoded := text.replace(" ", "%20")
	# You can add more replacements for other unsafe characters if needed
	return encoded
# ------------------------
# Download single file
# ------------------------
func download_file(res_path: String, file_name: String, folder_path: String) -> void:
	var local_path = folder_path + file_name
	if FileAccess.file_exists(local_path):
		load_resource(local_path, res_path, file_name)
		return

	var folder_key = get_server_folder_key(file_name)  # server folder name
	var safe_file_name = url_encode(file_name)
	var url := "%s/download_file/%s/%s" % [BASE_URL, folder_key, safe_file_name]

	var http := HTTPRequest.new()
	add_child(http)
	pending_downloads += 1
	http.request_completed.connect(Callable(self, "_on_file_download_completed").bind(local_path, res_path, file_name))
	http.request(url)


func _on_file_download_completed(result: int, response_code: int, headers: Array, body: PackedByteArray, local_path: String, res_path: String, file_name: String) -> void:
	pending_downloads -= 1
	if response_code != 200:
		print("Failed to download:", file_name)
		return

	# Save file to disk
	var f = FileAccess.open(local_path, FileAccess.WRITE)
	f.store_buffer(body)
	f.close()
	print("Downloaded:", local_path)

	# Load the resource (textures, audio, scripts, scenes) via unified function
	load_resource(local_path, res_path, file_name)

	if pending_downloads == 0:
		print("All files downloaded and ready!")



# ------------------------
# Load resource based on type
# ------------------------
func load_resource(local_path: String, res_path: String, file_name: String) -> void:
	if not FileAccess.file_exists(local_path):
		print("❌ Resource not found:", local_path)
		download_item_with_dependencies(file_name, get_server_folder_key(file_name))
		return

	var resource: Resource = null

	if file_name.ends_with(".mp3") or file_name.ends_with(".ogg") or file_name.ends_with(".wav"):
		resource = load_audio_from_file(local_path)
	elif file_name.ends_with(".png") or file_name.ends_with(".jpg"):
		resource = load_texture_from_file(local_path)
	elif file_name.ends_with(".gd"):
		resource = load_script_from_file(local_path)
	elif file_name.ends_with(".tres") or file_name.ends_with(".tscn"):
		resource = ResourceLoader.load(local_path)
		resource.take_over_path(res_path)
		if resource and item_metadata.has(file_name):
			patch_resource_dependencies(resource, item_metadata[file_name])

		if has_node("$Slot"):
			$Slot.item = load(res_path)
			$Slot.update_slot()
	else:
		print("⚠️ Unknown file type:", file_name)

	if resource:
		print("✅ Loaded resource:", file_name)




# ------------------------
# Fetch all JSON files from server
# ------------------------
func fetch_all_jsons() -> void:
	var url = "%s/list_jsons" % BASE_URL
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(Callable(self, "_on_list_jsons_completed"))
	http.request(url)

func patch_resource_dependencies(res: Resource, metadata: Dictionary) -> void:
	if not metadata.has("dependencies"):
		return

	for field_name in metadata.dependencies.keys():
		var dep = metadata.dependencies[field_name]
		var dep_type = dep.get("type", "")
		var file_name = dep.get("file", "")
		var full_path = ""

		match dep_type:
			"audio":
				full_path = SFX_DIR + file_name
				if FileAccess.file_exists(full_path):
					var loaded = ResourceLoader.load(full_path)
					if loaded and loaded is AudioStream and res.has(field_name):
						res.set(field_name, loaded)
						print("✅ Patched audio:", field_name, "->", full_path)
				else:
					download_item_with_dependencies(file_name, "sfx")

			"texture":
				full_path = TEXTURES_DIR + file_name
				if FileAccess.file_exists(full_path):
					var loaded = ResourceLoader.load(full_path)
					if loaded and loaded is Texture and res.has(field_name):
						res.set(field_name, loaded)
						print("✅ Patched texture:", field_name, "->", full_path)
				else:
					download_item_with_dependencies(file_name, "textures")

			"script":
				full_path = SCRIPTS_DIR + file_name
				if FileAccess.file_exists(full_path):
					var file = FileAccess.open(full_path, FileAccess.READ)
					if file:
						var code = file.get_as_text()
						file.close()
						var script = GDScript.new()
						script.source_code = code
						if res.has(field_name):
							res.set(field_name, script)
							print("✅ Patched script:", field_name, "->", full_path)
				else:
					download_item_with_dependencies(file_name, "scripts")

			_:
				print("⚠️ Unknown dependency type:", dep_type, "for field:", field_name)


func load_audio_from_file(path: String) -> AudioStream:
	if path.ends_with(".mp3"):
		var audio = AudioStreamMP3.new()
		audio.file = path
		return audio
	var audio = AudioStreamOggVorbis.new()
	audio.resource_path = path
	return audio

func load_texture_from_file(path: String) -> Texture:
	var img = Image.load_from_file(path)
	if img:
		return ImageTexture.create_from_image(img)
	return null

func load_script_from_file(path: String) -> GDScript:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var code = file.get_as_text()
	file.close()
	var script = GDScript.new()
	script.source_code = code
	return script

# ------------------------
# Handle JSON list response
# ------------------------
func _on_list_jsons_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	if response_code != 200:
		print("Failed to fetch JSON list from server!")
		return

	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		print("Failed to parse server JSON list:", json.get_error_message())
		return

	var data = json.data
	if "json_files" in data:
		for json_file_path in data["json_files"]:
			var name = json_file_path.get_file().replace(".json", "")
			server_items[name] = json_file_path

	print("Available items on server:")
	for item_name in server_items.keys():
		print(" - ", item_name)
		download_item_with_dependencies(item_name, "items")


func _on_button_pressed() -> void:
	#$TextureRect.texture = load("res://gun.png")
	$AudioStreamPlayer.stream = load("res://log 7.mp3")
	$AudioStreamPlayer.play()
