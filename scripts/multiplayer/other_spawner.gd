extends MultiplayerSpawner

signal spawned_object(id:int, object)


func _ready() -> void:
	set_multiplayer_authority(1)
	spawn_function = custom_spawn
	despawned.emit()
	Globals.add_object.connect(spawn_object)
	spawned_object.emit()
	
func print_spawned_object(id:int,object):
	print("spawned ",id,object)

@rpc("any_peer")
func spawn_object(data := []) -> void:
	if not multiplayer.is_server(): return
	spawn(data)

func custom_spawn(data: Array) -> Node:
	var id
	var spawn_position
	var instance_scene_path
	var item_path
	var amount
	var spawn_viewer:bool
	if data.size() >= 1:
		id = data[0]
	if data.size() >= 2:
		spawn_position = data[1]
	if data.size() >= 3:
		instance_scene_path = data[2]
	if data.size() >= 4:
		item_path= data[3]
	if data.size() >= 5:
		spawn_viewer = data[4]
	if data.size() >= 6:
		amount = data[5]
	
	var object = load(instance_scene_path).instantiate()
	
	if typeof(spawn_position) == TYPE_TRANSFORM3D:
		object.global_transform = spawn_position
	elif typeof(spawn_position) == TYPE_VECTOR3:
		object.position = spawn_position
	
	if item_path != null:
		if "item" in object:
			object.item = load(item_path)
		elif "resource" in object:
			object.resource = load(item_path)
		print(load(item_path))
			
	if amount != null:
		object.amount = amount
	if spawn_viewer:
		create_viewer(id,object)
	object.set_multiplayer_authority(id,true)
	
	spawned_object.emit(id, object)
	return object
	
func create_viewer(id: int, object) -> void:
	if Connection.is_server():
		var viewer := VoxelViewer.new()

		viewer.view_distance = 10
		viewer.requires_visuals = false
		viewer.requires_collisions = true
		
		viewer.set_network_peer_id(id)
		viewer.set_requires_data_block_notifications(true)
		object.add_child(viewer)
