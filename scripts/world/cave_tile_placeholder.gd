extends Node2D

@export_enum("floor", "wall", "gate", "prop") var tile_role := "floor"

@onready var top_shape: Polygon2D = %TopShape
@onready var side_shape: Polygon2D = %SideShape
@onready var accent_shape: Polygon2D = %AccentShape
@onready var glow_shape: Polygon2D = %GlowShape

var gate_id := ""
var _theme_color := Color("4fd6b4")


## Recebe dados do gerador. Cenas artísticas substitutas podem implementar o mesmo método opcional.
func setup(data: Dictionary) -> void:
	var tile_size: Vector2 = data.get("tile_size", Vector2(128, 64))
	var region: String = data.get("region", "cave")
	_theme_color = data.get("theme_color", _region_color(region))
	gate_id = String(data.get("gate_id", ""))
	match tile_role:
		"wall":
			_setup_wall(tile_size)
		"gate":
			_setup_gate(tile_size)
		"prop":
			_setup_prop(tile_size, region)
		_:
			_setup_floor(tile_size, region)


## Abre ou recompõe visualmente um tile de portão.
func set_open(is_open: bool) -> void:
	if tile_role != "gate":
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale:y", 0.08 if is_open else 1.0, 0.32)
	tween.tween_property(self, "modulate:a", 0.22 if is_open else 1.0, 0.24)


## Monta um losango de piso com um detalhe interno fácil de substituir por sprite.
func _setup_floor(tile_size: Vector2, region: String) -> void:
	var half := tile_size * 0.5
	top_shape.polygon = _diamond(half)
	top_shape.color = _region_color(region)
	accent_shape.polygon = _diamond(half * 0.72)
	accent_shape.color = Color(_theme_color, 0.10)
	side_shape.visible = false
	glow_shape.visible = false
	z_index = -5


## Monta uma borda rochosa com topo e face lateral, cada uma ainda sendo um nó separado.
func _setup_wall(tile_size: Vector2) -> void:
	var half := tile_size * 0.5
	top_shape.polygon = _diamond(half)
	top_shape.color = Color("142c38")
	side_shape.visible = true
	side_shape.polygon = PackedVector2Array([
		Vector2(-half.x, 0), Vector2(0, half.y), Vector2(half.x, 0),
		Vector2(half.x, 35), Vector2(0, half.y + 50), Vector2(-half.x, 35),
	])
	side_shape.color = Color("091923")
	accent_shape.polygon = PackedVector2Array([
		Vector2(-half.x * 0.6, -4), Vector2(0, -half.y * 0.72),
		Vector2(half.x * 0.35, -3), Vector2(0, half.y * 0.25),
	])
	accent_shape.color = Color("365564")
	glow_shape.visible = false
	z_index = -2


## Monta uma grade de coral sobre o tile marcado no blueprint.
func _setup_gate(tile_size: Vector2) -> void:
	var half := tile_size * 0.5
	top_shape.polygon = PackedVector2Array([
		Vector2(-half.x * 0.78, 10), Vector2(-half.x * 0.58, -48),
		Vector2(-half.x * 0.4, 8), Vector2(-half.x * 0.15, -66),
		Vector2(0, 8), Vector2(half.x * 0.22, -62),
		Vector2(half.x * 0.4, 8), Vector2(half.x * 0.66, -46),
		Vector2(half.x * 0.78, 10),
	])
	top_shape.color = _theme_color
	side_shape.visible = true
	side_shape.polygon = PackedVector2Array([
		Vector2(-half.x * 0.88, 13), Vector2(0, half.y), Vector2(half.x * 0.88, 13),
		Vector2(0, half.y * 0.25),
	])
	side_shape.color = Color(_theme_color, 0.34)
	accent_shape.visible = false
	glow_shape.visible = true
	glow_shape.polygon = _diamond(half * 0.9)
	glow_shape.color = Color(_theme_color, 0.22)
	z_index = 4


## Monta coral ou flora bioluminescente em um nó independente do piso.
func _setup_prop(tile_size: Vector2, region: String) -> void:
	var half := tile_size * 0.5
	var prop_color := Color("a45bc1") if region == "boss" else Color("62d878")
	top_shape.polygon = PackedVector2Array([
		Vector2(-13, 14), Vector2(-18, -27), Vector2(-8, -12),
		Vector2(-3, -55), Vector2(7, -18), Vector2(21, -39),
		Vector2(14, 15),
	])
	top_shape.color = prop_color
	side_shape.visible = false
	accent_shape.polygon = PackedVector2Array([
		Vector2(-half.x * 0.32, 17), Vector2(0, half.y * 0.78),
		Vector2(half.x * 0.32, 17), Vector2(0, 8),
	])
	accent_shape.color = Color(prop_color, 0.18)
	glow_shape.visible = false
	z_index = 2


## Retorna o losango padrão compartilhado por piso, parede e brilho.
func _diamond(half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -half.y), Vector2(half.x, 0),
		Vector2(0, half.y), Vector2(-half.x, 0),
	])


## Mantém as cores de área centralizadas para que todos os tiles respondam do mesmo modo.
func _region_color(region: String) -> Color:
	match region:
		"spawn":
			return Color("174653")
		"tutorial":
			return Color("18525a")
		"combat":
			return Color("173d4c")
		"boss":
			return Color("322b50")
		"exit":
			return Color("273c52")
		_:
			return Color("143743")
