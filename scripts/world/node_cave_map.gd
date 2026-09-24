extends Node2D
## O layout autoral fica na cena e pode ser editado pelo Inspector.
## Cada caractere do layout vira um tile-nó.
## Legenda: s origem, p trilha, c combate, b arena, e saída, ~ lagoa, r rocha, a alga, I relíquia.
## P jogador, T marco tutorial, L eco narrativo, C gatilho combate, M inimigos, B chefe, D foco da câmera.
## 1 portão do tutorial, 2 portão do chefe, 3 portão pós-chefe.

const TILE_SIZE := Vector2(180, 128)
const TILE_STEP := Vector2(96, 64)
const MAP_ORIGIN := Vector2(256, 192)
const ITEM_SCENE := preload("res://scenes/world/items/cave_collectible.tscn")
const PIXEL_ASSET := preload("res://scripts/world/pixel_asset_cache.gd")
const EXIT_GATE_TEXTURE := preload("res://assets/sprites/world/orange_iron_gate_pixel.png")

@export var floor_tile_scene: PackedScene = preload("res://scenes/world/tiles/cave_floor_tile.tscn")
@export var wall_tile_scene: PackedScene = preload("res://scenes/world/tiles/cave_wall_tile.tscn")
@export var gate_tile_scene: PackedScene = preload("res://scenes/world/tiles/cave_gate_tile.tscn")
@export var prop_tile_scene: PackedScene = preload("res://scenes/world/tiles/cave_prop_tile.tscn")
@export_multiline var map_layout := ""

@onready var background: ColorRect = %Background
@onready var floor_tiles: Node2D = %FloorTiles
@onready var wall_tiles: Node2D = %WallTiles
@onready var gate_tiles: Node2D = %GateTiles
@onready var props: Node2D = %Props
@onready var markers: Node2D = %Markers
@onready var items: Node2D = %Items
@onready var lights: Node2D = %Lights

var _floor_cells: Dictionary = {}
var _anchors: Dictionary = {}
var _mob_anchors: Array[Vector2] = []
var _story_echo_anchors: Array[Vector2] = []
var _story_echo_nodes: Array[Polygon2D] = []
var _item_anchors: Array[Vector2] = []
var _items_collected := 0
var _exit_gate_art: Sprite2D
var _light_texture: Texture2D
var _gate_nodes: Dictionary = {
	"tutorial": [],
	"boss": [],
	"post_boss": [],
}
var _gate_open := {
	"tutorial": false,
	"boss": false,
	"post_boss": false,
}
var _world_rect := Rect2()
var _max_columns := 0
var _map_rows: Array = []

signal item_collected(collected: int, total: int)


## Constrói o mapa inteiro como nós editáveis a partir do blueprint e registra seus marcadores.
func _ready() -> void:
	add_to_group("walkable_area")
	_map_rows = _get_map_rows()
	_build_floor_and_anchors()
	_story_echo_anchors.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	_story_echo_nodes.sort_custom(func(a: Polygon2D, b: Polygon2D) -> bool: return a.position.x < b.position.x)
	for echo_index in _story_echo_nodes.size():
		_story_echo_nodes[echo_index].visible = echo_index == 0
	_build_boundary_walls()
	_build_exit_gate_art()
	_world_rect = Rect2(Vector2.ZERO, Vector2(_max_columns * TILE_STEP.x + 512, _map_rows.size() * TILE_STEP.y + 384))
	background.position = _world_rect.position
	background.size = _world_rect.size


## O layout salvo na cena é a única fonte da planta, sem geração procedural.
func _get_map_rows() -> Array:
	if map_layout.strip_edges().is_empty():
		push_error("UnderwaterCave requer map_layout na cena.")
		return []
	var rows: Array = []
	for row in map_layout.split("\n", true):
		rows.append(row)
	return rows


## Instancia um nó de piso para cada caractere e converte letras especiais em marcadores nomeados.
func _build_floor_and_anchors() -> void:
	var mob_index := 0
	for row_index in _map_rows.size():
		var row_text: String = _map_rows[row_index]
		_max_columns = maxi(_max_columns, row_text.length())
		for column_index in row_text.length():
			var symbol := row_text.substr(column_index, 1)
			if symbol == " ":
				continue
			var cell := Vector2i(column_index, row_index)
			_floor_cells[cell] = symbol
			var region := _region_for_symbol(symbol)
			_spawn_tile(floor_tile_scene, floor_tiles, cell, "Floor", {
				"tile_size": TILE_SIZE,
				"region": region,
				"cell": cell,
			})
			if _should_spawn_prop(cell, symbol):
				_spawn_tile(prop_tile_scene, props, cell, "Prop", {
					"tile_size": TILE_SIZE,
					"region": region,
					"cell": cell,
					"prop_kind": _prop_kind_for_symbol(cell, symbol),
				})
			if symbol == "I":
				_spawn_item(cell)
				_spawn_light(cell, Color("d7ac68"), 0.85)
			elif symbol == "a":
				_spawn_light(cell, Color("52d7c2"), 0.58)
			elif symbol == "~" and cell.x % 2 == 0:
				_spawn_light(cell, Color("4ab0df"), 0.36)
			if symbol == "M":
				var mob_position := _cell_to_local(cell)
				_mob_anchors.append(mob_position)
				_register_anchor("mob_spawn_%d" % mob_index, mob_position)
				mob_index += 1
			elif symbol == "P":
				_register_anchor("player_spawn", _cell_to_local(cell))
			elif symbol == "L":
				var echo_position := _cell_to_local(cell)
				_story_echo_anchors.append(echo_position)
				_story_echo_nodes.append(_spawn_story_echo(echo_position))
			elif symbol == "T":
				_register_anchor("tutorial_focus", _cell_to_local(cell))
			elif symbol == "C":
				_register_anchor("combat_trigger", _cell_to_local(cell))
			elif symbol == "D":
				_register_anchor("boss_reveal_focus", _cell_to_local(cell))
			elif symbol == "B":
				_register_anchor("boss_spawn", _cell_to_local(cell))
			elif symbol == "E":
				_register_anchor("post_boss_exit", _cell_to_local(cell))
			elif symbol in ["1", "2", "3"]:
				_spawn_gate(cell, symbol)


## Detecta células vazias adjacentes e coloca nelas paredes como nós, sem desenhar polígonos globais.
func _build_boundary_walls() -> void:
	var boundary_cells: Dictionary = {}
	for cell_value in _floor_cells:
		var cell: Vector2i = cell_value
		for neighbour in _neighbours(cell):
			if not _floor_cells.has(neighbour):
				boundary_cells[neighbour] = true
	for cell_value in boundary_cells:
		_spawn_tile(wall_tile_scene, wall_tiles, cell_value, "Wall", {
			"tile_size": TILE_SIZE,
			"region": "wall",
			"cell": cell_value,
		})


## Centraliza a instanciação para permitir substituir qualquer cena de tile pelo Inspector.
func _spawn_tile(scene: PackedScene, parent: Node2D, cell: Vector2i, prefix: String, data: Dictionary) -> Node2D:
	if scene == null:
		return null
	var tile := scene.instantiate() as Node2D
	parent.add_child(tile)
	tile.name = "%s_%02d_%02d" % [prefix, cell.y, cell.x]
	tile.position = _cell_to_local(cell)
	if tile.has_method("setup"):
		tile.setup(data)
	return tile


## Adiciona o nó visual do portão e agrupa suas células sob um identificador semântico.
func _spawn_gate(cell: Vector2i, symbol: String) -> void:
	var gate_id := _gate_id_for_symbol(symbol)
	var gate_color := Color("4fd6b4")
	if gate_id == "boss":
		gate_color = Color("b66bd1")
	elif gate_id == "post_boss":
		gate_color = Color("ef8c42")
	var gate_node := _spawn_tile(gate_tile_scene, gate_tiles, cell, "Gate", {
		"tile_size": TILE_SIZE,
		"region": _region_for_symbol(symbol),
		"gate_id": gate_id,
		"theme_color": gate_color,
		"cell": cell,
	})
	_gate_nodes[gate_id].append(gate_node)


func _build_exit_gate_art() -> void:
	var gate_cells: Array = _gate_nodes.post_boss
	if gate_cells.is_empty():
		return
	var center := Vector2.ZERO
	for gate_tile in gate_cells:
		center += gate_tile.position
	center /= float(gate_cells.size())
	_exit_gate_art = Sprite2D.new()
	_exit_gate_art.name = "OrangeIronGate"
	_exit_gate_art.texture = PIXEL_ASSET.pixel_texture(EXIT_GATE_TEXTURE, Vector2i(96, 64))
	_exit_gate_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_exit_gate_art.position = center + Vector2(0, -77)
	_exit_gate_art.scale = Vector2(6.4, 4.8)
	_exit_gate_art.z_index = 5
	gate_tiles.add_child(_exit_gate_art)
	_spawn_light(Vector2i(105, 34), Color("ec853e"), 0.75)


func _spawn_item(cell: Vector2i) -> void:
	var item := ITEM_SCENE.instantiate() as Area2D
	item.name = "CompassRelic_%02d_%02d" % [cell.y, cell.x]
	item.position = _cell_to_local(cell)
	items.add_child(item)
	_item_anchors.append(item.position)
	item.picked_up.connect(_on_item_picked)


func _on_item_picked() -> void:
	_items_collected += 1
	item_collected.emit(_items_collected, _item_anchors.size())


func _spawn_light(cell: Vector2i, tint: Color, strength: float) -> void:
	if _light_texture == null:
		_light_texture = _make_light_texture()
	var light := PointLight2D.new()
	light.name = "Bioluminescence_%02d_%02d" % [cell.y, cell.x]
	light.position = _cell_to_local(cell) + Vector2(0, -18)
	light.texture = _light_texture
	light.texture_scale = 3.2
	light.color = tint
	light.energy = strength
	lights.add_child(light)


func _make_light_texture() -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var distance := Vector2(float(x) - 63.5, float(y) - 63.5).length() / 63.5
			var alpha := pow(maxf(0.0, 1.0 - distance), 2.3)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


## Registra um Marker2D visível na árvore e guarda sua posição para o diretor da fase.
func _register_anchor(anchor_name: String, local_anchor_position: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = anchor_name.to_pascal_case()
	marker.position = local_anchor_position
	markers.add_child(marker)
	_anchors[anchor_name] = local_anchor_position


## Desenha um pequeno losango luminoso para os pontos narrativos do prólogo.
func _spawn_story_echo(local_echo_position: Vector2) -> Polygon2D:
	var echo := Polygon2D.new()
	echo.name = "StoryEcho"
	echo.position = local_echo_position
	echo.z_index = 4
	echo.color = Color(0.28, 0.94, 0.78, 0.82)
	echo.polygon = PackedVector2Array([
		Vector2(0, -28), Vector2(24, 0), Vector2(0, 28), Vector2(-24, 0),
	])
	markers.add_child(echo)
	var pulse := echo.create_tween().set_loops()
	pulse.tween_property(echo, "scale", Vector2(1.22, 1.22), 0.65).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(echo, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_SINE)
	echo.set_meta("pulse_tween", pulse)
	return echo


## Converte coluna e linha do blueprint em posição visual de grade isométrica escalonada.
func _cell_to_local(cell: Vector2i) -> Vector2:
	var row_shift := TILE_STEP.x * 0.5 if cell.y % 2 != 0 else 0.0
	return MAP_ORIGIN + Vector2(cell.x * TILE_STEP.x + row_shift, cell.y * TILE_STEP.y)


## Retorna as seis células que compartilham lados no arranjo escalonado.
func _neighbours(cell: Vector2i) -> Array[Vector2i]:
	var diagonal_offset := -1 if cell.y % 2 == 0 else 1
	return [
		cell + Vector2i(-1, 0),
		cell + Vector2i(1, 0),
		cell + Vector2i(0, -1),
		cell + Vector2i(diagonal_offset, -1),
		cell + Vector2i(0, 1),
		cell + Vector2i(diagonal_offset, 1),
	]


## Testa o ator e sua margem em vários pontos contra os tiles navegáveis e portões.
func is_walkable(world_position: Vector2, margin := 26.0) -> bool:
	var local_point := to_local(world_position)
	for sample_offset in [
		Vector2.ZERO,
		Vector2(margin, 0), Vector2(-margin, 0),
		Vector2(0, margin), Vector2(0, -margin),
	]:
		if not _is_point_on_open_floor(local_point + sample_offset):
			return false
	return true


## Percorre o trajeto em passos curtos e para antes da primeira parede ou portão fechado.
func get_farthest_walkable_position(from_world: Vector2, to_world: Vector2, margin := 26.0) -> Vector2:
	var distance := from_world.distance_to(to_world)
	if distance <= 0.01:
		return from_world
	var direction := (to_world - from_world) / distance
	var last_walkable := from_world
	for step in range(12, ceili(distance) + 12, 12):
		var candidate := from_world + direction * minf(float(step), distance)
		if not is_walkable(candidate, margin):
			break
		last_walkable = candidate
	return last_walkable


## Localiza o losango sob um ponto e rejeita especificamente tiles de portões fechados.
func _is_point_on_open_floor(local_point: Vector2) -> bool:
	var guessed_row := roundi((local_point.y - MAP_ORIGIN.y) / TILE_STEP.y)
	var nearest_symbol := ""
	var nearest_distance := INF
	for row_index in range(guessed_row - 1, guessed_row + 2):
		var shift := TILE_STEP.x * 0.5 if row_index % 2 != 0 else 0.0
		var guessed_column := roundi((local_point.x - MAP_ORIGIN.x - shift) / TILE_STEP.x)
		for column_index in range(guessed_column - 1, guessed_column + 2):
			var cell := Vector2i(column_index, row_index)
			if not _floor_cells.has(cell):
				continue
			var center := _cell_to_local(cell)
			var diamond_distance := absf(local_point.x - center.x) / (TILE_SIZE.x * 0.5)
			diamond_distance += absf(local_point.y - center.y) / (TILE_SIZE.y * 0.5)
			if diamond_distance <= 1.03 and diamond_distance < nearest_distance:
				nearest_distance = diamond_distance
				nearest_symbol = _floor_cells[cell]
	if nearest_symbol.is_empty() or nearest_symbol in ["~", "r"]:
		return false
	var gate_id := _gate_id_for_symbol(nearest_symbol)
	return gate_id.is_empty() or bool(_gate_open[gate_id])


## Fornece limites calculados do blueprint para câmera e projéteis.
func get_world_rect() -> Rect2:
	return Rect2(global_position + _world_rect.position, _world_rect.size)


## Devolve um marcador global pelo nome; não há coordenadas duplicadas no diretor da fase.
func get_anchor_position(anchor_name: String) -> Vector2:
	return to_global(_anchors.get(anchor_name, Vector2.ZERO))


## Devolve todos os pontos de inimigo definidos com M no blueprint.
func get_mob_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for local_position in _mob_anchors:
		positions.append(to_global(local_position))
	return positions


func get_item_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for local_position in _item_anchors:
		positions.append(to_global(local_position))
	return positions


func get_collected_item_count() -> int:
	return _items_collected


## Retorna os ecos do prólogo na ordem natural de exploração, do naufrágio à câmara.
func get_story_echo_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for local_position in _story_echo_anchors:
		positions.append(to_global(local_position))
	return positions


## Apaga o brilho já investigado para deixar claro qual é o próximo destino.
func complete_story_echo(index: int) -> void:
	if index < 0 or index >= _story_echo_nodes.size():
		return
	var echo := _story_echo_nodes[index]
	if not is_instance_valid(echo):
		return
	var pulse_tween: Tween = echo.get_meta("pulse_tween") as Tween
	if pulse_tween:
		pulse_tween.kill()
	var fade := echo.create_tween().set_parallel(true)
	fade.tween_property(echo, "scale", Vector2(1.7, 1.7), 0.24)
	fade.tween_property(echo, "modulate:a", 0.0, 0.24)
	fade.chain().tween_callback(echo.queue_free)
	var next_index := index + 1
	if next_index < _story_echo_nodes.size():
		var next_echo := _story_echo_nodes[next_index]
		next_echo.modulate.a = 0.0
		next_echo.visible = true
		next_echo.create_tween().tween_property(next_echo, "modulate:a", 1.0, 0.28)


## Expõe contagens do mapa para testes e ferramentas do editor.
func get_tile_counts() -> Dictionary:
	return {
		"floor": floor_tiles.get_child_count(),
		"wall": wall_tiles.get_child_count(),
		"gate": _gate_nodes.tutorial.size() + _gate_nodes.boss.size() + _gate_nodes.post_boss.size(),
		"props": props.get_child_count(),
		"items": items.get_child_count(),
	}


## Libera a saída do tutorial.
func open_tutorial_gate() -> void:
	_set_gate_open("tutorial", true)


## Libera a entrada da arena do mini-chefe.
func open_boss_gate() -> void:
	_set_gate_open("boss", true)


## Libera o portão laranja abaixo do mini-chefe após a vitória.
func open_post_boss_gate() -> void:
	_set_gate_open("post_boss", true)


## Informa estados de portões para HUD e testes.
func is_tutorial_gate_open() -> bool:
	return bool(_gate_open.tutorial)


func is_boss_gate_open() -> bool:
	return bool(_gate_open.boss)


func is_post_boss_gate_open() -> bool:
	return bool(_gate_open.post_boss)


## Sincroniza lógica e animação de todos os tiles que formam um portão.
func _set_gate_open(gate_id: String, is_open: bool) -> void:
	if bool(_gate_open.get(gate_id, false)) == is_open:
		return
	_gate_open[gate_id] = is_open
	for gate_node in _gate_nodes.get(gate_id, []):
		if is_instance_valid(gate_node) and gate_node.has_method("set_open"):
			gate_node.set_open(is_open)
	if gate_id == "post_boss" and is_instance_valid(_exit_gate_art):
		var gate_tween := create_tween().set_parallel(true)
		gate_tween.tween_property(_exit_gate_art, "modulate:a", 0.0 if is_open else 1.0, 0.4)
		gate_tween.tween_property(_exit_gate_art, "scale:y", 0.04 if is_open else 4.8, 0.4)


## Define a paleta de cada caractere semântico do blueprint.
func _region_for_symbol(symbol: String) -> String:
	if symbol == "p":
		return "path"
	if symbol == "~":
		return "pool"
	if symbol == "r":
		return "rock"
	if symbol in ["s", "P", "L"]:
		return "spawn"
	if symbol in ["T", "1"]:
		return "tutorial"
	if symbol in ["c", "C", "M"]:
		return "combat"
	if symbol in ["b", "B", "D", "2"]:
		return "boss"
	if symbol in ["e", "E", "3"]:
		return "exit"
	return "cave"


## Traduz os números desenhados no blueprint para identificadores usados pelo jogo.
func _gate_id_for_symbol(symbol: String) -> String:
	match symbol:
		"1":
			return "tutorial"
		"2":
			return "boss"
		"3":
			return "post_boss"
		_:
			return ""


## Espalha props de forma determinística sem exigir posições manuais.
func _should_spawn_prop(cell: Vector2i, symbol: String) -> bool:
	if symbol in ["a", "r"]:
		return true
	if symbol in ["P", "T", "L", "C", "M", "D", "B", "E", "I", "~", "1", "2", "3"]:
		return false
	return absi(cell.x * 31 + cell.y * 17) % 23 == 0


func _prop_kind_for_symbol(cell: Vector2i, symbol: String) -> String:
	if symbol == "a":
		return "algae"
	if symbol == "r":
		return "rock"
	match absi(cell.x * 13 + cell.y * 29) % 4:
		0: return "algae"
		1: return "rock"
		2: return "coral"
		_: return "stalagmite"
