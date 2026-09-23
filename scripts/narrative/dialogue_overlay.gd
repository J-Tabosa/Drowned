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
var _portrait_cache: Dictionary = {}
var _mouths: Dictionary = {}
var _speaker_slot := ""
var _mouth_time := 0.0

const MOUTH_SOURCE_POINTS := {
	"breaker": Vector2(640, 480),
	"sharpshooter": Vector2(642, 359),
	"diver": Vector2(709, 394),
}


## Mantém o overlay escondido e sem processamento até uma sequência ser iniciada.
func _ready() -> void:
	curtain.visible = false
	for slot_name in ["left", "center", "right"]:
		var portrait: Control = _get_slot_nodes(slot_name).portrait
		var mouth := Polygon2D.new()
		mouth.name = "SpeakingMouth"
		mouth.polygon = PackedVector2Array([
			Vector2(-11, -3), Vector2(11, -3), Vector2(9, 6),
			Vector2(4, 10), Vector2(-5, 10), Vector2(-10, 6),
		])
		mouth.color = Color(0.20, 0.065, 0.065, 0.96)
		mouth.visible = false
		mouth.z_index = 2
		portrait.add_child(mouth)
		_mouths[slot_name] = mouth
	_layout_stage()
	get_viewport().size_changed.connect(_layout_stage)
	set_process(false)


func _layout_stage() -> void:
	var screen := get_viewport().get_visible_rect().size
	var slot_height := screen.y * 0.66
	var slot_width := minf(450.0, screen.y * 0.72)
	var slot_top := screen.y * 0.035
	var side_inset := -minf(36.0, screen.x * 0.03)
	var positions := {
		"left": Vector2(side_inset, slot_top),
		"center": Vector2((screen.x - slot_width) * 0.5, slot_top),
		"right": Vector2(screen.x - slot_width + side_inset, slot_top),
	}
	for slot_name in ["left", "center", "right"]:
		var portrait: Control = _get_slot_nodes(slot_name).portrait
		portrait.position = positions[slot_name]
		portrait.size = Vector2(slot_width, slot_height)
		portrait.pivot_offset = portrait.size * 0.5
		if _actors.has(_slots.get(slot_name, "")):
			_place_mouth(slot_name, _actors[_slots[slot_name]])
	var box_width := minf(1000.0, screen.x * 0.90)
	var box_top := minf(screen.y * 0.58, screen.y - 170.0)
	var box_bottom := screen.y - 10.0
	if screen.y < 480.0:
		speaker_label.add_theme_font_size_override("font_size", 17)
		dialogue_label.add_theme_font_size_override("font_size", 15)
		dialogue_label.custom_minimum_size.y = 58.0
		continue_indicator.add_theme_font_size_override("font_size", 15)
	else:
		speaker_label.add_theme_font_size_override("font_size", 21)
		dialogue_label.add_theme_font_size_override("font_size", 18)
		dialogue_label.custom_minimum_size.y = 67.0
		continue_indicator.add_theme_font_size_override("font_size", 18)
	dialogue_box.position = Vector2((screen.x - box_width) * 0.5, box_top)
	dialogue_box.size = Vector2(box_width, box_bottom - box_top)
	dialogue_accent.position = dialogue_box.position + Vector2(-12.0, -10.0)
	dialogue_accent.polygon = PackedVector2Array([
		Vector2(0, 20), Vector2(46, 0), Vector2(box_width + 24.0, 0),
		Vector2(box_width - 4.0, box_bottom - box_top + 20.0),
		Vector2(20, box_bottom - box_top + 20.0),
	])


## Recebe atores, ocupação inicial e falas; depois toca a entrada cinematográfica.
func start(sequence: Dictionary) -> void:
	_actors = sequence.get("actors", {})
	_slots = sequence.get("initial_slots", {}).duplicate()
	_lines = sequence.get("lines", [])
	_characters_per_second = float(sequence.get("characters_per_second", 42.0))
	if _lines.is_empty():
		finished.emit()
		return
	_layout_stage()
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
	_mouth_time += delta
	_set_speaker_mouth(fmod(_mouth_time, 0.23) < 0.115)
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
	_place_mouth(slot, actor)


## Aceita uma Texture2D pronta ou um caminho de recurso e usa nulo para o placeholder.
func _resolve_portrait(portrait_value: Variant) -> Texture2D:
	if portrait_value is Texture2D:
		return portrait_value
	if portrait_value is String and not portrait_value.is_empty() and ResourceLoader.exists(portrait_value):
		if _portrait_cache.has(portrait_value):
			return _portrait_cache[portrait_value]
		var original := load(portrait_value) as Texture2D
		var image := original.get_image()
		var bounds := _portrait_visible_region(image)
		if bounds.has_area():
			var atlas := AtlasTexture.new()
			atlas.atlas = original
			atlas.region = Rect2(bounds)
			_portrait_cache[portrait_value] = atlas
			return atlas
		_portrait_cache[portrait_value] = original
		return original
	return null


func _portrait_visible_region(image: Image) -> Rect2i:
	# Generated PNGs contain faint alpha specks outside the silhouette. A small
	# sampling stride finds the visible figure without treating those as artwork.
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			if image.get_pixel(x, y).a < 0.45:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x:
		return image.get_used_rect()
	return Rect2i(min_x, min_y, max_x - min_x + 3, max_y - min_y + 3).grow(16).intersection(Rect2i(Vector2i.ZERO, image.get_size()))


func _place_mouth(slot: String, actor: Dictionary) -> void:
	var mouth: Polygon2D = _mouths[slot]
	mouth.visible = false
	var source_point: Vector2 = MOUTH_SOURCE_POINTS.get(actor.get("id", ""), Vector2.ZERO)
	var texture_rect: TextureRect = _get_slot_nodes(slot).texture
	var atlas := texture_rect.texture as AtlasTexture
	if source_point == Vector2.ZERO or atlas == null:
		return
	var region := atlas.region
	var portrait: Control = _get_slot_nodes(slot).portrait
	var factor := minf(portrait.size.x / region.size.x, portrait.size.y / region.size.y)
	var drawn_size := region.size * factor
	var local := source_point - region.position
	if texture_rect.flip_h:
		local.x = region.size.x - local.x
	mouth.position = (portrait.size - drawn_size) * 0.5 + local * factor
	mouth.scale = Vector2.ONE * factor
	if actor.get("id", "") == "diver":
		mouth.color = Color(0.16, 0.055, 0.035, 0.96)
	else:
		mouth.color = Color(0.20, 0.065, 0.065, 0.96)


func _set_speaker_mouth(open: bool) -> void:
	for slot_name in _mouths:
		var mouth: Polygon2D = _mouths[slot_name]
		mouth.visible = open and slot_name == _speaker_slot and _get_slot_nodes(slot_name).texture.visible


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
	_mouth_time = 0.0
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
	_speaker_slot = active_slot
	_set_speaker_mouth(false)
	for slot_name in ["left", "center", "right"]:
		var portrait: Control = _get_slot_nodes(slot_name).portrait
		if not portrait.visible:
			continue
		var is_active: bool = slot_name == active_slot
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(portrait, "scale", Vector2.ONE if is_active else Vector2(0.94, 0.94), 0.18)
		tween.tween_property(portrait, "modulate", Color.WHITE if is_active else Color(0.42, 0.48, 0.52, 0.82), 0.18)
		portrait.z_index = 2 if is_active else 0


## Mostra imediatamente todo o texto e libera o indicador de continuação.
func _finish_typing() -> void:
	_typing = false
	_set_speaker_mouth(false)
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
	_set_speaker_mouth(false)
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
