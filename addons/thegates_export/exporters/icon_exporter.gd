@tool
class_name TGIconExporter
extends Node

var allowed_extensions = ["png", "jpg", "jpeg", "webp", "bmp", "svg"]


func export(settings: TGExportSettings) -> void:
	if not is_valid(settings): return
	
	var path = settings.get_icon_path()
	DirAccess.copy_absolute(settings.icon, path)


func is_valid(settings: TGExportSettings) -> bool:
	if settings.icon.is_empty():
		printerr("Icon is not chosen")
		return false
	
	if not FileAccess.file_exists(settings.icon):
		printerr("Can't open icon")
		return false
	
	if not settings.icon.get_extension() in allowed_extensions:
		printerr("Icon format is not supported")
		return false
	
	return true
