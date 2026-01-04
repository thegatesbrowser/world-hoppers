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
@onready var pivot: Node3D = $Pivot
@onready var ANI: AnimationPlayer = $Pivot/Model/AnimationPlayer
@onready var hit_sfx: AudioStreamPlayer3D = $hit
@onready var ping_label: Label = $Ping
@onready var pos_label: Label = $Pos
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var floor_ray: RayCast3D = $floor
@onready var camera_shake: CameraShake3DNode = $Pivot/Head/CameraShake3DNode
@onready var drop_node: Node3D = $Pivot/Head/Camera3D/Drop_node
@onready var camera = $Pivot/Head/Camera3D
@onready var ray = $Pivot/Head/Camera3D/RayCast3D
@onready var auto_jump: RayCast3D = $Pivot/AutoJump
@onready var can_auto_jump_check: RayCast3D = $Pivot/AutoJump2
@onready var _move_direction := Vector3.ZERO
@onready var item_holder = $Pivot/Head/Camera3D/Sway/item_holder
@onready var third_person_model: Node3D = $"Pivot/Model" # TP


func _ready() -> void:
	if is_multiplayer_authority():
		camera.make_current()
		third_person_model.hide()
	
	Globals.add_item_to_hand.connect(add_item_to_hand)
	Globals.remove_item_in_hand.connect(remove_item_in_hand)
	Globals.hunger_points_gained.connect(hunger_points_gained)
	Globals.fnished_loading.connect(free_player)
	
	spawn_position = start_position
	
	hunger = base_hunger
	health = max_health

	_update_tp_fp_visibility()
	_add_keybindings()
	

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
		pivot.rotate_y(-event.relative.x * SENSITIVITY)
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
	if not is_multiplayer_authority():
		return

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
	_rotation = pivot.rotation
	_direction = _move_direction

func save_data() -> void:
	#Position
	Globals.send_to_server.emit({"client_id": Globals.client_id,"change_name": "Position_x", "change": position.x})
	Globals.send_to_server.emit({"client_id": Globals.client_id,"change_name": "Position_y", "change": position.y})
	Globals.send_to_server.emit({"client_id": Globals.client_id,"change_name": "Position_z", "change": position.z})
	
	#Stats
	Globals.send_to_server.emit({"client_id": Globals.client_id,"change_name": "health", "change": health})
	Globals.send_to_server.emit({"client_id": Globals.client_id,"change_name": "hunger", "change": hunger})

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
	
	camera_shake._shake()
	
	global_position = spawn_position
	respawn(spawn_position)
	print("death")


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
	_move_direction = (pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
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

	_move_direction = (pivot.transform.basis * Vector3(dir.x, dir.y, dir.z)).normalized()
	
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


func _on_tree_exiting() -> void:
	save_data()
