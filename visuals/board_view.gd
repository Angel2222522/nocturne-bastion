class_name BoardView
extends Control

signal build_slot_pressed(slot_id: int)

const SLOT_HIT_RADIUS: float = 32.0
const UI_FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const BACKDROP: Texture2D = preload("res://assets/world/level_01_backdrop.jpg")
const RAPID_TOWER: Texture2D = preload("res://assets/towers/rapid_tower.png")
const CINDER_MITE: Texture2D = preload("res://assets/enemies/cinder_mite.png")

const ROAD_WIDTH: float = 38.0
const ROAD_SEAM_SPACING: float = 48.0

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
	if BACKDROP != null:
		draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("172321"))
	_draw_atmosphere()
	_update_map_transform()
	_draw_route()
	if route.size() >= 2:
		_draw_gate(_world_to_screen(route[0]), Color("eab45c"), false)
		_draw_gate(_world_to_screen(route[route.size() - 1]), Color("72d3bd"), true)
	_draw_build_slots()
	_draw_enemies()
	_draw_map_caption()
	_draw_frame()


func _draw_atmosphere() -> void:
	# The illustration carries detail; this wash keeps the playable path legible.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.05, 0.18))


func _draw_frame() -> void:
	var frame_color: Color = Color("e2c27a")
	frame_color.a = 0.32
	draw_rect(Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), frame_color, false, 1.0)


func _draw_map_caption() -> void:
	draw_rect(Rect2(Vector2(15.0, size.y - 39.0), Vector2(220.0, 25.0)), Color(0.035, 0.055, 0.06, 0.72))
	draw_string(
		UI_FONT,
		Vector2(25.0, size.y - 22.0),
		"01   /   ΘΕΡΜΙΚΟ ΠΕΡΑΣΜΑ",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("d8c89e")
	)


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
	_draw_rounded_road_layer(points, Color("17231f"), ROAD_WIDTH + 10.0)
	_draw_rounded_road_layer(points, Color("302f27"), ROAD_WIDTH + 3.0)
	_draw_rounded_road_layer(points, Color("655b43"), ROAD_WIDTH - 2.0)
	_draw_rounded_road_layer(points, Color("958361"), ROAD_WIDTH - 12.0)
	_draw_road_seams(points)
	_draw_rounded_road_layer(points, Color("5dcbb3", 0.52), 7.0)
	_draw_rounded_road_layer(points, Color("a0f1d7"), 2.0)


func _draw_rounded_road_layer(points: PackedVector2Array, color: Color, width: float) -> void:
	draw_polyline(points, color, width, true)
	var radius: float = width * 0.5
	for point in points:
		draw_circle(point, radius, color)


func _draw_road_seams(points: PackedVector2Array) -> void:
	for segment_index in range(points.size() - 1):
		var start: Vector2 = points[segment_index]
		var finish: Vector2 = points[segment_index + 1]
		var segment: Vector2 = finish - start
		var segment_length: float = segment.length()
		if segment_length <= ROAD_SEAM_SPACING:
			continue
		var tangent: Vector2 = segment / segment_length
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var seam_count: int = int(segment_length / ROAD_SEAM_SPACING)
		for seam_index in range(1, seam_count + 1):
			var distance: float = ROAD_SEAM_SPACING * float(seam_index)
			if distance >= segment_length - 12.0:
				continue
			var seam_center: Vector2 = start + tangent * distance
			draw_line(
				seam_center - normal * (ROAD_WIDTH * 0.29),
				seam_center + normal * (ROAD_WIDTH * 0.29),
				Color("594f3d", 0.8),
				1.5,
				true
			)


func _draw_gate(center: Vector2, color: Color, is_exit: bool) -> void:
	draw_circle(center, 13.0, Color("182420", 0.9))
	draw_arc(center, 12.0, 0.0, TAU, 36, color, 2.5, true)
	draw_arc(center, 6.0, 0.0, TAU, 24, Color("f1dfb5", 0.8), 1.0, true)
	if is_exit:
		var point: PackedVector2Array = PackedVector2Array([
			center + Vector2(0.0, -3.0),
			center + Vector2(4.0, 0.0),
			center + Vector2(0.0, 3.0),
			center + Vector2(-4.0, 0.0)
		])
		draw_colored_polygon(point, color)
	else:
		draw_line(center + Vector2(-3.0, 0.0), center + Vector2(3.0, 0.0), color, 2.0, true)
		draw_line(center + Vector2(0.0, -3.0), center + Vector2(0.0, 3.0), color, 2.0, true)


func _draw_build_slots() -> void:
	for slot in slots:
		var slot_id: int = int(slot["id"])
		var center: Vector2 = _world_to_screen(slot["position"])
		var occupied: bool = not String(slot.get("tower_id", "")).is_empty()
		_draw_build_site(center, slot_id == selected_slot, occupied)
		if occupied:
			draw_texture_rect(RAPID_TOWER, Rect2(center - Vector2(25.0, 25.0), Vector2(50.0, 50.0)), false)


func _draw_build_site(center: Vector2, is_selected: bool, is_occupied: bool) -> void:
	var brass: Color = Color("e6b35c") if is_selected else Color("bd9a61")
	var teal: Color = Color("80e2c7")
	if is_selected:
		draw_circle(center, 27.0, Color("e6b35c", 0.14))
		draw_arc(center, 25.0, 0.0, TAU, 48, Color("f5ca75", 0.9), 2.0, true)
	draw_circle(center + Vector2(0.0, 2.0), 20.0, Color("101816", 0.84))
	draw_circle(center, 17.0, Color("29312c"))
	draw_arc(center, 18.5, 0.0, TAU, 40, brass, 1.5 if not is_selected else 2.5, true)
	draw_arc(center, 14.0, 0.2, 2.0, 24, Color("dfc18b", 0.72), 1.0, true)
	for stud in [Vector2(-11.0, -11.0), Vector2(11.0, -11.0), Vector2(11.0, 11.0), Vector2(-11.0, 11.0)]:
		draw_circle(center + stud, 1.5, Color("c7aa74"))
	if not is_occupied:
		var crystal: PackedVector2Array = PackedVector2Array([
			center + Vector2(0.0, -4.0),
			center + Vector2(4.0, 0.0),
			center + Vector2(0.0, 4.0),
			center + Vector2(-4.0, 0.0)
		])
		draw_colored_polygon(crystal, teal)
		draw_circle(center, 1.5, Color("efffea"))


func _draw_enemies() -> void:
	for enemy in enemies:
		var center: Vector2 = _world_to_screen(enemy["position"])
		var maximum_health: float = maxf(float(enemy["maximum_health"]), 1.0)
		var health_ratio: float = clampf(float(enemy["health"]) / maximum_health, 0.0, 1.0)
		draw_circle(center + Vector2(0.0, 9.0), 13.0, Color(0.02, 0.025, 0.02, 0.4))
		draw_texture_rect(CINDER_MITE, Rect2(center - Vector2(19.0, 19.0), Vector2(38.0, 38.0)), false)
		var bar_rect: Rect2 = Rect2(center + Vector2(-13.0, -24.0), Vector2(26.0, 4.0))
		draw_rect(bar_rect, Color("241c17"))
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * health_ratio, bar_rect.size.y)), Color("f0a04c"))


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
