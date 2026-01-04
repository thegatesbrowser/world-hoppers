@tool
class_name TGPrepareFolders
extends Node


static func prepare(settings: TGExportSettings) -> void:
	if not DirAccess.dir_exists_absolute(settings.export_folder):
		DirAccess.make_dir_recursive_absolute(settings.export_folder)
		FileAccess.open(settings.export_folder.path_join(".gdignore"), FileAccess.WRITE).close()
	
	if not DirAccess.dir_exists_absolute(settings.keys_folder):
		DirAccess.make_dir_recursive_absolute(settings.keys_folder)
		FileAccess.open(settings.keys_folder.path_join(".gdignore"), FileAccess.WRITE).close()
