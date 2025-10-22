extends CanvasLayer

@export var enabled: bool :
	get:
		return visible
	set(value):
		visible = value
		counter.enabled = value
@onready var counter = $Counter


# Register the FPS counter with a console if the console exists.
func _ready():
	
	enabled = false


func toggle_enabled():
	enabled = !enabled
