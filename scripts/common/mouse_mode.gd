extends Control


func set_captured(captured: bool) -> void:
	
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func ui_captured(captured: bool, caller = null) -> void:
	if captured:
		if Helper.inventory_holder.visible or Helper.text_chat.visible or Helper.pause_menu.visible or DevConsole.visible:
			#print(inventory.visible,text_chat.visible,pause_menu.visible)
			return
			
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
