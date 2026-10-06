extends Control

@onready var cards: HBoxContainer = %Cards
@onready var hint: Label = %Hint

var _selected_index := 0
var _card_buttons: Array[Button] = []
var _previews: Array[TextureRect] = []


## Monta os cartões, seleciona o primeiro perfil e prepara navegação por teclado.
func _ready() -> void:
	MusicDirector.set_context("cavern")
	theme = NauticalUI.theme()
	_build_cards()
	_update_selection()
	_card_buttons[0].grab_focus()


## Permite alternar entre personagens e confirmar a escolha sem usar o mouse.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_selected_index = wrapi(_selected_index - 1, 0, _card_buttons.size())
		_update_selection()
	elif event.is_action_pressed("ui_right"):
		_selected_index = wrapi(_selected_index + 1, 0, _card_buttons.size())
		_update_selection()
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection(_selected_index)


## Constrói cada cartão diretamente a partir dos perfis centralizados no GameState.
func _build_cards() -> void:
	for index in GameState.CHARACTER_PROFILES.size():
		var profile: Dictionary = GameState.CHARACTER_PROFILES[index]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(240, 310)
		var style := NauticalUI.panel_style()
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 14
		style.content_margin_bottom = 14
		panel.add_theme_stylebox_override("panel", style)

		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 7)
		panel.add_child(column)

		var preview_space := CenterContainer.new()
		preview_space.custom_minimum_size = Vector2(0, 72)
		column.add_child(preview_space)
		var preview := TextureRect.new()
		var portrait_path := String(profile.get("portrait", ""))
		if ResourceLoader.exists(portrait_path):
			preview.texture = load(portrait_path) as Texture2D
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = Vector2(80, 72)
		preview.pivot_offset = preview.custom_minimum_size * 0.5
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_space.add_child(preview)
		_previews.append(preview)

		var name_label := Label.new()
		name_label.text = profile.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 20)
		column.add_child(name_label)

		var role_label := Label.new()
		role_label.text = profile.role
		role_label.custom_minimum_size.y = 20
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.add_theme_color_override("font_color", profile.color)
		role_label.add_theme_font_size_override("font_size", 14)
		column.add_child(role_label)

		var description := Label.new()
		description.text = profile.description
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.custom_minimum_size.y = 72
		description.add_theme_font_size_override("font_size", 13)
		column.add_child(description)
		for kind in ["passive", "skill"]:
			var detail := Label.new()
			detail.text = "%s: %s" % ["Passiva" if kind == "passive" else "Q", profile[kind + "_name"]]
			detail.tooltip_text = profile[kind + "_description"]
			detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			detail.add_theme_font_size_override("font_size", 12)
			detail.add_theme_color_override("font_color", profile.color)
			column.add_child(detail)

		var button := Button.new()
		button.text = "Escolher"
		button.custom_minimum_size.y = 32
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_confirm_selection.bind(index))
		button.focus_entered.connect(_focus_card.bind(index))
		button.mouse_entered.connect(_focus_card.bind(index))
		column.add_child(button)
		_card_buttons.append(button)
		cards.add_child(panel)


## Sincroniza foco ou hover com o índice atualmente selecionado.
func _focus_card(index: int) -> void:
	_selected_index = index
	_update_selection()


## Atualiza textos e escalas para destacar visualmente o cartão ativo.
func _update_selection() -> void:
	for index in _card_buttons.size():
		var selected := index == _selected_index
		_card_buttons[index].text = "Selecionado" if selected else "Escolher"
		_previews[index].scale = Vector2(1.1, 1.1) if selected else Vector2.ONE
	var profile: Dictionary = GameState.CHARACTER_PROFILES[_selected_index]
	hint.text = "Ataque: Espaço / clique  •  Especial: Q / botão direito  •  Enter para jogar"
	hint.tooltip_text = "%s: %s\n%s: %s" % [profile.passive_name, profile.passive_description, profile.skill_name, profile.skill_description]


## Salva o personagem, toca confirmação e abre a área inicial.
func _confirm_selection(index: int) -> void:
	var profile: Dictionary = GameState.CHARACTER_PROFILES[index]
	GameState.select_character(profile.id)
	_play_confirm_animation(_previews[index])
	await get_tree().create_timer(0.18).timeout
	get_tree().change_scene_to_file("res://scenes/narrative/intro_dialogue.tscn")


## Deforma o retângulo selecionado antes da troca de cena.
func _play_confirm_animation(preview: TextureRect) -> void:
	var tween := create_tween()
	tween.tween_property(preview, "scale", Vector2(1.45, 0.75), 0.08)
	tween.tween_property(preview, "scale", Vector2(0.9, 1.25), 0.08)
	tween.tween_property(preview, "scale", Vector2.ONE, 0.06)
