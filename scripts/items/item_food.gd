extends ItemBase
class_name ItemFood

@export var food_points: int
@export var eat_time: float

@export var time_rot_step:float = 5.0 ## the time it takes to change the rot stage
@export var max_rot_steps := 3

@export var rot_step_textures:Array[Texture]
@export var rot_step_holdable_models:Array[PackedScene]

@export_group("animations")
@export var use_ani:Animation
