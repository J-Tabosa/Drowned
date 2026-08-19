extends Node

## Cena visual única usada para exibir qualquer sequência de diálogo do projeto.
const DIALOGUE_OVERLAY := preload("res://scenes/ui/dialogue/dialogue_overlay.tscn")

var _active_overlay: CanvasLayer


## Mantém o autoload processando para concluir diálogos mesmo com o mundo pausado.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Exibe uma sequência sobre a cena atual e só termina quando todas as falas forem avançadas.
func play(sequence: Dictionary) -> void:
	if sequence.get("lines", []).is_empty():
		return
	while is_instance_valid(_active_overlay):
		await get_tree().process_frame
	var previous_pause_state := get_tree().paused
	_active_overlay = DIALOGUE_OVERLAY.instantiate()
	get_tree().current_scene.add_child(_active_overlay)
	get_tree().paused = true
	_active_overlay.start(sequence)
	await _active_overlay.finished
	get_tree().paused = previous_pause_state
	_active_overlay.queue_free()
	_active_overlay = null


## Informa se existe um diálogo ocupando a tela neste momento.
func is_playing() -> bool:
	return is_instance_valid(_active_overlay)
