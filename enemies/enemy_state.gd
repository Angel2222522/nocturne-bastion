class_name EnemyState
extends RefCounted

var enemy_id: String
var spawn_order: int
var health: float
var maximum_health: float
var armor: float
var speed: float
var kill_gold: int
var core_damage: int
var path_distance: float = 0.0
var alive: bool = true
var leaked: bool = false
var debuff: Dictionary = {}

func _init(id: String, order: int, definition: Dictionary) -> void:
	enemy_id = id
	spawn_order = order
	maximum_health = float(definition.get("health", 1.0))
	health = maximum_health
	armor = float(definition.get("armor", 0.0))
	speed = float(definition.get("speed", 0.0))
	kill_gold = int(definition.get("kill_gold", 0))
	core_damage = int(definition.get("core_damage", 1))


func take_damage(amount: float) -> bool:
	if not alive:
		return false
	health = maxf(0.0, health - maxf(0.0, amount))
	if health <= 0.0:
		alive = false
		return true
	return false


func move(delta: float) -> void:
	if alive:
		path_distance += speed * StatusEffectRules.movement_multiplier(debuff) * delta
		debuff = StatusEffectRules.tick(debuff, delta)


func position_on(route: Array) -> Vector2:
	return PathFollower.position_at(route, path_distance)
