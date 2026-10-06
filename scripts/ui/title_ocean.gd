extends Control
## A fixed 320 x 180 stage; independent water planes surround a shared boat rig.

const CREW_SOURCES := [
	"res://assets/sprites/characters/quebra_mar_source.png",
	"res://assets/sprites/characters/vigia_source.png",
	"res://assets/sprites/characters/mergulhador_source.png",
]
const LOOP_SECONDS := 4.8
var animation_time := 0.0
var manual_time := false
var storm := 0.0
var lightning := 0.0
var _sky: Node2D
var _water_layers: Array[Node2D] = []
var _boat: Node2D
var _crew: Array[Sprite2D] = []
var _weather: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sky = _layer("Sky", self, _draw_sky)
	_water_layers.append(_layer("DistantWater", self, _draw_water.bind(0)))
	_water_layers.append(_layer("MiddleWater", self, _draw_water.bind(1)))
	_boat = Node2D.new()
	_boat.name = "BoatRig"
	add_child(_boat)
	_layer("CabinAndMast", _boat, _draw_cabin)
	for index in CREW_SOURCES.size():
		var sailor := Sprite2D.new()
		sailor.name = ["QuebraMar", "Vigia", "Mergulhador"][index]
		# Use the actual original artwork, including its face, clothes and weapon.
		sailor.texture = PortraitAssets.resolve(CREW_SOURCES[index])
		sailor.scale = Vector2.ONE * 27.0 / sailor.texture.get_height()
		sailor.position = Vector2([-12, 6, 23][index], -10)
		_boat.add_child(sailor)
		_crew.append(sailor)
	_layer("HullAndDeck", _boat, _draw_hull)
	_water_layers.append(_layer("ForegroundWater", self, _draw_water.bind(2)))
	_weather = _layer("RainAndLightning", self, _draw_weather)
	_update_art()


func _layer(layer_name: String, parent: Node, draw_callback: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
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
	# All passengers, cabin and hull share heave and roll, so feet stay on deck.
	_boat.scale = Vector2(2, 2)
	_boat.position = Vector2(160 + sin(phase) * (1.0 + storm * 2.0),
		126 + sin(phase + 0.45) * (2.0 + storm * 4.0)).round()
	_boat.rotation = sin(phase) * (0.025 + storm * 0.075)
	_boat.modulate = Color.WHITE.lerp(Color("8994b0"), storm * 0.65)
	_sky.queue_redraw()
	for layer in _water_layers:
		layer.queue_redraw()
	_weather.queue_redraw()


func _draw_sky() -> void:
	_sky.draw_rect(Rect2(0, 0, 320, 180), Color("70c8e3").lerp(Color("172433"), storm))
	_sky.draw_rect(Rect2(0, 67, 320, 33), Color("a0dbe5").lerp(Color("263343"), storm))
	var sun := Color("f5e8ad").lerp(Color("465266"), storm)
	_sky.draw_rect(Rect2(271, 28, 14, 14), sun)
	_sky.draw_rect(Rect2(268, 31, 20, 8), sun)
	var phase := TAU * animation_time / LOOP_SECONDS
	var shift := roundf(sin(phase) * 2.0)
	var cloud := Color("d4edf0").lerp(Color("364656"), storm)
	for origin in [Vector2(25, 49), Vector2(210, 58), Vector2(93, 71)]:
		var p: Vector2 = origin + Vector2(shift, 0)
		_sky.draw_rect(Rect2(p, Vector2(29, 5)), cloud)
		_sky.draw_rect(Rect2(p + Vector2(5, -4), Vector2(15, 5)), cloud)
	# Just two flat distant islands, no painted texture or atmospheric beams.
	_sky.draw_colored_polygon(PackedVector2Array([Vector2(0, 95), Vector2(0, 89),
		Vector2(12, 89), Vector2(12, 84), Vector2(27, 84), Vector2(27, 91),
		Vector2(42, 91), Vector2(42, 98)]), Color("348da8").lerp(Color("192f3d"), storm))
	_sky.draw_rect(Rect2(284, 92, 36, 7), Color("348da8").lerp(Color("192f3d"), storm))


func _draw_water(index: int) -> void:
	var layer := _water_layers[index]
	var phase := TAU * animation_time / LOOP_SECONDS
	var surface: float = [96.0, 119.0, 146.0][index]
	var amplitude: float = [1.0, 1.5, 2.0][index] + storm * (index + 1)
	var direction := 1.0 if index != 1 else -1.0
	var points := PackedVector2Array()
	for x in range(-4, 325, 4):
		var y := surface + sin(x * 0.065 + phase * direction + index) * amplitude
		points.append(Vector2(x, roundf(y)))
	points.append(Vector2(324, 184))
	points.append(Vector2(-4, 184))
	var color: Color = [Color("328fbf"), Color("2377a9"), Color("175f91")][index]
	layer.draw_colored_polygon(points, color.lerp(Color("102e47"), storm * 0.85))
	# Short pixel bands travel at distinct speeds/depths instead of warping a flat image.
	var foam: Color = [Color("6dcbdc"), Color("46accb"), Color("318cb6")][index]
	foam = foam.lerp(Color("456782"), storm * 0.75)
	for row in 3:
		for band in 6:
			var x := fposmod(band * 59.0 + row * 23 + sin(phase * direction + row) * (4 + index * 3), 320)
			var y := surface + 5 + row * 9 + sin(phase + band * 1.5 + index) * 2
			layer.draw_rect(Rect2(Vector2(x, y).round(), Vector2(9 + (band % 3) * 3, 1)), foam)
	if index == 2:
		# Contact foam follows the rig, while the foreground swell hides its waterline.
		for side in [-1, 1]:
			var p := _boat.position + Vector2(side * 55, 18)
			layer.draw_rect(Rect2(p.round(), Vector2(10, 1)), foam)


func _draw_cabin() -> void:
	var cabin: Node2D = _boat.get_node("CabinAndMast")
	cabin.draw_rect(Rect2(-28, -16, 13, 19), Color("d2b080"))
	cabin.draw_rect(Rect2(-30, -18, 17, 3), Color("333c4a"))
	cabin.draw_rect(Rect2(-25, -13, 7, 7), Color("315b70"))
	cabin.draw_rect(Rect2(-22, -13, 1, 7), Color("ad8a59"))
	cabin.draw_rect(Rect2(-31, -29, 1, 32), Color("544738"))
	cabin.draw_rect(Rect2(-30, -28, 6, 3), Color("b75e4b"))


func _draw_hull() -> void:
	var hull: Node2D = _boat.get_node("HullAndDeck")
	hull.draw_colored_polygon(PackedVector2Array([Vector2(-32, 0), Vector2(32, 0),
		Vector2(29, 6), Vector2(24, 11), Vector2(-23, 11), Vector2(-29, 7)]), Color("182b3e"))
	hull.draw_rect(Rect2(-31, 0, 62, 2), Color("b7915f"))
	hull.draw_colored_polygon(PackedVector2Array([Vector2(-29, 3), Vector2(29, 3),
		Vector2(26, 6), Vector2(-27, 6)]), Color("327e85"))
	hull.draw_rect(Rect2(-23, 9, 47, 1), Color("0e1d30"))
	for x in [-9, 5, 18]:
		hull.draw_rect(Rect2(x, 4, 2, 2), Color("102737"))
	hull.draw_rect(Rect2(-19, -1, 6, 3), Color("80633f"))
	hull.draw_rect(Rect2(-18, -2, 4, 1), Color("c4a276"))


func _draw_weather() -> void:
	if storm > 0.0:
		for index in int(storm * 55):
			var x := fposmod(index * 53.7 - animation_time * (24.0 + storm * 35.0), 320)
			var y := fposmod(index * 37.3 + animation_time * (100.0 + storm * 90.0), 180)
			_weather.draw_line(Vector2(x, y).round(), Vector2(x - 2, y + 6).round(),
				Color(0.58, 0.74, 0.86, storm * 0.55), 1.0)
	if lightning > 0.0:
		_weather.draw_rect(Rect2(0, 0, 320, 180), Color(0.77, 0.87, 1.0, lightning * 0.32))
		_weather.draw_polyline(PackedVector2Array([Vector2(246, 0), Vector2(238, 25),
			Vector2(250, 24), Vector2(234, 52), Vector2(244, 50), Vector2(226, 79)]),
			Color(0.82, 0.93, 1.0, lightning), 1.0)
