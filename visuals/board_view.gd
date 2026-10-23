class_name BoardView
extends Control

signal build_slot_pressed(slot_id: int)

const SLOT_HIT_RADIUS: float = 32.0
const UI_FONT = preload("res://assets/fonts/DejaVuSans.ttf")

var route: Array = []
var slots: Array = []
var enemies: Array = []
var selected_slot: int = -1
var _map_origin: Vector2 = Vector2.ZERO
var _map_scale: float = 1.0

func set_snapshot(snapshot: Dictionary) -> void:
	route = snapshot.get("route", [])
	slots = snapshot.get("slots", [])
	enemies = snapshot.get("enemies", [])
	queue_redraw()


func set_selected_slot(slot_id: int) -> void:
	selected_slot = slot_id
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101d31"))
	_draw_grid()
	_update_map_transform()
	_draw_route()
	_draw_build_slots()
	_draw_enemies()
	draw_string(
		UI_FONT,
		Vector2(20, size.y - 18),
		"PULSE  /  ΔΟΚΙΜΑΣΤΙΚΟΣ ΤΟΜΕΑΣ 01",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color("90a9c3")
	)


func _draw_grid() -> void:
	var grid_color: Color = Color("24364c")
	var step: float = 36.0
	var x: float = 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		x += step
	var y: float = 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += step


func _update_map_transform() -> void:
	var available: Vector2 = size - Vector2(72.0, 84.0)
	var bounds: Rect2 = _world_bounds()
	_map_scale = minf(available.x / bounds.size.x, available.y / bounds.size.y)
	var scaled_size: Vector2 = bounds.size * _map_scale
	_map_origin = Vector2(
		(size.x - scaled_size.x) * 0.5,
		(size.y - scaled_size.y) * 0.5
	) - bounds.position * _map_scale


func _world_bounds() -> Rect2:
	var points: Array[Vector2] = []
	for point in route:
		points.append(point)
	for slot in slots:
		points.append(slot["position"])
	if points.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _world_to_screen(point: Vector2) -> Vector2:
	return _map_origin + point * _map_scale


func _draw_route() -> void:
	if route.size() < 2:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for point in route:
		points.append(_world_to_screen(point))
	draw_polyline(points, Color("20324a"), 42.0, true)
	draw_polyline(points, Color("476b78"), 28.0, true)
	draw_polyline(points, Color("76cfbf"), 3.0, true)
	for point in points:
		draw_circle(point, 5.0, Color("d8eee5"))


func _draw_build_slots() -> void:
	for slot in slots:
		var slot_id: int = int(slot["id"])
		var center: Vector2 = _world_to_screen(slot["position"])
		var occupied: bool = not String(slot.get("tower_id", "")).is_empty()
		var ring_color: Color = Color("f1b85b") if slot_id == selected_slot else Color("8ba4ba")
		if occupied:
			draw_circle(center, 18.0, Color("1e2636"))
			draw_arc(center, 20.0, 0.0, TAU, 32, Color("f1b85b"), 3.0, true)
			_draw_rapid_tower(center)
		else:
			draw_circle(center, 18.0, Color("16253a"))
			draw_arc(center, 20.0, 0.0, TAU, 32, ring_color, 2.0 if slot_id != selected_slot else 4.0, true)
			draw_circle(center, 3.0, Color("a7bac9"))


func _draw_rapid_tower(center: Vector2) -> void:
	var metal: Color = Color("efb85c")
	draw_circle(center, 11.0, Color("304256"))
	draw_circle(center, 7.0, metal)
	draw_line(center + Vector2(3.0, -2.0), center + Vector2(15.0, -8.0), Color("ffe3a6"), 4.0, true)
	draw_circle(center, 2.5, Color("f8f2dc"))


func _draw_enemies() -> void:
	for enemy in enemies:
		var center: Vector2 = _world_to_screen(enemy["position"])
		var health_ratio: float = clampf(float(enemy["health"]) / float(enemy["maximum_health"]), 0.0, 1.0)
		draw_circle(center, 12.0, Color("3a2531"))
		draw_circle(center, 8.0, Color("d96f55"))
		draw_circle(center + Vector2(-2.0, -2.0), 2.0, Color("ffe0a3"))
		draw_rect(Rect2(center + Vector2(-13.0, -21.0), Vector2(26.0, 4.0)), Color("341f2a"))
		draw_rect(Rect2(center + Vector2(-13.0, -21.0), Vector2(26.0 * health_ratio, 4.0)), Color("efb85c"))


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
