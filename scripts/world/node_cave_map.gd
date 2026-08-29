extends Node2D

## Cada caractere abaixo vira um tile-nó. Para redesenhar o mapa, edite apenas este desenho.
## Legenda: s spawn, t tutorial, c combate, b mini-chefe, e saída.
## P jogador, T marco tutorial, C gatilho combate, M inimigos, B chefe, D foco da câmera.
## 1 portão do tutorial, 2 portão do chefe, 3 portão pós-chefe.
const MAP_BLUEPRINT := [
	"",
	"                                          c",
	"                                   ccccccccccccccc",
	"                                ccccccccccccccccccccc",
	"                              ccccccccccccccccccccccccc",
	"                            cccccccccMccccccccccccccccccc",
	"                           ccccccccccccccccccccccccccccccc",
	"                        ttcccccMccccccccccccMcccccccccccccc",
	"                     ttt111ccccccccccccccccccccccccMccccccc",
	"                    ttttttcCccccccccccccccccccccccccccccccc",
	"                  tttttttccccccccccccccccccccccccccccccccccc",
	"                 ttttt    ccccccccccccccccccccccccccccccccc",
	"                tTtt      ccccccccccccccccccccccccccccccccc",
	"               tttt       cccccccMcccccccccccccccMccccccccc",
	"              tttt         ccccccccccccccMcccccccccccccccc",
	"       s     tttt           ccccccccccccccccccccccccccccc",
	"    sssssss tttt              ccccccccccbcccccccccccccc",
	"   sssssssssttt                 cccccccbDbccccccccccc",
	"  sssssssssttt                     ccccbbbcccccccc",
	"  sssssssssst                          bbbc",
	" ssssssPssssss                         222",
	"  sssssssssss                          bbb",
	"  sssssssssss                        bbbbbbb",
	"   sssssssss                       bbbbbbbbbbb",
	"    sssssss                        bbbbbbbbbbb",
	"       s                          bbbbbbBbbbbbb",
	"                                   bbbbbbbbbbb",
	"                                   bbbbbbbbbbb",
	"                                     bbbebbb",
	"                                       eee",
	"                                       333",
	"                                       eee",
	"                                       eEe",
	"                                        e",
]

const TILE_SIZE := Vector2(180, 128)
const TILE_STEP := Vector2(96, 64)
const MAP_ORIGIN := Vector2(256, 192)

@export var floor_tile_scene: PackedScene = preload("res://scenes/world/tiles/cave_floor_tile.tscn")
@export var wall_tile_scene: PackedScene = preload("res://scenes/world/tiles/cave_wall_tile.tscn")
@export var gate_tile_scene: PackedScene = preload("res://scenes/world/tiles/cave_gate_tile.tscn")
@export var prop_tile_scene: PackedScene = preload("res://scenes/world/tiles/cave_prop_tile.tscn")

@onready var background: ColorRect = %Background
@onready var floor_tiles: Node2D = %FloorTiles
@onready var wall_tiles: Node2D = %WallTiles
@onready var gate_tiles: Node2D = %GateTiles
@onready var props: Node2D = %Props
@onready var markers: Node2D = %Markers

var _floor_cells: Dictionary = {}
var _anchors: Dictionary = {}
var _mob_anchors: Array[Vector2] = []
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


## Constrói o mapa inteiro como nós editáveis a partir do blueprint e registra seus marcadores.
func _ready() -> void:
	add_to_group("walkable_area")
	_build_floor_and_anchors()
	_build_boundary_walls()
	_world_rect = Rect2(Vector2.ZERO, Vector2(_max_columns * TILE_STEP.x + 512, MAP_BLUEPRINT.size() * TILE_STEP.y + 384))
	background.position = _world_rect.position
	background.size = _world_rect.size


## Instancia um nó de piso para cada caractere e converte letras especiais em marcadores nomeados.
func _build_floor_and_anchors() -> void:
	var mob_index := 0
	for row_index in MAP_BLUEPRINT.size():
		var row_text: String = MAP_BLUEPRINT[row_index]
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
			})
			if _should_spawn_prop(cell, symbol):
				_spawn_tile(prop_tile_scene, props, cell, "Prop", {
					"tile_size": TILE_SIZE,
					"region": region,
				})
			if symbol == "M":
				var mob_position := _cell_to_local(cell)
				_mob_anchors.append(mob_position)
				_register_anchor("mob_spawn_%d" % mob_index, mob_position)
				mob_index += 1
			elif symbol == "P":
				_register_anchor("player_spawn", _cell_to_local(cell))
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
	})
	_gate_nodes[gate_id].append(gate_node)


## Registra um Marker2D visível na árvore e guarda sua posição para o diretor da fase.
func _register_anchor(anchor_name: String, local_anchor_position: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = anchor_name.to_pascal_case()
	marker.position = local_anchor_position
	markers.add_child(marker)
	_anchors[anchor_name] = local_anchor_position


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


## Localiza o losango sob um ponto e rejeita especificamente tiles de portões fechados.
func _is_point_on_open_floor(local_point: Vector2) -> bool:
	var guessed_row := roundi((local_point.y - MAP_ORIGIN.y) / TILE_STEP.y)
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
			if diamond_distance <= 1.03:
				var symbol: String = _floor_cells[cell]
				var gate_id := _gate_id_for_symbol(symbol)
				return gate_id.is_empty() or bool(_gate_open[gate_id])
	return false


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


## Expõe contagens do mapa para testes e ferramentas do editor.
func get_tile_counts() -> Dictionary:
	return {
		"floor": floor_tiles.get_child_count(),
		"wall": wall_tiles.get_child_count(),
		"gate": gate_tiles.get_child_count(),
		"props": props.get_child_count(),
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


## Define a paleta de cada caractere semântico do blueprint.
func _region_for_symbol(symbol: String) -> String:
	if symbol in ["s", "P"]:
		return "spawn"
	if symbol in ["t", "T", "1"]:
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
	if symbol in ["P", "T", "C", "M", "D", "B", "E", "1", "2", "3"]:
		return false
	return absi(cell.x * 31 + cell.y * 17) % 19 == 0
