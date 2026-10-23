class_name TowerState
extends RefCounted

var tower_id: String
var definition: Dictionary
var level: int = 1
var specialization: String = ""

func _init(id: String, tower_definition: Dictionary) -> void:
	tower_id = id
	definition = tower_definition.duplicate(true)


func next_upgrade_cost(branch: String = "") -> int:
	var levels: Array = definition.get("levels", [])
	if level < 3:
		if not branch.is_empty():
			return -1
		return int(levels[level].get("purchase_cost", -1))
	if not specialization.is_empty():
		return -1
	var specializations: Dictionary = definition.get("specializations", {})
	if not specializations.has(branch):
		return -1
	return int(specializations[branch].get("purchase_cost", -1))


func advance(branch: String = "") -> bool:
	if next_upgrade_cost(branch) < 0:
		return false
	if level < 3:
		level += 1
	else:
		specialization = branch
	return true


func current_stats() -> Dictionary:
	if not specialization.is_empty():
		return definition.get("specializations", {}).get(specialization, {}).duplicate(true)
	var levels: Array = definition.get("levels", [])
	return levels[level - 1].duplicate(true)
