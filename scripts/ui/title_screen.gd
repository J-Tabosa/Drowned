extends Control

@onready var ocean: Control = $PixelOcean/OceanViewport/Ocean
@onready var title: Label = $Title
@onready var play_button: Button = $Play
var _starting := false
var _thunder_stream: AudioStreamWAV
var _menu: PanelContainer
var _menu_buttons: Array[Button] = []
var _settings: PanelContainer
var _credits: PanelContainer
var _modal_shade: ColorRect
var _rain_audio: AudioStreamPlayer
var _speed: OptionButton
var _volume: HSlider
var _close_settings: Button
var _close_credits: Button


func _ready() -> void:
	MusicDirector.set_context("cavern")
	theme = NauticalUI.theme()
	title.add_theme_font_override("font", preload("res://assets/fonts/nautical_title.ttf"))
	_build_menu()
	_build_modals()
	_build_rain()
	play_button.pressed.connect(_start_game)
	get_viewport().size_changed.connect(_layout)
	_layout()
	play_button.grab_focus()


func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.name = "Menu"
	_menu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_menu.add_theme_stylebox_override("panel", NauticalUI.panel_style())
	add_child(_menu)
	var column := VBoxContainer.new()
	column.name = "Buttons"
	column.add_theme_constant_override("separation", 12)
	_menu.add_child(column)
	play_button.reparent(column)
	_menu_buttons.append(play_button)
	for entry in [["Settings", "Configurações", _open_settings],
		["Credits", "Créditos", _open_credits], ["Quit", "Sair", _quit_game]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.pressed.connect(entry[2])
		column.add_child(button)
		_menu_buttons.append(button)
	for button in _menu_buttons:
		NauticalUI.title_button(button)


func _modal(name_text: String, heading: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name_text
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_theme_stylebox_override("panel", NauticalUI.panel_style())
	add_child(panel)
	var column := VBoxContainer.new()
	column.name = "Content"
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	panel.hide()
	return panel


func _build_modals() -> void:
	_modal_shade = ColorRect.new()
	_modal_shade.name = "ModalShade"
	_modal_shade.color = Color(0.01, 0.035, 0.06, 0.78)
	add_child(_modal_shade)
	_modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_shade.hide()
	_settings = _modal("Settings", "Configurações")
	var content: VBoxContainer = _settings.get_node("Content")
	_speed = NauticalUI.speed_selector()
	content.add_child(_speed)
	var label := Label.new()
	label.text = "Volume da música"
	content.add_child(label)
	_volume = HSlider.new()
	_volume.name = "MusicVolume"
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.value = MusicDirector.music_volume
	_volume.custom_minimum_size.y = 32
	_volume.value_changed.connect(MusicDirector.set_music_volume)
	content.add_child(_volume)
	_close_settings = Button.new()
	_close_settings.text = "Voltar"
	_close_settings.pressed.connect(_close_modal)
	NauticalUI.title_button(_close_settings)
	content.add_child(_close_settings)
	_credits = _modal("Credits", "Créditos")
	var credit_text := Label.new()
	credit_text.text = "DROWNED\n\nUm RPG de João Victor Tabosa e amigos.\n\nCenários e sprites de abertura:\nImageGen · direção e integração no Godot"
	credit_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits.get_node("Content").add_child(credit_text)
	_close_credits = Button.new()
	_close_credits.text = "Voltar"
	_close_credits.pressed.connect(_close_modal)
	NauticalUI.title_button(_close_credits)
	_credits.get_node("Content").add_child(_close_credits)


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var scale_factor := clampf(minf(screen.x / 960.0, screen.y / 540.0), 0.65, 1.5)
	var width := 252.0 * scale_factor
	var left := screen.x * 0.05
	title.add_theme_font_size_override("font_size", int(43 * scale_factor))
	title.add_theme_constant_override("outline_size", maxi(3, int(5 * scale_factor)))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.position = Vector2(left - 6, screen.y * 0.10)
	title.size = Vector2(width + 12, 78 * scale_factor)
	_menu.position = Vector2(left, screen.y * 0.31)
	_menu.size = Vector2(width, 0)
	_menu.get_node("Buttons").add_theme_constant_override("separation", int(12 * scale_factor))
	for button in _menu_buttons:
		button.custom_minimum_size = Vector2(0, 46 * scale_factor)
		button.add_theme_font_size_override("font_size", int(19 * scale_factor))
	for panel in [_settings, _credits]:
		panel.custom_minimum_size.x = minf(420.0 * scale_factor, screen.x - 32.0)
		for child in panel.get_node("Content").get_children():
			if child is Label:
				child.custom_minimum_size.x = panel.custom_minimum_size.x - 36.0
		panel.reset_size()
		panel.position = (screen - panel.size) * 0.5


func _open_settings() -> void:
	if _starting:
		return
	_speed.selected = GameState.dialogue_speed_index
	_volume.set_value_no_signal(MusicDirector.music_volume)
	_settings.show()
	_modal_shade.show()
	_set_menu_enabled(false)
	_layout()
	_speed.grab_focus()


func _open_credits() -> void:
	if _starting:
		return
	_credits.show()
	_modal_shade.show()
	_set_menu_enabled(false)
	_layout()
	_close_credits.grab_focus()


func _close_modal() -> void:
	_settings.hide()
	_credits.hide()
	_modal_shade.hide()
	_set_menu_enabled(true)
	play_button.grab_focus()


func _set_menu_enabled(enabled: bool) -> void:
	for button in _menu_buttons:
		button.disabled = not enabled


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _modal_shade.visible and not _starting:
		_close_modal()
		get_viewport().set_input_as_handled()


func _quit_game() -> void:
	if not _starting:
		get_tree().quit()


func _start_game(duration := 2.6) -> void:
	if _starting or SceneTransition.busy or _modal_shade.visible:
		return
	_starting = true
	_set_menu_enabled(false)
	_rain_audio.play()
	var darkening := create_tween().set_parallel(true)
	darkening.tween_property(ocean, "storm", 1.0, duration).set_trans(Tween.TRANS_SINE)
	darkening.tween_property(title, "modulate:a", 0.0, duration * 0.65)
	darkening.tween_property(_menu, "modulate:a", 0.0, duration * 0.5)
	await get_tree().create_timer(duration * 0.42).timeout
	_thunder()
	await get_tree().create_timer(duration * 0.42).timeout
	_thunder()
	await darkening.finished
	SceneTransition.transition_to("res://scenes/ui/menus/character_select.tscn", 0.65)


func _process(_delta: float) -> void:
	if _rain_audio:
		_rain_audio.volume_db = linear_to_db(maxf(0.0001, ocean.storm * 0.16))
	# Autowrapped labels settle after container sorting; keep the open modal centered.
	for panel in [_settings, _credits]:
		if panel and panel.visible:
			panel.position = (get_viewport().get_visible_rect().size - panel.size) * 0.5


func _build_rain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	var data := PackedByteArray()
	var filtered := 0.0
	for index in 44100:
		filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.45)
		var value := int(filtered * 14000)
		data.append(value & 255)
		data.append((value >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 44100
	_rain_audio = AudioStreamPlayer.new()
	_rain_audio.name = "Rain"
	_rain_audio.stream = stream
	_rain_audio.volume_db = -80.0
	add_child(_rain_audio)


func _thunder() -> void:
	ocean.lightning = 1.0
	var flash := create_tween()
	flash.tween_property(ocean, "lightning", 0.0, 0.35)
	if _thunder_stream == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261006
		var data := PackedByteArray()
		var filtered := 0.0
		for index in 26460:
			var t := float(index) / 22050.0
			filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.018)
			var envelope := minf(t / 0.025, 1.0) * pow(maxf(0, 1.0 - t / 1.2), 1.8)
			var value := int(clampf(filtered * 5.0 * envelope, -1, 1) * 22000)
			data.append(value & 255)
			data.append((value >> 8) & 255)
		_thunder_stream = AudioStreamWAV.new()
		_thunder_stream.format = AudioStreamWAV.FORMAT_16_BITS
		_thunder_stream.mix_rate = 22050
		_thunder_stream.data = data
	var audio := AudioStreamPlayer.new()
	audio.stream = _thunder_stream
	audio.volume_db = -8.0
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
