@tool
class_name TGImageExporter
extends Node

var allowed_extensions = ["png", "jpg", "jpeg", "webp", "bmp"]


func export(settings: TGExportSettings) -> void:
	if not is_valid(settings): return
	
	var path = settings.get_image_path()
	DirAccess.copy_absolute(settings.image, path)


func is_valid(settings: TGExportSettings) -> bool:
	if settings.image.is_empty():
		printerr("Thumbnail image is not chosen")
		return false
	
	if not FileAccess.file_exists(settings.image):
		printerr("Can't open thumbnail image")
		return false
	
	if not settings.image.get_extension() in allowed_extensions:
		printerr("Thumbnail image format is not supported")
		return false
	
	return true
