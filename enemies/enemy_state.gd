class_name EnemyState
extends RefCounted

const StatusEffectRulesScript = preload("res://combat/status_effect_rules.gd")
const PathFollowerScript = preload("res://enemies/path_follower.gd")

var enemy_id: String
var spawn_order: int
var health: float
var maximum_health: float
var armor: float
var speed: float
var kill_gold: int
var core_damage: int
var attack_damage: float
var attack_interval: float
var attack_range: float
var is_flying: bool
var path_distance: float = 0.0
var alive: bool = true
var leaked: bool = false
var debuff: Dictionary = {}
var attack_cooldown: float = 0.0


func _init(id: String, order: int, definition: Dictionary) -> void:
	enemy_id = id
	spawn_order = order
	maximum_health = float(definition.get("health", 1.0))
	health = maximum_health
	armor = clampf(float(definition.get("armor", 0.0)), 0.0, 1.0)
	speed = maxf(0.0, float(definition.get("speed", 0.0)))
	kill_gold = maxi(0, int(definition.get("kill_gold", 0)))
	core_damage = maxi(1, int(definition.get("core_damage", 1)))
	attack_damage = maxf(0.0, float(definition.get("attack_damage", 0.0)))
	attack_interval = maxf(0.05, float(definition.get("attack_interval", 1.0)))
	attack_range = maxf(0.0, float(definition.get("attack_range", 0.0)))
	is_flying = bool(definition.get("is_flying", false))


func take_damage(amount: float) -> bool:
	if not alive:
		return false
	health = maxf(0.0, health - maxf(0.0, amount))
	if health <= 0.0:
		alive = false
		return true
	return false


func move(delta: float) -> void:
	if not alive:
		return
	path_distance += speed * StatusEffectRulesScript.movement_multiplier(debuff) * delta
	debuff = StatusEffectRulesScript.tick(debuff, delta)


func apply_knockback(distance: float) -> void:
	if alive:
		path_distance = maxf(0.0, path_distance - maxf(0.0, distance))


func attack_damage_after_effects() -> float:
	return attack_damage * (1.0 - clampf(float(debuff.get("attack_reduction", 0.0)), 0.0, 1.0))


func position_on(route: Array) -> Vector2:
	return PathFollowerScript.position_at(route, path_distance)
