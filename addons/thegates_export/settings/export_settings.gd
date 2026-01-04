@tool
class_name TGExportSettings
extends Resource

@export var title: String
@export var description: String
@export var image: String
@export var export_folder: String

const PACK_NAME = "project.zip"
const IMAGE_NAME = "image.%s"
const GATE_NAME = "project.gate"

var pack_path: String : get = get_pack_path
var image_path: String : get = get_image_path
var gate_path: String : get = get_gate_path


func get_pack_path() -> String:
	return export_folder + "/" + PACK_NAME


func get_image_path() -> String:
	if image.is_empty(): return ""
	
	var ext = image.get_extension()
	return export_folder + "/" + IMAGE_NAME % [ext]


func get_gate_path() -> String:
	return export_folder + "/" + GATE_NAME
