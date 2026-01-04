extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for slot in get_children():
		slot.item_changed.connect(slot_changed)
			
	
	if Backend.playerdata:
		var blueprints = Backend.playerdata.Blueprints
		if blueprints:
			var data = JSON.parse_string(blueprints)
			if data:
				update_client(data)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func update_client(data):
	if data == null: return

	for i in data:
		
		var slot = get_child(i.to_int())
		
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

func slot_changed(index:int,item_path:String,amount:int,parent:String,health:float,rot:int):
		if Backend.playerdata.Blueprints == null:
			Globals.save.emit()
		else:
			#print(index," ",item_path," ",amount," ",parent," ",health," ",rot)
			Globals.save_slot.emit(index,item_path,amount,parent,health,rot)

func save() -> Dictionary:
	var save_data:Dictionary = {}
	for slot in get_children():
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
