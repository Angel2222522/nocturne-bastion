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
	if levels.is_empty() or not branch.is_empty() and not ["A", "B"].has(branch):
		return -1
	if level < levels.size():
		if not branch.is_empty():
			return -1
		return int(levels[level].get("purchase_cost", -1))
	if not specialization.is_empty() or branch.is_empty():
		return -1
	var specializations: Dictionary = definition.get("specializations", {})
	if not specializations.has(branch):
		return -1
	return int(specializations[branch].get("purchase_cost", -1))


func advance(branch: String = "") -> bool:
	if next_upgrade_cost(branch) < 0:
		return false
	var levels: Array = definition.get("levels", [])
	if level < levels.size():
		level += 1
	else:
		specialization = branch
	return true


func current_stats() -> Dictionary:
	var levels: Array = definition.get("levels", [])
	if levels.is_empty():
		return {}
	var index: int = clampi(level - 1, 0, levels.size() - 1)
	var stats: Dictionary = levels[index].duplicate(true)
	if not specialization.is_empty():
		var branches: Dictionary = definition.get("specializations", {})
		if branches.has(specialization):
			stats.merge(branches[specialization], true)
	return stats
