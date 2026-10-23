class_name StatusEffectRules
extends RefCounted

## Reapplying a matching mage hit refreshes its timer instead of adding time.
static func apply_mage_debuff(
	current: Dictionary,
	slow_fraction: float,
	attack_reduction: float,
	duration: float
) -> Dictionary:
	var refreshed: Dictionary = current.duplicate(true)
	refreshed["slow_fraction"] = clampf(slow_fraction, 0.0, 1.0)
	refreshed["attack_reduction"] = clampf(attack_reduction, 0.0, 1.0)
	refreshed["remaining"] = maxf(0.0, duration)
	return refreshed


static func tick(effect: Dictionary, delta: float) -> Dictionary:
	if effect.is_empty():
		return {}
	var updated: Dictionary = effect.duplicate(true)
	updated["remaining"] = maxf(0.0, float(updated.get("remaining", 0.0)) - maxf(0.0, delta))
	if float(updated["remaining"]) <= 0.0:
		return {}
	return updated


static func movement_multiplier(effect: Dictionary) -> float:
	return 1.0 - clampf(float(effect.get("slow_fraction", 0.0)), 0.0, 1.0)
