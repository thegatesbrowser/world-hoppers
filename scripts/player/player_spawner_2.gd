extends Node

@export var player_scene: PackedScene
@export var spawn_points: Array[Node3D]
@export var player_container: Node3D

@export var view_range:int = 60

func _ready() -> void:
	create_player()
	
func create_player():
	var spawn_pos = get_spawn_position()
	var player: Player = player_scene.instantiate()
	player.position = spawn_pos
	player_container.add_child(player)
	make_viewer(player)
	
func get_spawn_position(respawn:bool = false) -> Vector3:
	var pos:Vector3

	pos = spawn_points.pick_random().global_position
	
	return pos

func make_viewer(player: Player) -> void:
	var viewer := VoxelViewer.new()
	
	# larger so blocks don't get unloaded too soon
	viewer.view_distance = view_range + 16
	
	player.add_child(viewer)
