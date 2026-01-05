extends CanvasLayer

var registered_inputs: Dictionary = {}

@onready var console: RichTextLabel = $MarginContainer/MarginContainer/contents/console
@onready var text_input = $MarginContainer/MarginContainer/contents/HBoxContainer/text_input

var history: Array[String] = []
var history_index: int = -1

func register_input(name: String, value) -> void:
	if registered_inputs.has(name):
		push_warning("Console input '%s' already exists, overwriting." % name)
	registered_inputs[name] = value

func unregister_input(name: String) -> void:
	registered_inputs.erase(name)

func _init() -> void:
	_add_keybindings()
	
func on_run_command(cmd: String) -> void:
	if cmd == "":
		return

	update_console(cmd)

	var inputs := build_expression_inputs()

	var expression := Expression.new()
	var parse_error := expression.parse(cmd, inputs.keys())
	if parse_error != OK:
		update_console(expression.get_error_text(), "red")
		return

	var result = expression.execute(inputs.values(), self)

	if expression.has_execute_failed():
		update_console("FAILED: " + expression.get_error_text(), "red")
		return

	if result != null:
		update_console("------------------------")
		add_history(str(result))
		update_console(str(result))
		update_console("------------------------")


# Reload the current scene
func reload() -> void:
	get_tree().reload_current_scene()
	
func _process(delta: float) -> void:
	on_input()
	
func on_input() -> void:
	_add_keybindings()
	if Input.is_action_just_pressed("console_toggle"):
		visible = !visible
		if visible:
			text_input.grab_focus()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if Input.is_action_just_pressed('console_entered'):
		add_history(text_input.text)
		on_run_command(text_input.text)
		history_index = -1
		text_input.text = ''
		
	elif Input.is_action_just_released('console_prev'):
		if history.size() == 0:
			return
		history_index = clamp(history_index + 1, 0, history.size() - 1)
		text_input.text = history[history_index]
		# Hack to make the caret go to the end of the line
		# If I ever have a line of code over 100k characters, please send help
		text_input.caret_column = 100000
	elif Input.is_action_just_released('console_next'):
		if history.size() == 0:
			return
		history_index = clamp(history_index - 1, 0, history.size() - 1)
		text_input.text = history[history_index]
		text_input.caret_column = 100000

func build_expression_inputs() -> Dictionary:
	var inputs: Dictionary = {}
	# --- Dynamically registered inputs ---
	for key in registered_inputs:
		inputs[key] = registered_inputs[key]

	return inputs


func update_console(text,color:String = "white"):
		
	console.text += str("[color=",color,"]",text,"[/color]" ,"\n")

func methods(node:Node):
	if not node:
		update_console("FAILED: invaild node in methods. (node == null)","red")
	else:
		update_console("METHODS","yellow")
		var method_names = node.get_script().get_script_method_list().map(func (x
		):return x.name)
		var method_args = node.get_script().get_script_method_list().map(func (x
		):return x.args)
		
		var methods:Dictionary
		for method_name in method_names:
			var name_index = method_names.find(method_name)
			var args:Array = method_args[name_index]
			methods[method_name] = {"args":args}

		
		#print(node.get_script().get_script_method_list(),methods)
		
		for method in methods.keys():
			var print = str(method,"(",")")
			if not methods[method].args.is_empty():
				var args:String
				var arg_names:Array = methods[method].args.map(func (x): return x.name)
				var arg_type:Array = methods[method].args.map(func (x): return x.type)
				var arg_classes:Array = methods[method].args.map(func (x): return x.class_name)
				for arg in arg_names:
					var arg_index = arg_names.find(arg)
					var type = arg_type[arg_index]
					var arg_class = arg_classes[arg_index]
					if args == "":
						if type == 0 or type == 24:
							if arg_class != "":
								args += str(arg,": ",arg_class)
							else:
								args += str(arg,": ",type_string(type))
					else:
						if type == 0 or type == 24:
							if arg_class != "":
								args += str(arg,": ",arg_class)
							else:
								args += str(arg,": ",type_string(type))
				
				print = str(method,"(",args,")")
			
			var id = method_names.find(method) + 1
			add_history(print)
			update_console(str(id,". ",print))

func variables(node:Object,contents :bool = false):
	if not node:
		update_console("FAILED: invaild node in variables. (node == null)","red")
	else:
		update_console("VARIABLES","yellow")
		var variables:Array = node.get_script().get_script_property_list().map(func (x): return x.name)
		var variables_type:Array = node.get_script().get_script_property_list().map(func (x): return x.type)
		var variables_class:Array = node.get_script().get_script_property_list().map(func (x): return x.class_name)
		print(node.get_script().get_script_property_list())
		for variable in variables:
			var text:String
			var id = variables.find(variable) 
			var type = variables_type[id]
			var var_class = variables_class[id]
			var inside_var = node.get(variable)
			
			if type == 0 or type == 24:
				if !var_class == "":
					text = str(id + 1,". ",variable,": ",var_class)
				else:
					text = str(id + 1,". ",variable)
			else:
				text =  str(id + 1,". ",variable,": ",type_string(type))
				
			if contents:
				update_console(str(text," == ",inside_var))
			else:
				update_console(text)
			
			add_history(variable)
			



func clear():
	console.text = ""
	console.clear()

func _add_keybindings() -> void:
	var actions = InputMap.get_actions()
	if "console_toggle" not in actions: _add_key_input_action("console_toggle", KEY_F2)
	if "console_entered" 	not in actions: _add_key_input_action("console_entered", KEY_ENTER)
	if "console_next" 	not in actions: _add_key_input_action("console_next", KEY_DOWN)
	if "console_prev" 	not in actions: _add_key_input_action("console_prev", KEY_UP)

func _add_key_input_action(name: String, key: Key) -> void:
	var ev = InputEventKey.new()
	ev.physical_keycode = key
	
	InputMap.add_action(name)
	InputMap.action_add_event(name, ev)

func add_history(text):
	history.push_front(text)
	history_index = -1
	
func references():
	for reference in registered_inputs:
		update_console(reference,"Green")
