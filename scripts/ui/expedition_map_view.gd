extends Control

signal destination_clicked(world_position: Vector2)
var arena: Node2D
var exploration: Node
var player: Node2D
var teleport_mode := false
var zoom := 1.0
var pan := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS if teleport_mode else Control.CURSOR_MOVE


func map_scale() -> float:
	var bounds: Rect2 = arena.get_world_rect()
	return minf((size.x - 36) / bounds.size.x, (size.y - 36) / bounds.size.y) * zoom


func world_to_map(point: Vector2) -> Vector2:
	return (point - arena.get_world_rect().get_center()) * map_scale() + size * 0.5 + pan


func map_to_world(point: Vector2) -> Vector2:
	return (point - size * 0.5 - pan) / map_scale() + arena.get_world_rect().get_center()


func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(arena):
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("050e15"))
	var scale_factor := map_scale()
	for cell in arena._floor_cells:
		var center := world_to_map(arena.to_global(arena._cell_to_local(cell)))
		var shape := PackedVector2Array([center + Vector2(0, -50) * scale_factor,
			center + Vector2(48, -14) * scale_factor, center + Vector2(48, 14) * scale_factor,
			center + Vector2(0, 50) * scale_factor, center + Vector2(-48, 14) * scale_factor,
			center + Vector2(-48, -14) * scale_factor])
		var symbol: String = arena._floor_cells[cell]
		var tint := Color("18232c")
		if exploration.is_revealed(cell):
			tint = Color("567e86")
			if symbol == "~": tint = Color("124656")
			if symbol == "r": tint = Color("303d48")
			if arena._region_for_symbol(symbol) == "boss": tint = Color("685273")
			var gate: String = arena._gate_id_for_symbol(symbol)
			if not gate.is_empty(): tint = Color("83dfbe") if arena._gate_open[gate] else Color("d8a55a")
		draw_colored_polygon(shape, tint)
	if exploration.route.size() > 1:
		for index in range(1, exploration.route.size()):
			var previous: Vector2 = exploration.route[index - 1]
			var next: Vector2 = exploration.route[index]
			if previous.distance_to(next) <= exploration.REVEAL_RADIUS * 2:
				draw_line(world_to_map(previous), world_to_map(next), Color(0.38, 0.85, 0.83, 0.6), 1.5, true)
	for item in arena.items.get_children():
		if not item.visible: continue
		_draw_marker(item.global_position, Color("efd099"), 3)
	for gate_id in arena._gate_nodes:
		if arena._gate_nodes[gate_id].is_empty(): continue
		var gate: Node2D = arena._gate_nodes[gate_id][0]
		_draw_marker(gate.global_position, Color("83dfbe") if arena._gate_open[gate_id] else Color("ef995b"), 4)
	var position_on_map := world_to_map(player.global_position)
	draw_circle(position_on_map, 7, Color("08151e"))
	draw_colored_polygon(PackedVector2Array([position_on_map + Vector2(0, -6),
		position_on_map + Vector2(5, 5), position_on_map + Vector2(-5, 5)]), Color("b2fff3"))


func _draw_marker(world_position: Vector2, tint: Color, radius: float) -> void:
	var point: Vector2 = arena.to_local(world_position)
	for cell in arena._floor_cells:
		if arena._cell_to_local(cell).distance_to(point) < 50 and exploration.is_revealed(cell):
			draw_rect(Rect2(world_to_map(world_position) - Vector2.ONE * radius, Vector2.ONE * radius * 2), tint)
			return


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var anchor := map_to_world(event.position)
			zoom = clampf(zoom * (1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 1.0, 8.0)
			pan += event.position - world_to_map(anchor)
			queue_redraw()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if teleport_mode and event.pressed:
				destination_clicked.emit(map_to_world(event.position))
			else:
				_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pan += event.relative
		queue_redraw()
		accept_event()
