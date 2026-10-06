extends Control
## Dedicated low-resolution environment continues animating during dialogue pause.

var animation_time := 0.0
var manual_time := false
var _texture: Texture2D
var _drop_clock := 0.0
var _next_drop := 4.2
var _drops: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture = load("res://assets/art/dialogue/underwater_cave.png")
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
			position.y += 70.0 * delta
			drop.position = position
		_drops = _drops.filter(func(drop: Dictionary) -> bool: return drop.age < 2.8)
	queue_redraw()


func _spawn_drop() -> void:
	var x := _rng.randf_range(size.x * 0.16, size.x * 0.84)
	_drops.append({"position": Vector2(x, size.y * 0.12), "age": 0.0})


func _draw() -> void:
	if _texture == null:
		return
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
	for side in [0, 1]:
		for blade in 5:
			_draw_kelp(Vector2(size.x * (0.055 if side == 0 else 0.925) + blade * 5, size.y * 0.73),
				18.0 + blade * 6.0, blade + side * 3)
	for drop in _drops:
		var position: Vector2 = drop.position
		draw_rect(Rect2(position.round(), Vector2(1, 3)), Color(0.40, 0.79, 0.85, 0.45))
		draw_rect(Rect2((position - Vector2(0, 2)).round(), Vector2(1, 1)), Color(0.73, 0.92, 0.95, 0.45))


func _draw_kelp(root_position: Vector2, height: float, seed_offset: int) -> void:
	var outline := PackedVector2Array()
	for step in 9:
		var progress := float(step) / 8.0
		var sway := sin(animation_time * 0.8 + seed_offset * 0.8 + progress * 2.5) * progress * 4.0
		outline.append((root_position + Vector2(sway - (2.0 - progress), -height * progress)).round())
	for step in range(8, -1, -1):
		var progress := float(step) / 8.0
		var sway := sin(animation_time * 0.8 + seed_offset * 0.8 + progress * 2.5) * progress * 4.0
		outline.append((root_position + Vector2(sway + (2.0 - progress), -height * progress)).round())
	draw_colored_polygon(outline, Color("205647") if seed_offset % 2 == 0 else Color("337457"))
