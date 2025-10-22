extends Node3D

var Terrian:VoxelTerrain
@export var check_size:Vector3 = Vector3(40,60,40)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Terrian = Helper.terrian

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if multiplayer.is_server():
		var aabb:AABB = AABB(global_position,check_size)
		if Terrian.is_area_meshed(aabb):
			print("area around")
			get_parent().world_loaded = true
			queue_free()
