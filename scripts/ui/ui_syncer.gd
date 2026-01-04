extends Node

var registered_ui_info:Dictionary = {}
var opened_ui:Vector3 ## tells the server which ui is opened

func _ready() -> void:
	Globals.register_ui.connect(register_ui)
	Globals.sync_add_metadata.connect(add_metadata)
	Globals.open_ui.connect(create_ui)
	Globals.open_registered_ui.connect(open_registered_ui)
	Globals.update_registered_ui.connect(update_registered_ui)

func add_metadata(pos:Vector3,metadata) -> void:
	sync_add_metadata.rpc_id(1,pos,metadata)
	
	
@rpc("any_peer","call_local") 
func sync_add_metadata(pos,metadata) -> void:
	var t = get_tree().get_first_node_in_group("VoxelTerrain") as VoxelTerrain
	t.get_voxel_tool().set_voxel_metadata(pos,metadata)

func register_ui(id:Vector3,ui_scene:String):
	if multiplayer.is_server():
		server_register_ui(id,ui_scene)
	else:
		server_register_ui.rpc_id(1,id,ui_scene)

@rpc("any_peer","reliable")
func server_register_ui(id:Vector3,ui_scene:String):
	registered_ui_info[str(id)] = {
		"ui_scene": ui_scene,
		"contains": null
	}

func update_registered_ui(id:Vector3,containments:Dictionary):
	server_update_registered_ui.rpc_id(1,id,containments)

@rpc("any_peer","reliable")
func server_update_registered_ui(id:Vector3,containments:Dictionary):
	if not registered_ui_info.has(str(id)): return
	
	registered_ui_info[str(id)].contains = JSON.stringify(containments)

func open_registered_ui(id:Vector3):
	server_query_open_ui.rpc_id(1,id)

@rpc("any_peer","reliable")
func server_query_open_ui(id:Vector3):
	if not registered_ui_info.has(str(id)): return

	var data = registered_ui_info[str(id)]

	create_ui.rpc_id(multiplayer.get_remote_sender_id(),data.ui_scene,id,data.contains, false)


@rpc("any_peer","reliable")
func create_ui(ui_scene:String, id:Vector3, containments , metadata := true):
	
	var ui = load(ui_scene).instantiate()
	if "id" in ui:
		ui.id = id
	if "metadata" in ui:
		ui.metadata = metadata
	Helper.inventory_array.add_child(ui)

	if containments != null:
		if not containments.is_empty():
			ui.update_client(JSON.parse_string(containments))
			
	Helper.inventory_holder.spawned.append(ui)
	Helper.inventory_holder.open_inventory(id)
