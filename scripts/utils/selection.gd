# selection.gd
# Autoload — tracks what the camera is focused on.
extends Node

# Everything that can be selected registers itself here
var selectables: Array = []

# Index of currently selected object
var current_index: int = 0

# Register a body or rocket as selectable
func register(obj: Dictionary) -> void:
	# obj = { "name": "Earth", "type": "body" }
	# or   = { "name": "Rocket 1", "type": "rocket", "node": <Node2D> }
	selectables.append(obj)

func next() -> Dictionary:
	if selectables.is_empty():
		return {}
	current_index = (current_index + 1) % selectables.size()
	return current()

func previous() -> Dictionary:
	if selectables.is_empty():
		return {}
	current_index = (current_index - 1 + selectables.size()) % selectables.size()
	return current()

func current() -> Dictionary:
	if selectables.is_empty():
		return {}
	return selectables[current_index]

func select_by_name(name: String) -> void:
	for i in selectables.size():
		if selectables[i]["name"] == name:
			current_index = i
			return
