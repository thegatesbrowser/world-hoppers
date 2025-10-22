extends CharacterBody3D
class_name Player

signal hunger_updated(hunger)
signal health_updated(health)

const SENSITIVITY = 0.004

# Bob variables
const BOB_FREQ = 2.4
const BOB_AMP = 0.03
var t_bob = 0.0

# FOV variables
const BASE_FOV = 90.0
const FOV_CHANGE = 1.5

var start_position:Vector3
var spawn_position: Vector3

const SWIMMING_SPEED = 4.0
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 7.0
const CROUCH_SPEED = 3.0
var custom_speed:bool = false
const gravity = 22.5
var speed: float

var is_flying: bool = false
var speed_mode = false
var found_ground:bool = false
var swimming:bool = false
var crouching:bool = false

var set_fall_height:bool = false
var start_fall_height:float 
var end_fall_height:float
var fall_time:float = 0.0


@export var can_autojump: bool = true

# Clamp sync delta for faster interpolation
var sync_delta_max := 0.2
var sync_delta := 0.0
var start_interpolate := false
var position_before_sync: Vector3 = Vector3.ZERO
var last_sync_time_ms: int = 0

var _camera_transform:Transform3D
var _position: Vector3
var _velocity: Vector3
var _rotation: Vector3 = Vector3.ZERO
var _direction: Vector3 = Vector3.ZERO

var health
var protection:int
var hunger: float = 0

var spawn_point_set := {}
var check_terrian_timer:Timer

@export_group("STATS")
@export var max_health: int = 3
@export var fall_hurt_height:float = 4.0
@export_subgroup("HUNGER")
@export var base_hunger: float = 5.0
@export var hunger_update_time := 10.0
@export var moving_hunger_times_debuff := 2.0
@export var hunger_step: float = 0.1

@onready var hit_shader:ColorRect = $"hit shader"
@onready var rotation_root: Node3D = $RotationRoot
@onready var ANI: AnimationPlayer = $RotationRoot/Model/AnimationPlayer
@onready var hit_sfx: AudioStreamPlayer3D = $hit
@onready var ping_label: Label = $Ping
@onready var pos_label: Label = $Pos
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var floor_ray: RayCast3D = $floor
@onready var camera_shake: CameraShake3DNode = $RotationRoot/Head/CameraShake3DNode
@onready var terrain_interation:TerrainInteraction = $Hands/TerrainInteraction
@onready var drop_node: Node3D = $RotationRoot/Head/Camera3D/Drop_node
@onready var camera = $RotationRoot/Head/Camera3D
@onready var ray = $RotationRoot/Head/Camera3D/RayCast3D
@onready var auto_jump: RayCast3D = $RotationRoot/AutoJump
@onready var can_auto_jump_check: RayCast3D = $RotationRoot/AutoJump2
@onready var _synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var _move_direction := Vector3.ZERO
@onready var item_holder = $RotationRoot/Head/Camera3D/Sway/item_holder
@onready var third_person_model: Node3D = $"RotationRoot/Model" # TP


func _ready() -> void:
	Globals.add_item_to_hand.connect(add_item_to_hand)
	Globals.remove_item_in_hand.connect(remove_item_in_hand)
	Globals.hunger_points_gained.connect(hunger_points_gained)
	Globals.fnished_loading.connect(free_player)
	
	spawn_position = start_position
	
	if !Backend.playerdata.is_empty():
		if Backend.playerdata.hunger == null:
			hunger = base_hunger
		else:
			hunger = Backend.playerdata.hunger

		if Backend.playerdata.hunger == null:
			health = max_health
		else:
			health = Backend.playerdata.health
	else:
		hunger = base_hunger
		health = max_health

	if not is_multiplayer_authority():
		_synchronizer.delta_synchronized.connect(on_synchronized)
		_synchronizer.synchronized.connect(on_synchronized)
	else:
		camera.current = true
		
	_update_tp_fp_visibility()
	_add_keybindings()
	

func _exit_tree():
	save_data()
	
func _update_tp_fp_visibility() -> void:
	if is_multiplayer_authority():
		item_holder.show()
		third_person_model.hide()
	else:
		item_holder.hide()
		third_person_model.show()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() and Connection.is_peer_connected: return
	if Globals.paused: return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE: return
	
	if event is InputEventMouseMotion:
		rotation_root.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func update_shaders():
	var blocks_shader:ShaderMaterial = load("res://assets/materials/block_shader.tres")
	blocks_shader.set_shader_parameter("character_position", global_position)
	var grass_shader:ShaderMaterial = load("res://assets/materials/tall_grass.tres")
	grass_shader.set_shader_parameter("character_position", global_position)
	var flower_shader:ShaderMaterial = load("res://assets/materials/tall_flower.tres")
	flower_shader.set_shader_parameter("character_position", global_position)
	var reed_shader:ShaderMaterial = load("res://assets/materials/reeds.tres")
	reed_shader.set_shader_parameter("character_position", global_position)
	var wheat_shader:ShaderMaterial = load("res://assets/materials/wheat.tres")
	wheat_shader.set_shader_parameter("character_position", global_position)
	var wheat_seed_shader:ShaderMaterial = load("res://assets/materials/wheat_seed.tres")
	wheat_seed_shader.set_shader_parameter("character_position", global_position)

func _process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	update_shaders()
	hunger_update(_delta)

	
	_camera_transform = camera.global_transform
		
	pos_label.text = str("pos   ", global_position)
	camera.far = Globals.view_range
	
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() and Connection.is_peer_connected:
		interpolate_client(delta); return

	if !Globals.paused and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE and !DevConsole.visible:
		mine_and_place(delta)
	if !is_flying and !Globals.paused and !swimming and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE and !DevConsole.visible:
		normal_movement(delta)
	if is_flying and !Globals.paused and !swimming and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE and !DevConsole.visible:
		flying_movement(delta)
		
	if Globals.paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE or DevConsole.visible:
		velocity.x = lerp(velocity.x,0.0,.1)
		velocity.z = lerp(velocity.x,0.0,.1)

	# Head bob
	if SettingsManager.headbob:
		t_bob += delta * velocity.length() * float(is_on_floor())
		camera.transform.origin = _headbob(t_bob)
	
	# FOV
	if SettingsManager.varing_fov:
		var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
		var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
		
		
	if !is_flying and !swimming and found_ground:
		# Add the gravity.
		if not is_on_floor():
			
			if !set_fall_height:
				start_fall_height = global_position.y
				set_fall_height = true
				
			# Gravity
			velocity.y -= gravity * delta
		else:
			# Fall Damage
			end_fall_height = global_position.y
			
			if !swimming:
				if start_fall_height - end_fall_height >= fall_hurt_height and set_fall_height:
					var damage = start_fall_height - end_fall_height
					hit(damage)

			set_fall_height = false
	
	
	move_and_slide()
	set_sync_properties()
	
func set_sync_properties() -> void:
	_position = position
	_velocity = velocity
	_rotation = rotation_root.rotation
	_direction = _move_direction

func save_data() -> void:
	#Position
	Globals.send_to_server.emit({"client_id": Globals.client_id,"change_name": "Position_x", "change": position.x})
	Globals.send_to_server.emit({"client_id": Globals.client_id,"change_name": "Position_y", "change": position.y})
	Globals.send_to_server.emit({"client_id": Globals.client_id,"change_name": "Position_z", "change": position.z})
	
	#Stats
	Globals.send_to_server.emit({"client_id": Globals.client_id,"change_name": "health", "change": health})
	Globals.send_to_server.emit({"client_id": Globals.client_id,"change_name": "hunger", "change": hunger})
	
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
	
	if Connection.is_server():
		position = _position

func interpolate_client(delta: float) -> void:
	if not start_interpolate: return
	
	# Interpolate rotation
	rotation_root.rotation = _rotation.slerp(rotation_root.rotation, delta)
	
	if _direction:
		# Don't interpolate to avoid small jitter when stopping
		if (_position - position).length() > 1.0 and _velocity.is_zero_approx():
			position = _position # Fix misplacement
		
		if ANI.current_animation != "waling": ANI.play("waling")
	else:
		# Interpolate between position_before_sync and _position
		# and add to ongoing movement to compensate misplacement
		var t = 1.0 if is_zero_approx(sync_delta) else delta / sync_delta
		sync_delta = clampf(sync_delta - delta, 0, sync_delta_max)
		
		var less_misplacement = position_before_sync.move_toward(_position, t)
		position += less_misplacement - position_before_sync
		position_before_sync = less_misplacement
		
		if ANI.current_animation != "idle": ANI.play("idle")
	
	velocity.y -= gravity * delta
	move_and_slide()

func toggle_flying() -> void:
	is_flying = !is_flying

func toggle_clipping() -> void:
	collision.disabled = !collision.disabled
	if collision.disabled:
		is_flying = true
		
func show_pos() -> void:
	pos_label.visible = !pos_label.visible


func show_ping() -> void:
	ping_label.visible = !ping_label.visible


func _headbob(time: float) -> Vector3:
	var pos: Vector3 = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos


func is_print_logs() -> bool:
	var args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	return "--print_logs" in args

func add_item_to_hand(scene:PackedScene) -> void:
		
	remove_item_in_hand()
			
	var holdable_mesh = scene.instantiate()
	item_holder.add_child(holdable_mesh) 

func remove_item_in_hand() -> void:
	for i in item_holder.get_children():
		i.queue_free()
	
@rpc("any_peer","call_local")
func hit(damage: int = 1) -> void:
	
	#cant get damage that is neg
	if damage - protection < 0:
		damage = 0
	
	health -= (damage - protection)
	
	hit_sfx.play()
	camera_shake._shake()

	if health <= 0:
		death()

	# hit special effects
	if damage != 0:
		var mat = hit_shader.get_material() as ShaderMaterial
		var tween = create_tween()
		tween.tween_property(mat,"shader_parameter/inner_radius",0.4,.4)
		tween.tween_property(mat,"shader_parameter/inner_radius", 0.9,0.4)
		

func hunger_update(_delta: float) -> void:
	if _move_direction:
		hunger_update_time -= _delta * moving_hunger_times_debuff
	else:
		hunger_update_time -= _delta
		
	if hunger_update_time <= 0:
		
		if hunger == base_hunger:
			if health + 1 <= base_hunger:
				health += 1
			else:
				health = max_health
				
		if hunger <= 0:
			#print("dying of hunger")
			hit.rpc_id(get_multiplayer_authority(),1)
			health_updated.emit(health)
			
		if _move_direction:
			hunger -= hunger_step * moving_hunger_times_debuff
		else:
			hunger -= hunger_step
		
		hunger_updated.emit(hunger)
			
		hunger_update_time = 10


func death() -> void:
	health = max_health
	hunger = base_hunger
	
	drop_items(global_position)
	
	camera_shake._shake()
	
	global_position = spawn_position
	respawn.rpc(spawn_position)
	print("death")


@rpc("any_peer", "call_local", "reliable")
func respawn(pos: Vector3) -> void:
	print("respawn")
	global_position = pos
	velocity = Vector3.ZERO
	found_ground = false
	var aabb:AABB = AABB(pos,Vector3(40,60,40))
	if Helper.terrian.is_area_meshed(aabb):
		found_ground = true
	else:
		## creates a timer to know when the terrian does get meshed
		check_terrian_timer = Timer.new()
		check_terrian_timer.wait_time = 1.0
		add_child(check_terrian_timer)
		check_terrian_timer.start()
		check_terrian_timer.timeout.connect(_check_terrian_timer)
		
func drop_items(drop_position:Vector3):
	var object_spawner:MultiplayerSpawner
	
	var inventory_items = Helper.player_inventory.get_all()
	var hotbar_items = Helper.hotbar.get_all()
	
	for item_name in hotbar_items:
		Helper.hotbar.remove_item(item_name,hotbar_items[item_name].amount)
		Helper.object_spawner.spawn_object.rpc_id(1,[1,global_position,"res://scenes/items/dropped_item.tscn",hotbar_items[item_name].item_path,hotbar_items[item_name].amount])
	
	for item_name in inventory_items:
		Helper.player_inventory.remove_item(item_name,inventory_items[item_name].amount)
		Helper.object_spawner.spawn_object.rpc_id(1,[1,global_position,"res://scenes/items/dropped_item.tscn",inventory_items[item_name].item_path,inventory_items[item_name].amount])

func hunger_points_gained(amount: int) -> void:
	if hunger + amount < base_hunger:
		hunger += amount
	else:
		hunger = base_hunger

func normal_movement(delta:float):
	# Handle Sprint.
	if not custom_speed:
		if Input.is_action_pressed("Sprint"):
			speed = SPRINT_SPEED
		else:
			speed = WALK_SPEED
			
			# Crouch
			if Input.is_action_pressed("Crouch"):
				crouching = true
				speed = CROUCH_SPEED
			else:
				speed = WALK_SPEED
				crouching = false
			
	var input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	_move_direction = (rotation_root.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if _move_direction:
			if ANI.current_animation != "waling":
				ANI.play("waling")
			velocity.x = _move_direction.x * speed
			velocity.z = _move_direction.z * speed
		else:
			if ANI.current_animation != "idle":
				ANI.play("idle")
					
			velocity.x = lerp(velocity.x, _move_direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, _move_direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, _move_direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, _move_direction.z * speed, delta * 3.0)
		
	# Handle Jump.
	if Input.is_action_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	## Auto jump
	var moving_forward = input_dir.y < 0
	if can_autojump and moving_forward and is_on_floor():
		if auto_jump.is_colliding() and !can_auto_jump_check.is_colliding():
			velocity.y = JUMP_VELOCITY
			
			
func flying_movement(delta:float):
	var dir = Vector3.ZERO
	if Input.is_action_pressed("__debug_camera_forward"): 	dir.z -= 1
	if Input.is_action_pressed("__debug_camera_back"): 		dir.z += 1
	if Input.is_action_pressed("__debug_camera_left"): 		dir.x -= 1
	if Input.is_action_pressed("__debug_camera_right"): 	dir.x += 1
	if Input.is_action_pressed("__debug_camera_up"): 		dir.y += 1
	if Input.is_action_pressed("__debug_camera_down"): 		dir.y -= 1

	_move_direction = (rotation_root.transform.basis * Vector3(dir.x, dir.y, dir.z)).normalized()
	
	velocity = lerp(velocity, _move_direction * SPRINT_SPEED, 0.1)
		
func mine_and_place(delta:float):
	var hotbar = Helper.hotbar
	var hotbar_item:ItemBase = hotbar.get_current().item

			
	if Input.is_action_just_pressed("Build"):
		
		if ray.is_colliding():
			var coll = ray.get_collider()
			
			if coll is CreatureBase:
						
				if coll.creature_resource.utility != null:
					var util = coll.creature_resource.utility as Utilities
					if util.has_ui:
						print(coll.spawn_pos)
						Globals.open_registered_ui.emit(coll.spawn_pos)
		
	if Input.is_action_just_pressed("Mine"):
		
		if ray.is_colliding():
			var coll = ray.get_collider()
			
			if coll.is_in_group("Hitbox"):
				var parent = coll.get_parent()
				if parent is HealthComponent:
					if hotbar_item is ItemTool:
						print("attack ",parent.owner.name)
						parent.rpc_id(parent.get_multiplayer_authority(),"hit",hotbar_item.damage)
					else:
						print("attack ",parent.owner.name)
						parent.rpc_id(parent.get_multiplayer_authority(),"hit",1)
	
	if Input.is_action_just_released("Mine"):
		if hotbar_item is ItemTool:
			if hotbar_item.projectable:
				if hotbar_item.throws_self:
					var current_slot = hotbar.get_current() as Slot
					current_slot.amount -= 1
					Helper.object_spawner.spawn_object.rpc_id(1,[get_multiplayer_authority(),_camera_transform,"res://scenes/items/weapons/projectile.tscn",hotbar_item.projectile_resource.get_path()])
				else:
					var find_item = hotbar_item.projectile_item
					var item_slot = Globals.find_item(find_item)
					if item_slot != null:
						if item_slot.amount - hotbar_item.amount_needed:
							if item_slot.amount >= 0:
								item_slot.amount -= hotbar_item.amount_needed
								Helper.object_spawner.spawn_object.rpc_id(1,[get_multiplayer_authority(),_camera_transform,"res://scenes/items/weapons/projectile.tscn",hotbar_item.projectile_resource.get_path()])
					
func _speed_mode():
	speed_mode = !speed_mode
	if speed_mode:
		speed * 3
	else:
		speed * 1
		
# after loading lets the player move
func free_player():
	MouseMode.set_captured(true)
	found_ground = true

func _check_terrian_timer():
	var aabb:AABB = AABB(global_position,Vector3(40,60,40))
	if Helper.terrian.is_area_meshed(aabb):
		found_ground = true
		check_terrian_timer.queue_free()
		

func _add_keybindings() -> void:
	var actions = InputMap.get_actions()
	if "__debug_camera_forward" not in actions: _add_key_input_action("__debug_camera_forward", KEY_W)
	if "__debug_camera_back" 	not in actions: _add_key_input_action("__debug_camera_back", KEY_S)
	if "__debug_camera_left" 	not in actions: _add_key_input_action("__debug_camera_left", KEY_A)
	if "__debug_camera_right" 	not in actions: _add_key_input_action("__debug_camera_right", KEY_D)
	if "__debug_camera_up" 		not in actions: _add_key_input_action("__debug_camera_up", KEY_SPACE)
	if "__debug_camera_down" 	not in actions: _add_key_input_action("__debug_camera_down", KEY_SHIFT)

func _add_key_input_action(name: String, key: Key) -> void:
	var ev = InputEventKey.new()
	ev.physical_keycode = key
	
	InputMap.add_action(name)
	InputMap.action_add_event(name, ev)
