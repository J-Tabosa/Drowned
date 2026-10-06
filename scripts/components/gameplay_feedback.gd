extends RefCounted
## Efeitos curtos compartilhados; todos pertencem à cena e respeitam a pausa.

static var _sounds: Dictionary = {}
static var _last_cue: Dictionary = {}


static func sound(parent: Node, cue: String) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_cue.get(cue, -1000)) < 45:
		return
	if parent.get_tree().get_nodes_in_group("feedback_audio").size() >= 10:
		return
	_last_cue[cue] = now
	var percussion := {
		"damage": [0.18, 125.0, 0.65],
		"hit": [0.13, 185.0, 0.72],
		"heavy_hit": [0.24, 82.0, 0.42],
		"swish": [0.13, 420.0, 0.94],
		"heavy_swing": [0.21, 165.0, 0.75],
		"death": [0.28, 105.0, 0.62],
		"heavy_death": [0.40, 62.0, 0.45],
	}
	if not _sounds.has(cue) and percussion.has(cue):
		_sounds[cue] = _percussion(cue, percussion[cue])
	if not _sounds.has(cue):
		var notes: Array = {
			"damage": [150.0, 85.0], "blocked": [190.0, 150.0],
			"ready": [660.0, 880.0], "complete": [440.0, 660.0, 880.0],
			"gate": [220.0, 330.0, 440.0], "key": [550.0, 825.0],
			"protect": [330.0, 550.0],
			"boss_warning": [165.0, 130.0, 95.0],
		}.get(cue, [440.0])
		var data := PackedByteArray()
		var rate := 22050
		var note_length := 0.085
		for frequency in notes:
			for sample in int(rate * note_length):
				var time := float(sample) / rate
				var envelope := sin(PI * time / note_length)
				var value := int(sin(TAU * float(frequency) * time) * envelope * 6500.0)
				data.append(value & 255)
				data.append((value >> 8) & 255)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.data = data
		_sounds[cue] = stream
	var audio := AudioStreamPlayer.new()
	audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	audio.stream = _sounds[cue]
	audio.volume_db = -14.0 if percussion.has(cue) else -10.0
	parent.add_child(audio)
	audio.add_to_group("feedback_audio")
	audio.finished.connect(audio.queue_free)
	audio.play()


## Ruído filtrado mais um grave descendente: pshh para golpes, tum para o Guardião.
static func _percussion(cue: String, settings: Array) -> AudioStreamWAV:
	var rate := 22050
	var duration: float = settings[0]
	var frequency: float = settings[1]
	var noise_mix: float = settings[2]
	var random := RandomNumberGenerator.new()
	random.seed = absi(cue.hash())
	var data := PackedByteArray()
	var filtered := 0.0
	for sample in int(rate * duration):
		var time := float(sample) / rate
		var progress := time / duration
		var envelope := minf(time / 0.002, 1.0) * pow(1.0 - progress, 2.6)
		filtered = lerpf(filtered, random.randf_range(-1.0, 1.0), 0.55)
		var tone := sin(TAU * frequency * (time - 0.38 * time * time / duration))
		var value := int(clampf(lerpf(tone, filtered, noise_mix) * envelope, -1.0, 1.0) * 15000.0)
		data.append(value & 255)
		data.append((value >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream


## Faíscas pixeladas e um estalo de impacto; o nó pertence à cena e respeita a pausa.
static func impact(parent: Node2D, world_position: Vector2, direction: Vector2, heavy := false) -> void:
	var effect := Node2D.new()
	effect.name = "HitImpact"
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	effect.add_to_group("hit_impacts")
	parent.add_child(effect)
	effect.global_position = world_position
	effect.z_index = 8
	var radius := 18.0 if heavy else 11.0
	var flash := Polygon2D.new()
	var points := PackedVector2Array()
	for index in 16:
		points.append(Vector2.from_angle(TAU * index / 16.0) * (radius if index % 2 == 0 else radius * 0.28))
	flash.polygon = points
	flash.color = Color("ffe3be")
	effect.add_child(flash)
	var tween := effect.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector2.ONE * 0.1, 0.15)
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	for index in 10 if heavy else 7:
		var particle := Polygon2D.new()
		particle.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		particle.color = Color("ff8d99") if index % 2 == 0 else Color("97e0da")
		effect.add_child(particle)
		var angle := TAU * float(index) / (10.0 if heavy else 7.0)
		var travel := Vector2.from_angle(angle) * (38.0 if heavy else 25.0) + direction * 18.0
		tween.tween_property(particle, "position", travel, 0.25)
		tween.tween_property(particle, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(effect.queue_free)


static func burst(parent: Node2D, world_position: Vector2, tint: Color) -> void:
	var effect := Node2D.new()
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	parent.add_child(effect)
	effect.global_position = world_position
	effect.z_index = 8
	var ring := Line2D.new()
	for index in 25:
		ring.add_point(Vector2.from_angle(TAU * index / 24.0) * 24.0)
	ring.width = 2.0
	ring.default_color = tint
	effect.add_child(ring)
	var tween := effect.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 2.5, 0.35)
	for index in 8:
		var particle := Polygon2D.new()
		particle.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		particle.color = tint
		effect.add_child(particle)
		tween.tween_property(particle, "position", Vector2.from_angle(TAU * index / 8.0) * 58.0 + Vector2(0, -16), 0.4)
	tween.tween_property(effect, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(effect.queue_free)


static func pulse(control: Control, tint: Color) -> void:
	if control.has_meta("feedback_tween"):
		var previous: Tween = control.get_meta("feedback_tween")
		if previous.is_valid():
			previous.kill()
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * 1.035
	control.modulate = tint
	var tween := control.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, 0.25)
	tween.tween_property(control, "modulate", Color.WHITE, 0.3)
	control.set_meta("feedback_tween", tween)
