class_name PathFollower
extends RefCounted

static func total_length(route: Array) -> float:
	var length: float = 0.0
	for index in range(1, route.size()):
		length += route[index - 1].distance_to(route[index])
	return length


static func position_at(route: Array, distance: float) -> Vector2:
	if route.is_empty():
		return Vector2.ZERO
	if route.size() == 1 or distance <= 0.0:
		return route[0]
	var remaining: float = distance
	for index in range(1, route.size()):
		var start: Vector2 = route[index - 1]
		var finish: Vector2 = route[index]
		var segment_length: float = start.distance_to(finish)
		if remaining <= segment_length:
			return start.lerp(finish, remaining / segment_length)
		remaining -= segment_length
	return route[route.size() - 1]
