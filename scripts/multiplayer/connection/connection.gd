extends Node
class_name Connection

signal connected
signal disconnected

static var is_peer_connected: bool

var your_id:int
@export var port: int
@export var max_clients: int
@export var host: String
@export var use_localhost_in_editor: bool


func _ready() -> void:
	if Connection.is_server(): start_server()
	connected.connect(func(): Connection.is_peer_connected = true)
	disconnected.connect(func(): Connection.is_peer_connected = false)
	disconnected.connect(disconnect_all)


static func is_server() -> bool:
	var args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	return "--server" in args


func get_port() -> int:
	var args = OS.get_cmdline_args()
	var index = args.find("--port")
	
	if index == -1 or args.size() <= index + 1: return -1
	return int(args[index + 1])


func start_server() -> void:
	if max_clients == 0:
		max_clients = 32
	
	var new_port = get_port()
	if new_port != -1:
		port = new_port
	
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, max_clients)
	if err != OK:
		Debug.log_msg("Cannot start server. Err: " + str(err))
		disconnected.emit()
		return
	else:
		Debug.log_msg("Server started on port " + str(port))
		connected.emit()
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)


func start_client() -> void:
	var address = host
	if OS.has_feature("editor") and use_localhost_in_editor:
		address = "localhost"
	
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		Debug.log_msg("Cannot start client. Err: " + str(err))
		disconnected.emit()
		return
	else: Debug.log_msg("Connecting to server: %s:%d..." % [address, port])
	
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.server_disconnected.connect(server_connection_failure)
	multiplayer.connection_failed.connect(server_connection_failure)


func connected_to_server() -> void:
	Debug.log_msg("Connected to server")
	connected.emit()


func server_connection_failure() -> void:
	Debug.log_msg("Disconnected")
	disconnected.emit()


func peer_connected(id: int) -> void:
	Debug.log_msg("Peer connected: " + str(id))


func peer_disconnected(id: int) -> void:
	Debug.log_msg("Peer disconnected: " + str(id))


func disconnect_all() -> void:
	disconnect_from_signal("peer_connected", peer_connected)
	disconnect_from_signal("peer_disconnected", peer_disconnected)
	disconnect_from_signal("connected_to_server", connected_to_server)
	disconnect_from_signal("server_disconnected", server_connection_failure)
	disconnect_from_signal("connection_failed", server_connection_failure)
	
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func disconnect_from_signal(signal_name: String, callable: Callable) -> void:
	if multiplayer.is_connected(signal_name, callable):
		multiplayer.disconnect(signal_name, callable)
