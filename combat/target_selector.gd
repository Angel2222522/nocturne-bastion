class_name TargetSelector
extends RefCounted

## Chooses the most advanced living target in range; ties preserve array order.
static func choose_most_advanced_in_range(
	enemies: Array,
	route: Array,
	tower_position: Vector2,
	attack_range: float
) -> Variant:
	var selected: Variant = null
	var best_progress: float = -1.0
	var range_squared: float = attack_range * attack_range
	for enemy in enemies:
		if not enemy.alive:
			continue
		if tower_position.distance_squared_to(enemy.position_on(route)) > range_squared:
			continue
		if enemy.path_distance > best_progress:
			selected = enemy
			best_progress = enemy.path_distance
	return selected


## Global sniper rule: maximum current EHP, independent of distance and path progress.
## First-in-array wins an exact tie, keeping the result deterministic.
static func choose_highest_current_ehp(enemies: Array) -> Variant:
	var selected: Variant = null
	var best_ehp: float = -1.0
	for enemy in enemies:
		if not enemy.alive:
			continue
		var score: float = DamageRules.effective_health(enemy.health, enemy.armor)
		if score > best_ehp:
			selected = enemy
			best_ehp = score
	return selected
