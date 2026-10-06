extends Control
## Simple dark silhouettes on a fixed pixel grid. Only crystals emit local light.

var animation_time := 0.0
var manual_time := false
var _drop_clock := 0.0
var _next_drop := 4.2
var _drops: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 6042026


func _process(delta: float) -> void:
	if not manual_time:
		animation_time += delta
		_drop_clock += delta
		if _drop_clock >= _next_drop:
			_spawn_drop()
			_drop_clock = 0.0
			_next_drop = _rng.randf_range(4.5, 8.5)
		for drop in _drops:
			drop.age += delta
			var position: Vector2 = drop.position
			position.y += 44.0 * delta
			drop.position = position
		_drops = _drops.filter(func(drop: Dictionary) -> bool: return drop.age < 2.8)
	queue_redraw()


func _spawn_drop() -> void:
	var x := _rng.randf_range(52, 268)
	_drops.append({"position": Vector2(x, 24), "age": 0.0})


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color("050c12"))
	# Large, quiet rock clusters, without noisy texture or light from above.
	_rock([Vector2(0, 0), Vector2(320, 0), Vector2(320, 49), Vector2(300, 49),
		Vector2(300, 33), Vector2(273, 33), Vector2(273, 20), Vector2(228, 20),
		Vector2(228, 16), Vector2(91, 16), Vector2(91, 22), Vector2(47, 22),
		Vector2(47, 35), Vector2(24, 35), Vector2(24, 57), Vector2(0, 57)], "0d1b23")
	_rock([Vector2(0, 41), Vector2(24, 41), Vector2(24, 75), Vector2(16, 75),
		Vector2(16, 112), Vector2(32, 112), Vector2(32, 147), Vector2(0, 147)], "0b1921")
	_rock([Vector2(320, 34), Vector2(300, 34), Vector2(300, 66), Vector2(308, 66),
		Vector2(308, 110), Vector2(292, 110), Vector2(292, 144), Vector2(320, 144)], "0b1921")
	for spike in [Vector2(55, 22), Vector2(113, 16), Vector2(204, 16), Vector2(279, 33)]:
		draw_rect(Rect2(spike, Vector2(6, 9)), Color("0d1b23"))
		draw_rect(Rect2(spike + Vector2(2, 9), Vector2(2, 6)), Color("0d1b23"))
	_rock([Vector2(0, 142), Vector2(30, 142), Vector2(30, 136), Vector2(80, 136),
		Vector2(80, 145), Vector2(149, 145), Vector2(149, 139), Vector2(201, 139),
		Vector2(201, 134), Vector2(261, 134), Vector2(261, 141), Vector2(320, 141),
		Vector2(320, 180), Vector2(0, 180)], "09171e")
	# A few subdued ledges give the silhouettes shape without detail everywhere.
	for ledge in [Rect2(0, 54, 21, 3), Rect2(301, 64, 19, 3), Rect2(30, 136, 42, 2)]:
		draw_rect(ledge, Color("132832"))
	for crystal in [Vector2(19, 84), Vector2(297, 91), Vector2(228, 141)]:
		_draw_crystal(crystal)
	for side in [0, 1]:
		for blade in 3:
			_draw_kelp(Vector2((14 if side == 0 else 302) + blade * 4, 143),
				16.0 + blade * 6, blade + side * 3)
	for drop in _drops:
		var position: Vector2 = drop.position
		draw_rect(Rect2(position.round(), Vector2(1, 2)), Color("315461"))


func _rock(points: Array, color: String) -> void:
	draw_colored_polygon(PackedVector2Array(points), Color(color))


func _draw_crystal(origin: Vector2) -> void:
	# Tiny stepped pools of light, limited to the rock around each crystal.
	var pulse := 0.85 + sin(animation_time * 1.2 + origin.x) * 0.10
	draw_rect(Rect2(origin + Vector2(-10, -12), Vector2(24, 20)), Color(0.08, 0.25, 0.29, 0.12 * pulse))
	draw_rect(Rect2(origin + Vector2(-5, -8), Vector2(14, 13)), Color(0.10, 0.36, 0.40, 0.16 * pulse))
	draw_rect(Rect2(origin + Vector2(-3, -5), Vector2(3, 6)), Color("266a78"))
	draw_rect(Rect2(origin + Vector2(1, -9), Vector2(3, 10)), Color("4a9eaa"))
	draw_rect(Rect2(origin + Vector2(2, -8), Vector2(1, 6)), Color("83ccd0"))
	draw_rect(Rect2(origin + Vector2(5, -4), Vector2(2, 5)), Color("357f90"))


func _draw_kelp(root_position: Vector2, height: float, seed_offset: int) -> void:
	for step in int(height):
		var progress := float(step) / height
		var sway := sin(animation_time * 0.8 + seed_offset + progress * 2.5) * progress * 2.0
		draw_rect(Rect2((root_position + Vector2(sway, -step)).round(), Vector2(2, 1)),
			Color("16352f") if seed_offset % 2 == 0 else Color("1d4038"))
