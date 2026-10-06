extends Control
## Low-resolution canvas is scaled with nearest filtering by its SubViewport.

var animation_time := 0.0
var manual_time := false
var storm := 0.0
var lightning := 0.0
var _sea: TextureRect
var _boat: Sprite2D
var _weather: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sea = TextureRect.new()
	_sea.texture = load("res://assets/art/title/blue_sea.png")
	_sea.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sea.stretch_mode = TextureRect.STRETCH_SCALE
	_sea.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = load("res://shaders/title_ocean.gdshader")
	_sea.material = shader
	add_child(_sea)
	_sea.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boat = Sprite2D.new()
	_boat.texture = load("res://assets/art/title/fishing_boat_trio.png")
	_boat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_boat)
	_weather = Control.new()
	_weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather.draw.connect(_draw_weather)
	add_child(_weather)
	_update_art()


func _process(delta: float) -> void:
	if not manual_time:
		animation_time += delta
	_update_art()


func _update_art() -> void:
	if _sea == null:
		return
	var material: ShaderMaterial = _sea.material
	var phase := TAU * animation_time / 4.8
	material.set_shader_parameter("phase", phase)
	material.set_shader_parameter("storm", storm)
	var factor := size.x * 0.52 / _boat.texture.get_width()
	_boat.scale = Vector2.ONE * factor
	_boat.position = Vector2(size.x * 0.5 + sin(phase + 0.6) * 2.0,
		size.y * 0.58 + sin(phase * (1.0 + storm)) * (1.5 + storm * 4.5)).round()
	_boat.rotation = sin(phase + 1.2) * (0.008 + storm * 0.055)
	_boat.modulate = Color.WHITE.lerp(Color("8396b8"), storm * 0.7)
	_weather.size = size
	_weather.queue_redraw()


func _draw_weather() -> void:
	var phase := TAU * animation_time / 4.8
	# Sea foam moves around the hull even before the weather turns.
	for index in 7:
		var x := size.x * (0.28 + index * 0.069) + sin(phase + index) * 2.0
		var y := size.y * 0.80 + sin(phase + index * 0.6) * (1.0 + storm * 2.0)
		_weather.draw_rect(Rect2(Vector2(x, y).round(), Vector2(8, 1)), Color(0.7, 0.92, 0.98, 0.4))
	if storm > 0.0:
		for index in int(storm * 85):
			var x := fposmod(index * 53.7 - animation_time * (24.0 + storm * 35.0), size.x)
			var y := fposmod(index * 37.3 + animation_time * (100.0 + storm * 90.0), size.y)
			_weather.draw_line(Vector2(x, y).round(), Vector2(x - 3, y + 9).round(), Color(0.58, 0.74, 0.86, storm * 0.55), 1.0)
	if lightning > 0.0:
		_weather.draw_rect(Rect2(Vector2.ZERO, size), Color(0.77, 0.87, 1.0, lightning * 0.32))
		var origin := Vector2(size.x * 0.77, 0)
		var points := PackedVector2Array([origin, origin + Vector2(-8, 25), origin + Vector2(4, 24),
			origin + Vector2(-12, 52), origin + Vector2(-2, 50), origin + Vector2(-20, 79)])
		_weather.draw_polyline(points, Color(0.82, 0.93, 1.0, lightning), 2.0)
