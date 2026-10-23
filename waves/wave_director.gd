class_name WaveDirector
extends RefCounted

var enemy_id: String = ""
var remaining_to_spawn: int = 0
var spawn_interval: float = 0.0
var time_to_spawn: float = 0.0
var started: bool = false
var entries: Array = []
var entry_index: int = 0

func start(wave_definition: Dictionary) -> void:
	entries = wave_definition.get("entries", []).duplicate(true)
	entry_index = 0
	time_to_spawn = 0.0
	started = true
	_load_entry()


func advance(delta: float) -> Array[String]:
	var spawned: Array[String] = []
	if not started or remaining_to_spawn <= 0:
		return spawned
	time_to_spawn -= maxf(0.0, delta)
	while time_to_spawn <= 0.0 and remaining_to_spawn > 0:
		spawned.append(enemy_id)
		var interval_after_spawn: float = spawn_interval
		remaining_to_spawn -= 1
		if remaining_to_spawn == 0:
			entry_index += 1
			_load_entry()
		time_to_spawn += interval_after_spawn
	return spawned


func all_spawned() -> bool:
	return started and entry_index >= entries.size()


func _load_entry() -> void:
	while entry_index < entries.size():
		var entry: Dictionary = entries[entry_index]
		enemy_id = String(entry.get("enemy_id", ""))
		remaining_to_spawn = maxi(0, int(entry.get("count", 0)))
		spawn_interval = maxf(0.01, float(entry.get("spawn_interval", 1.0)))
		if remaining_to_spawn > 0:
			return
		entry_index += 1
	remaining_to_spawn = 0
	enemy_id = ""
