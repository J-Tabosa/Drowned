extends ColorRect

signal chosen(upgrade: String)
var _buttons: Array[Button] = []
var _title: Label
var _hint: Label

func _ready() -> void:
	name = "RunRewardPanel"
	theme = NauticalUI.theme(Color("83dfbe"))
	NauticalUI.skin(self)
	z_index = 20
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 20
	column.offset_top = 16
	column.offset_right = -20
	column.offset_bottom = -16
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	_title = Label.new()
	_title.text = "ONDA VENCIDA"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	column.add_child(_title)
	_hint = Label.new()
	_hint.text = "Recupere o fôlego. Escolha uma melhoria para esta partida."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 14)
	column.add_child(_hint)
	for index in 2:
		var button := Button.new()
		button.custom_minimum_size.y = 68
		button.add_theme_font_size_override("font_size", 15)
		column.add_child(button)
		_buttons.append(button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	var factor := minf(1.0, minf(viewport_size.x / 480.0, viewport_size.y / 340.0))
	size = Vector2(440, 282)
	scale = Vector2.ONE * factor
	position = (viewport_size - size * factor) * 0.5

func present(wave: int) -> void:
	_title.text = "ONDA %d VENCIDA" % wave
	var upgrades := ["power", "recharge"] if wave == 1 else ["power", "vitality"]
	var text := {
		"power": "Maré Cortante\n+20% de dano em todos os ataques",
		"recharge": "Maré Veloz\nEspecial recarrega 20% mais rápido",
		"vitality": "Fôlego Profundo\n+25% de vida máxima e cura imediata",
	}
	for index in 2:
		for connection in _buttons[index].pressed.get_connections():
			_buttons[index].pressed.disconnect(connection.callable)
		_buttons[index].text = text[upgrades[index]]
		_buttons[index].pressed.connect(_choose.bind(upgrades[index]))
	show()
	_buttons[0].grab_focus()

func _choose(upgrade: String) -> void:
	if not visible or get_tree().paused:
		return
	hide()
	chosen.emit(upgrade)
