extends CanvasLayer

signal finished

@onready var curtain: Control = %Curtain
@onready var dimmer: ColorRect = %Dimmer
@onready var top_bar: ColorRect = %TopBar
@onready var bottom_bar: ColorRect = %BottomBar
@onready var dialogue_accent: Polygon2D = %DialogueAccent
@onready var dialogue_box: PanelContainer = %DialogueBox
@onready var speaker_label: Label = %SpeakerLabel
@onready var dialogue_label: Label = %DialogueLabel
@onready var continue_indicator: Label = %ContinueIndicator

@onready var left_portrait: Control = %LeftPortrait
@onready var center_portrait: Control = %CenterPortrait
@onready var right_portrait: Control = %RightPortrait
@onready var left_texture: TextureRect = %LeftTexture
@onready var center_texture: TextureRect = %CenterTexture
@onready var right_texture: TextureRect = %RightTexture
@onready var left_placeholder: Control = %LeftPlaceholder
@onready var center_placeholder: Control = %CenterPlaceholder
@onready var right_placeholder: Control = %RightPlaceholder
@onready var left_head: ColorRect = %LeftHead
@onready var left_body: ColorRect = %LeftBody
@onready var left_arm: ColorRect = %LeftArm
@onready var center_head: ColorRect = %CenterHead
@onready var center_body: ColorRect = %CenterBody
@onready var center_arm: ColorRect = %CenterArm
@onready var right_head: ColorRect = %RightHead
@onready var right_body: ColorRect = %RightBody
@onready var right_arm: ColorRect = %RightArm

var _actors: Dictionary = {}
var _slots: Dictionary = {}
var _slot_home_positions: Dictionary = {}
var _lines: Array = []
var _line_index := -1
var _characters_per_second := 42.0
var _revealed_characters := 0.0
var _typing := false
var _active := false
var _transitioning := false
var _indicator_tween: Tween


## Mantém o overlay escondido e sem processamento até uma sequência ser iniciada.
func _ready() -> void:
	curtain.visible = false
	set_process(false)


## Recebe atores, ocupação inicial e falas; depois toca a entrada cinematográfica.
func start(sequence: Dictionary) -> void:
	_actors = sequence.get("actors", {})
	_slots = sequence.get("initial_slots", {}).duplicate()
	_lines = sequence.get("lines", [])
	_characters_per_second = float(sequence.get("characters_per_second", 42.0))
	if _lines.is_empty():
		finished.emit()
		return
	_slot_home_positions = {
		"left": left_portrait.position,
		"center": center_portrait.position,
		"right": right_portrait.position,
	}
	for slot_name in ["left", "center", "right"]:
		_apply_actor_to_slot(slot_name, _slots.get(slot_name, ""))
	curtain.visible = true
	_active = true
	_transitioning = true
	set_process(true)
	await _animate_opening()
	_transitioning = false
	_line_index = 0
	await _show_current_line()


## Revela o texto gradualmente de acordo com a velocidade configurada na sequência.
func _process(delta: float) -> void:
	if not _active or not _typing:
		return
	_revealed_characters += _characters_per_second * delta
	var total := dialogue_label.get_total_character_count()
	dialogue_label.visible_characters = mini(int(_revealed_characters), total)
	if dialogue_label.visible_characters >= total:
		_finish_typing()


## Intercepta confirmação, ação primária ou clique para completar/avançar a fala.
func _unhandled_input(event: InputEvent) -> void:
	if not _active or _transitioning:
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("primary_action") or clicked:
		get_viewport().set_input_as_handled()
		_advance()


## Faz barras, três retratos e caixa entrarem por direções diferentes.
func _animate_opening() -> void:
	var top_target := top_bar.position
	var bottom_target := bottom_bar.position
	var accent_target := dialogue_accent.position
	var box_target := dialogue_box.position
	var left_target := left_portrait.position
	var center_target := center_portrait.position
	var right_target := right_portrait.position
	top_bar.position.y -= 86.0
	bottom_bar.position.y += 86.0
	dialogue_accent.position.y += 250.0
	dialogue_box.position.y += 250.0
	left_portrait.position.x -= 380.0
	center_portrait.position.y -= 390.0
	right_portrait.position.x += 380.0
	dimmer.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(dimmer, "modulate:a", 1.0, 0.28)
	tween.tween_property(top_bar, "position", top_target, 0.32)
	tween.tween_property(bottom_bar, "position", bottom_target, 0.32)
	tween.tween_property(left_portrait, "position", left_target, 0.42).set_delay(0.08)
	tween.tween_property(center_portrait, "position", center_target, 0.44).set_delay(0.1)
	tween.tween_property(right_portrait, "position", right_target, 0.42).set_delay(0.12)
	tween.tween_property(dialogue_accent, "position", accent_target, 0.34).set_delay(0.14)
	tween.tween_property(dialogue_box, "position", box_target, 0.34).set_delay(0.16)
	await tween.finished


## Devolve as referências visuais correspondentes a uma posição do palco.
func _get_slot_nodes(slot: String) -> Dictionary:
	match slot:
		"center":
			return {
				"portrait": center_portrait, "texture": center_texture,
				"placeholder": center_placeholder, "head": center_head,
				"body": center_body, "arm": center_arm,
			}
		"right":
			return {
				"portrait": right_portrait, "texture": right_texture,
				"placeholder": right_placeholder, "head": right_head,
				"body": right_body, "arm": right_arm,
			}
		_:
			return {
				"portrait": left_portrait, "texture": left_texture,
				"placeholder": left_placeholder, "head": left_head,
				"body": left_body, "arm": left_arm,
			}


## Copia nome, cor e textura opcional de um ator para a posição solicitada.
func _apply_actor_to_slot(slot: String, actor_id: String) -> void:
	var nodes := _get_slot_nodes(slot)
	var actor: Dictionary = _actors.get(actor_id, {})
	var occupied := not actor.is_empty()
	nodes.portrait.visible = occupied
	if not occupied:
		_slots[slot] = ""
		return
	var actor_color: Color = actor.get("color", Color("6a91a1"))
	var portrait_texture := _resolve_portrait(actor.get("portrait"))
	nodes.head.color = actor_color.lightened(0.12)
	nodes.body.color = actor_color
	nodes.arm.color = actor_color.darkened(0.12)
	nodes.texture.texture = portrait_texture
	nodes.texture.visible = portrait_texture != null
	nodes.placeholder.visible = portrait_texture == null
	nodes.portrait.modulate = Color.WHITE
	nodes.portrait.scale = Vector2.ONE
	_slots[slot] = actor_id


## Aceita uma Texture2D pronta ou um caminho de recurso e usa nulo para o placeholder.
func _resolve_portrait(portrait_value: Variant) -> Texture2D:
	if portrait_value is Texture2D:
		return portrait_value
	if portrait_value is String and not portrait_value.is_empty() and ResourceLoader.exists(portrait_value):
		return load(portrait_value) as Texture2D
	return null


## Executa em ordem os comandos de entrada, saída ou substituição anteriores a uma fala.
func _apply_transitions(transitions: Array) -> void:
	for command_value in transitions:
		var command: Dictionary = command_value
		var slot: String = command.get("slot", "right")
		var action: String = command.get("action", "replace")
		if action == "exit":
			await _animate_slot_exit(slot)
		elif action == "enter" or action == "replace":
			await _animate_slot_enter(slot, command.get("actor", ""))


## Retira um ator do palco e limpa sua ocupação depois da animação.
func _animate_slot_exit(slot: String) -> void:
	var nodes := _get_slot_nodes(slot)
	var portrait: Control = nodes.portrait
	if not portrait.visible:
		_slots[slot] = ""
		return
	var home: Vector2 = _slot_home_positions[slot]
	var target := home + _transition_offset(slot)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(portrait, "position", target, 0.26)
	tween.tween_property(portrait, "modulate:a", 0.0, 0.2)
	await tween.finished
	portrait.visible = false
	portrait.position = home
	portrait.modulate = Color.WHITE
	_slots[slot] = ""


## Substitui o ocupante atual, prepara o novo ator fora da tela e o anima para dentro.
func _animate_slot_enter(slot: String, actor_id: String) -> void:
	if _slots.get(slot, "") != "":
		await _animate_slot_exit(slot)
	_apply_actor_to_slot(slot, actor_id)
	var nodes := _get_slot_nodes(slot)
	var portrait: Control = nodes.portrait
	if not portrait.visible:
		return
	var home: Vector2 = _slot_home_positions[slot]
	portrait.position = home + _transition_offset(slot)
	portrait.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait, "position", home, 0.34)
	tween.tween_property(portrait, "modulate:a", 1.0, 0.24)
	await tween.finished


## Escolhe a direção externa usada pelas transições de cada posição.
func _transition_offset(slot: String) -> Vector2:
	match slot:
		"left":
			return Vector2(-360, 0)
		"center":
			return Vector2(0, -390)
		_:
			return Vector2(360, 0)


## Aplica transições, resolve o ator da fala e reinicia o typewriter.
func _show_current_line() -> void:
	_transitioning = true
	if is_instance_valid(_indicator_tween):
		_indicator_tween.kill()
	var line: Dictionary = _lines[_line_index]
	await _apply_transitions(line.get("transitions", []))
	var actor_id: String = line.get("actor", _slots.get(line.get("side", "left"), ""))
	var actor: Dictionary = _actors.get(actor_id, {})
	speaker_label.text = line.get("speaker", actor.get("name", ""))
	speaker_label.add_theme_color_override("font_color", actor.get("color", Color.WHITE))
	dialogue_label.text = line.get("text", "")
	dialogue_label.visible_characters = 0
	_revealed_characters = 0.0
	_typing = true
	_transitioning = false
	continue_indicator.visible = false
	_focus_actor(actor_id)


## Localiza o slot do falante, clareia-o e recua os demais participantes.
func _focus_actor(actor_id: String) -> void:
	var active_slot := ""
	for slot_name in _slots:
		if _slots[slot_name] == actor_id:
			active_slot = slot_name
	for slot_name in ["left", "center", "right"]:
		var portrait: Control = _get_slot_nodes(slot_name).portrait
		if not portrait.visible:
			continue
		var is_active: bool = slot_name == active_slot
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(portrait, "scale", Vector2.ONE if is_active else Vector2(0.94, 0.94), 0.18)
		tween.tween_property(portrait, "modulate", Color.WHITE if is_active else Color(0.42, 0.48, 0.52, 0.82), 0.18)


## Mostra imediatamente todo o texto e libera o indicador de continuação.
func _finish_typing() -> void:
	_typing = false
	dialogue_label.visible_characters = -1
	continue_indicator.visible = true
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(continue_indicator, "position:y", continue_indicator.position.y + 5.0, 0.38)
	_indicator_tween.tween_property(continue_indicator, "position:y", continue_indicator.position.y, 0.38)


## Completa a digitação atual ou passa para a próxima linha; no fim, fecha o overlay.
func _advance() -> void:
	if _typing:
		_finish_typing()
		return
	_line_index += 1
	if _line_index >= _lines.size():
		_close()
	else:
		_show_current_line()


## Retira barras, caixa e todos os slots da tela antes de emitir finished.
func _close() -> void:
	if _transitioning:
		return
	_transitioning = true
	_active = false
	continue_indicator.visible = false
	if is_instance_valid(_indicator_tween):
		_indicator_tween.kill()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(dimmer, "modulate:a", 0.0, 0.24)
	tween.tween_property(top_bar, "position:y", top_bar.position.y - 86.0, 0.28)
	tween.tween_property(bottom_bar, "position:y", bottom_bar.position.y + 86.0, 0.28)
	tween.tween_property(dialogue_accent, "position:y", dialogue_accent.position.y + 250.0, 0.28)
	tween.tween_property(left_portrait, "position:x", left_portrait.position.x - 380.0, 0.3)
	tween.tween_property(center_portrait, "position:y", center_portrait.position.y - 390.0, 0.3)
	tween.tween_property(right_portrait, "position:x", right_portrait.position.x + 380.0, 0.3)
	tween.tween_property(dialogue_box, "position:y", dialogue_box.position.y + 250.0, 0.28)
	await tween.finished
	set_process(false)
	finished.emit()
