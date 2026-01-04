@tool
extends Control
class_name TGExportResult

const URL_TEXT = "Open this url in [url=https://thegates.io/]TheGates app[/url]"
const FOLDER_TEXT = "Project exported to this folder"

@export var settings: TGExportSettings
@export var rich_text_label: RichTextLabel
@export var line_edit: LineEdit
@export var button: Button

var copy_icon: Texture2D
var folder_icon: Texture2D


func _ready() -> void:
	visible = false
	line_edit.text = ""
	button.pressed.connect(on_button_pressed)

	copy_icon = EditorInterface.get_base_control().get_theme_icon(&"ActionCopy", &"EditorIcons")
	folder_icon = EditorInterface.get_base_control().get_theme_icon(&"Load", &"EditorIcons")


func update_result() -> void:
	if settings.export_locally:
		set_folder()
		button.add_theme_icon_override("icon", folder_icon)
	else:
		set_url(settings.published_url)
		button.add_theme_icon_override("icon", copy_icon)


func set_url(url: String) -> void:
	visible = not url.is_empty()
	line_edit.text = url
	rich_text_label.text = URL_TEXT


func set_folder() -> void:
	visible = FileAccess.file_exists(settings.get_pack_path())
	line_edit.text = settings.export_folder
	rich_text_label.text = FOLDER_TEXT


func on_button_pressed() -> void:
	if settings.export_locally:
		OS.shell_open(line_edit.text)
	else:
		DisplayServer.clipboard_set(line_edit.text)
