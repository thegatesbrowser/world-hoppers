@tool
extends EditorPlugin

var dock: Control

func _enter_tree():
	# Load dock scene
	dock = load("res://addons/mod_packer/mod_packer_ui.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	print("Mod Packer Plugin loaded")

func _exit_tree():
	remove_control_from_docks(dock)
	dock.queue_free()
