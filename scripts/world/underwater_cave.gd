extends Node2D

## Dimensões da caverna completa. O valor também alimenta os limites da câmera.
const WORLD_SIZE := Vector2(6900, 3600)

## Barreiras temporárias que organizam o tutorial e o acesso ao mini-chefe.
const TUTORIAL_GATE := Rect2(Vector2(1870, 1180), Vector2(110, 1240))
const BOSS_GATE := Rect2(Vector2(4320, 1360), Vector2(120, 970))

## Contorno navegável único da caverna. As reentrâncias criam três câmaras e dois corredores.
var WALKABLE_POLYGON := PackedVector2Array([
	Vector2(180, 1800),
	Vector2(300, 1150),
	Vector2(850, 650),
	Vector2(1450, 700),
	Vector2(1820, 1050),
	Vector2(1950, 1435),
	Vector2(2300, 1435),
	Vector2(2380, 960),
	Vector2(2860, 500),
	Vector2(3500, 580),
	Vector2(3950, 1000),
	Vector2(4070, 1435),
	Vector2(4680, 1435),
	Vector2(4800, 900),
	Vector2(5400, 450),
	Vector2(6200, 650),
	Vector2(6600, 1250),
	Vector2(6680, 1900),
	Vector2(6500, 2750),
	Vector2(5900, 3180),
	Vector2(5100, 3000),
	Vector2(4750, 2550),
	Vector2(4650, 2245),
	Vector2(4070, 2245),
	Vector2(3950, 2650),
	Vector2(3450, 3150),
	Vector2(2750, 3030),
	Vector2(2300, 2600),
	Vector2(2200, 2245),
	Vector2(1950, 2245),
	Vector2(1800, 2600),
	Vector2(1300, 3020),
	Vector2(700, 2900),
	Vector2(280, 2450),
])

var _tutorial_gate_open := false
var _boss_gate_open := false


## Registra a caverna para consultas de navegação, cria títulos e solicita o desenho inicial.
func _ready() -> void:
	add_to_group("walkable_area")
	_create_zone_label("GRUTA DO DESPERTAR", Vector2(520, 980), Color("70d6d2"))
	_create_zone_label("CÂMARA DOS AFOGADOS", Vector2(2700, 810), Color("7ac9bd"))
	_create_zone_label("FOSSO DO GUARDIÃO", Vector2(5250, 800), Color("c58ad8"))
	queue_redraw()


## Retorna verdadeiro quando o ponto e sua margem permanecem no piso e fora dos portões fechados.
func is_walkable(world_position: Vector2, margin := 26.0) -> bool:
	var samples := [
		world_position,
		world_position + Vector2(margin, 0),
		world_position + Vector2(-margin, 0),
		world_position + Vector2(0, margin),
		world_position + Vector2(0, -margin),
	]
	for sample in samples:
		var local_sample := to_local(sample)
		if not Geometry2D.is_point_in_polygon(local_sample, WALKABLE_POLYGON):
			return false
		if not _tutorial_gate_open and TUTORIAL_GATE.has_point(local_sample):
			return false
		if not _boss_gate_open and BOSS_GATE.has_point(local_sample):
			return false
	return true


## Fornece os limites globais para câmera, projéteis e entidades temporárias.
func get_world_rect() -> Rect2:
	return Rect2(global_position, WORLD_SIZE)


## Libera a passagem ao concluir os dois exercícios do tutorial.
func open_tutorial_gate() -> void:
	if _tutorial_gate_open:
		return
	_tutorial_gate_open = true
	queue_redraw()


## Libera a passagem ao derrotar todos os inimigos da câmara central.
func open_boss_gate() -> void:
	if _boss_gate_open:
		return
	_boss_gate_open = true
	queue_redraw()


## Informa o estado do primeiro portão para HUD e testes automatizados.
func is_tutorial_gate_open() -> bool:
	return _tutorial_gate_open


## Informa o estado do portão do mini-chefe para HUD e testes automatizados.
func is_boss_gate_open() -> bool:
	return _boss_gate_open


## Desenha toda a caverna procedural: água profunda, piso, setores, grade, props e portões.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("030b16"))
	_draw_deep_water_currents()
	draw_colored_polygon(WALKABLE_POLYGON, Color("0b2935"))
	_draw_regions()
	_draw_isometric_tiles()
	_draw_paths()
	_draw_bioluminescence()
	_draw_cave_props()
	_draw_gates()
	var outline := PackedVector2Array(WALKABLE_POLYGON)
	outline.append(WALKABLE_POLYGON[0])
	draw_polyline(outline, Color("315f6d"), 32.0, true)
	draw_polyline(outline, Color("65a6a8"), 6.0, true)


## Cria correntes largas no vazio ao redor do piso para reforçar a sensação subaquática.
func _draw_deep_water_currents() -> void:
	for current_y in [330.0, 920.0, 2720.0, 3330.0]:
		draw_polyline(PackedVector2Array([
			Vector2(100, current_y),
			Vector2(1450, current_y + 80),
			Vector2(2850, current_y - 35),
			Vector2(4300, current_y + 70),
			Vector2(6750, current_y),
		]), Color(0.08, 0.32, 0.42, 0.17), 24.0, true)


## Aplica cores próprias às três zonas para orientar o jogador sem arte final.
func _draw_regions() -> void:
	var tutorial_chamber := PackedVector2Array([
		Vector2(250, 1800), Vector2(380, 1220), Vector2(880, 730),
		Vector2(1430, 780), Vector2(1770, 1100), Vector2(1870, 1450),
		Vector2(1870, 2240), Vector2(1700, 2530), Vector2(1280, 2930),
		Vector2(720, 2810), Vector2(340, 2380),
	])
	var combat_chamber := PackedVector2Array([
		Vector2(1980, 1450), Vector2(2290, 1450), Vector2(2440, 1010),
		Vector2(2880, 570), Vector2(3460, 650), Vector2(3890, 1030),
		Vector2(4050, 1450), Vector2(4300, 1450), Vector2(4300, 2240),
		Vector2(4050, 2240), Vector2(3880, 2600), Vector2(3420, 3050),
		Vector2(2790, 2950), Vector2(2360, 2550), Vector2(2200, 2240),
		Vector2(1980, 2240),
	])
	var boss_chamber := PackedVector2Array([
		Vector2(4460, 1450), Vector2(4680, 1450), Vector2(4860, 960),
		Vector2(5420, 530), Vector2(6140, 720), Vector2(6500, 1290),
		Vector2(6570, 1900), Vector2(6400, 2670), Vector2(5860, 3080),
		Vector2(5160, 2900), Vector2(4820, 2510), Vector2(4650, 2240),
		Vector2(4460, 2240),
	])
	draw_colored_polygon(tutorial_chamber, Color(0.04, 0.28, 0.33, 0.70))
	draw_colored_polygon(combat_chamber, Color(0.07, 0.22, 0.31, 0.78))
	draw_colored_polygon(boss_chamber, Color(0.14, 0.16, 0.29, 0.82))


## Preenche apenas o interior válido com losangos para manter a leitura isométrica.
func _draw_isometric_tiles() -> void:
	for y in range(280, 3360, 48):
		var row := int((y - 280) / 48)
		var shift := 48 if row % 2 else 0
		for x in range(180 + shift, 6760, 96):
			var center := Vector2(x, y)
			var diamond := PackedVector2Array([
				center + Vector2(0, -24),
				center + Vector2(48, 0),
				center + Vector2(0, 24),
				center + Vector2(-48, 0),
				center + Vector2(0, -24),
			])
			if _polygon_points_are_inside(diamond):
				draw_polyline(diamond, Color(0.18, 0.48, 0.50, 0.20), 1.0, true)


## Confirma se todos os pontos fornecidos pertencem ao piso navegável.
func _polygon_points_are_inside(points: PackedVector2Array) -> bool:
	for point in points:
		if not Geometry2D.is_point_in_polygon(point, WALKABLE_POLYGON):
			return false
	return true


## Desenha a trilha que conduz naturalmente do tutorial até a arena final.
func _draw_paths() -> void:
	draw_polyline(PackedVector2Array([
		Vector2(570, 1830), Vector2(1120, 1770), Vector2(1600, 1840),
		Vector2(2150, 1840), Vector2(2750, 1790), Vector2(3380, 1860),
		Vector2(3970, 1830), Vector2(4580, 1840), Vector2(5230, 1800),
		Vector2(5850, 1880), Vector2(6260, 1830),
	]), Color(0.33, 0.67, 0.62, 0.24), 76.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(3000, 1820), Vector2(3180, 1230), Vector2(3500, 900),
	]), Color(0.26, 0.57, 0.59, 0.18), 48.0, true)


## Espalha flora e poças luminosas que marcam caminhos, entradas e bordas de arena.
func _draw_bioluminescence() -> void:
	var glow_points := [
		Vector2(470, 1510), Vector2(760, 2470), Vector2(1320, 1210),
		Vector2(1720, 2050), Vector2(2260, 1740), Vector2(2690, 2520),
		Vector2(3020, 1120), Vector2(3720, 2410), Vector2(4170, 1690),
		Vector2(4700, 2020), Vector2(5150, 1160), Vector2(5510, 2640),
		Vector2(6060, 1190), Vector2(6310, 2280),
	]
	for glow_position in glow_points:
		draw_circle(glow_position, 44.0, Color(0.15, 0.84, 0.73, 0.09))
		draw_circle(glow_position, 19.0, Color(0.28, 0.94, 0.78, 0.28))
		draw_line(glow_position + Vector2(-12, 7), glow_position + Vector2(-18, -24), Color("4fd6b4"), 6.0)
		draw_line(glow_position + Vector2(7, 9), glow_position + Vector2(13, -17), Color("73e3c1"), 5.0)


## Adiciona rochas, colunas atlantes quebradas e bolhas como placeholders de ambientação.
func _draw_cave_props() -> void:
	var rocks := [
		Vector2(520, 1120), Vector2(980, 840), Vector2(1510, 1080),
		Vector2(530, 2580), Vector2(1450, 2700), Vector2(2570, 920),
		Vector2(3350, 850), Vector2(3820, 1220), Vector2(2500, 2680),
		Vector2(3640, 2780), Vector2(4930, 1120), Vector2(5750, 800),
		Vector2(6290, 1370), Vector2(6200, 2550), Vector2(5250, 2760),
	]
	for rock_position in rocks:
		_draw_rock(rock_position)

	var ruins := [
		Vector2(1180, 2200), Vector2(2820, 1380), Vector2(3540, 2320),
		Vector2(5120, 1510), Vector2(5890, 2290),
	]
	for ruin_position in ruins:
		draw_rect(Rect2(ruin_position - Vector2(28, 56), Vector2(56, 112)), Color("263f51"), true)
		draw_rect(Rect2(ruin_position - Vector2(28, 56), Vector2(56, 112)), Color("6b8ea3"), false, 4.0)
		draw_line(ruin_position + Vector2(-22, -18), ruin_position + Vector2(18, -34), Color("3ed0b1"), 4.0)

	for bubble_position in [Vector2(820, 1320), Vector2(1560, 2360), Vector2(3070, 2400), Vector2(4010, 1570), Vector2(5480, 1030), Vector2(6120, 2010)]:
		for index in 3:
			draw_circle(bubble_position + Vector2(index * 16, index * -27), 5.0 + index * 2.0, Color(0.55, 0.89, 0.95, 0.25), false, 2.0)


## Desenha uma formação rochosa irregular a partir de uma posição central.
func _draw_rock(rock_position: Vector2) -> void:
	var rock := PackedVector2Array([
		rock_position + Vector2(-54, 26), rock_position + Vector2(-38, -34),
		rock_position + Vector2(4, -53), rock_position + Vector2(49, -25),
		rock_position + Vector2(61, 22), rock_position + Vector2(12, 44),
	])
	draw_colored_polygon(rock, Color("172f3c"))
	var outline := PackedVector2Array(rock)
	outline.append(rock[0])
	draw_polyline(outline, Color("426574"), 4.0, true)


## Renderiza os portões fechados; quando liberados, deixa somente um arco luminoso no chão.
func _draw_gates() -> void:
	_draw_gate(TUTORIAL_GATE, _tutorial_gate_open, Color("45dbc2"))
	_draw_gate(BOSS_GATE, _boss_gate_open, Color("bd72d6"))


## Desenha uma passagem de coral em estado bloqueado ou liberado.
func _draw_gate(gate_rect: Rect2, is_open: bool, gate_color: Color) -> void:
	var center := gate_rect.get_center()
	if is_open:
		draw_line(Vector2(gate_rect.position.x, center.y), Vector2(gate_rect.end.x, center.y), Color(gate_color, 0.35), 16.0)
		return
	for y in range(int(gate_rect.position.y), int(gate_rect.end.y), 58):
		draw_line(Vector2(gate_rect.position.x + 12, y), Vector2(gate_rect.end.x - 12, y + 28), gate_color, 12.0)
		draw_circle(Vector2(center.x, y + 14), 19.0, Color(gate_color, 0.42))


## Cria um título de área no próprio mundo para tornar a estrutura espacial legível.
func _create_zone_label(label_text: String, label_position: Vector2, label_color: Color) -> void:
	var label := Label.new()
	label.text = label_text
	label.position = label_position
	label.add_theme_color_override("font_color", Color(label_color, 0.70))
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.04, 0.08, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_font_size_override("font_size", 28)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 2
	add_child(label)
