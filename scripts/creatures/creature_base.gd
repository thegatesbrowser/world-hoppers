extends CharacterBody3D
class_name CreatureBase

var spawn_pos:Vector3
var gravity:float = 30
var world_loaded:bool = false
var position_before_sync: Vector3 = Vector3.ZERO
var last_sync_time_ms: int = 0
var is_despawning:bool = false
var dropped_items:bool = false
var target:Vector3
var path:PackedVector3Array

@onready var player_view_distance: float = 128 * sqrt(2)

@export var creature_resource: Creature

@onready var jump: RayCast3D = $jump
@onready var rotation_root: Node3D = $RotationRoot
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var attack_coll: CollisionShape3D = $"attack range/CollisionShape3D"
@onready var guide: Node3D = $guide
@onready var multiplayer_sync:MultiplayerSynchronizer = $MultiplayerSynchronizer

@export_group("Sync Properties")
@export var _position: Vector3
@export var _velocity: Vector3
@export var _rotation: Vector3 = Vector3.ZERO
@export var _direction: Vector3 = Vector3.ZERO

@export var sync_delta_max := 0.2
@export var sync_delta := 0.0
@export var start_interpolate := false

@onready var hit_sfx:AudioStreamPlayer3D = $Sounds/hurt

var ani: AnimationPlayer
var mesh: MeshInstance3D
var meshs: Array[MeshInstance3D]
var despawn_timer := Timer.new()

var health:int
var stopped:bool = false

var past_points:Array[Vector3]

func _ready() -> void:
	
	if not multiplayer.is_server():
		multiplayer_sync.delta_synchronized.connect(on_synchronized)
		multiplayer_sync.synchronized.connect(on_synchronized)
		
	health = creature_resource.max_health

	var body = creature_resource.body_scene.instantiate()
	rotation_root.add_child(body)

	for i in body.get_children(true):
		if i is MeshInstance3D:
			meshs.append(i)

	collision.shape = creature_resource.collision_shape
	collision.position = creature_resource.collision_offset

	ani = body.find_child("AnimationPlayer")

	if creature_resource.utility != null:
		if creature_resource.utility.has_ui:
			Globals.register_ui.emit(spawn_pos,creature_resource.utility.ui_scene_path)
	
	#despawn_timer.autostart = true
	#despawn_timer.wait_time = 5.0
	#despawn_timer.name == "despawn_timer"
	#add_child(despawn_timer,true)
	#despawn_timer.timeout.connect(try_despawn)
	
func _process(delta: float) -> void:
				
	if not multiplayer.is_server(): return
	
	var closest_player:Player = get_closest_player()
	if closest_player:
		var distance_to_player = global_position.distance_to(closest_player.global_position)
		
		if distance_to_player > player_view_distance:
			try_despawn()

func _physics_process(delta: float) -> void:
	
	if not multiplayer.is_server():
		interpolate_client(delta)
		return
		
	if not world_loaded: return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if jump.is_colliding() and !stopped:
			#print("jump")
			velocity.y += 10

	#Path()
	
	var pos2d:Vector2 = Vector2(global_position.x,global_position.z)
	var target2d:Vector2 = Vector2(guide.global_position.x,guide.global_position.z)
	
	var dir = (pos2d - target2d) / 2
	jump.look_at(Vector3(guide.global_position.x,jump.global_position.y + 0.01 ,guide.global_position.z))
	
	rotation_root.rotation.y = lerp_angle(rotation_root.rotation.y,atan2(dir.x,dir.y), delta / 0.2)
	
	move_and_slide()
	
	set_sync_properties()

func interpolate_client(delta: float) -> void:
	if not start_interpolate: return
	#print("inter")
	# Interpolate rotation
	rotation_root.rotation = _rotation.slerp(rotation_root.rotation, delta)
	
	# Don't interpolate to avoid small jitter when stopping
	if (_position - position).length() > 1 and _velocity.is_zero_approx():
		position = _position.slerp(_position,delta) # Fix misplacement
	
	# Interpolate between position_before_sync and _position
	# and add to ongoing movement to compensate misplacement
	var t = 2 if is_zero_approx(sync_delta) else delta / sync_delta
	sync_delta = clampf(sync_delta - delta, 0, sync_delta_max)
	
	var less_misplacement = position_before_sync.move_toward(_position, t)
	position += less_misplacement - position_before_sync
	position_before_sync = less_misplacement
	
	velocity.y -= gravity * delta
	move_and_slide()
	
func get_random_pos_in_sphere(radius : float) -> Vector3:
	var x1= randi_range(-1,1)
	var x2= randi_range(-1,1)

	while x1*x1 + x2*x2 >=1:
		x1= randi_range(-1,1)
		x2= randi_range(-1,1)
		
	var random_pos_on_unit_sphere = Vector3 (
		1 -2 * (x1*x1 + x2*x2),
		0,
		1 -2 * (x1*x1 + x2*x2))
		
	random_pos_on_unit_sphere.x *= randi_range(-radius, radius)
	random_pos_on_unit_sphere.z *= randi_range(-radius, radius)

	return random_pos_on_unit_sphere

@rpc("any_peer", "unreliable")
func hit(hit_from:Vector3,damage:int = 1):
	
	health -= damage
	
	if health <= 0:
		drop_items.rpc_id(multiplayer.get_remote_sender_id())
		try_despawn()
	else:
		hit_sfx.play()
		knockback(hit_from,3.0)
		
func knockback(hit_from:Vector3,strength:float):
	var direction = -global_position.direction_to(hit_from)
	#print("hit ",direction)
	velocity += Vector3(direction.x,0,direction.z) * strength

func save() -> Dictionary:
	
	var save = {
		"creature_path":creature_resource.get_path(),
		"x":global_position.x,
		"y":global_position.y,
		"z":global_position.z,
		"health":health,
		"spawn_pos_x":spawn_pos.x,
		"spawn_pos_y":spawn_pos.y,
		"spawn_pos_z":spawn_pos.z,
	}
	return save
	
func set_sync_properties() -> void:
	_position = position
	_velocity = velocity
	_rotation = rotation_root.rotation

func on_synchronized() -> void:
	velocity = _velocity
	position_before_sync = position
	
	var sync_time_ms = Time.get_ticks_msec()
	sync_delta = clampf(float(sync_time_ms - last_sync_time_ms) / 1000, 0, sync_delta_max)
	last_sync_time_ms = sync_time_ms
	
	if not start_interpolate:
		start_interpolate = true
		position = _position
		rotation_root.rotation = _rotation


	
func try_despawn() -> void:
	if is_despawning: return
	
	is_despawning = true
	await get_tree().create_timer(1.0).timeout
	queue_free()

@rpc("any_peer","reliable")
func drop_items() -> void:
	if multiplayer.is_server(): return
	if dropped_items: return
	
	var slot_manager = get_node("/root/Main").find_child("SlotManager")

	for item in creature_resource.drop_items:
		slot_manager.add_item_to_hotbar_or_inventory(item)
	dropped_items = true

func get_closest_player():
	var last_distance: float = 0.0
	var closest_player: CharacterBody3D
	
	for i in get_tree().get_nodes_in_group("Player"):
		if last_distance == 0.0:
			last_distance = global_position.distance_to(i.global_position)
			closest_player = i
		else:
			if last_distance > global_position.distance_to(i .global_position):
				last_distance = global_position.distance_to(i .global_position)
				closest_player = i

	return closest_player
