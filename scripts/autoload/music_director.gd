extends Node
## Stems share the same clock; only their gains change between encounter states.

const STEM_PATHS := [
	"res://assets/audio/music/cavern.wav",
	"res://assets/audio/music/waves_drums.wav",
	"res://assets/audio/music/boss_guitar.wav",
]
const SILENT_DB := -60.0
var context := "cavern"
var music_volume := 0.65
var _players: Array[AudioStreamPlayer] = []
var _transition: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load("user://preferences.cfg") == OK:
		music_volume = clampf(float(config.get_value("audio", "music_volume", 0.65)), 0.0, 1.0)
	for path in STEM_PATHS:
		var audio := AudioStreamPlayer.new()
		var resource: AudioStreamWAV = load(path)
		var stream: AudioStreamWAV = resource.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 4
		audio.stream = stream
		audio.volume_db = SILENT_DB
		add_child(audio)
		_players.append(audio)
	# All play commands enter the audio server in the same frame.
	for audio in _players:
		audio.play()
	set_context("cavern", 0.8)


func _process(_delta: float) -> void:
	# Dialogue pauses combat, while the score keeps its underwater atmosphere.
	var menu_paused := get_tree().paused and not DialogueManager.is_playing()
	for audio in _players:
		audio.stream_paused = menu_paused


func set_context(next: String, fade := 1.5) -> void:
	context = next if next in ["cavern", "waves", "boss"] else "cavern"
	if _transition and _transition.is_valid():
		_transition.kill()
	_transition = create_tween().set_parallel(true)
	var offset := linear_to_db(music_volume) if music_volume > 0.0 else SILENT_DB
	var levels := [-9.0, -12.0 if context in ["waves", "boss"] else SILENT_DB,
		-8.0 if context == "boss" else SILENT_DB]
	for index in _players.size():
		var target := maxf(SILENT_DB, float(levels[index]) + offset)
		_transition.tween_property(_players[index], "volume_db", target, fade)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	var config := ConfigFile.new()
	config.load("user://preferences.cfg")
	config.set_value("audio", "music_volume", music_volume)
	config.save("user://preferences.cfg")
	set_context(context, 0.1)
