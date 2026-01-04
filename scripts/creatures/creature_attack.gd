extends State

var target:Player = null

@export var attack_raycast: RayCast3D
@export var creature : CreatureBase

func Enter(data:Dictionary):
	if data.has("player"):
		target = data.player
		print(data.player.name)
	
func Physics_Update(delta:float):
	if not target: 
		Transitioned.emit(self,"Idle",{})
		return
	
	var direction = creature.global_position.direction_to(target.global_position)

	creature.velocity.x = lerpf(creature.velocity.x,direction.x * creature.creature_resource.speed,.5)
	creature.velocity.z = lerpf(creature.velocity.z,direction.z * creature.creature_resource.speed,.5)
	
	creature.guide.global_position = target.global_position
	
	attack_raycast.look_at(target.global_position)
	
	var distance:float = creature.global_position.distance_to(target.global_position)
	
	if attack_raycast.is_colliding():
		var coll = attack_raycast.get_collider()
		if coll is Player:
			coll.rpc_id(coll.get_multiplayer_authority(),"hit",creature.creature_resource.damage)
			Transitioned.emit(self,"Idle",{})
			
	#print("distance ",distance)
	Transitioned.emit(self,"Idle",{})
