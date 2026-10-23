class_name Wallet
extends RefCounted

var gold: int

func _init(starting_gold: int = 0) -> void:
	gold = maxi(0, starting_gold)


func can_afford(cost: int) -> bool:
	return cost >= 0 and gold >= cost


func try_spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	gold -= cost
	return true


func add_gold(amount: int) -> void:
	if amount > 0:
		gold += amount


func add_kill_reward(base_reward: int, multiplier: float = 1.0) -> int:
	var reward: int = floori(float(base_reward) * maxf(0.0, multiplier))
	add_gold(reward)
	return reward
