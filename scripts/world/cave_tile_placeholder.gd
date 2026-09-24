extends Node2D

const PIXEL_ASSET := preload("res://scripts/world/pixel_asset_cache.gd")
const WATER_SHADER := preload("res://shaders/cave_pool_ripple.gdshader")
const FLOOR_TEXTURE := preload("res://assets/sprites/world/cave_floor_pixel32.png")
const PATH_TEXTURE := preload("res://assets/sprites/world/cave_path_pixel32.png")
const WALL_TEXTURE := preload("res://assets/sprites/world/cave_wall_pixel32.png")
const POOL_TEXTURE := preload("res://assets/sprites/world/cave_pool_pixel32.png")
const PROP_ATLAS := preload("res://assets/sprites/world/cave_props_pixel_atlas.png")

@export_enum("floor", "wall", "gate", "prop") var tile_role := "floor"

@onready var top_shape: Polygon2D = %TopShape
@onready var side_shape: Polygon2D = %SideShape
@onready var accent_shape: Polygon2D = %AccentShape
@onready var glow_shape: Polygon2D = %GlowShape

var gate_id := ""
var _theme_color := Color("4fd6b4")
var _collision_shape: CollisionShape2D


func setup(data: Dictionary) -> void:
	var tile_size: Vector2 = data.get("tile_size", Vector2(180, 128))
	var region: String = data.get("region", "cave")
	var cell: Vector2i = data.get("cell", Vector2i.ZERO)
	_theme_color = data.get("theme_color", _region_color(region))
	gate_id = String(data.get("gate_id", ""))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match tile_role:
		"wall":
			_setup_wall(tile_size, cell)
		"gate":
			_setup_gate(tile_size)
		"prop":
			_setup_prop(String(data.get("prop_kind", "algae")))
		_:
			_setup_floor(tile_size, region, cell)


func set_open(is_open: bool) -> void:
	if tile_role != "gate":
		return
	if is_instance_valid(_collision_shape):
		_collision_shape.set_deferred("disabled", is_open)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale:y", 0.08 if is_open else 1.0, 0.32)
	tween.tween_property(self, "modulate:a", 0.0 if is_open else 1.0, 0.28)


func _setup_floor(tile_size: Vector2, region: String, cell: Vector2i) -> void:
	var half := tile_size * 0.5
	var source: Texture2D = FLOOR_TEXTURE
	var base_color := Color("213743")
	if region == "path":
		source = PATH_TEXTURE
		base_color = Color("304653")
	elif region == "pool":
		source = POOL_TEXTURE
		base_color = Color("123f55")
	top_shape.polygon = _diamond(half)
	var logical_size := Vector2i(32, 32) if region == "pool" else Vector2i(16, 16)
	_apply_texture(top_shape, PIXEL_ASSET.pixel_texture(source, logical_size, base_color), cell)
	top_shape.color = _region_color(region)
	if region == "pool":
		var ripple := ShaderMaterial.new()
		ripple.shader = WATER_SHADER
		ripple.set_shader_parameter("phase_offset", float(posmod(cell.x * 7 + cell.y * 11, 13)) * 0.32)
		top_shape.material = ripple
	side_shape.visible = false
	accent_shape.visible = false
	glow_shape.visible = false
	z_index = -5


func _setup_wall(tile_size: Vector2, cell: Vector2i) -> void:
	var half := tile_size * 0.5
	top_shape.polygon = _diamond(half)
	_apply_texture(top_shape, PIXEL_ASSET.pixel_texture(WALL_TEXTURE, Vector2i(32, 32), Color("142936")), cell)
	top_shape.color = Color("657984")
	side_shape.visible = false
	accent_shape.visible = false
	glow_shape.visible = false
	_add_collision(Vector2(78, 48))
	z_index = -2


func _setup_gate(tile_size: Vector2) -> void:
	var half := tile_size * 0.5
	top_shape.polygon = PackedVector2Array([
		Vector2(-half.x * 0.58, 12), Vector2(-half.x * 0.58, -47),
		Vector2(-half.x * 0.39, -50), Vector2(-half.x * 0.39, 12),
		Vector2(-half.x * 0.08, 12), Vector2(-half.x * 0.08, -58),
		Vector2(half.x * 0.08, -58), Vector2(half.x * 0.08, 12),
		Vector2(half.x * 0.39, 12), Vector2(half.x * 0.39, -50),
		Vector2(half.x * 0.58, -47), Vector2(half.x * 0.58, 12),
	])
	top_shape.color = _theme_color.darkened(0.35)
	side_shape.visible = true
	side_shape.polygon = PackedVector2Array([
		Vector2(-half.x * 0.78, 16), Vector2(0, half.y * 0.66),
		Vector2(half.x * 0.78, 16), Vector2(0, half.y * 0.31),
	])
	side_shape.color = Color(_theme_color, 0.24)
	accent_shape.visible = false
	glow_shape.visible = true
	glow_shape.polygon = _diamond(half * 0.88)
	glow_shape.color = Color(_theme_color, 0.12)
	_add_collision(Vector2(76, 54))
	z_index = 4


func _setup_prop(kind: String) -> void:
	top_shape.visible = false
	side_shape.visible = false
	accent_shape.visible = false
	glow_shape.visible = false
	var sprite := Sprite2D.new()
	sprite.name = kind.to_pascal_case()
	sprite.texture = PIXEL_ASSET.pixel_texture(PROP_ATLAS, Vector2i(64, 64))
	sprite.region_enabled = true
	var quadrant := Vector2i.ZERO
	match kind:
		"rock": quadrant = Vector2i(1, 0)
		"coral": quadrant = Vector2i(0, 1)
		"stalagmite": quadrant = Vector2i(1, 1)
	sprite.region_rect = Rect2(quadrant.x * 32, quadrant.y * 32, 32, 32)
	sprite.scale = Vector2(3.4, 3.4) if kind != "rock" else Vector2(3.6, 3.6)
	sprite.position.y = -24.0 if kind == "algae" or kind == "stalagmite" else -7.0
	add_child(sprite)
	if kind == "rock":
		_add_collision(Vector2(74, 50))
	z_index = 2


func _add_collision(size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "WorldCollision"
	body.collision_layer = 16
	body.collision_mask = 0
	add_child(body)
	_collision_shape = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	_collision_shape.shape = rectangle
	body.add_child(_collision_shape)


func _apply_texture(polygon: Polygon2D, texture: Texture2D, cell: Vector2i) -> void:
	var sample_width := float(texture.get_width())
	var sample_height := float(texture.get_height())
	polygon.texture = texture
	var uv := PackedVector2Array([
		Vector2(sample_width * 0.5, 0),
		Vector2(sample_width, sample_height * 0.5),
		Vector2(sample_width * 0.5, sample_height),
		Vector2(0, sample_height * 0.5),
	])
	var variant := posmod(cell.x * 17 + cell.y * 31, 4)
	for index in uv.size():
		var point := uv[index]
		match variant:
			1:
				point.x = sample_width - point.x
			2:
				point.y = sample_height - point.y
			3:
				point = Vector2(point.y, sample_width - point.x)
		uv[index] = point
	polygon.uv = uv


func _diamond(half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -half.y), Vector2(half.x, 0),
		Vector2(0, half.y), Vector2(-half.x, 0),
	])


func _region_color(region: String) -> Color:
	match region:
		"spawn": return Color("9cbac0")
		"path": return Color("d1c1a0")
		"combat": return Color("9ba8b3")
		"boss": return Color("a098b5")
		"exit": return Color("a89582")
		"pool": return Color("8bd1d6")
		"rock": return Color("8ba0a5")
		_: return Color("a3bbc1")
