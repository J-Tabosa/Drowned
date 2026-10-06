extends Control
## Generated rock planes, local crystal glows, rooted kelp and occasional drops.

const BACKGROUND := preload("res://assets/art/dialogue/cave_crystals.png")
const KELP := preload("res://assets/art/dialogue/kelp.png")
const CRYSTALS := [Vector2(31, 99), Vector2(296, 78), Vector2(280, 132)]
var animation_time := 0.0
var manual_time := false
var _drop_clock := 0.0
var _next_drop := 4.2
var _drops: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
			position.y = minf(145.0, position.y + (42.0 + drop.age * 55.0) * delta)
			drop.position = position
		_drops = _drops.filter(func(drop: Dictionary) -> bool: return drop.age < 2.0)
	queue_redraw()


func _spawn_drop() -> void:
	# Drops begin at the hanging rock tips, not in the open middle of the cave.
	var tips := [Vector2(45, 47), Vector2(83, 35), Vector2(202, 24), Vector2(260, 45)]
	_drops.append({"position": tips[_rng.randi_range(0, tips.size() - 1)], "age": 0.0})


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 320, 180), false)
	for origin in CRYSTALS:
		var pulse := 0.055 + sin(animation_time * 1.15 + origin.x) * 0.018
		for radius in [11.0, 7.0, 3.0]:
			draw_circle(origin, radius, Color(0.15, 0.8, 0.78, pulse * 0.45))
	for index in 4:
		var roots := [Vector2(9, 146), Vector2(50, 164), Vector2(302, 157), Vector2(316, 139)]
		_draw_kelp(roots[index], index)
	for drop in _drops:
		var position: Vector2 = drop.position
		if position.y < 145.0:
			draw_rect(Rect2(position.round(), Vector2(1, 3)), Color("65949f"))
		else:
			var width: float = 2.0 + (float(drop.age) - 1.0) * 4.0
			draw_line(Vector2(position.x - width, 146).round(), Vector2(position.x + width, 146).round(),
				Color(0.3, 0.6, 0.65, clampf(2.0 - drop.age, 0.0, 0.6)), 1.0)


func _draw_kelp(root_position: Vector2, index: int) -> void:
	# Pixel rows bend progressively; the last row remains attached to its root.
	var height := 36
	var tint := Color("799a93") if index % 2 == 0 else Color("60827f")
	for row in height:
		var progress := float(height - 1 - row) / (height - 1)
		var sway := roundf(sin(animation_time * 0.85 + index + progress * 1.8) * progress * 2.5)
		var destination := Rect2(root_position.x - 10 + sway, root_position.y - height + row, 20, 1)
		draw_texture_rect_region(KELP, destination, Rect2(0, row, 20, 1), tint)
