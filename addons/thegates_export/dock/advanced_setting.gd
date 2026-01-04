@tool
extends Control
class_name AdvancedSetting

@export var settings: TGExportSettings


func _ready() -> void:
	visible = settings.advanced_settings
	settings.advanced_settings_changed.connect(func(enabled: bool): visible = enabled)
