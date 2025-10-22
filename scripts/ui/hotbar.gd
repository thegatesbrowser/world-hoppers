extends ScrollContainer
class_name HotBar

@export var eat_sfx: AudioStreamPlayer
@onready var slot_container: HBoxContainer = $"MarginContainer/VBoxContainer/Slots"

var selected_item: ItemBase 

var current_key = 1
var slots: Array = [] ## slot_container 
var keys
var slot_manager:SlotManager

func _ready() -> void:
	slot_manager = get_node("/root/Main").find_child("SlotManager")

	Globals.spawn_item_hotbar.connect(spawn_item_hotbar)
	Globals.remove_item_from_hotbar.connect(remove_item)
	
	slots = slot_container.get_children()
	
	for slot in slots:
		# connect signals to save hotbar data
		slot.item_changed.connect(slot_updated)

	if !Backend.playerdata.is_empty():
		if Backend.playerdata.Hotbar != null:
			update(JSON.parse_string(Backend.playerdata.Hotbar))
			# update the hotbar with the saved data
			pass
			
	
			
func _input(_event: InputEvent) -> void:
	if Globals.paused: return
	
	if Input.is_action_just_released("Scroll_Up"):
		current_key -= 1
	
	elif Input.is_action_just_released("Scroll_Down"):
		current_key += 1
		
	else:
		for i in range(9):
			if Input.is_action_just_pressed(str(i + 1)):
				current_key = i
		if Input.is_action_just_pressed("0"):
			current_key = 9
	
	current_key %= 10
	_unpress_all()
	slots[current_key].focused = true
	_press_key(current_key)


func _unpress_all() -> void:
	for i in slot_container.get_children():
		i.button_pressed = false
		i.focused = false


func get_current() -> Slot:
	return slots[current_key]


func _press_key(i: int) -> void:
	selected_item = null
	slots[i].button_pressed = true
	Globals.remove_item_in_hand.emit()
	slot_manager.selected_slot = slots[current_key]
	
	if slots[current_key].item != null:
		selected_item = slots[current_key].item.duplicate()
	
		## add holdable if has one
		
		## General holdables
		if slots[current_key].item.holdable_mesh != null:
				Globals.add_item_to_hand.emit(slots[current_key].item.holdable_mesh)
				
		## Placeable items
		if slots[current_key].item is ItemBlock:
			Globals.current_block = slots[current_key].item.unique_name
			Globals.can_build = true 
			Globals.custom_block = &""
		else:
			Globals.can_build = false

		## Tool items
		if slots[current_key].item is ItemTool:
			Globals.custom_block = slots[current_key].item.unique_name

		## Food items
		elif slots[current_key].item is ItemFood: 
			selected_item = slots[current_key].item
			var holdable_array = selected_item.rot_step_holdable_models as Array
			if not holdable_array.is_empty():
				var holdable = holdable_array[slots[current_key].rot]
				Globals.add_item_to_hand.emit(holdable)
		else:
			## Others ?
			#Globals.custom_block = slots[current_key].item.unique_name
			#Globals.can_build = true 
			pass
			
	else:
		Globals.can_build = false
		
	current_key = i


func remove_item(unique_name: String = "", amount: int = 1) -> void:
	#print("remove from hotbar ",unique_name,amount)
	if unique_name == "":
		var slot: Slot = get_current()
		slot.amount -= amount
		if slot.amount <= 0:
			slot.item = null
		slot.update_slot()

	else:
		for slot in slots:
			if slot.item != null:
				if slot.item.unique_name == unique_name:
					slot.amount -= amount
					if slot.amount <= 0:
						slot.item = null
					slot.update_slot()


func get_all() -> Dictionary:
	var items : Dictionary
	
	for slot in slots:
		var item = slot.item as ItemBase
		if item != null:
			items[item.unique_name] = {
				"amount":slot.amount,
				"item_path":item.resource_path
			}
			
	return items

func _on_dropall_pressed() -> void:
	print("drop")
	pass

func save() -> Dictionary:
	var save_data:Dictionary = {}
	for slot in slots:
		if slot.item != null:
			save_data[str(slot.get_index())] = {
				"item_path" : slot.item.get_path(),
				"amount" : slot.amount,
				"parent" : slot.get_parent().name,
				"health" : slot.health,
				"rot" : slot.rot,
				}
		else:
			save_data[str(slot.get_index())] = {
				"item_path" : "",
				"amount" : slot.amount,
				"parent" : slot.get_parent().name,
				"health" : slot.health,
				"rot" : slot.rot,
				}
	return save_data

func update(data) -> void:
	#print("update hotbar ",info)
	for i in data:
		
		var slot = find_child(data[i].parent).get_child(i.to_int())
		
		var item_file:String = data[i].item_path.get_file()
		
		if item_file != "":
			var user_path:String = "user://items/"+item_file
			var normal_path:String = data[i].item_path
			
			if FileAccess.file_exists(user_path):
				slot.item = load(user_path)
			else:
				slot.item = load(data[i].item_path)
				
		else:
			slot.item = null
			
		slot.health = data[i].health
		slot.amount = data[i].amount
		slot.rot = data[i].rot
		slot.update_slot()
		
	Globals.hotbar_full = hotbar_full()
		
# Signal to update the slot when item changes
func slot_updated(index: int, item_path: String, amount: int,parent:String,health:float,rot:int):
	#print("hotbar slot updated ",index,item_path,amount,parent,health,rot)
	if !Backend.playerdata.is_empty():
		if Backend.playerdata.Inventory == null:
			Globals.save.emit()
		else:
			Globals.save_slot.emit(index,item_path,amount,parent,health,rot)
	
func check_spawn(item:ItemBase) -> bool:
	for slot in slots:
		if slot.item == null:
			return true
		elif slot.item.unique_name == item.unique_name:
			if slot.item.max_stack >= slot.amount:
				return true
	return false

func spawn_item_hotbar(item:ItemBase) -> void:
	#print("spawn item hotbar ",item.unique_name)
	for slot in slots:
		if slot.item == null:
			slot.item = item
			slot.update_slot()
			break
		elif slot.item.unique_name == item.unique_name:
			if slot.item.max_stack >= slot.amount:
				#return
				slot.amount += 1
				slot.update_slot()
				break
				
				
func hotbar_full() -> bool:
	var full:bool = true
	for slot in slots:
		if slot.item == null:
			full = false
			#return true
	return full
