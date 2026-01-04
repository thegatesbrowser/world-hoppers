@tool
extends EditorPlugin

const DOCK_TSCN = "res://addons/thegates_export/dock/dock.tscn"
const EXPORT_GD = "res://addons/thegates_export/exporters/export.gd"

var dock: Control


func _enter_tree():
	dock = load(DOCK_TSCN).instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
