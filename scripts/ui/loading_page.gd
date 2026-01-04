extends Control

@export var itemLIB: ItemsLibrary
@export var scene: PackedScene
@export var loading_bar: ProgressBar

func _ready() -> void:
	#itemLIB.init_items()
	#ItemDownloader.completed_download.connect(construct_voxelLib)
	Backend.playerdata_updated.connect(start_scene)

func _process(delta):
	if loading_bar.value < 100:
		loading_bar.value += delta * 10
	else:
		loading_bar.value = 0
	
func start_scene() -> void:
	get_tree().call_deferred("change_scene_to_packed", scene)
	pass
	
func download_items():
	ItemDownloader.fetch_all_jsons()
	
func construct_voxelLib():
	var voxel_lib:VoxelBlockyTypeLibrary = load("res://resources/voxel_block_library.tres")
	
	var types = voxel_lib.get_types()
	#print(types.size())
	for item in itemLIB.block_items:
		var voxel:VoxelBlockyType = item.voxel
		if voxel:
			if not types.has(voxel):
				types.append(voxel)
				print("added ",voxel.unique_name," to the voxel LIB")
				
	#print(types.size())
	voxel_lib.set_types(types)
	
	await get_tree().create_timer(2.0).timeout
	start_scene()
	#print(voxel_lib.get_types().size())
		#if not types.has(voxel.unique_name):
			#v#oxel_lib.set()
		
