class_name NauticalUI
extends RefCounted

const INK := Color("081c2a")
const PAPER := Color("f0e4c6")
const BRASS := Color("bc965b")
const PANEL_PATH := "res://assets/ui/nautical_panel.png"

static func panel_style() -> StyleBox:
	if ResourceLoader.exists(PANEL_PATH):
		var style := StyleBoxTexture.new()
		var source: Texture2D = load(PANEL_PATH)
		var pixels := source.get_image()
		pixels.resize(256, 144, Image.INTERPOLATE_NEAREST)
		style.texture = ImageTexture.create_from_image(pixels)
		var edge := 15.0
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_texture_margin(side, edge)
			style.set_content_margin(side, 18)
		return style
	return flat(INK, BRASS)

static func flat(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	return style

static func theme(accent: Color = Color("42c6d7")) -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	for type in ["Label", "Button", "OptionButton", "CheckButton"]:
		result.set_color("font_color", type, PAPER)
	for type in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, flat(INK, BRASS))
		result.set_stylebox("hover", type, flat(Color("193b49"), accent))
		result.set_stylebox("pressed", type, flat(Color("245362"), accent))
		result.set_stylebox("focus", type, flat(Color(0, 0, 0, 0), PAPER))
	result.set_stylebox("panel", "PanelContainer", panel_style())
	return result


## Reuses the existing brass/rope frame for the title menu and modal buttons.
static func title_button(button: Button) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := panel_style()
		if style is StyleBoxTexture:
			style.set_content_margin_all(8)
			style.modulate_color = {"normal": Color.WHITE, "hover": Color("baf5ed"),
				"pressed": Color("82b4c0"), "disabled": Color("73828b")}[state]
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = PAPER
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("focus", focus)

static func skin(control: ColorRect) -> void:
	control.color = Color.TRANSPARENT
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := Panel.new()
	background.name = "NauticalFrame"
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override("panel", panel_style())
	control.add_child(background)
	control.move_child(background, 0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func column(panel: Control, controls: Array, scrollable := false) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "Layout"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	if scrollable:
		var scroll := ScrollContainer.new()
		scroll.name = "TextScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		margin.add_child(scroll)
		scroll.add_child(column)
	else:
		margin.add_child(column)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for control: Control in controls:
		control.reparent(column)
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		control.custom_minimum_size = Vector2.ZERO
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if control is Label:
			control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			control.add_theme_font_size_override("font_size", 16)
		if control is ProgressBar:
			control.custom_minimum_size.y = 12
	return column

static func speed_selector() -> OptionButton:
	var selector := OptionButton.new()
	selector.name = "TextSpeed"
	for label in ["Texto: lento", "Texto: normal", "Texto: rápido", "Texto: instantâneo"]:
		selector.add_item(label)
	selector.selected = int(Engine.get_main_loop().root.get_node("GameState").dialogue_speed_index)
	selector.item_selected.connect(func(index: int) -> void:
		Engine.get_main_loop().root.get_node("GameState").set_dialogue_speed(index)
	)
	return selector


static func navigation_heading(label: Label, accent: Color) -> void:
	var parent := label.get_parent()
	var index := label.get_index()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	parent.move_child(row, index)
	var icon := TextureRect.new()
	var compass := AtlasTexture.new()
	compass.atlas = load(PANEL_PATH)
	compass.region = Rect2(784, 0, 104, 100)
	icon.texture = compass
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(22, 22)
	icon.modulate = accent
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	label.reparent(row)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
