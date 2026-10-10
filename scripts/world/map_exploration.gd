extends Node

signal changed

const REVEAL_RADIUS := 420.0
var arena: Node2D
var player: Node2D
var explored: Dictionary = {}
var route := PackedVector2Array()
var debug_reveal := false
var _last_position := Vector2.INF
var _last_cell := Vector2i(-999, -999)


func _process(_delta: float) -> void:
	if is_instance_valid(player) and player.global_position.distance_to(_last_position) >= 24.0:
		observe(player.global_position)


func observe(world_position: Vector2) -> void:
	_last_position = world_position
	var point := arena.to_local(world_position)
	var row := roundi((point.y - arena.MAP_ORIGIN.y) / arena.TILE_STEP.y)
	var closest := Vector2i(-999, -999)
	var closest_distance := INF
	var added := false
	for y in range(row - 7, row + 8):
		var shift: float = arena.TILE_STEP.x * 0.5 if y % 2 != 0 else 0.0
		var column := roundi((point.x - arena.MAP_ORIGIN.x - shift) / arena.TILE_STEP.x)
		for x in range(column - 6, column + 7):
			var cell := Vector2i(x, y)
			if not arena._floor_cells.has(cell):
				continue
			var center: Vector2 = arena._cell_to_local(cell)
			var distance := center.distance_to(point)
			if distance < closest_distance:
				closest = cell
				closest_distance = distance
			if distance > REVEAL_RADIUS or explored.has(cell):
				continue
			# Water, walls and closed gates do not expose rooms behind them.
			if _has_sight(point, center):
				explored[cell] = true
				added = true
	if closest != _last_cell and closest_distance < 100.0:
		_last_cell = closest
		route.append(world_position)
		if route.size() > 2000:
			route.remove_at(0)
		added = true
	if added:
		changed.emit()


func _has_sight(from: Vector2, target: Vector2) -> bool:
	var distance := from.distance_to(target)
	var direction := from.direction_to(target)
	# One point per sample suffices for visibility; no actor-sized collision tests.
	# Stop at the near face of the target so water/gate edges themselves are visible.
	for step in range(32, ceili(maxf(0.0, distance - 80.0)) + 32, 32):
		if not arena._is_point_on_open_floor(from + direction * minf(float(step), distance)):
			return false
	return true


func is_revealed(cell: Vector2i) -> bool:
	return debug_reveal or explored.has(cell)


func toggle_debug_reveal() -> void:
	debug_reveal = not debug_reveal
	changed.emit()
