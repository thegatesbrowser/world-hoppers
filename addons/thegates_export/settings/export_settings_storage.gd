@tool
class_name TGExportSettingsBackup
extends Node

const STORAGE_DIR = "user://thegates_export"
const SETTINGS_FILE = "export_settings.tres"
const TOKEN_FILE = "publish.key"

@export var settings: TGExportSettings

var storage_dir: String = ProjectSettings.globalize_path(STORAGE_DIR)
var settings_backup_path: String = storage_dir + "/" + SETTINGS_FILE
var token_backup_path: String = storage_dir + "/" + TOKEN_FILE


func load_settings() -> void:
	if not settings.changed.is_connected(save_settings):
		settings.changed.connect(save_settings)
	if not DirAccess.dir_exists_absolute(storage_dir):
		DirAccess.make_dir_recursive_absolute(storage_dir)
	
	if not settings.fresh_install: return
	
	print("Restoring export settings from backup...")
	TGPrepareFolders.prepare(settings)
	restore_settings()
	restore_token()
	
	settings.fresh_install = false


func restore_settings() -> void:
	if not FileAccess.file_exists(settings_backup_path): return
	
	var resource := ResourceLoader.load(settings_backup_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null or not resource is TGExportSettings: return
	
	var backup := resource as TGExportSettings
	settings.title = backup.title
	settings.description = backup.description
	settings.icon = backup.icon
	settings.image = backup.image
	settings.discoverable = backup.discoverable
	settings.advanced_settings = backup.advanced_settings
	settings.export_locally = backup.export_locally
	settings.tos_accepted = backup.tos_accepted


func save_settings() -> void:
	var duplicate_settings := settings.duplicate(true)
	ResourceSaver.save(duplicate_settings, settings_backup_path)


func restore_token() -> void:
	if not FileAccess.file_exists(token_backup_path): return
	DirAccess.copy_absolute(token_backup_path, settings.token_path)


## Saved from project_publisher.gd
static func save_token(settings: TGExportSettings) -> void:
	var path = ProjectSettings.globalize_path(STORAGE_DIR + "/" + TOKEN_FILE)
	DirAccess.copy_absolute(settings.token_path, path)
