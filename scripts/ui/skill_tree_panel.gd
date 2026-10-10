extends ColorRect
## Paused, scrollable three-branch tree; every character has independent progress.

const CATALOG := preload("res://scripts/gameplay/skill_catalog.gd")
var character_id := "breaker"
var _was_paused := false
var _title: Label
var _balance: Label
var _buttons: Dictionary = {}
var _close_button: Button
var _card: Panel
var _paths: HBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	name = "SkillTree"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 30
	color = Color(0.015, 0.04, 0.07, 0.94)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = Panel.new()
	_card.theme = NauticalUI.theme()
	_card.add_theme_stylebox_override("panel", NauticalUI.flat(Color("091c28"), NauticalUI.BRASS))
	add_child(_card)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_card.add_child(_title)
	_balance = Label.new()
	_balance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_balance.add_theme_font_size_override("font_size", 14)
	_card.add_child(_balance)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(scroll)
	var paths := HBoxContainer.new()
	_paths = paths
	paths.name = "Branches"
	paths.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paths.add_theme_constant_override("separation", 12)
	scroll.add_child(paths)
	_close_button = Button.new()
	_close_button.text = "Voltar · Tab / Esc"
	_close_button.custom_minimum_size.y = 40
	_close_button.pressed.connect(close)
	_card.add_child(_close_button)
	get_viewport().size_changed.connect(_layout)
	GameState.progression_changed.connect(_on_progression_changed)
	_layout()
	hide()


func _layout() -> void:
	var screen := get_viewport_rect().size
	_card.size = Vector2(minf(780, screen.x - 24), minf(470, screen.y - 24))
	_card.position = (screen - _card.size) * 0.5
	_title.position = Vector2(16, 12)
	_title.size = Vector2(_card.size.x - 32, 34)
	_balance.position = Vector2(16, 52)
	_balance.size = Vector2(_card.size.x - 32, 44)
	_scroll.position = Vector2(16, 108)
	_scroll.size = Vector2(_card.size.x - 32, _card.size.y - 172)
	_close_button.position = Vector2(16, _card.size.y - 52)
	_close_button.size = Vector2(_card.size.x - 32, 40)


func present(profile: Dictionary) -> void:
	if visible:
		return
	character_id = profile.id
	_title.text = "ÁRVORE · " + String(profile.name)
	_title.add_theme_color_override("font_color", profile.color)
	var paths := _paths
	for child in paths.get_children():
		child.free()
	_buttons.clear()
	for branch in CATALOG.branches(character_id):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		paths.add_child(column)
		var heading := Label.new()
		heading.text = branch.name
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.add_theme_font_size_override("font_size", 14)
		column.add_child(heading)
		for index in branch.nodes.size():
			var skill: Dictionary = branch.nodes[index]
			if index > 0:
				var arrow := Label.new()
				arrow.text = "↓"
				arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				column.add_child(arrow)
			var button := Button.new()
			button.custom_minimum_size.y = 48
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size", 14)
			button.pressed.connect(_learn.bind(skill.id))
			column.add_child(button)
			_buttons[skill.id] = button
			var description := Label.new()
			description.text = skill.description
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			description.add_theme_font_size_override("font_size", 13)
			column.add_child(description)
	_was_paused = get_tree().paused
	get_tree().paused = true
	show()
	_refresh()
	_layout()
	_close_button.grab_focus()


func _refresh() -> void:
	_balance.text = "%d XP disponíveis · O Guardião concede 100 XP. Inimigos comuns recuperam fôlego." % GameState.get_skill_xp(character_id)
	for skill_id in _buttons:
		var skill := CATALOG.find_skill(character_id, skill_id)
		var learned := GameState.has_skill(character_id, skill_id)
		var locked: bool = not skill.requires.is_empty() and not GameState.has_skill(character_id, skill.requires)
		var status: String = "APRENDIDA" if learned else "REQUER " + CATALOG.find_skill(character_id, skill.requires).name if locked else "%d XP" % skill.cost
		_buttons[skill_id].text = skill.name + "\n" + status
		_buttons[skill_id].disabled = not GameState.can_learn_skill(character_id, skill_id)


func _learn(skill_id: String) -> void:
	if visible:
		GameState.learn_skill(character_id, skill_id)


func _on_progression_changed(changed_id: String) -> void:
	if visible and changed_id == character_id:
		_refresh()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = _was_paused
