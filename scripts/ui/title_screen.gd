extends Control

@onready var ocean: Control = $PixelOcean/OceanViewport/Ocean
@onready var title: Label = $Title
@onready var play_button: Button = $Play
var _starting := false
var _thunder_stream: AudioStreamWAV


func _ready() -> void:
	MusicDirector.set_context("cavern")
	play_button.theme = NauticalUI.theme()
	play_button.pressed.connect(_start_game)
	get_viewport().size_changed.connect(_layout)
	_layout()
	play_button.grab_focus()


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	title.position = Vector2(0, screen.y * 0.065)
	title.size = Vector2(screen.x, screen.y * 0.17)
	title.add_theme_font_size_override("font_size", int(minf(82.0, screen.x * 0.10)))
	play_button.size = Vector2(180, 44)
	play_button.position = Vector2((screen.x - 180) * 0.5, screen.y * 0.855)


func _start_game(duration := 2.6) -> void:
	if _starting or SceneTransition.busy:
		return
	_starting = true
	play_button.disabled = true
	var darkening := create_tween().set_parallel(true)
	darkening.tween_property(ocean, "storm", 1.0, duration).set_trans(Tween.TRANS_SINE)
	darkening.tween_property(title, "modulate:a", 0.0, duration * 0.65)
	darkening.tween_property(play_button, "modulate:a", 0.0, duration * 0.5)
	await get_tree().create_timer(duration * 0.42).timeout
	_thunder()
	await get_tree().create_timer(duration * 0.42).timeout
	_thunder()
	await darkening.finished
	SceneTransition.transition_to("res://scenes/ui/menus/character_select.tscn", 0.65)


func _thunder() -> void:
	ocean.lightning = 1.0
	var flash := create_tween()
	flash.tween_property(ocean, "lightning", 0.0, 0.35)
	if _thunder_stream == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261006
		var data := PackedByteArray()
		var filtered := 0.0
		for index in 22050:
			var t := float(index) / 22050.0
			filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.055)
			var envelope := minf(t / 0.035, 1.0) * pow(1.0 - t, 1.8)
			var value := int(clampf((filtered * 2.8 + sin(TAU * 42.0 * t) * 0.18) * envelope, -1, 1) * 16000)
			data.append(value & 255)
			data.append((value >> 8) & 255)
		_thunder_stream = AudioStreamWAV.new()
		_thunder_stream.format = AudioStreamWAV.FORMAT_16_BITS
		_thunder_stream.mix_rate = 22050
		_thunder_stream.data = data
	var audio := AudioStreamPlayer.new()
	audio.stream = _thunder_stream
	audio.volume_db = -10.0
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
