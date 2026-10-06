extends Control

@onready var cards: HBoxContainer = %Cards
var _selected_index := 0
var _card_buttons: Array[Button] = []
var _previews: Array[TextureRect] = []
var _panels: Array[PanelContainer] = []
var _leaving := false


func _ready() -> void:
	MusicDirector.set_context("cavern")
	theme = NauticalUI.theme()
	_build_cards()
	_layout_cards()
	get_viewport().size_changed.connect(_layout_cards)
	_update_selection()
	_card_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or SceneTransition.busy:
		return
	if event.is_action_pressed("ui_left"):
		_selected_index = wrapi(_selected_index - 1, 0, _card_buttons.size())
		_card_buttons[_selected_index].grab_focus()
	elif event.is_action_pressed("ui_right"):
		_selected_index = wrapi(_selected_index + 1, 0, _card_buttons.size())
		_card_buttons[_selected_index].grab_focus()
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection(_selected_index)


func _build_cards() -> void:
	for index in GameState.CHARACTER_PROFILES.size():
		var profile: Dictionary = GameState.CHARACTER_PROFILES[index]
		var panel := PanelContainer.new()
		panel.name = "Card_" + profile.id
		var style := NauticalUI.panel_style()
		style.set_content_margin_all(18)
		panel.add_theme_stylebox_override("panel", style)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		panel.add_child(column)
		var preview := TextureRect.new()
		preview.texture = PortraitAssets.resolve(profile.portrait)
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(preview)
		_previews.append(preview)
		for kind in ["passive", "skill"]:
			var detail := Label.new()
			detail.name = kind.capitalize()
			detail.text = "%s · %s" % ["Passiva" if kind == "passive" else "Q", profile[kind + "_name"]]
			detail.tooltip_text = profile[kind + "_description"]
			detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.add_theme_font_size_override("font_size", 13)
			detail.add_theme_color_override("font_color", profile.color)
			column.add_child(detail)
		var button := Button.new()
		button.name = "Choose"
		button.text = "Escolher"
		button.tooltip_text = profile.name
		button.custom_minimum_size.y = 40
		button.pressed.connect(_confirm_selection.bind(index))
		button.focus_entered.connect(_focus_card.bind(index))
		button.mouse_entered.connect(_focus_card.bind(index))
		column.add_child(button)
		_card_buttons.append(button)
		_panels.append(panel)
		cards.add_child(panel)


func _layout_cards() -> void:
	var screen := get_viewport().get_visible_rect().size
	var width := minf(272.0, (screen.x - 96.0) / 3.0)
	var height := minf(424.0, screen.y - 72.0)
	for index in _panels.size():
		_panels[index].custom_minimum_size = Vector2(width, height)
		_previews[index].custom_minimum_size = Vector2(0, maxf(100.0, height - 156.0))
		_previews[index].pivot_offset = Vector2(width * 0.5, (height - 156.0) * 0.5)


func _focus_card(index: int) -> void:
	if _leaving:
		return
	_selected_index = index
	_update_selection()


func _update_selection() -> void:
	for index in _card_buttons.size():
		var selected := index == _selected_index
		_previews[index].modulate = Color.WHITE if selected else Color(0.80, 0.88, 0.94)
		var accent: Color = GameState.CHARACTER_PROFILES[index].color
		_card_buttons[index].add_theme_stylebox_override("normal", NauticalUI.flat(Color("102b38"), accent if selected else NauticalUI.BRASS))


func _confirm_selection(index: int) -> void:
	if _leaving or SceneTransition.busy:
		return
	_leaving = true
	GameState.select_character(GameState.CHARACTER_PROFILES[index].id)
	for button in _card_buttons:
		button.disabled = true
	SceneTransition.transition_to("res://scenes/narrative/intro_dialogue.tscn")
