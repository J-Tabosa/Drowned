extends ColorRect

signal teleport_requested(world_position: Vector2)
var map_view: Control
var _card: Panel
var _title: Label
var _hint: Label
var _close: Button
var _fit: Button
var _was_paused := false
var _refresh_wait := 0.0


func _ready() -> void:
	name = "ExpeditionMap"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 25
	color = Color(0.015, 0.035, 0.05, 0.96)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = Panel.new()
	_card.theme = NauticalUI.theme()
	_card.add_theme_stylebox_override("panel", NauticalUI.flat(Color("091c28"), NauticalUI.BRASS))
	add_child(_card)
	_title = Label.new()
	_title.text = "CARTA DA GRUTA"
	_title.add_theme_font_size_override("font_size", 22)
	_card.add_child(_title)
	map_view = preload("res://scripts/ui/expedition_map_view.gd").new()
	_card.add_child(map_view)
	map_view.destination_clicked.connect(func(point: Vector2): teleport_requested.emit(point))
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_hint)
	_close = Button.new()
	_close.text = "Voltar · M / Esc"
	_close.pressed.connect(close)
	_card.add_child(_close)
	_fit = Button.new()
	_fit.text = "Ver tudo"
	_fit.pressed.connect(map_view.reset_view)
	_card.add_child(_fit)
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()


func setup(arena: Node2D, exploration: Node, player: Node2D) -> void:
	map_view.arena = arena
	map_view.exploration = exploration
	map_view.player = player
	exploration.changed.connect(map_view.queue_redraw)


func _layout() -> void:
	var screen := get_viewport_rect().size
	_card.size = screen - Vector2(24, 24)
	_card.position = Vector2(12, 12)
	_title.position = Vector2(16, 12)
	_title.size = Vector2(_card.size.x - 32, 32)
	map_view.position = Vector2(16, 52)
	map_view.size = Vector2(_card.size.x - 32, _card.size.y - 160)
	map_view.queue_redraw()
	_hint.position = Vector2(16, _card.size.y - 102)
	_hint.size = Vector2(_card.size.x - 32, 44)
	_fit.position = Vector2(16, _card.size.y - 50)
	_fit.size = Vector2(120, 34)
	_close.position = Vector2(_card.size.x - 200, _card.size.y - 50)
	_close.size = Vector2(184, 34)


func present(teleport := false) -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	map_view.teleport_mode = teleport
	map_view._dragging = false
	map_view.mouse_default_cursor_shape = Control.CURSOR_CROSS if teleport else Control.CURSOR_MOVE
	_title.text = "TELEPORTE · CLIQUE NO CHÃO" if teleport else "CARTA DA GRUTA"
	set_status("")
	_layout()
	show()
	map_view.queue_redraw()
	_close.grab_focus()


func set_status(message: String) -> void:
	_hint.text = message if not message.is_empty() else ("Clique: teleportar · Botão direito: arrastar · Roda: zoom" if map_view.teleport_mode else "Claro: explorado · Escuro: desconhecido · Turquesa: trajeto / você · Dourado: chave · Laranja: portão\nArraste para mover · Roda: zoom")


func close() -> void:
	if not visible: return
	hide()
	map_view.teleport_mode = false
	get_tree().paused = _was_paused


func _process(delta: float) -> void:
	if not visible: return
	_refresh_wait -= delta
	if _refresh_wait <= 0:
		_refresh_wait = 0.2
		map_view.queue_redraw()
