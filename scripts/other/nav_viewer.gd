extends Node3D

const Voxels = preload("res://resources/voxel_block_library.tres")

@export var x_radius:int = 16
@export var y_radius:int = 2
@export var z_radius:int = 16


func _ready() -> void:
	Nav.update_nav_pool()

func grab_surrounds():
	var return_points = []

	for x in range(-x_radius,x_radius):
		for y in range(-y_radius,y_radius):
			for z in range(-z_radius,z_radius):
				if is_inside_tree():
					var block_pos = floor(global_position) + Vector3(x,y,z)
					var voxel_tool = Helper.terrian.get_voxel_tool()
					var voxel_id:int = voxel_tool.get_voxel(block_pos)
					#print("voxel",voxel_id)
					if voxel_id == 0 or voxel_id == Voxels.get_model_index_default("reeds") or voxel_id == Voxels.get_model_index_default("tall_grass") or voxel_id == Voxels.get_model_index_default("tall_flower"):
						var below_voxel_id:int = voxel_tool.get_voxel(block_pos - Vector3(0,1,0))
						if ground(below_voxel_id):
							return_points.append(Vector3(block_pos.x,block_pos.y,block_pos.z))

	return return_points

func ground(voxel_id:int) -> bool:
	if voxel_id == Voxels.get_model_index_default("grass"):
		return true
	if voxel_id == Voxels.get_model_index_default("sand"):
		return true
	elif voxel_id == Voxels.get_model_index_default("stone"):
		return true
	elif voxel_id == Voxels.get_model_index_default("dirt"):
		return true
	else:
		return false

	
