extends Node


@export var terrain_interaction:TerrainInteraction
@export var items_library: ItemsLibrary
@export var voxel_library = preload("res://resources/voxel_block_library.tres")
@export var floor_ray:RayCast3D
@export var drop_item_scene:PackedScene
@export var item_holder:Node3D
@export var interactable_icon:TextureRect
@export var break_block:Node3D

var eat_timer: Timer


var mining_block:Vector3i

func _ready():
	items_library.init_items(true)
	Globals.drop_item.connect(drop)
	terrain_interaction.enable()
	

func drop(owner_id: int ,item: ItemBase ,amount := 1) -> void:
	print("drop")
	if get_multiplayer_authority() != owner_id: return
	print(get_multiplayer_authority(), " is ", owner_id)
	if floor_ray.is_colliding():
		var pos = floor_ray.get_collision_point()
		
		sync_drop.rpc_id(1,item.resource_path,pos,amount)


@rpc("any_peer","call_local")
func sync_drop(item_path: String, pos: Vector3 ,amount := 1) -> void:
	Globals.add_object.emit([1,pos,"res://scenes/items/dropped_item.tscn",item_path,amount])
