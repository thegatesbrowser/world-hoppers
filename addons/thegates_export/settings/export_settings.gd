@tool
class_name TGExportSettings
extends Resource

signal advanced_settings_changed(enabled: bool)
signal export_locally_changed(enabled: bool)
signal tos_accepted_changed(accepted: bool)

@export var title: String: set = set_title
@export var description: String: set = set_description
@export var icon: String: set = set_icon
@export var image: String: set = set_image
@export var discoverable: bool: set = set_discoverable

@export var advanced_settings: bool: set = set_advanced_settings
@export var export_locally: bool: set = set_export_locally
@export var tos_accepted: bool: set = set_tos_accepted

@export var fresh_install: bool

const PACK_NAME = "project.zip"
const ICON_NAME = "icon.%s"
const IMAGE_NAME = "image.%s"
const GATE_NAME = "project.gate"
const TOKEN_NAME = "publish.key"

var export_folder: String = ProjectSettings.globalize_path("res://addons/thegates_export/export")
var keys_folder: String = ProjectSettings.globalize_path("res://addons/thegates_export/keys")

var pack_path: String : get = get_pack_path
var icon_path: String : get = get_icon_path
var image_path: String : get = get_image_path
var gate_path: String : get = get_gate_path
var token_path: String : get = get_token_path

var supported_versions: = ["4.3", "4.5"]
var supported_rendering_methods: = ["forward_plus"]

var published_url: String


func get_pack_path() -> String:
	return export_folder + "/" + PACK_NAME


func get_icon_path() -> String:
	if icon.is_empty(): return ""
	
	var ext = icon.get_extension()
	return export_folder + "/" + ICON_NAME % [ext]


func get_image_path() -> String:
	if image.is_empty(): return ""
	
	var ext = image.get_extension()
	return export_folder + "/" + IMAGE_NAME % [ext]


func get_gate_path() -> String:
	return export_folder + "/" + GATE_NAME


func get_token_path() -> String:
	return keys_folder + "/" + TOKEN_NAME


func get_godot_version() -> String:
	var version_info = Engine.get_version_info()
	var major = version_info["major"]
	var minor = version_info["minor"]
	return str(major) + "." + str(minor)


func get_rendering_method() -> String:
	return ProjectSettings.get_setting("rendering/renderer/rendering_method")


func set_title(value: String) -> void:
	title = value
	changed.emit()


func set_description(value: String) -> void:
	description = value
	changed.emit()


func set_icon(value: String) -> void:
	icon = value
	changed.emit()


func set_image(value: String) -> void:
	image = value
	changed.emit()


func set_discoverable(value: bool) -> void:
	discoverable = value
	changed.emit()


func set_advanced_settings(value: bool) -> void:
	advanced_settings = value
	advanced_settings_changed.emit(value)
	changed.emit()


func set_export_locally(value: bool) -> void:
	export_locally = value
	export_locally_changed.emit(value)
	changed.emit()


func set_tos_accepted(value: bool) -> void:
	tos_accepted = value
	tos_accepted_changed.emit(value)
	changed.emit()


func save_on_changed() -> void:
	if not changed.is_connected(save):
		changed.connect(save)


func save() -> void:
	ResourceSaver.save(self, resource_path)
