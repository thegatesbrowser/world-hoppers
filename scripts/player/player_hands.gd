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
var mine_timer: Timer

var mining_block:Vector3i

func _ready():
	items_library.init_items(true)
	Globals.drop_item.connect(drop)
	terrain_interaction.enable()
	
	mine_timer = Timer.new()
	mine_timer.one_shot = true
	add_child(mine_timer)
	
	eat_timer = Timer.new()
	eat_timer.one_shot = true
	add_child(eat_timer)


func _process(_delta: float) -> void:
	if not is_multiplayer_authority() and Connection.is_peer_connected: return
	if Globals.paused: return
	
	if is_interactable():
		interactable_icon.show()
	else:
		interactable_icon.hide()
	
	if Input.is_action_just_pressed("Build"):
		if terrain_interaction.can_place():
			if Globals.can_build:
				
				Helper.sound_manager.play_sound(Globals.current_block,terrain_interaction.last_hit.position)
				var player_pos = get_parent().global_position
				terrain_interaction.place_block(Globals.current_block,player_pos)
				Globals.remove_item_from_hotbar.emit()
				
		if Input.is_action_pressed("Build"):
			if eat_timer.is_stopped():
				if Helper.slot_manager.selected_slot != null:
					var item =  Helper.slot_manager.selected_slot.item
					if item is ItemFood:
						
						eat_timer.wait_time = item.eat_time
						eat_timer.name = "food eat timer"
						eat_timer.start()
						
						#if hand_ani.current_animation != "eat":
								#hand_ani.play("eat")
								
						await eat_timer.timeout
						
						if Input.is_action_pressed("Build"):
							#eat_sfx.play()
							
							if item != null:
								Globals.hunger_points_gained.emit(item.food_points)
								print("ate ", item.unique_name, " gained ", item.food_points," food points")
								Globals.remove_item_from_hotbar.emit()
								Globals.remove_item_in_hand.emit()
								#hand_ani.stop()
			

	if Input.is_action_just_pressed("Mine"):
		if !get_parent().crouching:
			interaction() ## checks for interactions
			if is_interactable(): return
				
	if Input.is_action_pressed("Mine"):
		var current_slot = Helper.hotbar.get_current()
		var current_item:ItemBase = current_slot.item
	
		if terrain_interaction.last_hit != null:
			if not mine_timer.is_stopped():
				if mining_block != terrain_interaction.last_hit.position:
					mine_timer.stop()
					mine_timer.disconnect("timeout",Callable(self,"_break_block"))
					break_block.stop()
					
			if mine_timer.is_stopped():
				mining_block = terrain_interaction.last_hit.position
				var breaking_block:String = terrain_interaction.get_type()
				
				var item:ItemBase = items_library.get_item(breaking_block)
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
						_break_block(breaking_block)
					
					break_block.start_break(break_time)
					
					mine_timer.wait_time = break_time
					#print(break_time,":base_break_time ",base_break_time," reduction ",reduction," timer ",mine_timer.wait_time)
					mine_timer.start()
					mine_timer.connect("timeout",Callable(self,"_break_block").bind(breaking_block))
	else:
		break_block.stop()

func is_interactable() -> bool:
	if terrain_interaction.last_hit == null: return false
	
	var type = terrain_interaction.get_type()
	
	if type == "air": return false
	
	var item = items_library.get_item(type)
	
	if item == null:
		return false
		
	if item.utility != null:
		return true
	else:
		return false


func interaction() -> void:
	if terrain_interaction.last_hit == null: return
	
	var type = terrain_interaction.get_type()
	
	if type == "air": return
	
	var item = items_library.get_item(type)

	if item != null:
		if item.utility != null:
			if item.utility.has_ui:
				terrain_interaction.rpc_id(1,"get_voxel_meta",terrain_interaction.last_hit.position)
				
			if item.utility.spawn_point:
				get_parent().spawn_position = terrain_interaction.last_hit.position + Vector3i(0,1,0)
				print_debug("spawn point set ",get_parent().spawn_position)
			
			if item.utility.portal:
				terrain_interaction.rpc_id(1,"get_voxel_meta",terrain_interaction.last_hit.position)
				#

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

@rpc("any_peer","call_local")
func receive_meta(meta_data, type:int, position:Vector3):
	var item_name = voxel_library.get_type_name_and_attributes_from_model_index(type)[0]
	var item = items_library.get_item(item_name)
		
	print("receive ",meta_data, "type ",type)
	if type == voxel_library.get_model_index_default("portal"):
		Globals.enter_portal.emit(meta_data)
		
	if item_name == "chest":
		print("chest")

		print("open ",position)
		Globals.open_ui.emit(item.utility.ui_scene_path,position, meta_data)
	
	if item_name == "cooker":
		print("cooker")

		print("open ",position)
		Globals.open_ui.emit(item.utility.ui_scene_path,position,meta_data)
		
	if item_name == "blueprint_station":
		Globals.open_ui.emit(item.utility.ui_scene_path,position,null)

func _break_block(block_type:String):
	mine_timer.disconnect("timeout",Callable(self,"_break_block"))
	if Input.is_action_pressed("Mine"):
		#print(block_type)
		break_block.stop()
		terrain_interaction.break_block()
