extends Control
## Compact ImageGen art on a fixed 320 x 180 stage, animated in separate planes.

const SKY := preload("res://assets/art/title/clear_sky.png")
const CLOUD := preload("res://assets/art/title/cloud.png")
const BOAT := preload("res://assets/art/title/boat_stern.png")
const WATER := preload("res://assets/art/title/water_tile.png")
const LOOP_SECONDS := 4.8
var animation_time := 0.0
var manual_time := false
var storm := 0.0
var lightning := 0.0
var _sky: Node2D
var _cloud_layers: Array[Node2D] = []
var _water_layers: Array[Node2D] = []
var _boat: Node2D
var _weather: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sky = _layer("Sky", self, _draw_sky)
	for index in 2:
		_cloud_layers.append(_layer("Clouds%d" % index, self, _draw_clouds.bind(index)))
	_water_layers.append(_layer("DistantWater", self, _draw_water.bind(0)))
	_water_layers.append(_layer("MiddleWater", self, _draw_water.bind(1)))
	_boat = Node2D.new()
	_boat.name = "BoatRig"
	add_child(_boat)
	var sprite := Sprite2D.new()
	sprite.name = "Stern"
	sprite.texture = BOAT
	sprite.position = Vector2(0, -54)
	_boat.add_child(sprite)
	_water_layers.append(_layer("ForegroundWater", self, _draw_water.bind(2)))
	_weather = _layer("RainAndLightning", self, _draw_weather)
	_update_art()


func _layer(layer_name: String, parent: Node, draw_callback: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	layer.draw.connect(draw_callback)
	parent.add_child(layer)
	return layer


func _process(delta: float) -> void:
	if not manual_time:
		animation_time += delta
	_update_art()


func _update_art() -> void:
	if _boat == null:
		return
	var phase := TAU * animation_time / LOOP_SECONDS
	_boat.position = Vector2(229 + sin(phase) * (1.0 + storm * 2.0),
		163 + sin(phase + 0.45) * (1.8 + storm * 3.4)).round()
	_boat.rotation = sin(phase) * (0.022 + storm * 0.05)
	_boat.modulate = Color.WHITE.lerp(Color("65798f"), storm * 0.8)
	_sky.queue_redraw()
	for layer in _cloud_layers + _water_layers:
		layer.queue_redraw()
	_weather.queue_redraw()


func _draw_sky() -> void:
	_sky.draw_texture_rect(SKY, Rect2(0, 0, 320, 180), false)
	_sky.draw_rect(Rect2(0, 0, 320, 180), Color(0.025, 0.055, 0.095, storm * 0.88))


func _draw_clouds(index: int) -> void:
	var layer := _cloud_layers[index]
	var speed := 1.1 if index == 0 else 2.5
	var tint := Color("dcebf1") if index == 0 else Color.WHITE
	tint = tint.lerp(Color("3b485d"), storm)
	for cloud in 3:
		var width := 52.0 if index == 0 else 80.0
		var x := fposmod(cloud * 143.0 + index * 61.0 + animation_time * speed, 430.0) - 85.0
		var y := 21.0 + index * 29.0 + cloud * 8.0
		layer.draw_texture_rect(CLOUD, Rect2(roundf(x), y, width, width * 0.3), false, tint)


func _draw_water(index: int) -> void:
	var layer := _water_layers[index]
	var phase := TAU * animation_time / LOOP_SECONDS
	var surface: float = [125.0, 143.0, 172.0][index]
	var amplitude: float = [0.7, 1.2, 1.8][index] + storm * (index + 1)
	var direction := -1.0 if index == 1 else 1.0
	var points := PackedVector2Array()
	for x in range(-4, 325, 4):
		points.append(Vector2(x, roundf(surface + sin(x * 0.06 + phase * direction + index) * amplitude)))
	points.append(Vector2(324, 184))
	points.append(Vector2(-4, 184))
	var uv := PackedVector2Array()
	var texture_scale: float = [0.55, 0.85, 1.25][index]
	var shift := sin(phase * direction) * (4 + index * 3)
	for point in points:
		uv.append(Vector2((point.x + shift) / (160.0 * texture_scale),
			(point.y - surface + index * 13.0) / (64.0 * texture_scale)))
	var tint: Color = [Color("a3dded"), Color("c2e8ea"), Color("86b6ca")][index]
	tint = tint.lerp(Color("3b566f"), storm * 0.8)
	layer.draw_polygon(points, PackedColorArray([tint]), uv, WATER)
	if index == 2:
		var foam := Color("a5d8d4").lerp(Color("64849a"), storm * 0.7)
		for side in [-1, 1]:
			var p := _boat.position + Vector2(side * 46 - 4, 6)
			layer.draw_line(p.round(), (p + Vector2(11, 1)).round(), foam, 1.0)
			layer.draw_line((p + Vector2(side * 4, 3)).round(), (p + Vector2(side * 4 + 7, 3)).round(), foam, 1.0)


func _draw_weather() -> void:
	if storm > 0.0:
		for index in int(storm * 90):
			var x := fposmod(index * 53.7 - animation_time * (24.0 + storm * 35.0), 320)
			var y := fposmod(index * 37.3 + animation_time * (100.0 + storm * 90.0), 180)
			_weather.draw_line(Vector2(x, y).round(), Vector2(x - 2, y + 6).round(),
				Color(0.58, 0.74, 0.86, storm * 0.6), 1.0)
	if lightning > 0.0:
		_weather.draw_rect(Rect2(0, 0, 320, 180), Color(0.77, 0.87, 1.0, lightning * 0.38))
		_weather.draw_polyline(PackedVector2Array([Vector2(278, 0), Vector2(269, 25),
			Vector2(280, 24), Vector2(262, 52), Vector2(270, 50), Vector2(252, 85)]),
			Color(0.82, 0.93, 1.0, lightning), 1.0)
