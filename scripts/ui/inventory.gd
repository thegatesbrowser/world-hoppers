extends ScrollContainer
class_name Inventory

# External references
@export var sync:bool = true ## FALSE for the player main inventory
@export var slot_container: GridContainer
@export var metadata:bool = true
@export var id: Vector3
@export var items_library: ItemsLibrary

#var times:int = 0
var items = []
var slots = [] ## List of slots in the inventory
var full:bool = false
var inventory = [] ## List of ItemBase unique names in the inventory

func _ready() -> void:
	slots = slot_container.get_children()

	for slot in slots:
		slot.item_changed.connect(change)

	Globals.spawn_item_inventory.connect(spawn_item)
	Globals.remove_item.connect(remove_item)
	Globals.check_amount_of_item.connect(check_amount_of_item)
	
	
	## TODO fix saving inventory data somewhere else other than backend
	#if is_in_group("Main Inventory"):
		#print("check ",Backend.playerdata.Inventory)
		#if Backend.playerdata.Inventory != null:
			#var json := JSON.new()
			#var data = json.parse_string(Backend.playerdata.Inventory)
			#update(data)
		
	
func _process(_delta: float) -> void:
	
	check_slots()
	check_if_full()
								
func is_even(x: int) -> bool:
	return x % 2 == 0

func spawn_item(item:ItemBase, amount:int = 1,health:int = 0) -> void:
	if full:
		return
	for slot in slots:
		if slot.item == null:
			slot.item = item
			slot.amount = amount
			
			if item is ItemFood:
				slot.start_rot(item.time_rot_step)
			
			if health != 0:
				slot.health = health

			
			for num in amount:
				inventory.append(item.unique_name)

			slot.update_slot()
			check_if_full()
			sort()
			break


func sort() -> void:
	#print("sorting inventory")
	items.clear()
	for i in slots:
		if i.item != null:
			if items.has(i.item.unique_name) == false:
				items.append(i.item.unique_name)
				#slots.append(i)
				
	for slot in slot_container.get_children():
		var find_item
		if slot.item != null:
			if slot.amount < slot.item.max_stack:
				find_item = slot
				
				for i in slots:
					if i.item == find_item.item:
						if i != find_item:
							if find_item != null:
								if find_item.item != null:
									if find_item.amount + i.amount  <= find_item.item.max_stack:
										find_item.amount += i.amount
										i.item = null
										i.update_slot()
										find_item.update_slot()
										return


func _on_sort_pressed() -> void:
	sort()

func check_amount_of_item(unique_name:StringName) -> int:
	var amount = 0
	for name in inventory:
		if name == unique_name:
			amount += 1
		elif unique_name in name: ## if asking for a part of the name like "wood" and the item is "oak_wood"
			amount += 1
	return amount


func remove_item(unique_name:StringName,amount:int) -> void:
	if id != Vector3.ZERO: return ## id mean its not the players inventory
	#print("remove from inventory ",unique_name,amount)
	for i in amount:
		for slot in slots:
			if slot.item != null:
				if slot.item.unique_name == unique_name:
					if slot.amount == 1:
						slot.item = null
					else:
						slot.amount -= 1
					slot.update_slot()
					var index = inventory.find(unique_name)
					if index != -1:
						inventory.remove_at(index)
						check_if_full()
						break
				elif unique_name in slot.item.unique_name:
					if slot.amount == 1:
						slot.item = null
					else:
						slot.amount -= 1
					slot.update_slot()
					var index = inventory.find(unique_name)
					if index != -1:
						inventory.remove_at(index)
						check_if_full()
						break


func check_if_full() -> void:
	var full:bool = false

	for slot in slots:
		if slot.item == null:
			full = false
			break
			
	full = full

func check_slots():
	inventory.clear()
	
	for slot in slots:
		if slot.item != null:
			for amount in slot.amount:
				inventory.append(slot.item.unique_name)
			

func change(index: int, item_path: String, amount: int,parent:String,health:float,rot:int):
	if sync:
		var _save = save()
		var data = JSON.stringify(_save)
		if metadata:
			Helper.terrian.set_voxel_meta(id,data)
			
func open_with_meta(data):
	show()
	#print("new details ",data)
	if not data:
		return

	for i in data:
		
		var slot = find_child(data[i].parent).get_child(i.to_int())
		
		if data[i].item_path != "":
			slot.item = load(data[i].item_path)
		else:
			slot.item = null
			
		slot.health = data[i].health
		slot.amount = data[i].amount
		slot.rot = data[i].rot
		slot.update_slot()
			

func add_meta_data(data):
	print(data)
	#Helper.terrian.set_voxel_meta.rpc_id(1,id)
	#print("data",data)
	#Helper.terrian.get_vo
	#Helper.terrian.get_voxel_tool().set_voxel_metadata(id,data)
	#print(" change",TerrainHelper.get_terrain_tool().get_voxel_tool().get_voxel_metadata(id))

## updates the ui with the backend playerdata
func update(data):
	print(data)
	if data == null: return

	for i in data:
		
		var slot = find_child(data[i].parent).get_child(i.to_int())
		
		var item_file:String = data[i].item_path.get_file()
		
		if item_file != "":
			slot.item = load(data[i].item_path)
		else:
			slot.item = null
			
		slot.health = data[i].health
		slot.amount = data[i].amount
		slot.rot = data[i].rot
		slot.update_slot()

	pass


func get_all() -> Dictionary:
	var items : Dictionary
	
	for slot in slot_container.get_children():
		var item = slot.item as ItemBase
		if item != null:
			items[item.unique_name] = {
				"amount":slot.amount,
				"item_path":item.resource_path
			}
			
	return items

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


func _on_tree_exiting() -> void:
	pass
	## TODO fix saving data somewhere else other than backend
	#var ui_data = save()
	#print(ui_data)
	#var data = JSON.stringify(ui_data)
	#Backend._update({"client_id" : Backend.client_id , "change_name" : name,"change" : data})
	#print("saved inventory")
