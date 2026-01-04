@tool
class_name TGFileDialog
extends Control

signal dir_selected(dir: String)
signal file_selected(path: String)
signal files_selected(paths: PackedStringArray)

@export var file_mode: EditorFileDialog.FileMode
@export var access: EditorFileDialog.Access
@export var filters: PackedStringArray
@export var minsize: Vector2i

var fileDialog : EditorFileDialog


func _ready() -> void:
	fileDialog = EditorFileDialog.new()
	fileDialog.file_mode = file_mode
	fileDialog.access = access
	fileDialog.filters = filters
	
	fileDialog.dir_selected.connect(func(dir): dir_selected.emit(dir))
	fileDialog.file_selected.connect(func(path): file_selected.emit(path))
	fileDialog.files_selected.connect(func(paths): files_selected.emit(paths))


func open_file_dialog() -> void:
	if not is_instance_valid(fileDialog.get_parent()):
		EditorInterface.popup_dialog_centered(fileDialog, minsize)
	else:
		fileDialog.popup_centered(minsize)
