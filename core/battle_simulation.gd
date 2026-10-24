class_name BattleSimulation
extends RefCounted

const DataCatalogScript = preload("res://core/data_catalog.gd")
const DamageRulesScript = preload("res://combat/damage_rules.gd")
const TargetSelectorScript = preload("res://combat/target_selector.gd")
const EnemyStateScript = preload("res://enemies/enemy_state.gd")
const PathFollowerScript = preload("res://enemies/path_follower.gd")
const WalletScript = preload("res://economy/wallet.gd")
const WaveDirectorScript = preload("res://waves/wave_director.gd")
const TowerStateScript = preload("res://towers/tower_state.gd")
const SoldierStateScript = preload("res://units/soldier_state.gd")
const EnhancerRulesScript = preload("res://economy/enhancer_rules.gd")
const StatusEffectRulesScript = preload("res://combat/status_effect_rules.gd")

const FIXED_STEP: float = 0.1
const EVENT_LIMIT: int = 1200

var catalog: DataCatalog
var wallet: Wallet
var wave_director: WaveDirector
var route: Array[Vector2] = []
var build_slots: Array[Vector2] = []
var enemies: Array = []
var soldiers: Array = []
var towers: Dictionary = {}
var phase: String = "ready"
var lives: int
var elapsed_time: float = 0.0
var spawned_count: int = 0
var killed_count: int = 0
var leaked_count: int = 0
var next_spawn_order: int = 0
var wave_spawned_count: int = 0
var spawned_by_enemy: Dictionary = {}
var active_wave: Dictionary = {}
var path_length: float = 0.0
var wave_enemy_total: int = 0
var wave_index: int = -1
var wave_kills: int = 0
var wave_leaks: int = 0
var _next_soldier_id: int = 0
var _event_sequence: int = 0
var _event_log: Array[Dictionary] = []


func _init() -> void:
	catalog = DataCatalogScript.new()
	wallet = WalletScript.new(int(catalog.wave_config.get("initial_gold", 0)))
	lives = int(catalog.wave_config.get("initial_lives", 1))
	wave_director = WaveDirectorScript.new()
	_load_level_geometry()
	var waves: Array = catalog.wave_config.get("waves", [])
	if not waves.is_empty():
		active_wave = waves[0].duplicate(true)
		for entry in active_wave.get("entries", []):
			wave_enemy_total += int(entry.get("count", 0))


func _load_level_geometry() -> void:
	for point in catalog.level.get("route", []):
		route.append(Vector2(float(point[0]), float(point[1])))
	for point in catalog.level.get("build_slots", []):
		build_slots.append(Vector2(float(point[0]), float(point[1])))
	path_length = PathFollowerScript.total_length(route)


func request_build(slot_id: int, tower_id: String = "rapid") -> bool:
	if phase in ["won", "lost"] or slot_id < 0 or slot_id >= build_slots.size() or towers.has(slot_id):
		return false
	var definition: Dictionary = catalog.tower_definition(tower_id)
	var levels: Array = definition.get("levels", [])
	if definition.is_empty() or not bool(definition.get("prototype_enabled", false)) or levels.is_empty():
		return false
	var cost: int = build_cost(tower_id)
	if cost < 0 or not wallet.try_spend(cost):
		return false
	var state: TowerState = TowerStateScript.new(tower_id, definition)
	towers[slot_id] = {
		"state": state,
		"cooldown": 0.0,
		"production_cooldown": 0.0,
		"growth_start_time": elapsed_time,
		"roster_sequence": 0
	}
	_emit_event("build", {"slot": slot_id, "tower_id": tower_id, "position": build_slots[slot_id], "cost": cost})
	return true


func build_cost(tower_id: String = "rapid") -> int:
	var definition: Dictionary = catalog.tower_definition(tower_id)
	var levels: Array = definition.get("levels", [])
	if levels.is_empty():
		return -1
	var raw_cost: int = int(levels[0].get("purchase_cost", -1))
	return _adjusted_cost(raw_cost, tower_id)


func upgrade_cost(slot_id: int, branch: String = "") -> int:
	if not towers.has(slot_id):
		return -1
	var state: TowerState = towers[slot_id]["state"]
	return _adjusted_cost(state.next_upgrade_cost(branch), state.tower_id)


func upgrade_tower(slot_id: int, branch: String = "") -> bool:
	if phase in ["won", "lost"] or not towers.has(slot_id):
		return false
	var runtime: Dictionary = towers[slot_id]
	var state: TowerState = runtime["state"]
	var cost: int = upgrade_cost(slot_id, branch)
	if cost < 0 or not wallet.try_spend(cost) or not state.advance(branch):
		return false
	runtime["cooldown"] = 0.0
	towers[slot_id] = runtime
	_emit_event("upgrade", {"slot": slot_id, "tower_id": state.tower_id, "level": state.level, "specialization": state.specialization, "position": build_slots[slot_id], "cost": cost})
	return true


func start_wave() -> bool:
	if phase not in ["ready", "intermission"]:
		return false
	var waves: Array = catalog.wave_config.get("waves", [])
	var next_index: int = wave_index + 1
	if next_index < 0 or next_index >= waves.size():
		return false
	wave_index = next_index
	active_wave = waves[wave_index].duplicate(true)
	wave_enemy_total = 0
	for entry in active_wave.get("entries", []):
		wave_enemy_total += int(entry.get("count", 0))
	wave_kills = 0
	wave_leaks = 0
	wave_spawned_count = 0
	wave_director.start(active_wave)
	phase = "active"
	_emit_event("wave_start", {"wave": wave_index + 1, "name": String(active_wave.get("display_name", "")), "total": wave_enemy_total})
	return true


func tick(delta: float = FIXED_STEP) -> void:
	if phase != "active" or delta <= 0.0:
		return
	var step: float = minf(delta, 0.25)
	elapsed_time += step
	for enemy_id in wave_director.advance(step):
		_spawn_enemy(enemy_id)
	_advance_enemies(step)
	_advance_soldiers(step)
	_enemy_attacks(step)
	_fire_towers(step)
	_remove_inactive_units()
	if lives <= 0:
		phase = "lost"
		_emit_event("battle_end", {"result": "lost", "wave": wave_index + 1})
		return
	if wave_director.all_spawned() and enemies.is_empty():
		wallet.add_gold(int(catalog.wave_config.get("wave_clear_bonus", 0)))
		var waves: Array = catalog.wave_config.get("waves", [])
		if wave_index + 1 >= waves.size():
			phase = "won"
			_emit_event("battle_end", {"result": "won", "wave": wave_index + 1, "bonus": int(catalog.wave_config.get("wave_clear_bonus", 0))})
		else:
			phase = "intermission"
			_emit_event("wave_clear", {"wave": wave_index + 1, "bonus": int(catalog.wave_config.get("wave_clear_bonus", 0))})


func _spawn_enemy(enemy_id: String) -> void:
	var definition: Dictionary = catalog.enemy_definition(enemy_id)
	if definition.is_empty():
		push_error("Wave references an unknown enemy: " + enemy_id)
		return
	var enemy: EnemyState = EnemyStateScript.new(enemy_id, next_spawn_order, definition)
	enemies.append(enemy)
	_emit_event("spawn", {"id": enemy.spawn_order, "enemy_id": enemy_id, "position": enemy.position_on(route), "is_flying": enemy.is_flying})
	next_spawn_order += 1
	spawned_count += 1
	wave_spawned_count += 1
	spawned_by_enemy[enemy_id] = int(spawned_by_enemy.get(enemy_id, 0)) + 1


func _advance_enemies(delta: float) -> void:
	for enemy in enemies:
		if not enemy.alive:
			continue
		var before: Vector2 = enemy.position_on(route)
		enemy.move(delta)
		if enemy.path_distance >= path_length:
			enemy.alive = false
			enemy.leaked = true
			lives = maxi(0, lives - enemy.core_damage)
			leaked_count += 1
			wave_leaks += 1
			_emit_event("leak", {"id": enemy.spawn_order, "position": route.back(), "damage": enemy.core_damage})
			_emit_event("core_hit", {"position": route.back(), "damage": enemy.core_damage})
		elif before.distance_to(enemy.position_on(route)) > 0.0001:
			_emit_event("move", {"id": enemy.spawn_order, "from": before, "position": enemy.position_on(route)})


func _advance_soldiers(delta: float) -> void:
	for soldier in soldiers:
		if not soldier.alive:
			continue
		soldier.attack_cooldown = maxf(0.0, soldier.attack_cooldown - delta)
		var attack_range: float = float(catalog.battle_tuning.get("soldier_attack_range", 1.55))
		var target: Variant = _nearest_enemy(soldier.position, attack_range, soldier.can_attack_fliers)
		if target == null:
			target = _nearest_enemy(soldier.position, float(catalog.battle_tuning.get("soldier_notice_range", 3.5)), soldier.can_attack_fliers)
			if target != null:
				var before: Vector2 = soldier.position
				var destination: Vector2 = target.position_on(route)
				var toward: Vector2 = destination - soldier.position
				if toward.length() > attack_range:
					soldier.position += toward.normalized() * minf(toward.length() - attack_range * 0.85, soldier.movement_speed * delta)
					_emit_event("soldier_move", {"id": soldier.id, "from": before, "position": soldier.position})
				if soldier.position.distance_to(destination) > attack_range:
					continue
		if soldier.attack_cooldown > 0.0:
			continue
		if target == null:
			continue
		soldier.attack_cooldown = soldier.attack_interval
		var target_position: Vector2 = target.position_on(route)
		_emit_event("soldier_attack", {"id": soldier.id, "from": soldier.position, "target": target_position})
		_apply_damage(target, soldier.damage, 0.0, "physical", 0.0, "soldier", soldier.id)


func _enemy_attacks(delta: float) -> void:
	for enemy in enemies:
		if not enemy.alive or enemy.attack_damage <= 0.0:
			continue
		enemy.attack_cooldown = maxf(0.0, enemy.attack_cooldown - delta)
		var enemy_position: Vector2 = enemy.position_on(route)
		var target: Variant = null
		var closest: float = enemy.attack_range
		for soldier in soldiers:
			if not soldier.alive:
				continue
			var distance: float = enemy_position.distance_to(soldier.position)
			if distance <= closest:
				closest = distance
				target = soldier
		if target == null or enemy.attack_cooldown > 0.0:
			continue
		enemy.attack_cooldown = enemy.attack_interval
		var attack_damage: float = enemy.attack_damage_after_effects()
		var died: bool = target.take_damage(attack_damage)
		_emit_event("soldier_hit", {"id": target.id, "position": target.position, "damage": attack_damage, "died": died})
		if died:
			_emit_event("soldier_death", {"id": target.id, "position": target.position})


func _fire_towers(delta: float) -> void:
	var slot_ids: Array = towers.keys()
	slot_ids.sort()
	for slot_value in slot_ids:
		var slot_id: int = int(slot_value)
		var runtime: Dictionary = towers[slot_id]
		var state: TowerState = runtime["state"]
		if state.tower_id == "enhancer":
			continue
		var stats: Dictionary = _effective_stats(slot_id)
		if state.tower_id == "barracks":
			_produce_soldiers(slot_id, runtime, stats, delta)
			towers[slot_id] = runtime
			continue
		var cooldown: float = float(runtime["cooldown"]) - delta
		var shots: int = 0
		while cooldown <= 0.0 and shots < 8:
			var attacked: Dictionary = {}
			var attacker_count: int = maxi(1, int(stats.get("attacker_count", 1)))
			for attacker_index in range(attacker_count):
				var target: Variant = _select_tower_target(slot_id, stats, attacked)
				if target == null:
					break
				attacked[target.spawn_order] = true
				_fire_single_attack(slot_id, stats, target)
			if attacked.is_empty():
				cooldown = 0.0
				break
			cooldown += maxf(0.01, float(stats.get("interval", 1.0)))
			shots += 1
		runtime["cooldown"] = cooldown
		towers[slot_id] = runtime


func _select_tower_target(slot_id: int, stats: Dictionary, excluded: Dictionary = {}) -> Variant:
	var state: TowerState = towers[slot_id]["state"]
	var eligible: Array = []
	var is_global_sniper: bool = state.tower_id == "rapid" and state.specialization == "B"
	for enemy in enemies:
		if enemy.alive and (is_global_sniper or not excluded.has(enemy.spawn_order)):
			eligible.append(enemy)
	if state.tower_id == "rapid" and state.specialization == "B":
		return TargetSelectorScript.choose_highest_current_ehp(eligible)
	return TargetSelectorScript.choose_most_advanced_in_range(
		eligible, route, build_slots[slot_id], float(stats.get("range", 0.0)), bool(stats.get("can_target_flying", true))
	)


func _fire_single_attack(slot_id: int, stats: Dictionary, target: Variant) -> void:
	var state: TowerState = towers[slot_id]["state"]
	var origin: Vector2 = build_slots[slot_id]
	var target_position: Vector2 = target.position_on(route)
	var kind: String = state.tower_id
	_emit_event("shot", {"slot": slot_id, "tower_id": kind, "position": origin, "target": target_position, "target_id": target.spawn_order})
	var base_damage: float = float(stats.get("damage", 0.0))
	if kind == "nuclear":
		base_damage *= float(stats.get("damage_multiplier", 1.0))
		_emit_event("blast", {"slot": slot_id, "position": target_position, "radius": float(stats.get("blast_radius", 1.0))})
		for enemy in enemies:
			if not enemy.alive:
				continue
			if target_position.distance_to(enemy.position_on(route)) <= float(stats.get("blast_radius", 1.0)):
				_apply_damage(enemy, base_damage, enemy.armor, String(stats.get("damage_type", "nuclear")), 0.0, kind, slot_id)
			var global_fraction: float = float(stats.get("global_damage_fraction", 0.0))
			if global_fraction > 0.0 and enemy.alive:
				var global_damage: float = base_damage * global_fraction
				_apply_damage(enemy, global_damage, enemy.armor, "nuclear", 0.0, "radiation", slot_id)
				_emit_event("radiation", {"slot": slot_id, "position": enemy.position_on(route), "damage": global_damage})
		return
	_apply_damage(target, base_damage, target.armor, String(stats.get("damage_type", "physical")), float(stats.get("armor_penetration", 0.0)), kind, slot_id)
	if kind == "mage" and target.alive:
		var state_after: TowerState = towers[slot_id]["state"]
		if state_after.specialization == "B":
			var previous_position: Vector2 = target.position_on(route)
			target.apply_knockback(float(stats.get("knockback_distance", 0.0)))
			var knockback_position: Vector2 = target.position_on(route)
			if previous_position.distance_to(knockback_position) > 0.0001:
				_emit_event("knockback", {"id": target.spawn_order, "from": previous_position, "position": knockback_position})
		else:
			target.debuff = StatusEffectRulesScript.apply_mage_debuff(
				target.debuff,
				float(stats.get("slow_fraction", 0.0)),
				float(stats.get("enemy_attack_reduction", 0.0)),
				float(stats.get("effect_duration", 0.0))
			)
			_emit_event("debuff", {"id": target.spawn_order, "position": target.position_on(route), "duration": float(stats.get("effect_duration", 0.0))})


func _apply_damage(target: Variant, raw_damage: float, armor: float, damage_type: String, penetration: float, source: String, source_id: int) -> void:
	var amount: float = DamageRulesScript.calculate_damage(raw_damage, armor, damage_type, penetration)
	var died: bool = target.take_damage(amount)
	_emit_event("hit", {"id": target.spawn_order, "position": target.position_on(route), "damage": amount, "source": source, "source_id": source_id})
	if died:
		var reward_multiplier: float = _kill_reward_multiplier()
		var reward: int = wallet.add_kill_reward(target.kill_gold, reward_multiplier)
		killed_count += 1
		wave_kills += 1
		_emit_event("death", {"id": target.spawn_order, "position": target.position_on(route), "reward": reward, "source": source})


func _produce_soldiers(slot_id: int, runtime: Dictionary, stats: Dictionary, delta: float) -> void:
	var cooldown: float = float(runtime["production_cooldown"]) - delta
	var produced: int = 0
	var production_interval: float = float(stats.get("production_interval", 10.0))
	while cooldown <= 0.0 and produced < 4:
		var count: int = maxi(1, int(stats.get("soldiers_per_cycle", 1)))
		var multiplier: float = float(stats.get("soldier_damage_multiplier", 1.0))
		var damage: float = float(stats.get("soldier_damage", 0.0)) * multiplier
		var sequence: int = int(runtime["roster_sequence"])
		for index in range(count):
			var offset: float = float(sequence + index) * 0.11
			var soldier_position: Vector2 = build_slots[slot_id] + Vector2(0.0, 0.42 + fmod(offset, 0.45))
			var soldier: SoldierState = SoldierStateScript.new(
				_next_soldier_id, slot_id, soldier_position,
				float(stats.get("soldier_health", 50.0)), damage,
				float(stats.get("attack_interval", 1.0)), bool(stats.get("can_attack_fliers", false)),
				float(catalog.battle_tuning.get("soldier_move_speed", 1.8))
			)
			soldiers.append(soldier)
			_emit_event("soldier_spawn", {"id": soldier.id, "slot": slot_id, "position": soldier.position})
			_next_soldier_id += 1
		sequence += count
		runtime["roster_sequence"] = sequence
		cooldown += maxf(0.1, production_interval)
		produced += 1
	runtime["production_cooldown"] = cooldown


func _nearest_enemy(position: Vector2, radius: float, can_attack_fliers: bool = true) -> Variant:
	var selected: Variant = null
	var best_distance: float = radius
	for enemy in enemies:
		if not enemy.alive or enemy.is_flying and not can_attack_fliers:
			continue
		var distance: float = position.distance_to(enemy.position_on(route))
		if distance <= best_distance:
			selected = enemy
			best_distance = distance
	return selected


func _effective_stats(slot_id: int) -> Dictionary:
	var runtime: Dictionary = towers[slot_id]
	var state: TowerState = runtime["state"]
	var stats: Dictionary = state.current_stats()
	var tower_id: String = state.tower_id
	var enhancers: Array[Dictionary] = _enhancer_runtimes()
	var base_tuning: Dictionary = catalog.battle_tuning.get("enhancer_base", {})
	var matching_count: int = enhancers.size()
	if tower_id == "rapid":
		var damage_bonus: float = float(base_tuning.get("rapid_damage_bonus", 0.0)) * float(matching_count)
		if state.specialization == "A":
			damage_bonus += float(base_tuning.get("rapid_specialization_a_damage_bonus", 0.0)) * float(matching_count)
		stats["damage"] = float(stats.get("damage", 0.0)) * (1.0 + damage_bonus)
		if state.specialization == "A" and matching_count > 0:
			var base_stats: Dictionary = state.definition.get("levels", [])[state.level - 1]
			stats["range"] = maxf(float(stats.get("range", 0.0)), float(base_stats.get("range", 0.0)))
		if state.specialization == "B":
			stats["attacker_count"] = 1 + matching_count
	elif tower_id == "nuclear":
		if state.specialization in ["A", "B"]:
			stats["damage_multiplier"] = float(stats.get("damage_multiplier", 1.0)) + float(base_tuning.get("nuclear_specialization_damage_bonus_points", 0.0)) * float(matching_count)
		if state.specialization == "B":
			stats["global_damage_fraction"] = float(stats.get("global_damage_fraction", 0.0)) + float(base_tuning.get("nuclear_radiation_bonus_points", 0.0)) * float(matching_count)
	elif tower_id == "barracks":
		stats["production_interval"] = float(stats.get("production_interval", 10.0)) / (1.0 + float(matching_count) * float(base_tuning.get("barracks_production_divisor_per_enhancer", 0.0)))
		if state.specialization == "A":
			stats["soldier_damage_multiplier"] = float(stats.get("soldier_damage_multiplier", 1.0)) + float(base_tuning.get("barracks_specialization_a_damage_bonus_points", 0.0)) * float(matching_count)
		elif state.specialization == "B":
			stats["soldier_damage_multiplier"] = float(stats.get("soldier_damage_multiplier", 1.0)) + float(base_tuning.get("barracks_specialization_b_damage_bonus_points", 0.0)) * float(matching_count)
	elif tower_id == "mage":
		stats["attacker_count"] = 1 + matching_count * int(base_tuning.get("mage_extra_mages", 0))
	var affected: String = String(catalog.battle_tuning.get("enhancer_growth", {}).get("affected_stat_by_tower", {}).get(tower_id, ""))
	if not affected.is_empty():
		var ages: Array = []
		for enhancer in enhancers:
			var enhancer_state: TowerState = enhancer["state"]
			if enhancer_state.specialization == "B":
				ages.append(maxf(0.0, elapsed_time - float(enhancer["growth_start_time"])))
		var growth: Dictionary = catalog.battle_tuning.get("enhancer_growth", {})
		var growth_multiplier: float = EnhancerRulesScript.combined_growth_multiplier(
			ages,
			float(growth.get("fraction_per_interval", 0.008)),
			float(growth.get("interval_seconds", 30.0))
		)
		if affected == "damage":
			stats["damage"] = float(stats.get("damage", 0.0)) * growth_multiplier
		elif affected == "soldier_damage":
			stats["soldier_damage"] = float(stats.get("soldier_damage", 0.0)) * growth_multiplier
		elif affected == "range":
			stats["range"] = float(stats.get("range", 0.0)) * growth_multiplier
	return stats


func _adjusted_cost(raw_cost: int, tower_id: String) -> int:
	if raw_cost < 0:
		return -1
	if tower_id != "nuclear":
		return raw_cost
	var tuning: Dictionary = catalog.battle_tuning.get("enhancer_base", {})
	var discount: float = float(tuning.get("nuclear_cost_divisor_per_enhancer", 0.0)) * float(_enhancer_runtimes().size())
	return maxi(1, ceili(float(raw_cost) / (1.0 + discount)))


func _kill_reward_multiplier() -> float:
	var bonus: float = 0.0
	for enhancer in _enhancer_runtimes():
		var state: TowerState = enhancer["state"]
		if state.specialization == "A":
			bonus += float(state.current_stats().get("kill_gold_bonus_per_enhancer", 0.0))
	return 1.0 + bonus


func _enhancer_runtimes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for runtime in towers.values():
		var state: TowerState = runtime["state"]
		if state.tower_id == "enhancer":
			result.append(runtime)
	return result


func _remove_inactive_units() -> void:
	var active_enemies: Array = []
	for enemy in enemies:
		if enemy.alive:
			active_enemies.append(enemy)
	enemies = active_enemies
	var active_soldiers: Array = []
	for soldier in soldiers:
		if soldier.alive:
			active_soldiers.append(soldier)
	soldiers = active_soldiers


func events_after(sequence: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in _event_log:
		if int(event["sequence"]) > sequence:
			result.append(event.duplicate(true))
	return result


func event_sequence() -> int:
	return _event_sequence


func _emit_event(kind: String, data: Dictionary) -> void:
	_event_sequence += 1
	var event: Dictionary = {"sequence": _event_sequence, "kind": kind}
	event.merge(data, true)
	_event_log.append(event)
	if _event_log.size() > EVENT_LIMIT:
		_event_log.pop_front()


func snapshot() -> Dictionary:
	var slot_snapshots: Array[Dictionary] = []
	for index in range(build_slots.size()):
		var runtime: Dictionary = towers.get(index, {})
		var tower_id: String = ""
		var level: int = 0
		var specialization: String = ""
		var stats: Dictionary = {}
		if not runtime.is_empty():
			var state: TowerState = runtime["state"]
			tower_id = state.tower_id
			level = state.level
			specialization = state.specialization
			stats = _effective_stats(index)
		slot_snapshots.append({
			"id": index, "position": build_slots[index], "tower_id": tower_id,
			"level": level, "specialization": specialization, "stats": stats
		})
	var enemy_snapshots: Array[Dictionary] = []
	for enemy in enemies:
		enemy_snapshots.append({
			"id": enemy.spawn_order, "enemy_id": enemy.enemy_id,
			"position": enemy.position_on(route), "path_distance": enemy.path_distance,
			"health": enemy.health, "maximum_health": enemy.maximum_health,
			"armor": enemy.armor, "is_flying": enemy.is_flying,
			"debuff_remaining": float(enemy.debuff.get("remaining", 0.0))
		})
	var soldier_snapshots: Array[Dictionary] = []
	for soldier in soldiers:
		soldier_snapshots.append({"id": soldier.id, "tower_slot": soldier.tower_slot, "position": soldier.position, "health": soldier.health, "maximum_health": soldier.maximum_health})
	var waves: Array = catalog.wave_config.get("waves", [])
	return {
		"phase": phase, "wave": wave_index + 1, "wave_total": waves.size(),
		"wave_name": String(active_wave.get("display_name", "")),
		"wave_kills": wave_kills, "wave_leaks": wave_leaks,
		"gold": wallet.gold, "lives": lives, "elapsed_time": elapsed_time,
		"spawned": spawned_count, "wave_spawned": wave_spawned_count,
		"spawned_by_enemy": spawned_by_enemy.duplicate(), "killed": killed_count, "leaked": leaked_count,
		"remaining_to_spawn": wave_director.remaining_to_spawn,
		"route": route.duplicate(), "slots": slot_snapshots,
		"enemies": enemy_snapshots, "soldiers": soldier_snapshots
	}
