@tool
extends EditorPlugin

const AUTOLOAD_NAME := "Console"
const AUTOLOAD_PATH := "res://addons/dev_console/dev_console.tscn"

func _enter_tree():
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree():
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
