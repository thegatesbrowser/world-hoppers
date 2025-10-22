extends Node3D

@onready var player: Player = $"../../../../.."

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
#@onready var area_3d: Area3D = $Area3D

var ani_name:String
var toggled:bool = false

func _process(delta: float) -> void:
	var current_slot = Helper.hotbar.get_current()
	var current_item:ItemBase = current_slot.item
	if current_item != null:
		if current_item is ItemTool or current_item is ItemFood:
			if current_item is ItemTool:
				if current_item.toggle_ani:
					if Input.is_action_just_pressed("Mine"):
						if !toggled:
							use_item(current_item,false)
							toggled = true
						else:
							use_item(current_item,true)
							toggled = false
				else:
					if Input.is_action_pressed("Mine"):
						use_item(current_item)
					else:
						stop()
			else:
				if Input.is_action_pressed("Mine"):
					use_item(current_item)
				else:
					stop()

func use_item(item:ItemBase,reversed:bool = false) -> void:
	if not item is ItemTool and not item is ItemFood:
		return

	if animation_player.is_playing(): return
	
	var ani = item.use_ani
	if ani == null: return
	
	ani_name = ani.resource_name
	
	var lib:AnimationLibrary = animation_player.get_animation_library("")
	
	if !lib.has_animation(ani.resource_name):
		lib.add_animation(ani.resource_name,ani)
	if animation_player.has_animation(ani.resource_name):
		if reversed:
			animation_player.play_backwards(ani.resource_name)
		else:
			animation_player.play(ani.resource_name)
		
func stop() -> void:
	toggled = false
	if animation_player:
		if animation_player.has_animation(ani_name):
			var lib:AnimationLibrary = animation_player.get_animation_library("")
			animation_player.stop()
			lib.remove_animation(ani_name)
			player_speed(false,0.0)
			protection(0)

func create_attackbox() -> void:
	pass
	#var coll:CollisionShape3D = area_3d.get_child(0)
	#coll.disabled = false
	#var current_item:ItemBase = Helper.hotbar.get_current().item
	#
	#var overlapping := area_3d.get_overlapping_areas()
	#for area3d in overlapping:
		#if area3d.is_in_group("Hitbox"):
			#var parent = get_parent()
			#if parent is HealthComponent:
				#if current_item is ItemTool:
					#parent.hit.rpc_id(parent.get_multiplayer_authority(),current_item.damage)
	#coll.disabled = true

func protection(protection:int):
	player.protection = protection

func player_speed(active:bool,speed:float):
	player.custom_speed = active
	player.speed = speed


func _on_child_order_changed() -> void:
	if get_child_count() == 0:
		player_speed(false,0.0)
		protection(0)
