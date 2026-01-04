@tool
class_name TGGateExporter
extends Node

const SECTION = "gate"

# Keys
const TITLE = "title"
const DESCRIPTION = "description"
const ICON = "icon"
const IMAGE = "image"
const PACK = "resource_pack"
const GODOT_VERSION = "godot_version"
const DISCOVERABLE = "discoverable"


func export(settings: TGExportSettings) -> void:
	if not is_valid(settings): return
	
	var icon = settings.get_icon_path().get_file()
	var image = settings.get_image_path().get_file()
	var pack = settings.get_pack_path().get_file()
	var godot_version = settings.get_godot_version()
	
	var cfg = ConfigFile.new()
	cfg.set_value(SECTION, TITLE, settings.title)
	cfg.set_value(SECTION, DESCRIPTION, settings.description)
	cfg.set_value(SECTION, ICON, icon)
	cfg.set_value(SECTION, IMAGE, image)
	cfg.set_value(SECTION, PACK, pack)
	cfg.set_value(SECTION, GODOT_VERSION, godot_version)
	cfg.set_value(SECTION, DISCOVERABLE, settings.discoverable)

	var path = settings.get_gate_path()
	cfg.save(path)


func is_valid(settings: TGExportSettings) -> bool:
	return true
