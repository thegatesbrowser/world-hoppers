extends  Node

const item_lib:ItemsLibrary = preload("res://resources/items_library.tres")

@onready var blocks: Node = $Blocks


func _ready() -> void:
	item_lib.init_items()

## the node has to the same as the type else wont work
func play_sound(type: StringName, pos: Vector3,sound_type:String = "break") -> void:
	if not item_lib.items.has(type): return
		
	var item = item_lib.items[type]
	
	if item:
		if item is ItemBlock:
			if sound_type == "break":
				if item.block_sound:
					var sound := AudioStreamPlayer3D.new()
					sound.stream = item.block_sound
					sound.volume_db = item.volume
					sound.pitch_scale = item.pitch
					sound.max_distance = item.max_distance
					sound.panning_strength = item.panning_strength
					sound.autoplay = true
					
					sound.position = pos
					
					blocks.add_child(sound)
					
					sound.finished.connect(fnished_sound)
			elif sound_type == "walk":
				if item.walk_block_sound:
					var sound := AudioStreamPlayer3D.new()
					sound.stream = item.walk_block_sound
					sound.volume_db = item.walk_volume
					sound.pitch_scale = item.walk_pitch
					sound.max_distance = item.walk_max_distance
					sound.panning_strength = item.walk_panning_strength
					sound.autoplay = true
					
					sound.position = pos
					
					blocks.add_child(sound)
					
					sound.finished.connect(fnished_sound)
				
	#var sound = find_child(type)
	#if sound != null:
		#sound.global_position = pos
		#sound.play()


func play_UI_sound(type: StringName = &"UI") -> void:
	var sound = find_child(type)
	if sound != null:
		sound.play()

func fnished_sound():
	for i in blocks.get_children():
		if i is AudioStreamPlayer3D:
			if !i.playing: i.queue_free()
