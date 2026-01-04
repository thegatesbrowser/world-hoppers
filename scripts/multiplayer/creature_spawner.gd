extends MultiplayerSpawner

signal creature_spawned(id: int, creature)
signal creature_despawned(id: int)

var debug:bool
var creature_base = preload("res://scenes/creatures/creature_base.tscn")
@export var view_distance: int = 20

var creature_spawners:Dictionary

func _ready() -> void:
	spawn_function = custom_spawn
	Globals.create_spawner.connect(create_creature_spawner)
	Globals.spawn_creature.connect(spawn_creature)
	var spawn_tick := Timer.new()
	spawn_tick.wait_time = 5.0
	spawn_tick.autostart = true
	add_child(spawn_tick)
	spawn_tick.timeout.connect(tick)


@rpc("any_peer","call_local")
func spawn_creature(pos: Vector3, creature_path:String, spawn_pos = null) -> void:
	#print(creature, pos)
	
	var creature:Creature = load(creature_path)
	
	if not multiplayer.is_server(): return
	
	if get_tree().get_nodes_in_group("NPCS").size() >= 6:
		return
		
	var spawn_position = pos
	print("creature spawn pos ", spawn_position)
	spawn([1, spawn_position,creature.get_path(),spawn_pos])


func destroy_creature(Name: String) -> void:
	if not multiplayer.is_server(): return
	get_node(spawn_path).get_node(Name).queue_free()


func debug_spawn_creature(pos:Vector3,creature_name):
	var creature:String
	if creature_name == "fox":
		creature = "res://resources/creatures/fox.tres"
		
	print("debug_spawn ",pos,creature_name)
	if creature:
		spawn_creature.rpc_id(1,pos,creature)

func custom_spawn(data: Array) -> Node:
		
	var id: int = data[0]
	var spawn_position: Vector3 = data[1]
	
	## Loads from the path of the resource
	var creature_resource = load(data[2])
	
	var spawn_pos = data[3] ## start spawn from saving
	
	var creature = creature_base.instantiate() as CreatureBase
	creature.set_multiplayer_authority(id)
	creature.name = str(id)
	creature.position = spawn_position

	if spawn_pos != null:
		creature.spawn_pos = spawn_pos
	else:
		creature.spawn_pos = spawn_position

	creature.creature_resource = creature_resource
	
	create_viewer(id, creature)
	
	creature_spawned.emit(id, creature)
	return creature


func create_viewer(_id: int, creature: CreatureBase) -> void:
	if Connection.is_server():
		var viewer: VoxelViewer = VoxelViewer.new()

		viewer.view_distance = view_distance
		viewer.requires_visuals = false
		viewer.requires_collisions = true
		viewer.set_network_peer_id(1)

		creature.add_child(viewer)

func create_creature_spawner(spawner_pos:Vector3i,creature:String):
	return
	creature_spawners[spawner_pos] = {"creature":creature}
	#print("created_spawner")
	#print("spawners ",creature_spawners)
	pass
	
func tick():
	return
	if !multiplayer.is_server(): return
	if creature_spawners.size() == 0: return
		
	var rng := RandomNumberGenerator.new()
	var pos = creature_spawners.keys().pick_random()
	
	if pos:
		var closest_player = get_closest_player(pos)
		#print(closest_player.global_position.distance_to(pos),pos)
		if closest_player:
			if closest_player.global_position.distance_to(pos) > 120: return
			
			if pos:
				spawn_creature(pos,creature_spawners[pos].creature)

func get_closest_player(check_pos:Vector3i):
	var last_distance: float = 0.0
	var closest_player: CharacterBody3D
	
	for i in get_tree().get_nodes_in_group("Player"):
		if last_distance == 0.0:
			last_distance = check_pos.distance_to(i .global_position)
			closest_player = i
		else:
			if last_distance > check_pos.distance_to(i .global_position):
				last_distance = check_pos.distance_to(i .global_position)
				closest_player = i

	return closest_player
