extends MultiplayerSpawner
class_name PlayerSpawner

signal player_spawned(id: int, player: Player)
signal player_despawned(id: int)

@export var view_distance: int = 128
@export var player_scene: PackedScene
@export var stats_ui_updater: Control

@onready var spawn_points: SpawnPoints = $"../Game/SpawnPoints"

var players: Dictionary = {}


func _ready() -> void:
	assert(is_instance_valid(spawn_points), "Fix the path to spawn points")
	
	spawn_function = custom_spawn
	multiplayer.peer_connected.connect(check_player_data)
	multiplayer.peer_disconnected.connect(destroy_player)
	spawned.connect(on_spawned)
	despawned.connect(on_despawned)


func check_player_data(id: int) -> void:
	get_spawn_position.rpc_id(id)
	


func destroy_player(id: int) -> void:
	if not multiplayer.is_server(): return
	get_node(spawn_path).get_node(str(id)).queue_free()
	
	player_despawned.emit(id)


func custom_spawn(data: Array) -> Node:
	var id: int = data[0]
	var spawn_position: Vector3 = data[1]
	
	var player = player_scene.instantiate() as Player
	player.set_multiplayer_authority(id)
	player.name = str(id)
	player.position = spawn_position
	player.start_position = spawn_position
	
	create_viewer(id, player)
	
	players[id] = {
		"player": player
	}
	
	player_spawned.emit(id, player)
	stats_ui_updater.your_player = player
	return player


func create_viewer(id: int, player: Player) -> void:
	if Connection.is_server():
		var viewer := VoxelViewer.new()

		viewer.view_distance = view_distance
		viewer.requires_visuals = false
		viewer.requires_collisions = false
		
		viewer.set_network_peer_id(id)
		viewer.set_requires_data_block_notifications(true)
		player.add_child(viewer)
	
	elif id == multiplayer.get_unique_id():
		var viewer := VoxelViewer.new()
		
		# larger so blocks don't get unloaded too soon
		viewer.view_distance = view_distance + 16
		
		player.add_child(viewer)

		


func on_spawned(node: Node) -> void:
	player_spawned.emit(node.get_multiplayer_authority(), node)
	# Only set up commands for the local player's instance
	if node.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	var player := node as Player
	

	#print(node.get_multiplayer_authority())

func on_despawned(node: Node) -> void:
	player_despawned.emit(node.get_multiplayer_authority())

@rpc("any_peer","call_local","reliable")
func get_spawn_position() -> void:
	if multiplayer.is_server(): return
	
	var spawn_position:Vector3
	
	spawn_position = spawn_points.get_spawn_position()
	
	if not Backend.playerdata.is_empty():
		if Backend.playerdata.Position_x:
			spawn_position = Vector3(Backend.playerdata.Position_x,Backend.playerdata.Position_y,Backend.playerdata.Position_z) + Vector3(0,1,0)
			
	spawn_player.rpc_id(1,multiplayer.get_unique_id(),spawn_position)
		
@rpc("any_peer","call_local","reliable")
func spawn_player(id:int,spawn_position:Vector3) -> void:
	if not multiplayer.is_server(): return
	
	spawn([id, spawn_position])

	Debug.log_msg("Player %d spawned at %.v" % [id, spawn_position])
