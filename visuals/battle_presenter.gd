class_name BattlePresenter
extends RefCounted

# Read-only presentation adapter. Core simulation, data and decisions stay untouched.
# Enemy references retained across one tick let deaths be distinguished from leaks.
var _previous_enemies: Dictionary = {}
var _previous_health: Dictionary = {}
var _previous_cooldowns: Dictionary = {}
var _previous_towers: Dictionary = {}
var _previous_lives: int = -1
var _previous_time: float = 0.0


func capture(simulation: BattleSimulation) -> Dictionary:
	var snapshot: Dictionary = simulation.snapshot()
	var effects: Array[Dictionary] = []
	var current_enemies: Dictionary = {}
	var current_health: Dictionary = {}
	var current_cooldowns: Dictionary = {}
	var current_towers: Dictionary = {}
	var damaged: Array = []
	for enemy in _previous_enemies.values():
		if enemy.health < float(_previous_health.get(enemy.spawn_order, enemy.health)):
			damaged.append(enemy)
			effects.append({"kind": "hit", "id": enemy.spawn_order, "position": enemy.position_on(simulation.route)})
		if not enemy.alive:
			effects.append({"kind": "leak" if enemy.leaked else "death", "id": enemy.spawn_order, "position": enemy.position_on(simulation.route)})
	var visual_enemies: Array[Dictionary] = []
	for enemy in simulation.enemies:
		current_enemies[enemy.spawn_order] = enemy
		current_health[enemy.spawn_order] = enemy.health
		if not _previous_enemies.has(enemy.spawn_order) and enemy.health < enemy.maximum_health:
			damaged.append(enemy)
			effects.append({"kind": "hit", "id": enemy.spawn_order, "position": enemy.position_on(simulation.route)})
		visual_enemies.append({"id": enemy.spawn_order, "position": enemy.position_on(simulation.route), "health": enemy.health, "maximum_health": enemy.maximum_health, "distance": enemy.path_distance})
		if not _previous_enemies.has(enemy.spawn_order):
			effects.append({"kind": "spawn", "id": enemy.spawn_order, "position": enemy.position_on(simulation.route)})
	for slot_id in simulation.towers:
		var tower: Dictionary = simulation.towers[slot_id]
		var cooldown: float = float(tower["cooldown"])
		current_towers[slot_id] = true
		current_cooldowns[slot_id] = cooldown
		if not _previous_towers.has(slot_id):
			effects.append({"kind": "build", "slot": slot_id, "position": simulation.build_slots[slot_id]})
		# A reset of the actual cooldown is an observed shot, never an independent visual timer.
		if simulation.elapsed_time > _previous_time and cooldown > float(_previous_cooldowns.get(slot_id, 0.0)) + 0.001:
			var stats: Dictionary = simulation.catalog.tower_definition(String(tower["tower_id"]))["levels"][int(tower["level"]) - 1]
			var aim: Vector2 = simulation.build_slots[slot_id] + Vector2.RIGHT
			var best_distance: float = -1.0
			# Aim only at an actually damaged enemy. This never chooses a combat target.
			for enemy in damaged:
				var position: Vector2 = enemy.position_on(simulation.route)
				if position.distance_to(simulation.build_slots[slot_id]) <= float(stats["range"]) + 0.001 and enemy.path_distance > best_distance:
					best_distance = enemy.path_distance
					aim = position
			effects.append({"kind": "shot", "slot": slot_id, "position": simulation.build_slots[slot_id], "target": aim})
	if _previous_lives >= 0 and simulation.lives < _previous_lives and not simulation.route.is_empty():
		effects.append({"kind": "core_hit", "position": simulation.route.back()})
	_previous_enemies = current_enemies
	_previous_health = current_health
	_previous_cooldowns = current_cooldowns
	_previous_towers = current_towers
	_previous_lives = simulation.lives
	_previous_time = simulation.elapsed_time
	snapshot["enemies"] = visual_enemies
	snapshot["effects"] = effects
	return snapshot
