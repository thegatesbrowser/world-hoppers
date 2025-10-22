extends Node

const Voxel_lib = preload("res://resources/voxel_block_library.tres")

const MAX_UPDATES_PER_FRAME = 100
const INTERVAL_SECONDS = 0.1

const _spread_directions = [
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(0, 0, -1),
	Vector3(0, 0, 1),
	Vector3(0, -1, 0)
]


var _terrain_tool:VoxelTool
# TODO An efficient Queue data structure would be NICE
var _update_queue := []
var _process_queue := []
var _process_index := 0
var _scheduled_positions := {}
var _water_id := -1
var _water_top := -1
var _water_full := -1
var _time_before_next_process := 0.0


func _ready():
	_terrain_tool = get_tree().get_first_node_in_group("VoxelTerrain").get_voxel_tool()
	_terrain_tool.set_channel(VoxelBuffer.CHANNEL_TYPE)
	#var water = _blocks.get_block_by_name("water").base_info
	#_water_id = water.id
	_water_full = Voxel_lib.get_model_index_default("water_full")
	_water_top = Voxel_lib.get_model_index_default("water_top")


func schedule(pos: Vector3):
	if _scheduled_positions.has(pos):
		return
	_scheduled_positions[pos] = true
	_update_queue.append(pos)


func _process(delta: float):
	_time_before_next_process -= delta
	if _time_before_next_process <= 0.0:
		_time_before_next_process += INTERVAL_SECONDS
		_do_process_queue()


func _do_process_queue():
	var update_count = 0
	
	if _process_index >= len(_process_queue):
		_process_queue.clear()
		_process_index = 0
		_swap_queues()

	while update_count < MAX_UPDATES_PER_FRAME:
		if _process_index >= len(_process_queue):
			_process_queue.clear()
			_process_index = 0
			#if len(_update_queue) == 0:
			#	# No more work
			#	break
			break
			_swap_queues()

		var pos = _process_queue[_process_index]
		_process_cell(pos)
		_scheduled_positions.erase(pos)
		
		_process_index += 1
		update_count += 1


func _swap_queues():
	var tmp := _update_queue
	_update_queue = _process_queue
	_process_queue = tmp


func _process_cell(pos: Vector3):
	#print(pos)
	var v := _terrain_tool.get_voxel(pos)
	var rm := Voxel_lib.get_type_name_and_attributes_from_model_index(v)
	
	if !water(v):
		# Water got removed in the meantime
		return

	if v == _water_full:
		# Just to make sure the variant is correct
		_fill_with_water.rpc_id(1,pos)
	
	for di in len(_spread_directions):
		var npos = pos + _spread_directions[di]
		var nv = _terrain_tool.get_voxel(npos)
		if nv == Voxel_lib.get_model_index_default("air"):
			_fill_with_water.rpc_id(1,npos)
			schedule(npos)

@rpc("any_peer","call_local")
func _fill_with_water(pos: Vector3):
	var above := pos + Vector3(0, 1, 0)
	var below := pos - Vector3(0, 1, 0)
	var above_v := _terrain_tool.get_voxel(above)
	var below_v := _terrain_tool.get_voxel(below)
	#var above_rm := Voxel_lib.get_type_from_name(above_v)
	# Make sure the top has the surface model
	if water(above_v):
		_terrain_tool.set_voxel(pos, _water_full)
	else:
		_terrain_tool.set_voxel(pos, _water_top)
	if below_v == _water_top:
		_terrain_tool.set_voxel(below, _water_full)
		
		#
func water(v:int):
	var _is_water:bool = false
	if v == _water_full:
		_is_water = true
	if v == _water_top:
		_is_water = true
	return _is_water
