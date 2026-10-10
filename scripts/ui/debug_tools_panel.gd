extends ColorRect

signal tree_requested
signal restore_requested
signal teleport_requested
signal reveal_requested
var _was_paused := false
var _card: Panel
var _column: VBoxContainer


func _ready() -> void:
	name = "DebugTools"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 20
	color = Color(0.01, 0.025, 0.045, 0.94)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = Panel.new()
	_card.theme = NauticalUI.theme(Color("83dfbe"))
	_card.add_theme_stylebox_override("panel", NauticalUI.flat(Color("091c28"), NauticalUI.BRASS))
	add_child(_card)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16
	scroll.offset_top = 16
	scroll.offset_right = -16
	scroll.offset_bottom = -16
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 10)
	scroll.add_child(_column)
	var title := Label.new()
	title.text = "DEBUG · Ctrl + H + J"
	title.add_theme_font_size_override("font_size", 20)
	_column.add_child(title)
	var info := Label.new()
	info.text = "Testes de habilidades usam um progresso temporário.\nFechar este painel mantém o teste até restaurar ou sair da fase."
	info.add_theme_font_size_override("font_size", 12)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(info)
	_button("1 · Testar árvore (+1000 XP)", func(): tree_requested.emit())
	_button("Restaurar progresso real", func(): restore_requested.emit())
	_button("2 · Teleportar pelo mapa", func(): teleport_requested.emit())
	_button("3 · Alternar mapa revelado", func(): reveal_requested.emit())
	_button("Fechar · Esc", close)
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()


func _button(caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	_column.add_child(button)


func _layout() -> void:
	var screen := get_viewport_rect().size
	_card.size = Vector2(minf(460, screen.x - 24), minf(430, screen.y - 24))
	_card.position = (screen - _card.size) * 0.5


func present() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	show()


func close() -> void:
	if not visible: return
	hide()
	get_tree().paused = _was_paused
