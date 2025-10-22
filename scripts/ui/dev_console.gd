extends CanvasLayer


# command_name: reference_node_path example "Globals" or "Game/Player"
@export var references : Dictionary = {
	"Helper": "Helper",
	"Globals": "Globals",
	"Backend": "Backend",
}

@onready var console: RichTextLabel = $MarginContainer/MarginContainer/contents/console
@onready var text_input = $MarginContainer/MarginContainer/contents/HBoxContainer/text_input

var history: Array[String] = []
var history_index: int = -1

func _init() -> void:
	_add_keybindings()
	
func on_run_command(cmd: String, inputs:={}) -> void:
	if cmd == "": return
	
	update_console(cmd)
	
	var expression = Expression.new()
	var parse_error = expression.parse(cmd,inputs.keys())
	if parse_error != OK:
		# Code here to log and format the error to the dev console
		return
		
	print(parse_error)
	
	var result = expression.execute(inputs.values(),self)
	
	if expression.has_execute_failed():
		update_console(str("FAILED: ",expression.get_error_text()),"red",)
	else:
		update_console("passed","green")
		
	if result != null:
		update_console("RETURNED","yellow")
		add_history(str(result))
		update_console(str(result))

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
			MouseMode.ui_captured(false,self)
		else:
			MouseMode.ui_captured(true,self)
	
	if Input.is_action_just_pressed('console_entered'):
		add_history(text_input.text)
		var inputs:Dictionary
		for reference in references:
			inputs[reference] = get_tree().root.get_node(references[reference])
		on_run_command(text_input.text,inputs)
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

func test(text):
	return load("res://resources/items/stone.tres")

func update_console(text,color:String = "white"):
		
	console.text += str("[color=",color,"]",text,"[/color]" ,"\n")

func methods(node):
	if not node:
		update_console("FAILED: invaild node in methods. (node == null)","red")
	else:
		update_console("METHODS","yellow")
		var methods:Array = node.get_script().get_script_method_list().map(func (x): return x.name)
		for method in methods:
			var id = methods.find(method) + 1
			add_history(method)
			update_console(str(id,". ",method))

func variables(node):
	if not node:
		update_console("FAILED: invaild node in variables. (node == null)","red")
	else:
		update_console("VARIABLES","yellow")
		var variables:Array = node.get_script().get_script_property_list().map(func (x): return x.name)
		for variable in variables:
			var id = variables.find(variable) + 1
			add_history(variable)
			update_console(str(id,". ",variable))

func help():
	update_console("TOOLS","yellow")
	update_console("variables(node) gives variables of that node")
	update_console("methods(node) gives methods of that node")
	update_console("REFERENCES","yellow")
	for reference in references:
		update_console(reference)
	update_console("SHORT CUTS","yellow")
	update_console("you can press up and down on the keyboard to go through the history")

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
	
