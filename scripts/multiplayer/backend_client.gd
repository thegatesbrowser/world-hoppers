extends Node

@export var debug_ui:Control
@export var PlayerInfo:RichTextLabel

var exported_address = "ws://188.245.188.59:8819" 
var address:String

signal playerdata_updated

var peer = WebSocketMultiplayerPeer.new()
var id = 0
var rtcPeer: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
var hostId: int
var lobbyValue = ""
var lobbyInfo = {}
var cryptoUtil = UserCrypto.new()
var client_id: String

const CLIENT_ID_PATH := "user://client_id.txt"

var playerdata:Dictionary = {}

func _ready():
	if OS.is_debug_build():
		address = exported_address
		#address = "ws://127.0.0.1:8819"
	else:
		address = exported_address
	#Globals.send_data.connect(update)
	Globals.ask_for_portal.connect(ask_for_portal_url)
	Globals.send_slot_data.connect(update_slot)
	Globals.send_to_server.connect(_update)
	
	if Connection.is_server() == false:
		connectToServer("")
	else:
		connectToServer("")
		pass


func ask_for_player_data(cid):
	var data = {"client_id" : cid.strip_edges(true, true)}
	var message = {
		"peer" : id,
		"orgPeer" : self.id,
		"message" :  Util.Message.checkIn,
		"data": data,
		"Lobby": lobbyValue
	}
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())


func identify():
	var cid:String
	print("server? ",Connection.is_server() )
	if Connection.is_server():
		cid = "server"
		var data := {"client_id": cid}
		var message := {
			"peer" : id,
			"orgPeer" : self.id,
			"message" : Util.Message.identify,
			"data": data,
			"Lobby": lobbyValue
		}
		print("sent identify message", message)
		peer.put_packet(JSON.stringify(message).to_utf8_buffer())
	else:
		cid = get_saved_client_id()
			
		var data := {"client_id": cid}
		var message := {
			"peer" : id,
			"orgPeer" : self.id,
			"message" : Util.Message.identify,
			"data": data,
			"Lobby": lobbyValue
		}
		print("sent identify message", message)
		peer.put_packet(JSON.stringify(message).to_utf8_buffer())


func RTCServerConnected():
	print("backend server connected")

func RTCPeerConnected(peer_id):
	print("backend peer connected " + str(peer_id))

func RTCPeerDisconnected(peer_id):
	print("backend peer disconnected " + str(peer_id))

func _process(_delta):
	peer.poll()
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet != null:
			var dataString = packet.get_string_from_utf8()
			var data = JSON.parse_string(dataString)
			
			#print(data)
			
			if data.message == Util.Message.id:
				id = data.id
				identify()
			
			if data.message == Util.Message.identify:
				identify()
			#if data.message == Util.Message.userConnected:
				##GameManager.Players[data.id] = data.player
				#createPeer(data.id)
			if data.message == Util.Message.portal:
				print(data)
				set_portal_url.rpc(data.x,data.y,data.z)
			
			if data.message == Util.Message.playerinfo:
				playerdata = data
				playerdata_updated.emit()
				#print(playerdata)
				PlayerInfo.text = ""
				for i in data:
					var variable = data[i]
					PlayerInfo.text += str(i," : ",variable,"\n")
				
				#PlayerInfo.text = data.client_id + "\n"+ str(data.id)  + "\n" + str(data.health)
				client_id = data.client_id
				Globals.client_id = client_id
				save_client_id(client_id)

func update_slot(slot_data:Dictionary): ##{index: int, item_path: String, amount: int,parent: String,health: int, rot:int, client_id:String}
	var message = {
		"peer" : id,
		"orgPeer" : self.id,
		"message" : Util.Message.slot_update,
		"data": slot_data,
		"Lobby": lobbyValue
	}
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())


func _update(data:Dictionary):
	var message = {
		"peer" : id,
		"orgPeer" : self.id,
		"message" : Util.Message.update,
		"data": data,
		"Lobby": lobbyValue
	}
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
	
func connectToServer(_ip):
	peer.create_client(address)
	print("started client trying to connect or ", address)

func _on_start_client_button_down():
	connectToServer("")

func saveD():
	debug_ui.visible = !debug_ui.visible

func get_saved_client_id() -> String:
	if FileAccess.file_exists(CLIENT_ID_PATH):
		var f := FileAccess.open(CLIENT_ID_PATH, FileAccess.READ)
		var s := f.get_as_text().strip_edges(true, true)
		f.close()
		return s
	return ""

func save_client_id(cid: String) -> void:
	if Connection.is_server(): return
	var f := FileAccess.open(CLIENT_ID_PATH, FileAccess.WRITE)
	f.store_string(cid)
	f.close()

func ask_for_portal_url(voxel_x,voxel_y,voxel_z):
	var message = {
		"peer" : id,
		"orgPeer" : self.id,
		"message" : Util.Message.portal,
		"data": {"x":voxel_x,"y":voxel_y,"z":voxel_z},
		"Lobby": lobbyValue
	}
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
	print("sent portal url request")

@rpc("any_peer",'call_local')
func set_portal_url(x,y,z):
	var voxel_tool = Helper.terrian.get_voxel_tool()
	voxel_tool.set_voxel_metadata(Vector3(x,y,z),"test")
	#voxel_tool.set_voxel(Vector3(x,y,z),11)
	print("created portal at ",Vector3(x,y,z))

func delete_backend_save() -> bool:
	var message = {
		"peer" : id,
		"orgPeer" : self.id,
		"message" : Util.Message.delete_user_save,
		"data": {"client_id":client_id},
		"Lobby": lobbyValue
	}
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
	return true
