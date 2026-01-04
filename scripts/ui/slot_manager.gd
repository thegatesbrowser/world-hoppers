extends Node
class_name SlotManager

var hotbar_full:bool = false
var last_clicked_slot:Slot
var selected_slot:Slot ## the slot that is selected in the hotbar

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Drop"):
		_drop_last_clicked_item()

func _drop_last_clicked_item() -> void:
	#print("dropping last clicked item")
	if not last_clicked_slot: return
	
	var item := last_clicked_slot.item as ItemBase
	if item:
		Globals.drop_item.emit(multiplayer.get_unique_id(), item)
		if last_clicked_slot.type == "inventory":
			Globals.remove_item.emit(item.unique_name, 1)
		else:
			Globals.remove_item_from_hotbar.emit(item.unique_name, 1)
		last_clicked_slot = null

func slot_clicked(slot:Slot):
	if not Globals.paused:
		return

	_play_ui_sound()
	
	if slot.item is Blueprint:
		Globals.blueprint_hovered.emit(slot.item,slot)
	else:
		Globals.blueprint_unhovered.emit()

	if last_clicked_slot == null:
		last_clicked_slot = slot
		last_clicked_slot.focused = true
		return
		
	
	if slot == last_clicked_slot: ## deselect
		last_clicked_slot.focused = false
		last_clicked_slot = null
		return
		
	if slot.item == null:
		if last_clicked_slot.item.unique_name != "blueprint_station_craftable":
			#print(last_clicked_slot.item.unique_name)
			_move_item_to_slot(slot)
		else:
			last_clicked_slot.focused = false
			last_clicked_slot = null
			
	
	if slot != null and last_clicked_slot != null:
		if slot.item != null and last_clicked_slot.item != null:
			if slot.item.unique_name == last_clicked_slot.item.unique_name:
				print("stack")
				_stack_items(slot)
	if slot != null and last_clicked_slot != null:
		if slot.item != null and last_clicked_slot.item != null:
			if last_clicked_slot.item.unique_name != "blueprint_station_craftable":
				if slot.item.unique_name != "blueprint_station_craftable":
					_swap_items(slot)
	
	if last_clicked_slot != null:
		last_clicked_slot.focused = false
		last_clicked_slot = null
			
				
func add_item_to_hotbar_or_inventory(item:ItemBase):
	if !Helper.hotbar.check_spawn(item): Globals.spawn_item_inventory.emit(item)
	else:
		Helper.hotbar.spawn_item_hotbar(item)

func _move_item_to_slot(slot: Slot) -> void:
	if not _can_equip(slot, last_clicked_slot.item):
		return
		
	if not blueprint_check(last_clicked_slot.item,slot): return
		
	slot.item = last_clicked_slot.item
	slot.health = last_clicked_slot.health
	slot.amount = last_clicked_slot.amount
	slot.rot = last_clicked_slot.rot
	last_clicked_slot.item = null
	slot.update_slot()
	last_clicked_slot.update_slot()
	last_clicked_slot.focused = false
	last_clicked_slot = null

func _stack_items(slot: Slot) -> void:
	if slot.amount + last_clicked_slot.amount < slot.item.max_stack:
		if slot.item is ItemFood and last_clicked_slot.rot != slot.rot:
			return

		slot.amount += last_clicked_slot.amount
		last_clicked_slot.item = null

		last_clicked_slot.update_slot()
		slot.update_slot()

		last_clicked_slot.focused = false
		last_clicked_slot = null
		

func _swap_items(slot: Slot) -> void:
	if not _can_equip(slot, last_clicked_slot.item):
		return
	if not _can_equip(last_clicked_slot, slot.item):
		return
		
	if not blueprint_check(last_clicked_slot.item,slot): return
	
	if not blueprint_check(slot.item,last_clicked_slot): return
	
	var hold_health = slot.health
	var hold_amount = slot.amount
	var hold_rot = slot.rot
	var hold_item = slot.item

	slot.item = last_clicked_slot.item
	slot.rot = last_clicked_slot.rot
	slot.amount = last_clicked_slot.amount
	slot.health = last_clicked_slot.health

	last_clicked_slot.item = hold_item
	last_clicked_slot.amount = hold_amount
	last_clicked_slot.health = hold_health
	last_clicked_slot.rot = hold_rot

	last_clicked_slot.update_slot()
	slot.update_slot()

	last_clicked_slot.focused = false
	last_clicked_slot = null
	

func _can_equip(slot: Slot, item) -> bool:
	if slot.type == "chestplate":
		return item is ItemArmour and item.chest
	if slot.type == "pants":
		return item is ItemArmour and item.pants
	if slot.type == "helmet":
		return item is ItemArmour and item.helmet
	return true

func _play_ui_sound() -> void:
	var soundmanager = get_node("/root/Main").find_child("SoundManager")
	soundmanager.play_UI_sound()

func blueprint_check(item:ItemBase,slot:Slot) -> bool:
	if slot.type == "blueprint":
		if item is Blueprint:
			return true
		else:
			return false
	else:
		return true

func blueprint_holder_full():
	var blueprint_holder = get_tree().get_first_node_in_group("Blueprints")
	
	for slot in blueprint_holder.get_children():
		if slot.item == null: return slot
		
	return null
