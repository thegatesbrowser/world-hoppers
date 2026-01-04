@tool
class_name TGPackExporter
extends Node

var preset_creator: TGPresetCreator
var timer: Timer
var pid: int = -1


func _ready() -> void:
	preset_creator = TGPresetCreator.new()
	
	timer = Timer.new()
	timer.one_shot = false
	timer.timeout.connect(check_status)
	add_child(timer)


func export(settings: TGExportSettings) -> void:
	if not is_valid(settings): return
	
	var preset_name = preset_creator.create_and_get_preset()
	var path = settings.get_pack_path()
	var args = ["--headless", "--export-pack", preset_name, path]
	
	print("Execute godot: ", args)
	pid = OS.create_instance(args)
	
	print("Exporting...")
	start_checking_status()


func start_checking_status() -> void:
	timer.start(2)
	check_status()


func check_status() -> void:
	if OS.is_process_running(pid): return
	
	pid = -1
	timer.stop()
	print("Done!")


func is_valid(settings: TGExportSettings) -> bool:
	if settings.export_folder.is_empty():
		printerr("Export folder is not chosen")
		return false
	
	return true


func is_in_progress() -> bool:
	return OS.is_process_running(pid)
