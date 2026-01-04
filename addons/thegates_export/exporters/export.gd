@tool
class_name TGExport
extends Node

var pack_exporter: TGPackExporter
var image_exporter: TGImageExporter
var gate_exporter: TGGateExporter


func _ready() -> void:
	pack_exporter = TGPackExporter.new()
	image_exporter = TGImageExporter.new()
	gate_exporter = TGGateExporter.new()
	add_child(pack_exporter)
	add_child(image_exporter)
	add_child(gate_exporter)


func export_project(settings: TGExportSettings) -> void:
	if pack_exporter.is_in_progress():
		print("Export is still in progress, please wait")
		return
	
	print("\n=================== Starting export ===================")
	pack_exporter.export(settings)
	image_exporter.export(settings)
	gate_exporter.export(settings)
