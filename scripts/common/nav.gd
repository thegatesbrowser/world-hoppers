extends Node3D

var debug:bool = false

var astar := AStar3D.new()

var points := {}

var nav_viewers := []

var tick:float = 1.0

const _moore_dirs = [
	Vector3(-1, 0, -1),
	Vector3(0, 0, -1),
	Vector3(1, 0, -1),
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(-1, 0, 1),
	Vector3(0, 0, 1),
	Vector3(1, 0, 1),
	
	Vector3(-1, 1, -1),
	Vector3(0, 1, -1),
	Vector3(1, 1, -1),
	Vector3(-1, 1, 0),
	Vector3(1, 1, 0),
	Vector3(-1, 1, 1),
	Vector3(0, 1, 1),
	Vector3(1, 1, 1),
	
	Vector3(-1, -1, -1),
	Vector3(0, -1, -1),
	Vector3(1, -1, -1),
	Vector3(-1, -1, 0),
	Vector3(1, -1, 0),
	Vector3(-1, -1, 1),
	Vector3(0, -1, 1),
	Vector3(1, -1, 1),
]

func _ready() -> void:

	var update_nav_timer := Timer.new()
	update_nav_timer.wait_time = tick
	update_nav_timer.autostart = true
	add_child(update_nav_timer)
	update_nav_timer.timeout.connect(update_navs)

func create_point(pos):
	#print("multiplayer id ",multiplayer.get_unique_id())
	
	if points.has(pos): return

	var point_id = astar.get_available_point_id()

	if multiplayer.is_server():
		astar.add_point(point_id, pos)

	points[pos] = {
		"point_id":point_id,
	}

	if debug:
		create_visual_debug(pos)  # Create a visual debug sphere at the point position's center
   
	#print("Point created at: ", Vector3(x, y, z))
	#print("Total points: ", astar.get_point_count())

func create_visual_debug(pos:Vector3, point_scale:Vector3 = Vector3(0.4,.4,.4),material:StandardMaterial3D = null):
	var sphere := BoxMesh.new()
	
	var instance := MeshInstance3D.new()
	instance.mesh = sphere
	instance.position = pos
	instance.name = str(pos)
	
	add_child(instance)
	
	instance.scale = point_scale

	instance.material_override = material

func clear_points():

	## Debug Clear
	for mesh in get_children():
		if mesh is MeshInstance3D:
			mesh.queue_free()
			
	## Point Clear
	
	for i in points:
		if multiplayer.is_server():
			var point_id = points[i].point_id
			if astar.has_point(point_id):
				astar.remove_point(point_id)
	points.clear()
	#print(points)

func connect_points():
	if not multiplayer.is_server(): return

	for pos in points:
		for dir in _moore_dirs:
			var search_area = pos + dir
			if points.has(search_area):
				var current_id = points[pos].point_id
				var neighbor_id = points[search_area].point_id

				if not astar.are_points_connected(current_id,neighbor_id):
					astar.connect_points(current_id,neighbor_id)
					#print("astar connected point ", current_id, " to ", neighbor_id )

func find_path(from:Vector3,to:Vector3):
	# from and to are already been rounded
	var start_id = astar.get_closest_point(from)
	var end_id = astar.get_closest_point(to)

	if start_id == -1 or end_id == -1: return

	var path = astar.get_point_path(start_id,end_id,true)
	
	return path
	
	debug_path.rpc(path,start_id,end_id)
	
	

@rpc("any_peer")
func debug_path(path:PackedVector3Array, start_id:int, end_id:int):
	if multiplayer.is_server(): return # client debug
	if not debug: return
	
	var start := astar.get_point_position(start_id)
	var end := astar.get_point_position(end_id)
	
	for point in path:
		if point == start:
			create_visual_debug(point,Vector3(0.41,0.41,0.41),load("res://assets/materials/start_debug.tres"))
		elif point == end:
			create_visual_debug(point,Vector3(0.41,0.41,0.41),load("res://assets/materials/end_debug.tres"))
		else:
			create_visual_debug(point,Vector3(0.41,0.41,0.41),load("res://assets/materials/debug.tres"))

func update_nav_pool():
	nav_viewers = get_tree().get_nodes_in_group("NavViewer")

func update_navs():
	clear_points()

	for nav_viewer in nav_viewers:
		if nav_viewer != null:
			var surroundings = nav_viewer.grab_surrounds()
			for pos in surroundings:
				create_point(pos + Vector3(0.5,0,0.5))
				
	connect_points()

func allowed_path(path:PackedVector3Array) -> bool:
	var _path = path.duplicate()
	for point in _path:
		var curr_point = point
		_path.remove_at(_path.find(point))
		for next_point in _path:
			#print("current ",curr_point, " next point ",next_point)

			var height_range = curr_point.y - next_point.y 

			if height_range > 1:
				return false
			else:
				return true
	
	return false ## doesn't have a path

func toggle_nav_debug():
	debug = !debug

	if debug == false:
		clear_points()
