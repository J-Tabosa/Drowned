extends Node2D

## Tamanho total do cenário usado também pelos limites da câmera.
const WORLD_SIZE := Vector2(2300, 1400)

## Contorno navegável da enseada. Alterar estes pontos muda o formato da área.
var WALKABLE_POLYGON := PackedVector2Array([
	Vector2(150, 690),
	Vector2(270, 400),
	Vector2(560, 205),
	Vector2(875, 265),
	Vector2(1110, 390),
	Vector2(1435, 215),
	Vector2(1835, 310),
	Vector2(2150, 570),
	Vector2(2180, 850),
	Vector2(1980, 1120),
	Vector2(1600, 1195),
	Vector2(1310, 1060),
	Vector2(1010, 1240),
	Vector2(610, 1165),
	Vector2(280, 990),
])

## Registra a arena para que personagens possam consultar seus limites e pede o primeiro desenho.
func _ready() -> void:
	add_to_group("walkable_area")
	queue_redraw()


## Retorna verdadeiro apenas quando o ponto e sua margem permanecem dentro do contorno navegável.
func is_walkable(world_position: Vector2, margin := 26.0) -> bool:
	var samples := [
		world_position,
		world_position + Vector2(margin, 0),
		world_position + Vector2(-margin, 0),
		world_position + Vector2(0, margin),
		world_position + Vector2(0, -margin),
	]
	for sample in samples:
		if not Geometry2D.is_point_in_polygon(to_local(sample), WALKABLE_POLYGON):
			return false
	return true


## Fornece os limites globais para câmera, projéteis e outras entidades temporárias.
func get_world_rect() -> Rect2:
	return Rect2(global_position, WORLD_SIZE)


## Desenha a água, o piso irregular, setores, grade isométrica e ruínas placeholder.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("06131f"))
	draw_colored_polygon(WALKABLE_POLYGON, Color("102e3b"))
	_draw_regions()
	_draw_isometric_tiles()
	_draw_paths()
	_draw_ruins()
	var outline := PackedVector2Array(WALKABLE_POLYGON)
	outline.append(WALKABLE_POLYGON[0])
	draw_polyline(outline, Color("3c7b83"), 7.0, true)


## Colore suavemente três regiões para orientar a exploração sem depender de arte final.
func _draw_regions() -> void:
	var landing_cove := PackedVector2Array([
		Vector2(180, 680), Vector2(315, 420), Vector2(590, 265),
		Vector2(845, 330), Vector2(850, 875), Vector2(610, 1090), Vector2(310, 930),
	])
	var drowned_ruins := PackedVector2Array([
		Vector2(850, 330), Vector2(1110, 430), Vector2(1435, 275),
		Vector2(1640, 450), Vector2(1570, 970), Vector2(1305, 1010),
		Vector2(1010, 1170), Vector2(850, 875),
	])
	var eastern_basin := PackedVector2Array([
		Vector2(1640, 450), Vector2(1835, 370), Vector2(2090, 585),
		Vector2(2110, 825), Vector2(1930, 1055), Vector2(1570, 970),
	])
	draw_colored_polygon(landing_cove, Color(0.08, 0.25, 0.29, 0.45))
	draw_colored_polygon(drowned_ruins, Color(0.12, 0.22, 0.31, 0.52))
	draw_colored_polygon(eastern_basin, Color(0.08, 0.29, 0.32, 0.48))


## Preenche apenas o interior válido com losangos, criando leitura isométrica sem vazar para a água.
func _draw_isometric_tiles() -> void:
	for y in range(250, 1210, 48):
		var row := int((y - 250) / 48)
		var shift := 48 if row % 2 else 0
		for x in range(190 + shift, 2180, 96):
			var center := Vector2(x, y)
			var diamond := PackedVector2Array([
				center + Vector2(0, -24),
				center + Vector2(48, 0),
				center + Vector2(0, 24),
				center + Vector2(-48, 0),
				center + Vector2(0, -24),
			])
			if _polygon_points_are_inside(diamond):
				draw_polyline(diamond, Color(0.16, 0.40, 0.43, 0.28), 1.0, true)


## Confirma se todos os pontos fornecidos pertencem ao piso navegável.
func _polygon_points_are_inside(points: PackedVector2Array) -> bool:
	for point in points:
		if not Geometry2D.is_point_in_polygon(point, WALKABLE_POLYGON):
			return false
	return true


## Desenha rotas visuais que conectam a enseada, as ruínas centrais e a bacia oriental.
func _draw_paths() -> void:
	draw_polyline(PackedVector2Array([
		Vector2(355, 720), Vector2(690, 670), Vector2(1030, 720),
		Vector2(1350, 650), Vector2(1690, 690), Vector2(1960, 760),
	]), Color(0.32, 0.59, 0.57, 0.34), 42.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(1040, 720), Vector2(1110, 960), Vector2(1010, 1100),
	]), Color(0.32, 0.59, 0.57, 0.28), 34.0, true)


## Adiciona pilares e destroços retangulares que funcionam como referência de escala.
func _draw_ruins() -> void:
	var ruins := [
		Vector2(500, 500), Vector2(730, 890), Vector2(940, 480),
		Vector2(1220, 790), Vector2(1450, 520), Vector2(1740, 910),
		Vector2(1960, 620), Vector2(1160, 1090),
	]
	for ruin_position in ruins:
		draw_rect(Rect2(ruin_position - Vector2(24, 34), Vector2(48, 68)), Color("294957"), true)
		draw_rect(Rect2(ruin_position - Vector2(24, 34), Vector2(48, 68)), Color("6a91a1"), false, 3.0)
