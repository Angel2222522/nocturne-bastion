class_name EnhancerRules
extends RefCounted

## Prototype interpretation: each booster contributes linearly, without compounding or a cap.
static func growth_multiplier_for_age(
	elapsed_seconds: float,
	rate_per_interval: float = 0.008,
	interval_seconds: float = 30.0
) -> float:
	if interval_seconds <= 0.0 or elapsed_seconds < 0.0:
		return 1.0
	var completed_intervals: int = floori(elapsed_seconds / interval_seconds)
	return 1.0 + float(completed_intervals) * rate_per_interval


static func combined_growth_multiplier(
	booster_ages: Array,
	rate_per_interval: float = 0.008,
	interval_seconds: float = 30.0
) -> float:
	var total_bonus: float = 0.0
	for age in booster_ages:
		total_bonus += growth_multiplier_for_age(float(age), rate_per_interval, interval_seconds) - 1.0
	return 1.0 + total_bonus


static func combine_flat_bonuses(base_value: float, bonuses: Array) -> float:
	var total_bonus: float = 0.0
	for bonus in bonuses:
		total_bonus += float(bonus)
	return base_value * (1.0 + total_bonus)
