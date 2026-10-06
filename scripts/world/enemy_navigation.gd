extends RefCounted
## Grafos compartilhados por tamanho de ator; portões invalidam o cache na arena.

var _graphs: Dictionary = {}


func clear() -> void:
	_graphs.clear()


func get_path(arena: Node2D, from: Vector2, target: Vector2, radius: float) -> PackedVector2Array:
	var key := ceili(radius)
	if not _graphs.has(key):
		_graphs[key] = _build(arena, float(key))
	var graph: AStar2D = _graphs[key]
	if graph.get_point_count() == 0:
		return PackedVector2Array()
	var start := graph.get_closest_point(from)
	var finish := graph.get_closest_point(target)
	var path := graph.get_point_path(start, finish)
	if path.is_empty():
		return path
	# Skip the start cell only when the next segment has enough clearance.
	if path.size() > 1 and _segment_open(arena, from, path[1], radius):
		path.remove_at(0)
	if _segment_open(arena, path[path.size() - 1], target, radius):
		path.append(target)
	return path


func _build(arena: Node2D, radius: float) -> AStar2D:
	var graph := AStar2D.new()
	var ids: Dictionary = {}
	for cell in arena._floor_cells:
		var position: Vector2 = arena.to_global(arena._cell_to_local(cell))
		if not arena.is_walkable(position, radius):
			continue
		var id := graph.get_available_point_id()
		graph.add_point(id, position)
		ids[cell] = id
	for cell in ids:
		for neighbour in arena._neighbours(cell):
			if not ids.has(neighbour) or ids[cell] >= ids[neighbour]:
				continue
			var start: Vector2 = graph.get_point_position(ids[cell])
			var end: Vector2 = graph.get_point_position(ids[neighbour])
			if _segment_open(arena, start, end, radius):
				graph.connect_points(ids[cell], ids[neighbour])
	return graph


func _segment_open(arena: Node2D, start: Vector2, end: Vector2, radius: float) -> bool:
	return arena.get_farthest_walkable_position(start, end, radius).distance_squared_to(end) < 1.0
