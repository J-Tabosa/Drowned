extends CanvasLayer
## Persistent curtain covers loading and survives the old scene being freed.

signal revealed
var busy := true
var _curtain: ColorRect
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_curtain = ColorRect.new()
	_curtain.name = "FadeCurtain"
	_curtain.color = Color.BLACK
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_curtain)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_initial_reveal")


func _initial_reveal() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, 0.45)
	busy = false
	revealed.emit()


func _input(_event: InputEvent) -> void:
	if busy:
		get_viewport().set_input_as_handled()


func _fade_to(alpha: float, duration: float) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_curtain.show()
	_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(_curtain, "modulate:a", alpha, duration)
	await _fade.finished
	if alpha == 0.0:
		_curtain.hide()


func transition_to(path: String, duration := 0.45) -> void:
	if busy:
		return
	busy = true
	var request := ResourceLoader.load_threaded_request(path)
	if request != OK:
		busy = false
		push_error("Não foi possível carregar a próxima cena: " + path)
		return
	await _fade_to(1.0, duration)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		await _fade_to(0.0, duration)
		busy = false
		revealed.emit()
		push_error("Falha ao carregar a próxima cena: " + path)
		return
	var scene: PackedScene = ResourceLoader.load_threaded_get(path)
	var changed := get_tree().change_scene_to_packed(scene)
	if changed != OK:
		push_error("Falha ao abrir a próxima cena: " + path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, duration)
	busy = false
	revealed.emit()
