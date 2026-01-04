@tool
extends EditorPlugin

const DOCK_TSCN = "res://addons/thegates_export/dock/dock.tscn"
const EXPORT_GD = "res://addons/thegates_export/exporters/export.gd"

var dock: Control


func _enter_tree():
	scene_saved.connect(on_scene_saved)
	add_dock()


func _exit_tree():
	if scene_saved.is_connected(on_scene_saved):
		scene_saved.disconnect(on_scene_saved)
	remove_dock()


func on_scene_saved(scene_path: String):
	if scene_path == DOCK_TSCN:
		remove_dock()
		add_dock()


func add_dock():
	dock = load(DOCK_TSCN).instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	call_deferred("activate_dock_tab")


func remove_dock():
	if is_instance_valid(dock):
		remove_control_from_docks(dock)
		dock.free()
	
	dock = null


func activate_dock_tab():
	if not is_instance_valid(dock):
		return

	var tab_container: Node = dock.get_parent()
	while tab_container and not (tab_container is TabContainer):
		tab_container = tab_container.get_parent()

	if tab_container and tab_container is TabContainer:
		var tab_container_tc := tab_container as TabContainer
		var tab_count := tab_container_tc.get_tab_count()
		for i in tab_count:
			if tab_container_tc.get_tab_control(i) == dock:
				tab_container_tc.current_tab = i
				return
