@tool
extends Button

@export var settings: TGExportSettings

var tgExport: TGExport


func _ready() -> void:
	tgExport = TGExport.new()
	add_child(tgExport)
	
	button_up.connect(export)


func export() -> void:
	tgExport.export_project(settings)
