extends Node

# Debugging.
enum Level { DEBUG = 0, INFO = 1, WARNING = 2, ERROR = 3, CRITICAL = 4 }
@export var single_threaded_generate := false
@export var single_threaded_render := false
@export var capture_mouse_on_start := true

@export var paused := false


var current_block:StringName ## unique_name
var custom_block:StringName ## unique_name
var can_build:bool = false
var view_range:int = 128


# world gen
signal fnished_loading # let the player move ground has been made

signal create_spawner(pos:Vector3i,creature:String)
signal spawn_creature(pos:Vector3,creature,spawn_pos:Vector3)
signal hunger_points_gained(amount)
signal add_object(data:Array)
signal removed_spawnpoint(id:Vector3)

# portals
signal open_portal_url(id:Vector3)
signal create_portal(id:Vector3)
signal enter_portal(url:String)
signal add_portal_url(id:Vector3,url:String)
signal remove_portal_data(id:Vector3)

# ui
signal register_ui(id:Vector3,ui_scene_path:String)
signal open_ui(ui_scene:String, id:Vector3, containments )
signal open_registered_ui(id:Vector3)
signal update_registered_ui(id:Vector3, containments:Dictionary)

signal sync_add_metadata(pos,metadata)

signal remove_item_from_hotbar

signal spawn_item_inventory(item,amount,health)
signal spawn_item_hotbar(item)

signal check_amount_of_item(item)
signal remove_item(item,amount)
signal hotbar_slot_clicked(slot)
signal add_item_to_hand(item,scene:PackedScene)
signal remove_item_in_hand

signal blueprint_hovered(bluepring_resource:Blueprint,slot:Slot)
signal blueprint_unhovered

signal drop_item(item)
signal closed_inventory

var hotbar_full:bool 

signal start_hand_ani(ani_name)
signal stop_hand_ani()

# Backend
var client_id:String
signal save
signal save_slot(index: int, item_path: String, amount: int,parent: String,health: int)
signal send_to_server(data:Dictionary)
signal send_slot_data(data:Dictionary)
signal ask_for_portal(x,y,z)

func _ready():
	#Print.create_logger(0, print_level, Print.VERBOSE)
	pass

func find_item(item:ItemBase,inventory:bool = true,hotbar:bool = true, blueprints:bool = false) -> Slot:
	var return_ = null
	
	var _blueprints = get_tree().get_first_node_in_group("Blueprints")
	var _inventory = get_tree().get_first_node_in_group("Main Inventory")
	var hot_bar = get_tree().get_first_node_in_group("Hotbar")
	
	if inventory:
		for slot in _inventory.slots:
			if slot.item:
				if slot.item.unique_name == item.unique_name:
					return_ = slot
					break
				
	if blueprints:
		for slot in _blueprints.get_children():
			if slot.item:
				if slot.item.unique_name == item.unique_name:
					return_ = slot
					break
				
	if hotbar:
		if return_ == null:
			for slot in hot_bar.buttons:
				if slot.item:
					if slot.item.unique_name == item.unique_name:
						return_ = slot
						break
	return return_

func _create_spawner(pos:Vector3i,creature:String):
	create_spawner.emit(pos,creature)
