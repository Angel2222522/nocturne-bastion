class_name DamageRules
extends RefCounted

## Applies armor only to physical damage. Armor is represented as a fraction.
static func calculate_damage(
	raw_damage: float,
	armor: float,
	damage_type: String,
	armor_penetration: float = 0.0
) -> float:
	if raw_damage <= 0.0:
		return 0.0
	var effective_armor: float = 0.0
	if damage_type == "physical":
		var penetration: float = clampf(armor_penetration, 0.0, 1.0)
		effective_armor = clampf(armor, 0.0, 1.0) * (1.0 - penetration)
	return raw_damage * (1.0 - effective_armor)


## Effective health uses ordinary physical armor; it is the sniper's current target score.
static func effective_health(current_health: float, armor: float) -> float:
	var damage_fraction: float = 1.0 - clampf(armor, 0.0, 1.0)
	if damage_fraction <= 0.0:
		return INF
	return maxf(0.0, current_health) / damage_fraction
