# Implements random cellular automata behavior of the terrain,
# such as growth of grass and crops, fire etc.
extends Node

const ItemLib = preload('res://resources/Items.tres')
const VoxelLibraryResource = preload("res://resources/voxel_block_library.tres")

# Takes effect in a large radius around the player
const RADIUS = 100
# How many voxels are affected per frame
const VOXELS_PER_FRAME = 500

@onready var _terrain : VoxelTerrain
@onready var _voxel_tool : VoxelToolTerrain
@onready var _players_container : Node3D

var rng = RandomNumberGenerator.new()
@export var burnables: Array[int]
var plant_voxels = []


var water_dirs: Array[Vector3i] = [
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(0, 0, -1),
	Vector3(0, 0, 1),
	Vector3(-1, 0, -1),
	Vector3(1, 0, -1),
	Vector3(-1, 0, 1),
	Vector3(1, 0, 1),

	Vector3(-1, -1, 0),
	Vector3(1, -1, 0),
	Vector3(0, -1, -1),
	Vector3(0, -1, 1),
	Vector3(-1, -1, -1),
	Vector3(1, -1, -1),
	Vector3(-1, -1, 1),
	Vector3(1, -1, 1)
]


var _grass_dirs: Array[Vector3i] = [
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(0, 0, -1),
	Vector3(0, 0, 1),
	Vector3(-1, 0, -1),
	Vector3(1, 0, -1),
	Vector3(-1, 0, 1),
	Vector3(1, 0, 1),
	
	Vector3(-1, 1, 0),
	Vector3(1, 1, 0),
	Vector3(0, 1, -1),
	Vector3(0, 1, 1),
	Vector3(-1, 1, -1),
	Vector3(1, 1, -1),
	Vector3(-1, 1, 1),
	Vector3(1, 1, 1),

	Vector3(-1, -1, 0),
	Vector3(1, -1, 0),
	Vector3(0, -1, -1),
	Vector3(0, -1, 1),
	Vector3(-1, -1, -1),
	Vector3(1, -1, -1),
	Vector3(-1, -1, 1),
	Vector3(1, -1, 1)
]

var _fire_dirs: Array[Vector3i] = [
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(0, 0, -1),
	Vector3(0, 0, 1),
	Vector3(-1, 0, -1),
	Vector3(1, 0, -1),
	Vector3(-1, 0, 1),
	Vector3(1, 0, 1),
	
	Vector3(-1, 1, 0),
	Vector3(1, 1, 0),
	Vector3(0, 1, -1),
	Vector3(0, 1, 1),
	Vector3(-1, 1, -1),
	Vector3(1, 1, -1),
	Vector3(-1, 1, 1),
	Vector3(1, 1, 1),

	Vector3(-1, -1, 0),
	Vector3(1, -1, 0),
	Vector3(0, -1, -1),
	Vector3(0, -1, 1),
	Vector3(-1, -1, -1),
	Vector3(1, -1, -1),
	Vector3(-1, -1, 1),
	Vector3(1, -1, 1),
	
	Vector3(0,-1,0),
	Vector3(0,1,0),
]

func _init() -> void:
	ItemLib.init_items()

func _ready():
	if not Connection.is_server(): return
		
	plant_voxels = [VoxelLibraryResource.get_model_index_default("tall_grass"),VoxelLibraryResource.get_model_index_default("flower"),VoxelLibraryResource.get_model_index_default("tall_flower")]
	_terrain = get_tree().get_first_node_in_group("VoxelTerrain")
	_voxel_tool = _terrain.get_voxel_tool()
	_players_container = get_tree().get_first_node_in_group("PlayerContainer")
	#print("random ticker start", _terrain,_voxel_tool,_players_container)
	_voxel_tool.set_channel(VoxelBuffer.CHANNEL_TYPE)


func _process(_unused_delta: float) -> void:
	if not Connection.is_server(): return
	#var time_before = OS.get_ticks_usec()

	_grass_dirs.shuffle()

	# TODO Run random tick only once in areas where multiple players overlap!
	for i in _players_container.get_child_count():
		var character : Player = _players_container.get_child(i)
		var center : Vector3 = character.position.floor()
		var r := RADIUS
		var area := AABB(center - Vector3(r, r, r), 2 * Vector3(r, r, r))
		_voxel_tool.run_blocky_random_tick(area, VOXELS_PER_FRAME, _random_tick_callback, 16)

	#var time_spent = OS.get_ticks_usec() - time_before
	#print("Spent ", time_spent)
	
func burnable(raw_type: int) -> bool:
	return raw_type != 0 and burnables.has(raw_type)
	
func _makes_grass_die(raw_type: int) -> bool:
	return raw_type != 0 and not plant_voxels.has(raw_type)


func _random_tick_callback(pos: Vector3i, value: int) -> void:
	#print(value)
	var type = VoxelLibraryResource.get_type_name_and_attributes_from_model_index(value)[0]

	if ItemLib.types.has(type) == false: return
	var item = ItemLib.get_item(type)
	
	if value == VoxelLibraryResource.get_model_index_default("grass"):
		var above := pos + Vector3i(0, 1, 0)
		var above_v := _voxel_tool.get_voxel(above)
		#print("above ", above_v)
		#print(_makes_grass_die(above_v))
		if _makes_grass_die(above_v):
			# Turn to dirt
			_voxel_tool.set_voxel(pos,VoxelLibraryResource.get_model_index_default("dirt"))
			_terrain.save_block(pos)
		else:
			# Spread
			var attempts := 1
			var ra := randf()
			if ra < 0.15:
				attempts = 2
				if ra < 0.03:
					attempts = 3
	
			for i in attempts:
				for di in len(_grass_dirs):
					var npos := pos + _grass_dirs[di]
					var nv := _voxel_tool.get_voxel(npos)
					if nv == VoxelLibraryResource.get_model_index_default("dirt"):
						var above_neighbor := _voxel_tool.get_voxel(npos + Vector3i(0, 1, 0))
						if not _makes_grass_die(above_neighbor):
							_voxel_tool.set_voxel(npos, VoxelLibraryResource.get_model_index_default("grass"))
							_terrain.save_block(npos)
							break
	
	if value == VoxelLibraryResource.get_model_index_default("fire"):
		var above := pos + Vector3i(0, 1, 0)
		var above_v := _voxel_tool.get_voxel(above)
		# Spread
		var attempts := 8

		for i in attempts:
			for di in len(_fire_dirs):
				var npos := pos + _fire_dirs[di]
				var nv := _voxel_tool.get_voxel(npos)
				if burnable(nv):
					var above_neighbor := _voxel_tool.get_voxel(npos + Vector3i(0, 1, 0))
					_voxel_tool.set_voxel(npos, VoxelLibraryResource.get_model_index_default("fire"))
					_terrain.save_block(npos)
					break
					
		## gets rid of the fire if no surroundings
		var found_burnable:bool = false
		for di in len(_fire_dirs):
			var npos := pos + _fire_dirs[di]
			var nv := _voxel_tool.get_voxel(npos)
			if burnable(nv):
				found_burnable = true
				
		if found_burnable == false:
			_voxel_tool.set_voxel(pos, VoxelLibraryResource.get_model_index_default("air"))
	
	
	#print(value)
	if item is ItemPlant:
		var above := pos + Vector3i(0, 1, 0)
		var above_v := _voxel_tool.get_voxel(above)
		# Spread
		var rng = RandomNumberGenerator.new()
		#print("plant")
		if rng.randf() < 0.4:
			if item.next_plant_stage != null:
				
				var new_voxel = item.next_plant_stage.unique_name
				_voxel_tool.set_voxel(pos, VoxelLibraryResource.get_model_index_default(new_voxel))
			
		
	#if water(value):
		#print("water")
		#for di in len(water_dirs):
			#var npos := pos + water_dirs[di]
			#var nv := _voxel_tool.get_voxel(npos)
			#if nv == VoxelLibraryResource.get_model_index_default("air"):
				#var above_neighbor := _voxel_tool.get_voxel(npos + Vector3i(0, 1, 0))
				#if water(above_neighbor):
					#_voxel_tool.set_voxel(npos, VoxelLibraryResource.get_model_index_default("water_full"))
				#else:
					#_voxel_tool.set_voxel(npos, VoxelLibraryResource.get_model_index_default("water_top"))
				#
				#_terrain.save_block(npos)
		#
		
func water(v:int):
	var _is_water:bool = false
	if v == VoxelLibraryResource.get_model_index_default("water_full"):
		_is_water = true
	if v == VoxelLibraryResource.get_model_index_default("water_top"):
		_is_water = true
	return _is_water
