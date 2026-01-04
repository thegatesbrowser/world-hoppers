extends TextureButton
class_name Slot

signal item_changed(index:int,item_path:String,amount:int,parent:String,health:float,rot:int)

@export var locked:bool = false
@export var pressed_panel: Panel

@export var type: String = "inventory"
@export var amount: int = 1

@export var item: ItemBase
@export var background_texture:Texture

@onready var background_texturerect: TextureRect = $"CenterContainer/background texture"
@onready var image: TextureRect = $CenterContainer/Image
@onready var amount_label: Label = $amount
@onready var health_panel:Panel = $Health

var max_rot:int = 0
var rot:int = 0
var index:int
var health:int = 10001
var played_ani:bool = false
var focused:bool = false

func _process(_delta: float) -> void: 
	if item != null:
		if item is ItemTool:
			update_health()
	if focused:
		if !played_ani:
			GlobalAnimation._tween(self,"bounce",.3)
			played_ani = true
		pressed_panel.show()
	else:
		played_ani = false
		pressed_panel.hide()

		
func _ready() -> void:
	background_texturerect.texture = background_texture
	index = get_index()
	
	if item != null:
		background_texturerect.texture = item.background_texture
		image.texture = item.texture
		
	if item is ItemFood:
		start_rot(item.time_rot_step)

	update_slot()


func _on_pressed() -> void:
	#print("pressed slot ",index)
	var slot_manager = get_node("/root/Main").find_child("SlotManager")
	
	if !locked:
		if Globals.paused:
			if type == "hotbar":
				if item != null:
					Globals.hotbar_slot_clicked.emit(self)
					
			
			if item != null:
				slot_manager.slot_clicked(self)
			else:
				if slot_manager.last_clicked_slot != null:
					slot_manager.slot_clicked(self)


func update_slot() -> void:
	amount_label.text = str(amount)
	
	## destory item if amount is 0
	if amount <= 0:
		amount = 1
		item = null
		image.texture = null
		amount_label.hide()

	if item != null:
		background_texturerect.texture = item.background_texture
		image.texture = item.texture

		if amount >= 2:
			amount_label.show()
		else:
			amount_label.hide()

		if item is ItemFood:
			max_rot = item.max_rot_steps
			if item.rot_step_textures.size() >= rot:
				if item.rot_step_textures.size() != 0:
					image.texture = item.rot_step_textures[rot]
			else:
				item = null
				update_slot()

		else:
			stop_rot()

		if item is Blueprint:
			$Background_Image.show()
		else:
			$Background_Image.hide()
			
		if not item is ItemTool:
			health_panel.hide()
			$health.text = str(health)
		else:
			$health.text = str(health, "/", item.max_health)
			update_health()


		
		item_changed.emit(index,item.get_path(),amount,get_parent().name,health,rot)


	else:
		#print("item is null")
		amount = 1
		image.texture = null
		health = 0
		item_changed.emit(index,"",amount,get_parent().name,health,rot)
		health_panel.hide()
		amount_label.hide()
		#update_health()
		$Background_Image.hide()
		

func used() -> void:
	#print("used slot ",index)
	health -= item.degrade_rate
	if health <= 0:
		item = null
	update_slot()
	
var _time
var timer:Timer

func start_rot(time:float) -> void:
	var rot_timer = Timer.new()
	rot_timer.wait_time = time
	rot_timer.name = "rot_timer"
	add_child(rot_timer)
	rot_timer.start()
	rot_timer.timeout.connect(rot_update)
	timer = rot_timer
	_time = time
	
func stop_rot() -> void:
	var rot_timer = find_child("rot_timer")
	if rot_timer != null:
		#print("stopping rot timer")
		rot_timer.stop()
		rot = 0
	
func rot_update() -> void:
	
	rot += 1
	if rot >= max_rot:
		item = null
	update_slot()

func update_health():
		
	var heath_range = range(0,item.max_health + 1)
			
	var half_health = heath_range.size() / 2

	var red_health = half_health - half_health / 2

	var green_health = half_health + half_health / 2

	var health_pos = heath_range.find(roundi(health))

	if health_pos in range(red_health,half_health + 1):
		health_panel.modulate = Color.YELLOW
		#print("YELLOW")


	if health_pos >= green_health:
		
		health_panel.modulate = Color.GREEN
		#print("GREEN")
		
	if health_pos <= red_health:
		health_panel.modulate = Color.RED
		#print("RED")
	
	health_panel.show()
	
