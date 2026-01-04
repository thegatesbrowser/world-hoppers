extends PanelContainer

@onready var delete_save_confirm: ConfirmationDialog = $ConfirmationDialog
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_delete_save_pressed() -> void:
	delete_save_confirm.popup_centered()




func _on_confirmation_dialog_confirmed() -> void:
	print("Deleting save...")
	
	#multiplayer.peer_disconnected.emit()
	await Backend.delete_backend_save()
	
	#if OS.is_debug_build():
	get_tree().quit()
	#else:
		#var args := OS.get_cmdline_args()
		#args.append_array(OS.get_cmdline_user_args())
		#print(args)
		#var url := ""
		#for i in range(args.size()):
			#if args[i] == "--url" and i + 1 < args.size():
			#	url = args[i + 1]
			#	if get_tree().has_method("send_command"):
				#	get_tree().send_command("open_gate", [url])
			#	break
	

func _on_confirmation_dialog_canceled() -> void:
	print("Save deletion canceled.")
	# Optionally, you can reset the UI or perform other actions here.
	delete_save_confirm.hide()
