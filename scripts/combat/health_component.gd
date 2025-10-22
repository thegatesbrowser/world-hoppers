extends Node
class_name HealthComponent

@export_group("Hitbox")
@export var hitbox_collision:Shape3D
@export var hitbox_collision_offset:Vector3

@export_group("Health")
@export var max_health:int
var health:int

@export var health_bar_prefab:PackedScene
var health_bar

func _ready() -> void:
	health = max_health
	var hitbox := Area3D.new()
	hitbox.name = "hitbox"
	hitbox.position = hitbox_collision_offset
	var collision := CollisionShape3D.new()
	collision.shape = hitbox_collision
	add_child(hitbox,true)
	hitbox.add_child(collision)
	hitbox.add_to_group("Hitbox")

@rpc("any_peer","call_local")
func hit(damage:int):
	health -= damage
	print("damaged: amount ",damage," current health ",health)
	
	if health_bar_prefab:
		
		if max_health - damage == health: ## first hit
			create_healthbar(Vector3(0,0,0))
			
		update_healthbar(health,max_health)
		
	if health <= 0:
		killed.rpc_id(1)
		
func update_healthbar(health:int,max_health:int):
	pass
	
func create_healthbar(offset:Vector3) -> void:
	var health_bar = health_bar_prefab.instantiate()
	health_bar.name = "health_bar"
	add_child(health_bar)

@rpc("authority")
func killed() -> void:
	owner.call_deferred("queue_free")
	print(owner.name, " killed ")
