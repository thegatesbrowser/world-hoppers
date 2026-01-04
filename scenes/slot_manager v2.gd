extends Control
class_name SlotManager

var current_selected_slot:Slot
var current_hotbar_slot_selected:Slot

@onready var temp_visuals:Control = $SelectedSlot
@onready var selected_slot_visuals:TextureRect = $SelectedSlot/CenterContainer/Image
@onready var selected_slot_amount:Label = $SelectedSlot/amount
@onready var selected_slot_health:Panel = $SelectedSlot/Health
@onready var selected_slot_background:TextureRect = $SelectedSlot/Background_Image

func slot_clicked(slot:Slot):
	pass

func _process(delta: float) -> void:
	
	
	temp_visuals_update(delta)
	if Input.is_action_just_pressed("Right"):
		var closest_slot = get_closest_slot(get_global_mouse_position())
		print(closest_slot)
		
		closest_slot.visual_update(load("res://assets/models/axe.png"),0,false,false,false)
	
func update_temp_visuals(slot:Slot):
	if slot.item != null:
		selected_slot_visuals.texture = slot.item.texture
		selected_slot_amount.text = str(slot.amount)
		selected_slot_health.modulate = slot.health_panel.modulate
		selected_slot_health.visible = slot.health_panel.visible
		selected_slot_background.texture = slot.background_texturerect.texture
		selected_slot_background.visible = slot.background_texturerect.visible

func temp_visuals_update(delta:float):
	temp_visuals.global_position = get_global_mouse_position()
	
	if current_selected_slot != null:
		
		var closest_slot
		if current_selected_slot.item is Blueprint:
			closest_slot = get_closest_slot(get_global_mouse_position(),["blueprint"])
		else:
			closest_slot = get_closest_slot(get_global_mouse_position())
		
		if Input.is_action_just_released("Mine"):
			Helper.sound_manager.play_UI_sound()
			
			if closest_slot and closest_slot != current_selected_slot:
				if blueprint_check(current_selected_slot.item,closest_slot):
					print(closest_slot.get_parent().name)
					
					if closest_slot.item == null:
						#_move_item_to_slot(closest_slot)
						print("moved")
						closest_slot.item = current_selected_slot.item
						closest_slot.amount = current_selected_slot.amount
						closest_slot.health = current_selected_slot.health
						closest_slot.rot = current_selected_slot.rot
						closest_slot.update_slot()
						#
						current_selected_slot.item = null
						current_selected_slot.update_slot()
						current_selected_slot = null
						temp_visuals.hide()
					elif closest_slot.item == current_selected_slot.item:
						if closest_slot.amount + current_selected_slot.amount < closest_slot.item.max_stack:
							closest_slot.amount += current_selected_slot.amount
							closest_slot.update_slot()
							current_selected_slot.item = null
							current_selected_slot.update_slot()
							current_selected_slot = null
							temp_visuals.hide()
						else:
							print("cant stack")
							current_selected_slot = null
							temp_visuals.hide()
					else:
						var hold_health = closest_slot.health
						var hold_amount = closest_slot.amount
						var hold_rot = closest_slot.rot
						var hold_item = closest_slot.item

						closest_slot.item = current_selected_slot.item
						closest_slot.rot = current_selected_slot.rot
						closest_slot.amount = current_selected_slot.amount
						closest_slot.health = current_selected_slot.health

						current_selected_slot.item = hold_item
						current_selected_slot.amount = hold_amount
						current_selected_slot.health = hold_health
						current_selected_slot.rot = hold_rot

						current_selected_slot.update_slot()
						closest_slot.update_slot()

						current_selected_slot = null
						temp_visuals.hide()
				else:
					print("blueprint slot")
					current_selected_slot = null
					temp_visuals.hide()
			else:
				print("no closest slot")
				current_selected_slot = null
				temp_visuals.hide()
	else:
		if Input.is_action_just_pressed("Mine") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			var closest_slot = get_closest_slot(get_global_mouse_position())
			if closest_slot.item != null and get_global_mouse_position().distance_to(closest_slot.global_position) < 100:
				Helper.sound_manager.play_UI_sound()
				#closest_slot.visual_update(null,0,false,false,false)
				update_temp_visuals(closest_slot)
				current_selected_slot = closest_slot
				
				temp_visuals.show()
			
		#closest_slot.visual_update(load("res://assets/models/axe.png"),0,false,false,false)

func get_closest_slot(mouse_position:Vector2,look_for:Array[String] = ["hotbar","inventory"]) -> Slot:
	var last_distance
	var closest_slot:Slot
	
	var all_slots = get_tree().get_nodes_in_group("Slot")
	
	for slot in get_tree().get_nodes_in_group("Slot"):
		if not look_for.has(slot.type):
			all_slots.erase(slot)
	
	for slot in all_slots:
		if slot.visible:
			var distance:float = mouse_position.distance_to(slot.global_position + slot.size/2)
			if last_distance == null:
				last_distance = distance
				closest_slot = slot
			elif distance <= last_distance:
				last_distance = distance
				closest_slot = slot
				
	return closest_slot


func blueprint_check(item:ItemBase,slot:Slot) -> bool:
	if slot.type == "blueprint":
		if item is Blueprint:
			return true
		else:
			return false
	else:
		return true
		
func _can_equip(slot: Slot, item) -> bool:
	if slot.type == "chestplate":
		return item is ItemArmour and item.chest
	if slot.type == "pants":
		return item is ItemArmour and item.pants
	if slot.type == "helmet":
		return item is ItemArmour and item.helmet
	return true

func add_item_to_hotbar_or_inventory(item:ItemBase,item_path:String = ""):
	print(item)
	if item == null and item_path != "":
		item = load(item_path)
		
	if !Helper.hotbar.check_spawn(item): 
		print(item.unique_name, "inv")
		Globals.spawn_item_inventory.emit(item)
	else:
		print(item.unique_name)
		Helper.hotbar.spawn_item_hotbar(item)
