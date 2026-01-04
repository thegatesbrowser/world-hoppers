extends MultiplayerSpawner
class_name PlayerSpawner

signal player_spawned(id: int, player: Player)
signal player_despawned(id: int)




func _ready() -> void:
	spawn_function = custom_spawn
	multiplayer.peer_connected.connect(create_player)
	multiplayer.peer_disconnected.connect(destroy_player)
	spawned.connect(on_spawned)
	despawned.connect(on_despawned)


func create_player(id: int):
	if not multiplayer.is_server(): return
	
	var spawn_position = get_spawn_position()
	spawn([id, spawn_position])
	print("Player %d spawned at " % [id] + str(spawn_position))


func destroy_player(id: int):
	if not multiplayer.is_server(): return
	get_node(spawn_path).get_node(str(id)).queue_free()
	
	player_despawned.emit(id)


func respawn_player(id: int) -> void:
	var player = get_node(spawn_path).get_node(str(id)) as Player
	var spawn_position = get_spawn_position(true)
	player.respawn.rpc_id(id, spawn_position)
	print("Respawn player %d at " % [id] + str(spawn_position))


func custom_spawn(vars) -> Node:
	var id = vars[0]
	var pos = vars[1]
	
	var p: Player = player_scene.instantiate()
	p.set_multiplayer_authority(id)
	p.call_deferred("set_position", pos)
	p.name = str(id)
	
	make_viewer(id,p)
	player_spawned.emit(id, p)
	return p


func get_player_or_null(id: int) -> Player:
	return get_node(spawn_path).get_node_or_null(str(id))


func on_spawned(node: Node) -> void:
	player_spawned.emit(node.get_multiplayer_authority(), node)


func on_despawned(node: Node) -> void:
	player_despawned.emit(node.get_multiplayer_authority())

func get_spawn_position(respawn:bool = false) -> Vector3:
	var pos:Vector3
	
	#if Backend.playerdata.has("Position_x"):
		#if Backend.playerdata.Position_x != null:
			#pos = Vector3(Backend.playerdata.Position_x,Backend.playerdata.Position_y,Backend.playerdata.Position_z)
			#return pos

	#pos = spawn_points.pick_random().global_position
	
	return pos

func make_viewer(id: int, player: Player) -> void:
	if Connection.is_server():
		var viewer := VoxelViewer.new()

		viewer.view_distance = view_range
		viewer.requires_visuals = false
		viewer.requires_collisions = false
		
		viewer.set_network_peer_id(id)
		viewer.set_requires_data_block_notifications(true)
		player.add_child(viewer)
	
	elif id == multiplayer.get_unique_id():
		var viewer := VoxelViewer.new()
		
		# larger so blocks don't get unloaded too soon
		viewer.view_distance = view_range + 16
		
		player.add_child(viewer)
