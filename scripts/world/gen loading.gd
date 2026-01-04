extends Control

@onready var loading_bar = $ProgressBar
@export var terrain:VoxelTerrain
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

var isLoading:=true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if multiplayer.is_server(): return
	
	var location = Vector3(12,50,8)

	if !Backend.playerdata.is_empty():
		if Backend.playerdata.Position_x:
			location = Vector3(Backend.playerdata.Position_x,Backend.playerdata.Position_y,Backend.playerdata.Position_z)
			pass
				
	var aabb:AABB = AABB(location,Vector3(40,60,40))
	if terrain.is_area_meshed(aabb):
		print("loaded")
		isLoading = false

	if isLoading == false:
		Globals.fnished_loading.emit()
		queue_free()


	if loading_bar.value < 100:
		loading_bar.value += delta * 10
	else:
		loading_bar.value = 0
	

func hide_loading_screen():
	visible = !visible
