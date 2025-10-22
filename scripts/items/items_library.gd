extends Resource
class_name ItemsLibrary

@export var items_array: Array[ItemBase]

var items: Dictionary = {}
var types:Array = []

func init_items(print:bool = false):
	for item in items_array:
		items[item.unique_name] = item
		types.append(item.unique_name)
	print("ItemLIB ",items)

func get_item(unique_name: StringName) -> ItemBase:
	if not items.has(unique_name):
		push_error("Item with unique name '%s' does not exist in the library." % unique_name)
		return null
	return items[unique_name]
