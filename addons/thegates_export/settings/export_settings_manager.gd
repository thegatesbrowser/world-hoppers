@tool
extends Node

@export var settings: TGExportSettings
@export var backup: TGExportSettingsBackup

@export var title: LineEdit
@export var description: LineEdit
@export var icon: LineEdit
@export var image: LineEdit
@export var icon_fd: TGFileDialog
@export var image_fd: TGFileDialog
@export var discoverable: CheckBox

@export var advanced_settings: CheckButton
@export var export_locally: CheckButton
@export var tos_accepted: CheckBox


func _ready() -> void:
	settings.save_on_changed()
	backup.load_settings()
	set_initial()
	
	title.text_changed.connect(func(text): settings.title = text)
	description.text_changed.connect(func(text): settings.description = text)
	icon.text_changed.connect(func(text): settings.icon = text)
	icon_fd.file_selected.connect(func(path): settings.icon = path)
	image.text_changed.connect(func(text): settings.image = text)
	image_fd.file_selected.connect(func(path): settings.image = path)
	discoverable.toggled.connect(func(toggled_on): settings.discoverable = toggled_on)
	advanced_settings.toggled.connect(func(toggled_on): settings.advanced_settings = toggled_on)
	export_locally.toggled.connect(func(toggled_on): settings.export_locally = toggled_on)
	tos_accepted.toggled.connect(func(toggled_on): settings.tos_accepted = toggled_on)


func set_initial() -> void:
	title.text = settings.title
	description.text = settings.description
	icon.text = settings.icon
	image.text = settings.image
	discoverable.button_pressed = settings.discoverable
	advanced_settings.button_pressed = settings.advanced_settings
	export_locally.button_pressed = settings.export_locally
	tos_accepted.button_pressed = settings.tos_accepted
	
	title.text_changed.emit(title.text)
	description.text_changed.emit(description.text)
	icon.text_changed.emit(icon.text)
	image.text_changed.emit(image.text)
	discoverable.toggled.emit(settings.discoverable)
	advanced_settings.toggled.emit(settings.advanced_settings)
	export_locally.toggled.emit(settings.export_locally)
	tos_accepted.toggled.emit(settings.tos_accepted)
