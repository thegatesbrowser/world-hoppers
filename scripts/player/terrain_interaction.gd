extends Node
class_name TerrainInteraction

signal block_broken(type: StringName)

@export var distance: float = 10
@export var camera: Camera3D
@export var block: Node3D
@export var voxel_blocky_type_library: VoxelBlockyTypeLibrary
@export var item_library:ItemsLibrary
@export var ping_label:Label

const AIR_TYPE = 0

var light_ = preload("res://scenes/other/block_light.tscn")
var sound_ = preload("res://scenes/other/block_sound.tscn")

var plants: Array[int]
var terrain: VoxelTerrain
var voxel_tool: VoxelTool

var is_enabled: bool
var block_is_inside_character: bool
var last_hit: VoxelRaycastResult

var last_ping_time: float

var _dirs: Array[Vector3] = [
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

var slot_manager

func _ready() -> void:
	slot_manager = Helper.sound_manager
	
	plants = [voxel_blocky_type_library.get_model_index_default("tall_grass"),voxel_blocky_type_library.get_model_index_default("fern"),voxel_blocky_type_library.get_model_index_default("flower"),voxel_blocky_type_library.get_model_index_default("reeds"),voxel_blocky_type_library.get_model_index_default("tall_flower"),voxel_blocky_type_library.get_model_index_default("wheat"),voxel_blocky_type_library.get_model_index_default("wheat_seed")]

	if is_multiplayer_authority() or Connection.is_server():
		terrain = Helper.terrian
		voxel_tool = terrain.get_voxel_tool()
	else:
		block.visible = false


func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority() or not is_enabled:
		return
	
	var origin = camera.get_global_transform().origin
	var forward = -camera.get_global_transform().basis.z.normalized()
	last_hit = voxel_tool.raycast(origin, forward, distance, 1)

	if last_hit != null:
		
		var target_ = get_type()
		var target_block = voxel_blocky_type_library.get_type_from_name(target_).base_model
		#var aabbs = target_block.base_model.collision_aabbs
		block.scale = target_block.collision_aabbs.front().size
		block.global_position = Vector3(last_hit.position) + target_block.collision_aabbs.front().position + (Vector3.ONE / 2)
		block.global_rotation = Vector3.ZERO
		block.show()
	else:
		block.hide()


func enable() -> void:
	is_enabled = true


func disable() -> void:
	is_enabled = false


func can_place() -> bool:
	return last_hit != null and !block_is_inside_character and Globals.can_build


func can_break() -> bool:
	return last_hit != null


func get_type() -> StringName:
	var voxel: int = voxel_tool.get_voxel(last_hit.position)
	var array: Array = voxel_blocky_type_library.get_type_name_and_attributes_from_model_index(voxel)
	return array[0]


## Places a block with the given type
func place_block(type: StringName, player_pos: Vector3 = Vector3.ZERO) -> void:
	_place_block_server.rpc_id(1, type, last_hit.previous_position, player_pos)
	
	var item = item_library.get_item(type)
	if item == null: return
	
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	
	if item.rotatable:
		## make the block rotation towards the player when placed
		voxel_tool.value = voxel_blocky_type_library.get_model_index_single_attribute(type,get_direction(player_pos,last_hit.previous_position))
	else:
		voxel_tool.value = voxel_blocky_type_library.get_model_index_default(type)
	
	voxel_tool.do_point(last_hit.previous_position)


func break_block() -> void:
	if last_hit == null: return
	
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	voxel_tool.value = AIR_TYPE
	
	var above_voxel:int = voxel_tool.get_voxel(last_hit.position + Vector3i(0,1,0))
	
	var voxel: int = voxel_tool.get_voxel(last_hit.position)
	
	if plants.has(above_voxel):
		voxel_tool.do_point(last_hit.position + Vector3i(0,1,0))
		
	voxel_tool.do_point(last_hit.position)
	
	var soundmanager = Helper.sound_manager
	
	if last_hit != null:
		soundmanager.play_sound(voxel_blocky_type_library.get_type_name_and_attributes_from_model_index(voxel)[0],last_hit.previous_position)
	
	_break_block_server.rpc_id(1, last_hit.position)


@rpc("reliable", "authority")
func _place_block_server(type: StringName, position: Vector3, player_pos: Vector3 = Vector3.ZERO) -> void:
	var item = item_library.get_item(type)
	if item:
		if item.utility:
			if item.utility.portal:
				Globals.create_portal.emit(position)
				open_portal_ui.rpc_id(multiplayer.get_remote_sender_id(),position)
				
	
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	
	if item.light:
		spawn_light.rpc(position,item.light_colour,item.light_energy,item.light_size)
	
	if item.has_sound:
		spawn_sound.rpc(position,item.sound.get_path())
	
	if item.rotatable:
		## make the block rotation towards the player when placed
		voxel_tool.value = voxel_blocky_type_library.get_model_index_single_attribute(type,get_direction(player_pos,position))
	else:
		voxel_tool.value = voxel_blocky_type_library.get_model_index_default(type)
	
	voxel_tool.do_point(position)

@rpc("any_peer","call_local")
func get_voxel_meta(position:Vector3):
	var meta = voxel_tool.get_voxel_metadata(position)
	print("meta ", meta)
	get_parent().rpc_id(multiplayer.get_remote_sender_id(),"receive_meta",meta,voxel_tool.get_voxel(position),position)
	

@rpc("reliable", "authority")
func _break_block_server(position: Vector3) -> void:
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	voxel_tool.value = AIR_TYPE
	
	var above_voxel:int = voxel_tool.get_voxel(position + Vector3(0,1,0))
	
	var voxel: int = voxel_tool.get_voxel(position)
	
	if plants.has(above_voxel):
		voxel_tool.do_point(position + Vector3(0,1,0))
		
	voxel_tool.do_point(position)
	
	var array = voxel_blocky_type_library.get_type_name_and_attributes_from_model_index(voxel)
	
	if array[0] != "air":
		var item = item_library.get_item(array[0])
		
		# if no other drop items drop itself
		if item.drop_items.is_empty():
			send_item.rpc_id(multiplayer.get_remote_sender_id(),array[0])
			
		# can drop other items not only it self
		for drop_item in item.drop_items:
			send_item.rpc_id(multiplayer.get_remote_sender_id(),drop_item)
		
		if item.light:
			destory_light.rpc(position)
			
		if item.has_sound:
			destory_sound.rpc(position)
		
		if item.utility != null:
			if item.utility.has_ui:
				voxel_tool.set_voxel_metadata(position,null)
				
			elif item.utility.portal:
				Globals.remove_portal_data.emit(position)
				
			elif item.utility.spawn_point:
				remove_spawn_point.rpc(position)
				
	for di in len(_dirs):
		var npos := position + _dirs[di]
		var nv := voxel_tool.get_voxel(npos)
		if water(nv):
			var water_m = get_tree().get_first_node_in_group("Water Updater")
			water_m.schedule(npos)
		
	_block_broken_local.rpc_id(get_multiplayer_authority(), array[0])


@rpc("reliable", "any_peer")
func _block_broken_local(type: StringName) -> void:
	block_broken.emit(type)


func _on_Area_body_entered(_body: Node3D) -> void:
	block_is_inside_character = true


func _on_Area_body_exited(_body: Node3D) -> void:
	block_is_inside_character = false


@rpc("any_peer","call_remote")
func send_item(type: StringName) -> void:
	var slot_manager = Helper.slot_manager
	## if the player is holding a tool it will be damaged
	if slot_manager.selected_slot != null:
		if slot_manager.selected_slot.item != null:
			if slot_manager.selected_slot.item is ItemTool:
				slot_manager.selected_slot.used()
						
	## gives the broken item to the player
	var item = item_library.get_item(type)
	if item:
	#Globals.spawn_item_inventory.emit(item)
		slot_manager.add_item_to_hotbar_or_inventory(item)


@rpc("any_peer","call_local")
func open_portal_ui(id: Vector3) -> void:
	Globals.open_portal_url.emit(id)
	pass

@rpc("any_peer","call_local")
func remove_spawn_point(pos: Vector3) -> void:
	var player = get_parent().get_parent() as Player
	if player.spawn_position == pos + Vector3(0,1,0):
		player.spawn_position = player.start_position

func water(v:int):
	var _is_water:bool = false
	if v == voxel_blocky_type_library.get_model_index_default("water_full"):
		_is_water = true
	if v ==  voxel_blocky_type_library.get_model_index_default("water_top"):
		_is_water = true
	return _is_water

func get_direction(player_pos:Vector3, place_pos:Vector3):
	var dir = place_pos.direction_to(player_pos)
	print(dir)
	
	if round(dir).x != 0:
		if round(dir).x == 1:
			return VoxelBlockyAttributeDirection.DIR_NEGATIVE_X
		else:
			return VoxelBlockyAttributeDirection.DIR_POSITIVE_X
			
	elif round(dir).z != 0:
		if round(dir).z == 1:
			return VoxelBlockyAttributeDirection.DIR_NEGATIVE_Z
		else:
			return VoxelBlockyAttributeDirection.DIR_POSITIVE_Z


@rpc("any_peer","call_local")
func spawn_light(pos: Vector3,color:Color,energy:float, size:float = 5.0) -> void:
	var light = light_.instantiate()
	light.position = pos + Vector3(0.5,0.5,0.5)
	light.light_color = color
	light.light_energy = energy
	light.light_size = size
	var light_container = Helper.light_container
	light_container.add_child(light)

@rpc("any_peer","call_local")
func destory_light(pos:Vector3):
	var find_pos = pos + Vector3(0.5,0.5,0.5)
	var light_container = Helper.light_container
	for light in light_container.get_children():
		print("light check for ",find_pos, "light pos ",light.global_position)
		if light.global_position == find_pos:
			light.queue_free()

@rpc("any_peer","call_local")
func destory_sound(pos:Vector3):
	var find_pos = pos
	var sound_container = Helper.sound_container
	for sound in sound_container.get_children():
		if sound.position == find_pos:
			sound.queue_free()

@rpc("any_peer","call_local")
func spawn_sound(pos:Vector3, sound:String) -> void:
	var _sound = sound_.instantiate() as AudioStreamPlayer3D
	_sound.stream = load(sound)
	_sound.position = pos 
	var sound_container = Helper.sound_container
	sound_container.add_child(_sound)
	
