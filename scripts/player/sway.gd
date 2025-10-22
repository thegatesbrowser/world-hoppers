extends Node3D


@export var swayLeft := Vector3(0,0.11,0)
@export var swayRight := Vector3(0,-0.11,0)
@export var swayUp := Vector3(-0.11,0,0)
@export var swayDown := Vector3(0.11,0,0)
@export var swayNormal : Vector3

var mouseMovementY
var mouseMovementX
@export var swayThreshold := 5
@export var swayLerp := 1

func _input(event):
	if event is InputEventMouseMotion:
		mouseMovementY = -event.relative.x
		mouseMovementX = event.relative.y


func _physics_process(delta: float) -> void:
	if mouseMovementY != null:
		if mouseMovementY > swayThreshold:
			rotation = rotation.lerp(swayLeft, swayLerp * delta)
		elif mouseMovementY < -swayThreshold:
			rotation = rotation.lerp(swayRight, swayLerp * delta)

		if mouseMovementX > swayThreshold:
			rotation = rotation.lerp(swayUp, swayLerp * delta)
		elif mouseMovementX < -swayThreshold:
			rotation = rotation.lerp(swayDown, swayLerp * delta)

		else:
			rotation = rotation.lerp(swayNormal, swayLerp * delta)
