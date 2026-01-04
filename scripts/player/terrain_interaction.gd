extends Node
class_name TerrainInteraction

signal block_broken(type: StringName)


@onready var CrackOverlay:Node3D = $BlockOutline/CrackOverlay
@export var distance: float = 10
@export var camera: Camera3D
@export var block: Node3D
@export var interaction_icon:TextureRect
@export var ping_label:Label

const AIR_TYPE = 0

var light_ = preload("res://scenes/other/block_light.tscn")
var sound_ = preload("res://scenes/other/block_sound.tscn")

var plants: Array[int]
var terrain
var voxel_tool: VoxelTool

var block_is_inside_character: bool
var last_hit: VoxelRaycastResult
var mine_timer: Timer
var eat_timer: Timer
var mining_block:Vector3i

@export var voxel_blocky_type_library: VoxelBlockyTypeLibrary
@export var item_library:ItemsLibrary

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
	
	#plants = [voxel_blocky_type_library.get_model_index_default("tall_grass"),voxel_blocky_type_library.get_model_index_default("fern"),voxel_blocky_type_library.get_model_index_default("flower"),voxel_blocky_type_library.get_model_index_default("reeds"),voxel_blocky_type_library.get_model_index_default("tall_flower"),voxel_blocky_type_library.get_model_index_default("wheat"),voxel_blocky_type_library.get_model_index_default("wheat_seed")]

	terrain = get_tree().get_first_node_in_group("VoxelTerrain")
	voxel_tool = terrain.get_voxel_tool()
	#block.visible = false
	
	mine_timer = Timer.new()
	mine_timer.one_shot = true
	add_child(mine_timer)
	mine_timer.timeout.connect(_break_block)
	
	eat_timer = Timer.new()
	eat_timer.one_shot = true
	add_child(eat_timer)
	

func _process(delta: float) -> void:
	if not is_multiplayer_authority() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	
	var origin = camera.get_global_transform().origin
	var forward = -camera.get_global_transform().basis.z.normalized()
	last_hit = voxel_tool.raycast(origin, forward, distance, 1)

	if last_hit != null:
		
		if is_interactable():
			interaction_icon.show()
		else:
			interaction_icon.hide()
		
		if Input.is_action_just_pressed("Mine"):
			if !owner.crouching:
				if is_interactable():
					interaction()
					
		if Input.is_action_pressed("Mine") and !is_interactable():
			var current_slot = Helper.hotbar.get_current()
			var current_item:ItemBase = current_slot.item
		
			if last_hit != null:
				if not mine_timer.is_stopped():
					if mining_block != last_hit.position:
						mine_timer.stop()
						CrackOverlay.stop()
						
				if mine_timer.is_stopped():
					mining_block = last_hit.position
					var breaking_block:String = get_type()
					
					var item:ItemBase = item_library.get_item(breaking_block)
					var break_time:float
					
					if item:
						var base_break_time:float = item.break_time
						var reduction:float
						
						if current_item != null:
							
							if current_item is ItemTool:
								if current_item.suitable_blocks.has(breaking_block):
									reduction = current_item.breaking_efficiency
						
						break_time = base_break_time - reduction
						
						if break_time <= 0:
							CrackOverlay.stop()
							
							#remove + items
							terrain._break_block_server(last_hit.position)
						
						CrackOverlay.start_break(break_time)
						
						mine_timer.wait_time = break_time
						#print(break_time,":base_break_time ",base_break_time," reduction ",reduction," timer ",mine_timer.wait_time)
						mine_timer.start()
						
		else:
			CrackOverlay.stop()
			
		if Input.is_action_just_pressed("Build"):
			if can_place():
				if Globals.can_build:
					
					Helper.sound_manager.play_sound(Globals.current_block,last_hit.previous_position)
					var player_pos = get_parent().global_position
					terrain._place_block_server(Globals.current_block,last_hit.previous_position,player_pos)
					Globals.remove_item_from_hotbar.emit()
			
		var type = get_type()
		var target_block = voxel_blocky_type_library.get_type_from_name(type).base_model
		block.scale = target_block.collision_aabbs.front().size
		block.global_position = Vector3(last_hit.position) + target_block.collision_aabbs.front().position + (Vector3.ONE / 2)
		block.global_rotation = Vector3.ZERO
		block.show()
	else:
		interaction_icon.hide()
		block.hide()

func _break_block():
	if last_hit != null:
		if Input.is_action_pressed("Mine"):
			#print("break_overlay")
			CrackOverlay.stop()
			#server remove + items
			terrain._break_block_server(last_hit.position)
	
func can_place() -> bool:
	return last_hit != null and !block_is_inside_character and Globals.can_build


func can_break() -> bool:
	return last_hit != null


func get_type() -> StringName:
	var voxel: int = voxel_tool.get_voxel(last_hit.position)
	var array: Array = voxel_blocky_type_library.get_type_name_and_attributes_from_model_index(voxel)
	return array[0]


	
func _on_Area_body_entered(_body: Node3D) -> void:
	block_is_inside_character = true


func _on_Area_body_exited(_body: Node3D) -> void:
	block_is_inside_character = false

func open_portal_ui(id: Vector3) -> void:
	Globals.open_portal_url.emit(id)
	pass


func remove_spawn_point(pos: Vector3) -> void:
	var player = get_parent().get_parent() as Player
	if player.spawn_position == pos + Vector3(0,1,0):
		player.spawn_position = player.start_position

func is_interactable() -> bool:
	if last_hit == null: return false
	
	var type = get_type()
	
	if type == "air": return false
	
	var item = item_library.get_item(type)
	
	if item == null:
		return false
		
	if item.utility != null:
		return true
	else:
		return false
		
func interaction() -> void:
	if last_hit == null: return
	
	var type = get_type()
	
	if type == "air": return
	
	var item = item_library.get_item(type)

	if item != null:
		if item.utility != null:
			if item.utility.has_ui:
				print("ui")
				terrain.get_voxel_meta(last_hit.position,self.get_path())
				
			if item.utility.spawn_point:
				get_parent().spawn_position = last_hit.position + Vector3i(0,1,0)
				print_debug("spawn point set ",get_parent().spawn_position)
			
			if item.utility.portal:
				terrain.get_voxel_meta(last_hit.position,self.get_path())

@rpc("any_peer","call_local")
func receive_meta(meta_data, type:int, voxel_position:Vector3):
	var item_name = voxel_blocky_type_library.get_type_name_and_attributes_from_model_index(type)[0]
	var item = item_library.get_item(item_name)
		
	#print("receive ",meta_data, "type ",type)
	if type == voxel_blocky_type_library.get_model_index_default("portal"):
		Globals.enter_portal.emit(meta_data)
		
	if item_name == "chest":
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		#print("chest")
		#print("open ",voxel_position)
		Globals.open_ui.emit(item.utility.ui_scene_path,voxel_position, meta_data)
	
	if item_name == "cooker":
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		#print("cooker")
		#print("open ",voxel_position)
		Globals.open_ui.emit(item.utility.ui_scene_path,voxel_position,meta_data)
		
	if item_name == "blueprint_station":
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		print(voxel_position)
		Globals.open_ui.emit(item.utility.ui_scene_path,voxel_position,null)
