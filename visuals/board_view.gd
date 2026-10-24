class_name BoardView
extends Control

signal build_slot_pressed(slot_id: int)

const SLOT_HIT_RADIUS: float = 32.0
const FOUNDATION: Texture2D = preload("res://assets/vector/foundation.svg")
const TOWER_BASE: Texture2D = preload("res://assets/vector/tower_base.svg")
const TURRET: Texture2D = preload("res://assets/vector/turret.svg")
const MITE: Texture2D = preload("res://assets/vector/mite_body.svg")
const CORE: Texture2D = preload("res://assets/vector/core.svg")
const PORTAL: Texture2D = preload("res://assets/vector/portal.svg")
const BACKDROP: Texture2D = preload("res://assets/world/mineral_valley.jpg")

var route: Array = []
var slots: Array = []
var enemies: Array = []
var soldiers: Array = []
var selected_slot: int = -1
var _map_origin: Vector2 = Vector2.ZERO
var _map_scale: float = 1.0
var _clock: float = 0.0
var _snapshot_age: float = 0.1
var _previous_positions: Dictionary = {}
var _current_positions: Dictionary = {}
var _previous_soldier_positions: Dictionary = {}
var _current_soldier_positions: Dictionary = {}
var _angles: Dictionary = {}
var _recoil: Dictionary = {}
var _build_age: Dictionary = {}
var _hit_age: Dictionary = {}
var _effects: Array[Dictionary] = []
var _static_layer: Node2D
var _terrain_dirty: bool = true
var _core_hit_age: float = 10.0
var animation_counts: Dictionary = {
	"shot": 0, "hit": 0, "death": 0, "build": 0, "upgrade": 0,
	"spawn": 0, "leak": 0, "blast": 0, "radiation": 0, "debuff": 0,
	"knockback": 0, "soldier_spawn": 0, "soldier_move": 0, "soldier_attack": 0,
	"soldier_hit": 0, "soldier_death": 0, "wave_start": 0
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_static_layer = Node2D.new()
	_static_layer.show_behind_parent = true
	_static_layer.draw.connect(_draw_terrain)
	add_child(_static_layer)
	resized.connect(_invalidate_terrain)
	queue_redraw()


func _invalidate_terrain() -> void:
	_terrain_dirty = true


func set_snapshot(snapshot: Dictionary) -> void:
	if route.is_empty():
		_terrain_dirty = true
	route = snapshot.get("route", [])
	slots = snapshot.get("slots", [])
	enemies = snapshot.get("enemies", [])
	soldiers = snapshot.get("soldiers", [])
	_previous_positions = _current_positions.duplicate()
	_current_positions.clear()
	for enemy in enemies:
		_current_positions[int(enemy["id"])] = enemy["position"]
	_previous_soldier_positions = _current_soldier_positions.duplicate()
	_current_soldier_positions.clear()
	for soldier in soldiers:
		_current_soldier_positions[int(soldier["id"])] = soldier["position"]
	for key in _angles.keys():
		if key is String and String(key).begins_with("enemy_"):
			if not _current_positions.has(int(String(key).trim_prefix("enemy_"))):
				_angles.erase(key)
	_snapshot_age = 0.0
	for event in snapshot.get("effects", []):
		var kind: String = event["kind"]
		if animation_counts.has(kind):
			animation_counts[kind] += 1
		match kind:
			"shot":
				_recoil[int(event["slot"])] = 0.0
				_angles[int(event["slot"])] = (Vector2(event["target"]) - Vector2(event["position"])).angle()
			"build", "upgrade":
				_build_age[int(event["slot"])] = 0.0
			"hit":
				_hit_age[int(event["id"])] = 0.0
			"core_hit":
				_core_hit_age = 0.0
		if kind in ["shot", "death", "leak", "spawn", "blast", "radiation", "debuff", "knockback", "soldier_spawn", "soldier_attack", "soldier_hit", "soldier_death", "upgrade", "wave_start"]:
			var visual: Dictionary = event.duplicate(true)
			visual["age"] = 0.0
			visual["duration"] = _effect_duration(kind)
			_effects.append(visual)
	# Explicit bounds keep visual effects from growing with long battles.
	if _effects.size() > 128:
		_effects = _effects.slice(_effects.size() - 128)
	queue_redraw()


func set_selected_slot(slot_id: int) -> void:
	selected_slot = slot_id
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	_snapshot_age += delta
	_core_hit_age += delta
	for table in [_recoil, _build_age, _hit_age]:
		for key in table.keys():
			table[key] = float(table[key]) + delta
			if float(table[key]) > 0.65:
				table.erase(key)
	for index in range(_effects.size() - 1, -1, -1):
		_effects[index]["age"] = float(_effects[index]["age"]) + delta
		if float(_effects[index]["age"]) >= float(_effects[index]["duration"]):
			_effects.remove_at(index)
	_update_map_transform()
	if _terrain_dirty and is_instance_valid(_static_layer):
		_static_layer.queue_redraw()
		_terrain_dirty = false
	queue_redraw()


func _draw() -> void:
	_update_map_transform()
	_draw_gates()
	for slot in slots:
		var id: int = int(slot["id"])
		var center: Vector2 = _world_to_screen(slot["position"])
		var occupied: bool = not String(slot.get("tower_id", "")).is_empty()
		if id == selected_slot:
			_draw_selection(center)
		if occupied:
			_draw_tower(center, id, String(slot.get("tower_id", "rapid")), int(slot.get("level", 1)), String(slot.get("specialization", "")))
		else:
			_stamp(FOUNDATION, center, 43.0 * _visual_scale())
	for enemy in enemies:
		_draw_enemy(enemy)
	for soldier in soldiers:
		_draw_soldier(soldier)
	_draw_effects()


func _visual_scale() -> float:
	return clampf(_map_scale / 60.0, 0.52, 1.05)


func _effect_duration(kind: String) -> float:
	match kind:
		"shot":
			return 0.16
		"blast", "radiation", "debuff", "knockback", "soldier_attack", "soldier_hit":
			return 0.62
		"wave_start":
			return 0.85
		_:
			return 0.55


func _stamp(texture: Texture2D, center: Vector2, diameter: float, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(texture, Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), false, tint)


func _update_map_transform() -> void:
	var bounds: Rect2 = _world_bounds()
	var available: Vector2 = size - Vector2(88.0, 56.0)
	_map_scale = maxf(1.0, minf(available.x / bounds.size.x, available.y / bounds.size.y))
	_map_origin = (size - bounds.size * _map_scale) * 0.5 - bounds.position * _map_scale


func _world_bounds() -> Rect2:
	var minimum: Vector2 = Vector2.ZERO
	var maximum: Vector2 = Vector2.ONE
	for point in route:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	for slot in slots:
		minimum = minimum.min(slot["position"])
		maximum = maximum.max(slot["position"])
	return Rect2(minimum, maximum - minimum)


func _world_to_screen(point: Vector2) -> Vector2:
	return _map_origin + point * _map_scale


func _draw_terrain() -> void:
	_update_map_transform()
	_static_layer.draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, size), false)
	if route.size() < 2:
		return
	var points: PackedVector2Array = PackedVector2Array()
	var unit_scale: float = _visual_scale()
	for point in route:
		points.append(_world_to_screen(point))
	# Bedded trail, contrasting sculpted shoulders, then individual irregular paving stones.
	_static_layer.draw_polyline(points, Color("c4a08c", 0.42), 52.0 * unit_scale, true)
	_static_layer.draw_polyline(points, Color("e4c6a3"), 44.0 * unit_scale, true)
	_static_layer.draw_polyline(points, Color("b9917f"), 37.0 * unit_scale, true)
	_static_layer.draw_polyline(points, Color("cba18b"), 34.0 * unit_scale, true)
	for index in range(points.size() - 1):
		var start: Vector2 = points[index]
		var finish: Vector2 = points[index + 1]
		var tangent: Vector2 = (finish - start).normalized()
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var count: int = maxi(1, int(start.distance_to(finish) / (22.0 * unit_scale)))
		for stone_index in range(count):
			var a: Vector2 = start.lerp(finish, float(stone_index) / count)
			var b: Vector2 = start.lerp(finish, float(stone_index + 1) / count)
			var offset: float = sin(float(stone_index * 7 + index * 31)) * 1.5
			var color: Color = [Color("dbb29a"), Color("e1bba1"), Color("d7aa92"), Color("e6c0a4")][stone_index % 4]
			for side in [-1.0, 1.0]:
				var outer: float = side * 15.0 * unit_scale
				var poly: PackedVector2Array = PackedVector2Array([a + tangent * 1.0 + normal * (side + offset), b - tangent * 1.0 + normal * side, b - tangent * 1.5 + normal * outer, a + tangent * 2.0 + normal * (outer + offset)])
				_static_layer.draw_colored_polygon(poly, color)
			# Interrupted pale curb blocks look like actual stone, not a luminous route line.
			for side in [-1.0, 1.0]:
				var c: Vector2 = (a + b) * 0.5 + normal * side * (20.0 + offset * 0.45) * unit_scale
				_static_layer.draw_line(c - tangent * 8.0 * unit_scale, c + tangent * 8.0 * unit_scale, Color("f8e3bf"), 4.0 * unit_scale, true)
				_static_layer.draw_line(c - tangent * 8.0 * unit_scale + normal * 2.0 * unit_scale, c + tangent * 8.0 * unit_scale + normal * 2.0 * unit_scale, Color("af8d7e", 0.45), 1.0 * unit_scale, true)
	for point in points:
		var half_size: float = 17.0 * unit_scale
		_static_layer.draw_colored_polygon(PackedVector2Array([point + Vector2(-half_size,-half_size),point + Vector2(half_size,-half_size),point + Vector2(half_size,half_size),point + Vector2(-half_size,half_size)]), Color("dcb399"))


func _draw_selection(center: Vector2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_clock * 4.0)
	for sign_x in [-1.0, 1.0]:
		for sign_y in [-1.0, 1.0]:
			var corner: Vector2 = center + Vector2(sign_x, sign_y) * (25.0 + pulse) * _visual_scale()
			draw_polyline(PackedVector2Array([corner - Vector2(sign_x * 9.0, 0) * _visual_scale(), corner, corner - Vector2(0, sign_y * 9.0) * _visual_scale()]), Color("714a93"), 3.5 * _visual_scale(), true)


func _draw_tower(center: Vector2, id: int, tower_id: String, level: int, specialization: String) -> void:
	var age: float = float(_build_age.get(id, 1.0))
	var scale_factor: float = 1.0
	if age < 0.45:
		scale_factor = lerpf(0.35, 1.0, ease(clampf(age / 0.45, 0.0, 1.0), 0.3))
	var s: float = _visual_scale() * scale_factor
	_stamp(TOWER_BASE, center, 68.0 * s)
	var recoil_age: float = float(_recoil.get(id, 10.0))
	var pulse: float = 0.5 + 0.5 * sin(_clock * 3.2 + float(id))
	draw_set_transform(center, 0.0, Vector2.ONE * s)
	match tower_id:
		"rapid":
			var angle: float = float(_angles.get(id, -0.4))
			var kick: float = maxf(0.0, 1.0 - recoil_age / 0.16) * 4.5
			draw_set_transform(center - Vector2.RIGHT.rotated(angle) * kick * s, angle, Vector2.ONE * s)
			_stamp(TURRET, Vector2.ZERO, 61.0)
			if recoil_age < 0.085:
				draw_colored_polygon(PackedVector2Array([Vector2(21,-5),Vector2(37,0),Vector2(23,5)]), Color("fff3bd"))
		"nuclear":
			draw_circle(Vector2.ZERO, 24.0, Color("5d4b65"))
			draw_circle(Vector2.ZERO, 17.0, Color("463854"))
			draw_colored_polygon(PackedVector2Array([Vector2(-11,9),Vector2(-8,-7),Vector2(0,-22),Vector2(8,-7),Vector2(11,9),Vector2(0,16)]), Color("ff987f"))
			draw_colored_polygon(PackedVector2Array([Vector2(-5,5),Vector2(0,-15),Vector2(6,5),Vector2(0,11)]), Color("ffe4a2"))
			draw_arc(Vector2.ZERO, 28.0 + pulse * 2.0, 0.0, TAU, 24, Color("ffb280", 0.75), 2.2, true)
		"barracks":
			draw_colored_polygon(PackedVector2Array([Vector2(-22,-10),Vector2(-15,-22),Vector2(15,-22),Vector2(22,-10),Vector2(19,15),Vector2(-19,15)]), Color("9d775e"))
			draw_rect(Rect2(-16,-8,32,21), Color("d3a66d"))
			draw_rect(Rect2(-6,1,12,12), Color("574457"))
			draw_line(Vector2(0,-22), Vector2(0,-32), Color("f4d591"), 2.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(0,-32),Vector2(13,-28),Vector2(0,-23)]), Color("da7780"))
		"mage":
			draw_circle(Vector2.ZERO, 24.0, Color("56466c"))
			draw_colored_polygon(PackedVector2Array([Vector2(0,-27),Vector2(18,-4),Vector2(11,16),Vector2(-11,16),Vector2(-18,-4)]), Color("ab91df"))
			draw_colored_polygon(PackedVector2Array([Vector2(0,-19),Vector2(7,-3),Vector2(0,11),Vector2(-7,-3)]), Color("e6d6ff"))
			for index in range(3):
				var orbit: Vector2 = Vector2.RIGHT.rotated(_clock * 1.4 + index * TAU / 3.0) * 29.0
				draw_circle(orbit, 2.4, Color("d8bcff", 0.9))
		"enhancer":
			draw_circle(Vector2.ZERO, 24.0, Color("506454"))
			draw_circle(Vector2.ZERO, 17.0, Color("78966e"))
			draw_line(Vector2(0,13), Vector2(0,-19), Color("d4eea6"), 4.0, true)
			draw_line(Vector2(-13,-10), Vector2(13,-10), Color("d4eea6"), 3.0, true)
			draw_circle(Vector2(-13,-10), 4.0, Color("f0d38b"))
			draw_circle(Vector2(13,-10), 4.0, Color("f0d38b"))
			draw_arc(Vector2.ZERO, 29.0 + pulse * 3.0, 0.0, TAU, 24, Color("b5e59f", 0.75), 2.0, true)
	draw_set_transform(center, 0.0, Vector2.ONE * s)
	if level > 1 or not specialization.is_empty():
		for pip in range(mini(level - 1, 3)):
			draw_circle(Vector2(-8.0 + pip * 8.0, 22.0), 2.4, Color("ffe5a0"))
	if specialization == "A":
		draw_arc(Vector2.ZERO, 32.0, 0.2, 2.5, 12, Color("87e6cc"), 2.0, true)
	elif specialization == "B":
		draw_arc(Vector2.ZERO, 32.0, 3.3, 5.6, 12, Color("ff9b88"), 2.0, true)
	draw_set_transform(Vector2.ZERO)


func _tower_color(tower_id: String) -> Color:
	match tower_id:
		"rapid": return Color("85d7db")
		"nuclear": return Color("ff937c")
		"barracks": return Color("e7c77f")
		"mage": return Color("bda0ed")
		"enhancer": return Color("a5dc9e")
		_: return Color("c5a3d2")


func _draw_enemy(enemy: Dictionary) -> void:
	var id: int = int(enemy["id"])
	var position: Vector2 = enemy["position"]
	var old: Vector2 = _previous_positions.get(id, position)
	var t: float = clampf(_snapshot_age / 0.1, 0.0, 1.0)
	var world_position: Vector2 = old.lerp(position, t)
	var ground_center: Vector2 = _world_to_screen(world_position)
	var flying: bool = bool(enemy.get("is_flying", false))
	var center: Vector2 = ground_center + Vector2(0.0, -15.0 * _visual_scale()) if flying else ground_center
	var direction: Vector2 = position - old
	var angle: float = direction.angle() if direction.length_squared() > 0.000001 else float(_angles.get("enemy_%d" % id, 0.0))
	_angles["enemy_%d" % id] = angle
	# Gait follows actual travelled distance, so stationary enemies cannot walk in place.
	var gait: float = float(enemy.get("path_distance", 0.0)) * 19.0 - (1.0 - t) * direction.length() * 19.0
	var s: float = _visual_scale()
	if flying:
		draw_ellipse_shadow(ground_center + Vector2(0.0, 8.0 * s), Vector2(12.0 * s, 7.0 * s))
	draw_set_transform(center, angle)
	if not flying:
		draw_ellipse_shadow(Vector2(1.0, 4.0) * s, Vector2(20.0, 13.0) * s)
	for side in [-1.0, 1.0]:
		for leg in range(3):
			var step: float = sin(gait + leg * 2.1 + side * PI * 0.5)
			var root: Vector2 = Vector2(-10.0 + leg * 8.0, side * 6.0) * s
			var knee: Vector2 = Vector2(-14.0 + leg * 11.0 + step * 3.5, side * 16.0) * s
			var foot: Vector2 = (Vector2(-7.0 + step * 4.0, side * (5.0 - step * 2.0)) * s) + knee
			_draw_limb(root, knee, 5.0 * s, Color("533547"))
			_draw_limb(knee, foot, 3.0 * s, Color("533547"))
			draw_line(root, knee, Color("b86459"), 3.5 * s, true)
			draw_line(knee, foot, Color("815067"), 2.0 * s, true)
	var bob: float = sin(gait * 2.0) * 0.8 * s
	var flash: float = maxf(0.0, 1.0 - float(_hit_age.get(id, 1.0)) / 0.15)
	var enemy_id: String = String(enemy.get("enemy_id", "raider"))
	var body_size: float = 49.0 * s
	var body_tint: Color = Color("d28a67")
	match enemy_id:
		"runner":
			body_size *= 0.82
			body_tint = Color("ebaa69")
		"armored":
			body_size *= 1.16
			body_tint = Color("a7a8bd")
		"winged":
			body_size *= 0.92
			body_tint = Color("c78de0")
	if flying:
		var wing_flap: float = sin(_clock * 15.0 + float(id)) * 4.0 * s
		for side in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(-5.0,-2.0) * s, Vector2(side * 19.0,(-10.0 + wing_flap) * s), Vector2(side * 13.0,8.0 * s)]), Color("e6caff", 0.88))
	_stamp(MITE, Vector2(0,bob), body_size, Color.WHITE.lerp(body_tint, 0.43).lerp(Color("ffe8c1"), flash * 0.65))
	if enemy_id == "armored":
		draw_arc(Vector2(0,0), 16.0 * s, PI, TAU, 16, Color("e1e5ef"), 3.2 * s, true)
	draw_set_transform(Vector2.ZERO)
	var ratio: float = clampf(float(enemy["health"]) / maxf(1.0, float(enemy["maximum_health"])), 0.0, 1.0)
	var bar_width: float = 34.0 * s
	var bar_y: float = -29.0 * s
	draw_rect(Rect2(center + Vector2(-bar_width * 0.5,bar_y), Vector2(bar_width,6.0 * s)), Color("4e3b50"))
	draw_rect(Rect2(center + Vector2(-bar_width * 0.5 + s,bar_y + 2.0 * s), Vector2((bar_width - 2.0 * s) * ratio,2.5 * s)), Color("ffb966"))
	if float(enemy.get("debuff_remaining", 0.0)) > 0.0:
		draw_arc(center, 25.0 * s, 0.0, TAU, 24, Color("a9c7ff", 0.8), 2.0 * s, true)


func _draw_soldier(soldier: Dictionary) -> void:
	var soldier_id: int = int(soldier["id"])
	var world_position: Vector2 = soldier["position"]
	var previous: Vector2 = _previous_soldier_positions.get(soldier_id, world_position)
	var center: Vector2 = _world_to_screen(previous.lerp(world_position, clampf(_snapshot_age / 0.1, 0.0, 1.0)))
	var s: float = _visual_scale()
	var ratio: float = clampf(float(soldier["health"]) / maxf(1.0, float(soldier["maximum_health"])), 0.0, 1.0)
	var gait: float = sin(_clock * 13.0 + float(soldier_id)) * 2.2 * s if previous.distance_squared_to(world_position) > 0.00001 else 0.0
	draw_ellipse_shadow(center + Vector2(0.0, 5.0 * s), Vector2(9.0 * s, 5.0 * s))
	draw_line(center + Vector2(-2.0 * s,-1.0 * s), center + Vector2(-4.0 * s + gait,-6.0 * s), Color("584653"), 2.0 * s, true)
	draw_line(center + Vector2(2.0 * s,-1.0 * s), center + Vector2(4.0 * s - gait,-6.0 * s), Color("584653"), 2.0 * s, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-6,-3) * s, center + Vector2(-3,-12) * s, center + Vector2(4,-12) * s, center + Vector2(7,-2) * s, center + Vector2(5,5) * s, center + Vector2(-5,5) * s]), Color("e5cc8a"))
	draw_circle(center + Vector2(0.0,-13.0 * s), 4.3 * s, Color("e4b994"))
	draw_line(center + Vector2(5.0 * s,-6.0 * s), center + Vector2(12.0 * s,-13.0 * s), Color("d9e4d2"), 2.4 * s, true)
	draw_rect(Rect2(center + Vector2(-7.0 * s,-21.0 * s), Vector2(14.0 * s,2.0 * s)), Color("473b50"))
	draw_rect(Rect2(center + Vector2(-7.0 * s,-21.0 * s), Vector2(14.0 * s * ratio,2.0 * s)), Color("a8e097"))


func _draw_limb(start: Vector2, finish: Vector2, width: float, color: Color) -> void:
	var direction: Vector2 = (finish - start).normalized()
	var normal: Vector2 = Vector2(-direction.y, direction.x) * width * 0.5
	draw_colored_polygon(PackedVector2Array([start - normal, finish - normal * 0.55, finish + normal * 0.55, start + normal]), color)


func draw_ellipse_shadow(center: Vector2, radii: Vector2) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(16):
		points.append(center + Vector2(cos(index * TAU / 16.0), sin(index * TAU / 16.0)) * radii)
	draw_colored_polygon(points, Color(0.23,0.13,0.24,0.2))


func _draw_gates() -> void:
	if route.size() < 2:
		return
	var exit: Vector2 = _world_to_screen(route.back())
	var pulse: float = 0.5 + 0.5 * sin(_clock * 2.3)
	var s: float = _visual_scale()
	draw_ellipse_shadow(exit + Vector2(0,4) * s, Vector2(31.0 + pulse * 3.0,20.0) * s)
	_stamp(CORE, exit + Vector2(0,-5.0 - pulse * 2.0) * s, 74.0 * s, Color.WHITE.lerp(Color("ffc5af"), maxf(0.0,1.0-_core_hit_age / 0.3)))
	_stamp(PORTAL, _world_to_screen(route.front()) + Vector2(-12,-3) * s, 68.0 * s)
	for index in range(4):
		var phase: float = fmod(_clock * 0.35 + index * 0.25, 1.0)
		var point: Vector2 = exit + Vector2(sin(_clock + index * 2) * 17.0, -phase * 45.0)
		var alpha: float = sin(phase * PI) * 0.6
		draw_colored_polygon(PackedVector2Array([point+Vector2(0,-3),point+Vector2(2,0),point+Vector2(0,3),point+Vector2(-2,0)]), Color(0.64,0.36,0.85,alpha))


func _draw_effects() -> void:
	for effect in _effects:
		var world_position: Vector2 = effect.get("position", effect.get("from", route.front() if not route.is_empty() else Vector2.ZERO))
		var center: Vector2 = _world_to_screen(world_position)
		var progress: float = float(effect["age"]) / float(effect["duration"])
		var alpha: float = 1.0 - progress
		match String(effect["kind"]):
			"shot":
				var target: Vector2 = _world_to_screen(effect["target"])
				var direction: Vector2 = (target - center).normalized()
				var color: Color = _tower_color(String(effect.get("tower_id", "rapid")))
				draw_line(center + direction * 23.0 * _visual_scale(), target, Color(color.r,color.g,color.b,alpha * 0.78), 2.4 * _visual_scale(), true)
				for index in range(3):
					var point: Vector2 = target + Vector2.RIGHT.rotated(index * TAU / 3.0) * progress * 12.0 * _visual_scale()
					draw_line(point, point + Vector2(2,-3) * _visual_scale(), Color(1.0,0.88,0.62,alpha), 2.0 * _visual_scale(), true)
			"blast":
				var radius: float = float(effect.get("radius", 1.0)) * _map_scale * progress
				var blast_color: Color = Color("ffae83", alpha * 0.72)
				draw_circle(center, radius * 0.36, Color(blast_color.r,blast_color.g,blast_color.b,alpha * 0.18))
				draw_arc(center, radius, 0.0, TAU, 36, blast_color, 4.0 * _visual_scale(), true)
				draw_arc(center, radius * 0.68, 0.0, TAU, 30, Color("ffe2a3", alpha * 0.8), 2.0 * _visual_scale(), true)
			"radiation":
				var point: Vector2 = _world_to_screen(effect["position"])
				draw_arc(point, (8.0 + progress * 24.0) * _visual_scale(), 0.0, TAU, 24, Color("b4e69e", alpha * 0.72), 2.2 * _visual_scale(), true)
			"debuff":
				draw_arc(center, (16.0 + progress * 8.0) * _visual_scale(), 0.0, TAU, 24, Color("b4cfff", alpha * 0.78), 2.0 * _visual_scale(), true)
			"knockback":
				var from_point: Vector2 = _world_to_screen(effect.get("from", world_position))
				var to_point: Vector2 = _world_to_screen(effect.get("position", world_position))
				draw_line(from_point, to_point, Color("d8b5ff", alpha * 0.8), 3.0 * _visual_scale(), true)
				draw_arc(to_point, (10.0 + progress * 10.0) * _visual_scale(), 0.0, TAU, 20, Color("e8d2ff", alpha * 0.8), 2.0 * _visual_scale(), true)
			"soldier_spawn":
				for index in range(4):
					var sparkle: Vector2 = center + Vector2.RIGHT.rotated(index * TAU / 4.0) * (5.0 + progress * 12.0) * _visual_scale()
					draw_circle(sparkle, 2.4 * _visual_scale() * alpha, Color("eff1b2", alpha))
			"soldier_attack":
				var target: Vector2 = _world_to_screen(effect.get("target", world_position))
				var start: Vector2 = _world_to_screen(effect.get("from", world_position))
				draw_line(start, target, Color("fff0b5", alpha * 0.72), 1.8 * _visual_scale(), true)
			"soldier_hit":
				draw_arc(center, (7.0 + progress * 9.0) * _visual_scale(), 0.0, TAU, 18, Color("ff8f86", alpha), 2.4 * _visual_scale(), true)
			"soldier_death":
				draw_arc(center, (5.0 + progress * 18.0) * _visual_scale(), 0.0, TAU, 18, Color("e5a07c", alpha), 2.0 * _visual_scale(), true)
			"upgrade":
				draw_arc(center, (17.0 + progress * 18.0) * _visual_scale(), 0.0, TAU, 24, Color("ffe7a2", alpha * 0.84), 2.5 * _visual_scale(), true)
			"death":
				for index in range(7):
					var offset: Vector2 = Vector2.RIGHT.rotated(index * 2.4) * (6.0 + progress * 24.0) * _visual_scale()
					var point: Vector2 = center + offset + Vector2(0,progress * progress * 10.0) * _visual_scale()
					draw_colored_polygon(PackedVector2Array([point+Vector2(-3,-2),point+Vector2(3,-3),point+Vector2(2,3),point+Vector2(-2,2)]), Color(0.55,0.26,0.31,alpha))
			"spawn", "leak":
				for index in range(4):
					var point: Vector2 = center + Vector2.RIGHT.rotated(index * PI * 0.5) * progress * 18.0 * _visual_scale()
					draw_line(point, point + Vector2(0,-6) * _visual_scale(), Color(0.67,0.4,0.86,alpha), 2.0 * _visual_scale(), true)
			"wave_start":
				var width: float = lerpf(40.0, size.x * 0.72, progress)
				draw_line(Vector2((size.x - width) * 0.5, 28.0), Vector2((size.x + width) * 0.5, 28.0), Color("f0d296", alpha * 0.72), 3.0, true)


func _gui_input(event: InputEvent) -> void:
	_update_map_transform()
	var pressed: bool = false
	var event_position: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
		event_position = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		event_position = event.position
	if not pressed:
		return
	var nearest_id: int = -1
	var nearest_distance: float = SLOT_HIT_RADIUS * SLOT_HIT_RADIUS
	for slot in slots:
		var center: Vector2 = _world_to_screen(slot["position"])
		var distance: float = event_position.distance_squared_to(center)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_id = int(slot["id"])
	if nearest_id >= 0:
		build_slot_pressed.emit(nearest_id)
		accept_event()
