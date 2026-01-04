extends Node

@onready var http := HTTPRequest.new()
var zip_url := "http://127.0.0.1:8000/download/ee00b71f19e046fea29463c6905bfa2d.zip"
var local_zip_path := "user://session.zip"

func _ready():
	add_child(http)
	http.connect("request_completed", Callable(self, "_on_request_completed"))
	http.request(zip_url)


func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	if response_code != 200:
		push_error("Failed to download ZIP: %d" % response_code)
		return

	# Save ZIP
	var f := FileAccess.open(local_zip_path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open file for writing ZIP")
		return
	f.store_buffer(body)
	f.close()
	print("ZIP saved at:", local_zip_path)

	# Mount ZIP
	if ProjectSettings.load_resource_pack(local_zip_path, true):
		print("Resource pack loaded!")

		# Load resources from mod.json
		load_resources_from_manifest()
	else:
		push_error("Failed to load resource pack")


func load_resources_from_manifest():
	var manifest_file := "res://mod.json"
	if not FileAccess.file_exists(manifest_file):
		push_warning("mod.json not found")
		return

	var f := FileAccess.open(manifest_file, FileAccess.READ)
	if f == null:
		push_error("Failed to open mod.json")
		return
	var data := f.get_as_text()  # UTF-8 text
	f.close()

	# Correct Godot 4 JSON parsing
	var json_converter = JSON.new()
	var err = json_converter.parse(data)
	if err != OK:
		push_error("Failed to parse JSON: %s" % json_converter.get_error_message())
		return
	var manifest = json_converter.get_data()

	# Load resources from manifest
	for entry in manifest["files"]:
		var res := load(entry["res_path"])
		if res:
			$Slot.item = res
			$Slot.update_slot()
			print("Loaded resource:", entry["res_path"])
