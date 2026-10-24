class_name SoldierState
extends RefCounted

var id: int
var tower_slot: int
var position: Vector2
var health: float
var maximum_health: float
var damage: float
var movement_speed: float
var attack_interval: float
var attack_cooldown: float = 0.0
var can_attack_fliers: bool
var alive: bool = true


func _init(
	unit_id: int,
	slot_id: int,
	world_position: Vector2,
	unit_health: float,
	unit_damage: float,
	unit_attack_interval: float,
	attacks_fliers: bool,
	unit_movement_speed: float = 1.8
) -> void:
	id = unit_id
	tower_slot = slot_id
	position = world_position
	maximum_health = maxf(1.0, unit_health)
	health = maximum_health
	damage = maxf(0.0, unit_damage)
	movement_speed = maxf(0.0, unit_movement_speed)
	attack_interval = maxf(0.05, unit_attack_interval)
	can_attack_fliers = attacks_fliers


func take_damage(amount: float) -> bool:
	if not alive:
		return false
	health = maxf(0.0, health - maxf(0.0, amount))
	if health <= 0.0:
		alive = false
		return true
	return false
