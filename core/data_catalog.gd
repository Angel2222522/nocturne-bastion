class_name DataCatalog
extends RefCounted

var towers: Dictionary
var battle_tuning: Dictionary
var enemies: Dictionary
var level: Dictionary
var wave_config: Dictionary

func _init() -> void:
	var tower_data: Dictionary = _read_json("res://data/towers.json")
	towers = tower_data.get("towers", {})
	battle_tuning = tower_data.get("battle_tuning", {})
	enemies = _read_json("res://data/enemies.json").get("enemies", {})
	level = _read_json("res://data/level_01.json")
	wave_config = _read_json("res://data/waves.json")


func tower_definition(tower_id: String) -> Dictionary:
	return towers.get(tower_id, {}).duplicate(true)


func enemy_definition(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {}).duplicate(true)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing game data file: " + path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open game data file: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Game data root must be a JSON object: " + path)
		return {}
	return parsed
