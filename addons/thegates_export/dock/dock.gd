@tool
extends Control

@export var settings: TGExportSettings
@export var tos_container: Control
@export var export_button: Button
@export var delete_button: Button
@export var delete_button_container: Control
@export var export_result: TGExportResult

var tgExport: TGExport


func _ready() -> void:
	tgExport = TGExport.new()
	add_child(tgExport)
	
	update_info()
	check_project()
	
	export_button.pressed.connect(export)
	delete_button.pressed.connect(delete)
	settings.export_locally_changed.connect(func(_enabled): update_info())
	settings.tos_accepted_changed.connect(func(_accepted): update_info())


func export() -> void:
	await tgExport.export_project(settings)
	update_info()


func check_project() -> void:
	await tgExport.check_project(settings)
	update_info()


func delete() -> void:
	await tgExport.delete_project(settings)
	update_info()


func update_info() -> void:
	export_result.update_result()
	
	if settings.export_locally:
		export_button.disabled = false
		export_button.text = "Export to local folder"
		delete_button_container.visible = false
		tos_container.visible = false
	else:
		var show_tos = not settings.tos_accepted and settings.published_url.is_empty()
		tos_container.visible = show_tos
		export_button.disabled = show_tos
		export_button.text = "Publish to TheGates" if settings.published_url.is_empty() else "Update project"
		delete_button_container.visible = not settings.published_url.is_empty()
