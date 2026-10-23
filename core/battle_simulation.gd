class_name BattleSimulation
extends RefCounted

const DataCatalogScript = preload("res://core/data_catalog.gd")
const DamageRulesScript = preload("res://combat/damage_rules.gd")
const TargetSelectorScript = preload("res://combat/target_selector.gd")
const EnemyStateScript = preload("res://enemies/enemy_state.gd")
const PathFollowerScript = preload("res://enemies/path_follower.gd")
const WalletScript = preload("res://economy/wallet.gd")
const WaveDirectorScript = preload("res://waves/wave_director.gd")

const FIXED_STEP: float = 0.1

var catalog: DataCatalog
var wallet: Wallet
var wave_director: WaveDirector
var route: Array[Vector2] = []
var build_slots: Array[Vector2] = []
var enemies: Array = []
var towers: Dictionary = {}
var phase: String = "ready"
var lives: int
var elapsed_time: float = 0.0
var spawned_count: int = 0
var killed_count: int = 0
var leaked_count: int = 0
var next_spawn_order: int = 0
var active_wave: Dictionary = {}
var path_length: float = 0.0
var wave_enemy_total: int = 0


func _init() -> void:
	catalog = DataCatalogScript.new()
	wallet = WalletScript.new(int(catalog.wave_config.get("initial_gold", 0)))
	lives = int(catalog.wave_config.get("initial_lives", 1))
	wave_director = WaveDirectorScript.new()
	_load_level_geometry()
	if not catalog.wave_config.get("waves", []).is_empty():
		active_wave = catalog.wave_config["waves"][0].duplicate(true)
	for entry in active_wave.get("entries", []):
		wave_enemy_total += int(entry.get("count", 0))


func _load_level_geometry() -> void:
	var raw_route: Array = catalog.level.get("route", [])
	for point in raw_route:
		route.append(Vector2(float(point[0]), float(point[1])))
	var raw_slots: Array = catalog.level.get("build_slots", [])
	for point in raw_slots:
		build_slots.append(Vector2(float(point[0]), float(point[1])))
	path_length = PathFollowerScript.total_length(route)


func request_build(slot_id: int, tower_id: String = "rapid") -> bool:
	if slot_id < 0 or slot_id >= build_slots.size() or towers.has(slot_id):
		return false
	var definition: Dictionary = catalog.tower_definition(tower_id)
	if definition.is_empty() or not bool(definition.get("prototype_enabled", false)):
		return false
	var levels: Array = definition.get("levels", [])
	if levels.is_empty():
		return false
	var cost: int = int(levels[0].get("purchase_cost", -1))
	if not wallet.try_spend(cost):
		return false
	towers[slot_id] = {
		"tower_id": tower_id,
		"level": 1,
		"cooldown": 0.0
	}
	return true


func build_cost(tower_id: String = "rapid") -> int:
	var definition: Dictionary = catalog.tower_definition(tower_id)
	var levels: Array = definition.get("levels", [])
	if levels.is_empty():
		return -1
	return int(levels[0].get("purchase_cost", -1))


func start_wave() -> bool:
	if phase != "ready" or active_wave.is_empty():
		return false
	wave_director.start(active_wave)
	phase = "active"
	return true


func tick(delta: float = FIXED_STEP) -> void:
	if phase != "active" or delta <= 0.0:
		return
	var step: float = minf(delta, 0.25)
	elapsed_time += step
	for enemy_id in wave_director.advance(step):
		_spawn_enemy(enemy_id)
	_advance_enemies(step)
	_fire_towers(step)
	_remove_inactive_enemies()
	if lives <= 0:
		phase = "lost"
		return
	if wave_director.all_spawned() and enemies.is_empty():
		wallet.add_gold(int(catalog.wave_config.get("wave_clear_bonus", 0)))
		phase = "won"


func _spawn_enemy(enemy_id: String) -> void:
	var definition: Dictionary = catalog.enemy_definition(enemy_id)
	if definition.is_empty():
		push_error("Wave references an unknown enemy: " + enemy_id)
		return
	enemies.append(EnemyStateScript.new(enemy_id, next_spawn_order, definition))
	next_spawn_order += 1
	spawned_count += 1


func _advance_enemies(delta: float) -> void:
	for enemy in enemies:
		if not enemy.alive:
			continue
		enemy.move(delta)
		if enemy.path_distance >= path_length:
			enemy.alive = false
			enemy.leaked = true
			lives = maxi(0, lives - enemy.core_damage)
			leaked_count += 1


func _fire_towers(delta: float) -> void:
	var slot_ids: Array = towers.keys()
	slot_ids.sort()
	for slot_value in slot_ids:
		var slot_id: int = int(slot_value)
		var runtime: Dictionary = towers[slot_id]
		var definition: Dictionary = catalog.tower_definition(String(runtime["tower_id"]))
		var stats: Dictionary = definition["levels"][int(runtime["level"]) - 1]
		var cooldown: float = float(runtime["cooldown"]) - delta
		var shots_this_step: int = 0
		while cooldown <= 0.0 and shots_this_step < 8:
			var target: Variant = TargetSelectorScript.choose_most_advanced_in_range(
				enemies,
				route,
				build_slots[slot_id],
				float(stats.get("range", 0.0))
			)
			if target == null:
				cooldown = 0.0
				break
			var damage: float = DamageRulesScript.calculate_damage(
				float(stats.get("damage", 0.0)),
				target.armor,
				String(stats.get("damage_type", "physical")),
				float(stats.get("armor_penetration", 0.0))
			)
			if target.take_damage(damage):
				wallet.add_kill_reward(target.kill_gold)
				killed_count += 1
			cooldown += maxf(0.01, float(stats.get("interval", 1.0)))
			shots_this_step += 1
		runtime["cooldown"] = cooldown
		towers[slot_id] = runtime


func _remove_inactive_enemies() -> void:
	var survivors: Array = []
	for enemy in enemies:
		if enemy.alive:
			survivors.append(enemy)
	enemies = survivors


func snapshot() -> Dictionary:
	var slot_snapshots: Array[Dictionary] = []
	for index in range(build_slots.size()):
		var tower: Dictionary = towers.get(index, {})
		slot_snapshots.append({
			"id": index,
			"position": build_slots[index],
			"tower_id": String(tower.get("tower_id", "")),
			"level": int(tower.get("level", 0))
		})
	var enemy_snapshots: Array[Dictionary] = []
	for enemy in enemies:
		enemy_snapshots.append({
			"position": enemy.position_on(route),
			"health": enemy.health,
			"maximum_health": enemy.maximum_health,
			"armor": enemy.armor
		})
	return {
		"phase": phase,
		"gold": wallet.gold,
		"lives": lives,
		"elapsed_time": elapsed_time,
		"spawned": spawned_count,
		"killed": killed_count,
		"leaked": leaked_count,
		"remaining_to_spawn": wave_director.remaining_to_spawn,
		"route": route.duplicate(),
		"slots": slot_snapshots,
		"enemies": enemy_snapshots
	}
