extends Node

var hotbar:HotBar
var terrian:VoxelTerrain
var sound_manager
var player_inventory
var inventory_holder
var inventory_array:HBoxContainer
var blueprint_holder
var text_chat
var pause_menu
var settings
var slot_manager
var creature_spawner:MultiplayerSpawner
var player_spawner:MultiplayerSpawner
var object_spawner:MultiplayerSpawner
var light_container
var sound_container
var enviroment:WorldEnvironment

	
func load_helper() -> void:
	hotbar = get_node("/root/Main").find_child("Hotbar") as HotBar
	terrian = get_node("/root/Main").find_child("VoxelTerrain") as VoxelTerrain
	sound_manager = get_node("/root/Main").find_child("SoundManager")
	player_inventory = get_node("/root/Main").find_child("Inventory")
	inventory_holder = get_node("/root/Main").find_child("Inventory_UI")
	blueprint_holder = get_node("/root/Main").find_child("Blueprint_Holder")
	text_chat = get_node("/root/Main").find_child("Text_Chat")
	pause_menu = get_node("/root/Main").find_child("Pause_Menu")
	settings = get_node("/root/Main").find_child("Settings")
	slot_manager = get_node("/root/Main").find_child("SlotManager")
	creature_spawner = get_node("/root/Main").find_child("CreatureSpawner")
	player_spawner = get_node("/root/Main").find_child("PlayerSpawner")
	object_spawner = get_node("/root/Main").find_child("ObjectSpawner")
	light_container = get_node("/root/Main").find_child("Lights")
	sound_container = get_node("/root/Main").find_child("Sounds")
	enviroment = get_node("/root/Main").find_child("WorldEnvironment")
	inventory_array = get_node("/root/Main").find_child("Inventory_Array")
	

func test(text:String,color:Color):
	print("autoloads")
