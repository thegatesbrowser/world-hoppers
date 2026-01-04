@tool
class_name TGGateExporter
extends Node

const SECTION = "gate"
# Keys
const TITLE = "title"
const DESCRIPTION = "description"
const IMAGE = "image"
const PACK = "resource_pack"


func export(settings: TGExportSettings) -> void:
	if not is_valid(settings): return
	
	var image = settings.get_image_path().get_file()
	var pack = settings.get_pack_path().get_file()
	
	var cfg = ConfigFile.new()
	cfg.set_value(SECTION, TITLE, settings.title)
	cfg.set_value(SECTION, DESCRIPTION, settings.description)
	cfg.set_value(SECTION, IMAGE, image)
	cfg.set_value(SECTION, PACK, pack)
	
	var path = settings.get_gate_path()
	cfg.save(path)


func is_valid(settings: TGExportSettings) -> bool:
	if settings.title.is_empty():
		printerr("Title is empty")
		return false
	
	if settings.description.is_empty():
		printerr("Description is empty")
		return false
	
	return true
