extends Node2D

const DIALOGUE_CATALOG := preload("res://scripts/narrative/dialogue_catalog.gd")
const FEEDBACK := preload("res://scripts/components/gameplay_feedback.gd")

enum EncounterStage {
	MOVEMENT_TUTORIAL,
	EXPLORE_ECHOES,
	REACH_COMBAT,
	COMBAT,
	BOSS_REVEAL,
	REACH_BOSS,
	BOSS_PRESENTATION,
	BOSS,
	REACH_EXIT,
	COMPLETE,
}

const MOVEMENT_DISTANCE_REQUIRED := 420.0
const SPRINT_DISTANCE_REQUIRED := 180.0
const COMBAT_TRIGGER_RADIUS := 260.0
const BOSS_TRIGGER_RADIUS := 430.0
const STORY_ECHO_RADIUS := 150.0
const EXIT_TRIGGER_RADIUS := 170.0
const COMBAT_WAVE_SIZES := [4, 5, 6]

@export var skip_cinematics_for_tests := false

@onready var arena: Node2D = $Arena
@onready var cutscene_camera: Camera2D = %CutsceneCamera
@onready var boss_intro_card: CanvasLayer = %BossIntroCard
@onready var underwater_fog: CanvasLayer = %UnderwaterFog
@onready var character_label: Label = %CharacterLabel
@onready var action_label: Label = %ActionLabel
@onready var cooldown_bar: ProgressBar = %CooldownBar
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var enemy_label: Label = %EnemyLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var stage_label: Label = %StageLabel
@onready var tutorial_panel: ColorRect = %TutorialPanel
@onready var tutorial_title: Label = %TutorialTitle
@onready var tutorial_step: Label = %TutorialStep
@onready var tutorial_progress: ProgressBar = %TutorialProgress
@onready var boss_panel: ColorRect = %BossPanel
@onready var boss_name_label: Label = %BossNameLabel
@onready var boss_health_bar: ProgressBar = %BossHealthBar
@onready var result_panel: ColorRect = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_detail: Label = %ResultDetail
@onready var pause_panel: ColorRect = %PausePanel
@onready var settings_card: ColorRect = %SettingsCard
@onready var developer_panel: ColorRect = %DeveloperPanel
@onready var controls_label: Label = $Interface/Controls
@onready var relic_label: Label = %RelicLabel

var player: CharacterBody2D
var _boss: CharacterBody2D
var _stage := EncounterStage.MOVEMENT_TUTORIAL
var _enemies_alive := 0
var _movement_distance := 0.0
var _sprint_time := 0.0
var _last_player_position := Vector2.ZERO
var _movement_done := false
var _sprint_done := false
var _action_done := false
var _story_echo_index := 0
var _combat_spawned := false
var _combat_wave := -1
var _combat_spawn_cursor := 0
var _wave_transition_pending := false
var _boss_spawned := false
var _round_finished := false
var _developer_mode := false
var _last_input_device := "keyboard"
var _feedback_label: Label
var _cooldown_label: Label
var _feedback_time := 0.0
var _last_gate := ""
var _reject_wait := 0.0


## Inicializa jogador e HUD usando exclusivamente marcadores fornecidos pelo blueprint do mapa.
func _ready() -> void:
	_developer_mode = OS.get_cmdline_args().has("--debug")
	developer_panel.visible = _developer_mode
	pause_panel.visible = false
	settings_card.visible = false
	_create_feedback_labels()
	_style_hud()
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	_spawn_player()
	arena.item_collected.connect(_on_item_collected)
	arena.gate_opened.connect(_on_gate_opened)
	_on_item_collected(0, arena.get_item_positions().size())
	result_panel.visible = false
	boss_panel.visible = false
	tutorial_panel.visible = true
	_last_player_position = player.global_position
	_update_enemy_label()
	_update_tutorial_panel()
	_set_stage_text("1/3  EXPLORAÇÃO")
	_set_objective("Pratique os controles para iniciar a exploração.")
	_refresh_action_prompt()


func _on_item_collected(collected: int, total: int) -> void:
	relic_label.text = "CHAVES  %d/%d%s" % [collected, total, " • 1 usada" if arena._exit_key_used else ""]
	if collected > 0:
		_notify("Chave-bússola encontrada — abre o portão laranja.", Color("efb46b"), "key")
		FEEDBACK.burst(self, player.global_position, Color("efb46b"))
		FEEDBACK.pulse(relic_label, Color("efb46b"))
		if _stage == EncounterStage.REACH_EXIT and not arena.is_post_boss_gate_open():
			_set_objective("Leve uma chave-bússola ao portão laranja.")


func _create_feedback_labels() -> void:
	_feedback_label = Label.new()
	_feedback_label.name = "GameplayFeedback"
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_font_size_override("font_size", 18)
	_feedback_label.add_theme_color_override("font_shadow_color", Color("081722"))
	_feedback_label.add_theme_constant_override("shadow_outline_size", 5)
	_feedback_label.visible = false
	$Interface.add_child(_feedback_label)
	_cooldown_label = Label.new()
	_cooldown_label.name = "CooldownState"
	_cooldown_label.position = Vector2(18, 96)
	_cooldown_label.add_theme_font_size_override("font_size", 12)
	_cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Interface/TopPanel.add_child(_cooldown_label)
	$Interface/TopPanel.size.y = 122.0


func _notify(text: String, tint: Color, cue := "") -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", tint)
	_feedback_label.visible = true
	_feedback_time = 2.6
	FEEDBACK.pulse(_feedback_label, Color.WHITE)
	if not cue.is_empty():
		FEEDBACK.sound(self, cue)


func _objective_completed(text: String) -> void:
	_notify("✓ " + text, Color("83dfbe"), "complete")
	FEEDBACK.pulse(objective_label, Color("83dfbe"))
	FEEDBACK.burst(self, player.global_position, Color("83dfbe"))


func _on_gate_opened(gate_id: String) -> void:
	_notify("Portão laranja aberto — chave utilizada." if gate_id == "post_boss" else "Selo rompido — passagem aberta.", Color("efb46b"), "gate")
	if gate_id == "post_boss":
		relic_label.text = "CHAVES  %d/%d • 1 usada" % [arena.get_collected_item_count(), arena.get_item_positions().size()]
		_set_objective("Atravesse o portão aberto e alcance a saída.")


func _check_gate_interaction() -> void:
	if not player._controls_enabled:
		return
	var nearby: String = arena.get_nearby_closed_gate(player.global_position)
	if nearby == "post_boss" and _stage == EncounterStage.REACH_EXIT and arena.has_exit_key():
		arena.open_post_boss_gate()
	elif not nearby.is_empty() and nearby != _last_gate:
		_notify(arena.get_gate_hint(nearby), Color("efb46b"), "blocked")
	_last_gate = nearby


func _on_action_ready() -> void:
	if _round_finished:
		return
	FEEDBACK.pulse(cooldown_bar, Color("83dfbe"))
	FEEDBACK.sound(self, "ready")


func _on_action_rejected() -> void:
	if _round_finished or _reject_wait > 0.0:
		return
	_reject_wait = 0.4
	FEEDBACK.pulse(cooldown_bar, Color("efb46b"))
	FEEDBACK.pulse(_cooldown_label, Color("efb46b"))
	FEEDBACK.sound(self, "blocked")


func _on_invulnerability_changed(active: bool) -> void:
	if active:
		FEEDBACK.burst(self, player.global_position, Color("80e5ec"))
		FEEDBACK.sound(self, "protect")


func _on_player_damaged(amount: float, source: Vector2) -> void:
	_notify("−%d VIDA" % ceili(amount), Color("ff8d99"), "damage")
	FEEDBACK.pulse(health_bar, Color("ff8d99"))
	FEEDBACK.impact(self, player.global_position, source.direction_to(player.global_position))


var _hud_columns: Dictionary = {}
var _objective_toggle: Button
var _objective_time_left := 0.0
var _objective_pinned := false
var _hud_pixel_scale := 1.0
var _objective_mouse_position := Vector2(-100, -100)


func _style_hud() -> void:
	var accent: Color = GameState.get_selected_profile().color
	for node in [$Interface/TopPanel, $Interface/ObjectivePanel, tutorial_panel, boss_panel,
		result_panel, $Interface/PausePanel/PauseCard, settings_card]:
		node.theme = NauticalUI.theme(accent)
		NauticalUI.skin(node)
	_hud_columns["status"] = NauticalUI.column($Interface/TopPanel, [character_label, health_label, health_bar, action_label, cooldown_bar])
	_hud_columns["objective"] = NauticalUI.column($Interface/ObjectivePanel, [stage_label, objective_label], true)
	_hud_columns["tutorial"] = NauticalUI.column(tutorial_panel, [tutorial_title, tutorial_step, tutorial_progress], true)
	_hud_columns["boss"] = NauticalUI.column(boss_panel, [boss_name_label, boss_health_bar])
	_hud_columns["result"] = NauticalUI.column(result_panel, [result_title, result_detail], true)
	for path in ["TopPanel/TopAccent", "ObjectivePanel/ObjectiveAccent", "TutorialPanel/TutorialAccent"]:
		$Interface.get_node(path).hide()
	$Interface/PausePanel/SettingsCard/SettingsInfo.hide()
	var speed := NauticalUI.speed_selector()
	settings_card.add_child(speed)
	speed.position = Vector2(24, 178)
	speed.size = Vector2(300, 42)
	_style_bar(health_bar, Color("de6572"))
	_style_bar(cooldown_bar, accent)
	_style_bar(tutorial_progress, Color("52d7b0"))
	_style_bar(boss_health_bar, Color("af76c8"))
	NauticalUI.navigation_heading(character_label, accent)
	NauticalUI.navigation_heading(stage_label, Color("52d7b0"))
	NauticalUI.navigation_heading(tutorial_title, Color("52d7b0"))
	for panel in [$Interface/TopPanel, $Interface/ObjectivePanel, tutorial_panel, boss_panel]:
		var margin: MarginContainer = panel.get_node("Layout")
		for side in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 10)
	for key in ["status", "objective", "tutorial", "boss"]:
		_hud_columns[key].add_theme_constant_override("separation", 4)
	for label in [health_label, action_label, stage_label, objective_label, tutorial_step, tutorial_title, boss_name_label]:
		label.add_theme_font_size_override("font_size", 13)
	for label in [character_label, stage_label, tutorial_title]:
		label.get_parent().get_child(0).custom_minimum_size = Vector2(16, 16)
	health_bar.custom_minimum_size.y = 7
	cooldown_bar.custom_minimum_size.y = 5
	tutorial_progress.custom_minimum_size.y = 5
	boss_health_bar.custom_minimum_size.y = 10
	_objective_toggle = Button.new()
	_objective_toggle.name = "ObjectiveToggle"
	_objective_toggle.text = "Missão ▾"
	_objective_toggle.toggle_mode = true
	_objective_toggle.add_theme_font_size_override("font_size", 12)
	_objective_toggle.theme = NauticalUI.theme(Color("52d7b0"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBox = _objective_toggle.get_theme_stylebox(state).duplicate()
		style.set_content_margin_all(4)
		_objective_toggle.add_theme_stylebox_override(state, style)
	_objective_toggle.toggled.connect(func(pinned: bool) -> void:
		_objective_pinned = pinned
		if not pinned:
			_objective_time_left = 0.0
	)
	$Interface.add_child(_objective_toggle)
	character_label.add_theme_font_size_override("font_size", 16)
	result_title.add_theme_font_size_override("font_size", 23)

func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	var background := NauticalUI.flat(Color("142e3a"), NauticalUI.BRASS)
	background.set_content_margin_all(0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

func _place_panel(panel: Control, rect: Rect2) -> void:
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = rect.position
	panel.size = rect.size

func _layout_hud() -> void:
	var logical := get_viewport().get_visible_rect().size
	_hud_pixel_scale = logical.x / float(get_window().size.x)
	var screen := logical / _hud_pixel_scale
	var margin := 12.0
	var width := minf(280.0, screen.x * 0.42)
	var objective_width := minf(360.0, screen.x - width - margin * 3)
	var objective_x := maxf(width + margin * 2, (screen.x - objective_width) * 0.5)
	_place_compact_panel($Interface/TopPanel, Rect2(margin, margin, width, 126))
	_place_compact_panel($Interface/ObjectivePanel, Rect2(objective_x, 44, objective_width, 94))
	_place_compact_panel(_objective_toggle, Rect2(objective_x + objective_width - 100, margin, 100, 26))
	var context_width := minf(300.0, screen.x * 0.44)
	_place_compact_panel(tutorial_panel, Rect2(screen.x - context_width - margin, screen.y - 94 - margin, context_width, 94))
	_place_compact_panel(boss_panel, Rect2(screen.x - context_width - margin, screen.y - 76 - margin, context_width, 76))
	relic_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	relic_label.scale = Vector2.ONE * _hud_pixel_scale
	relic_label.position = Vector2(margin, screen.y - 28) * _hud_pixel_scale
	relic_label.size = Vector2(180, 20)
	relic_label.add_theme_font_size_override("font_size", 12)
	enemy_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	enemy_label.scale = Vector2.ONE * _hud_pixel_scale
	enemy_label.position = Vector2((screen.x - 260) * 0.5, 148) * _hud_pixel_scale
	enemy_label.size = Vector2(260, 24)
	var result_size := Vector2(minf(400, screen.x - 24), minf(220, screen.y - 24))
	_place_compact_panel(result_panel, Rect2((screen - result_size) * 0.5, result_size))
	result_panel.get_node("Layout").offset_bottom = -64
	var restart: Button = result_panel.get_node("Restart")
	restart.position = Vector2(24, result_size.y - 58)
	restart.size = Vector2(result_size.x - 48, 42)
	_feedback_label.scale = Vector2.ONE * _hud_pixel_scale
	_feedback_label.position = Vector2(margin, 170) * _hud_pixel_scale
	_feedback_label.size = Vector2(screen.x - margin * 2.0, 56)

func _place_compact_panel(panel: Control, rect: Rect2) -> void:
	_place_panel(panel, Rect2(rect.position * _hud_pixel_scale, rect.size))
	panel.scale = Vector2.ONE * _hud_pixel_scale

func _update_objective_visibility(delta: float) -> void:
	var panel: Control = $Interface/ObjectivePanel
	if _round_finished:
		panel.hide()
		_objective_toggle.hide()
		return
	if not get_tree().paused:
		_objective_time_left = maxf(0, _objective_time_left - delta)
	var mouse := _objective_mouse_position
	var hovering := _objective_toggle.get_global_rect().has_point(mouse)
	if panel.visible:
		hovering = hovering or panel.get_global_rect().has_point(mouse)
	panel.visible = _objective_pinned or hovering or _objective_time_left > 0
	_objective_toggle.text = "Missão ▴" if _objective_pinned else "Missão ▾"


## Monitora requisitos e proximidade dos marcadores C e B desenhados no blueprint.
func _process(delta: float) -> void:
	_update_objective_visibility(delta)
	if get_tree().paused or _round_finished or not is_instance_valid(player):
		return
	_feedback_time = maxf(0.0, _feedback_time - delta)
	_feedback_label.visible = _feedback_time > 0.0
	_reject_wait = maxf(0.0, _reject_wait - delta)
	var remaining: float = player.cooldown_remaining
	cooldown_bar.value = 100.0 * (1.0 - remaining / float(player.profile.cooldown))
	_cooldown_label.text = "RECARREGANDO  %.1f s" % remaining if remaining > 0.0 else "HABILIDADE PRONTA"
	if not player.can_receive_damage():
		_cooldown_label.text = "INVULNERÁVEL • " + _cooldown_label.text
	_cooldown_label.add_theme_color_override("font_color", Color("80e5ec") if not player.can_receive_damage() else Color("83dfbe") if remaining == 0.0 else Color("bdcbd4"))
	_check_gate_interaction()
	if _stage == EncounterStage.MOVEMENT_TUTORIAL:
		_track_tutorial()
	elif _stage == EncounterStage.EXPLORE_ECHOES:
		_check_story_echoes()
	elif _stage == EncounterStage.REACH_COMBAT:
		if player.global_position.distance_to(arena.get_anchor_position("combat_trigger")) <= COMBAT_TRIGGER_RADIUS:
			_start_combat_encounter()
	elif _stage == EncounterStage.REACH_BOSS:
		if player.global_position.distance_to(arena.get_anchor_position("boss_spawn")) <= BOSS_TRIGGER_RADIUS:
			_begin_boss_fight()
	elif _stage == EncounterStage.REACH_EXIT:
		if arena.is_post_boss_gate_open() and player.global_position.distance_to(arena.get_anchor_position("post_boss_exit")) <= EXIT_TRIGGER_RADIUS:
			_finish_round(true)


## Instancia o personagem no P do blueprint e conecta seus sinais ao HUD.
func _spawn_player() -> void:
	var profile := GameState.get_selected_profile()
	player = preload("res://scenes/characters/playable/placeholder_player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.setup(profile)
	add_child(player)
	player.global_position = arena.get_anchor_position("player_spawn")
	player.action_used.connect(_on_action_used)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.action_ready.connect(_on_action_ready)
	player.action_rejected.connect(_on_action_rejected)
	player.invulnerability_changed.connect(_on_invulnerability_changed)
	player.health_component.damaged.connect(_on_player_damaged)
	character_label.text = profile.name
	character_label.add_theme_color_override("font_color", profile.color)
	cooldown_bar.value = 100.0
	_on_player_health_changed(player.health_component.current_health, player.health_component.max_health)
	_refresh_action_prompt()


## Acompanha deslocamento, corrida com Ctrl e habilidade sem depender de uma posição específica.
func _track_tutorial() -> void:
	var frame_distance := player.global_position.distance_to(_last_player_position)
	_last_player_position = player.global_position
	if frame_distance > 0.0 and frame_distance < 180.0:
		_movement_distance = minf(MOVEMENT_DISTANCE_REQUIRED, _movement_distance + frame_distance)
	if player.is_sprinting() and frame_distance > 0.25:
		_sprint_time = minf(SPRINT_DISTANCE_REQUIRED, _sprint_time + frame_distance)
	if not _movement_done and _movement_distance >= MOVEMENT_DISTANCE_REQUIRED:
		_movement_done = true
		_objective_completed("Movimento aprendido")
	if not _sprint_done and _sprint_time >= SPRINT_DISTANCE_REQUIRED:
		_sprint_done = true
		_objective_completed("Corrida aprendida")
	_update_tutorial_panel()
	_try_complete_tutorial()


## Depois dos controles, conduz o jogador por três descobertas curtas antes da primeira arena.
func _try_complete_tutorial() -> void:
	if _stage != EncounterStage.MOVEMENT_TUTORIAL:
		return
	if not _movement_done or not _sprint_done or not _action_done:
		return
	_stage = EncounterStage.EXPLORE_ECHOES
	_objective_completed("Treinamento concluído")
	tutorial_title.text = "ECOS DA GRUTA"
	_set_objective("Investigue os sinais deixados entre os destroços.")
	_update_story_panel()


## Mostra somente a instrução atual para não transformar o tutorial em uma lista permanente.
func _update_tutorial_panel() -> void:
	if not _movement_done:
		tutorial_title.text = "MOVIMENTO"
		tutorial_step.text = "Use WASD ou as setas para explorar."
		tutorial_progress.value = (_movement_distance / MOVEMENT_DISTANCE_REQUIRED) * 100.0
	elif not _sprint_done:
		tutorial_title.text = "CORRIDA"
		tutorial_step.text = "Segure Ctrl enquanto se move."
		tutorial_progress.value = (_sprint_time / SPRINT_DISTANCE_REQUIRED) * 100.0
	elif not _action_done:
		tutorial_title.text = "HABILIDADE"
		tutorial_step.text = "Use %s uma vez." % GameState.get_selected_profile().action_name
		tutorial_progress.value = 0.0
	else:
		tutorial_progress.value = 100.0


## Dispara um diálogo curto ao encontrar cada eco, na ordem em que eles levam à câmara.
func _check_story_echoes() -> void:
	var echo_positions: Array[Vector2] = arena.get_story_echo_positions()
	if _story_echo_index >= echo_positions.size():
		_finish_story_echoes()
		return
	if player.global_position.distance_to(echo_positions[_story_echo_index]) > STORY_ECHO_RADIUS:
		return
	var discovered_index := _story_echo_index
	_story_echo_index += 1
	arena.complete_story_echo(discovered_index)
	_objective_completed("Eco %d de 3 investigado" % _story_echo_index)
	_update_story_panel()
	if not skip_cinematics_for_tests:
		await DialogueManager.play(DIALOGUE_CATALOG.get_exploration_echo(GameState.selected_character_id, discovered_index))
	_finish_story_echoes()


func _update_story_panel() -> void:
	var total: int = arena.get_story_echo_positions().size()
	if _story_echo_index >= total:
		tutorial_step.text = "Todos os sinais foram investigados."
	else:
		tutorial_step.text = "Sinal %d de %d — procure o brilho adiante." % [_story_echo_index + 1, total]
	tutorial_progress.value = (float(_story_echo_index) / maxf(float(total), 1.0)) * 100.0


## Abre o primeiro portão somente depois que o pequeno arco de exploração foi concluído.
func _finish_story_echoes() -> void:
	var total: int = arena.get_story_echo_positions().size()
	if _story_echo_index < total or _stage != EncounterStage.EXPLORE_ECHOES:
		return
	_stage = EncounterStage.REACH_COMBAT
	arena.open_tutorial_gate()
	tutorial_title.text = "CAMINHO LIBERADO"
	tutorial_step.text = "A Câmara dos Afogados está aberta."
	tutorial_progress.value = 100.0
	_set_objective("Entre na câmara e prepare-se para o confronto.")
	get_tree().create_timer(1.8).timeout.connect(func() -> void:
		if is_instance_valid(tutorial_panel):
			tutorial_panel.visible = false
	)


## Inicia uma sequência de ondas para dar peso à câmara sem despejar tudo ao mesmo tempo.
func _start_combat_encounter() -> void:
	if _combat_spawned or _round_finished:
		return
	_combat_spawned = true
	_stage = EncounterStage.COMBAT
	tutorial_panel.visible = false
	_set_stage_text("2/3  CÂMARA DOS AFOGADOS")
	_start_next_combat_wave()


func _start_next_combat_wave() -> void:
	if _stage != EncounterStage.COMBAT or _round_finished:
		return
	_wave_transition_pending = false
	_combat_wave += 1
	if _combat_wave >= COMBAT_WAVE_SIZES.size():
		_begin_boss_reveal()
		return
	var spawn_positions: Array[Vector2] = arena.get_mob_spawn_positions()
	var wave_size: int = COMBAT_WAVE_SIZES[_combat_wave]
	for index in wave_size:
		var spawn_index := (_combat_spawn_cursor + index) % spawn_positions.size()
		_spawn_enemy(spawn_positions[spawn_index], {
			"engaged": true,
			"max_health": 88.0 + float(_combat_wave) * 14.0 + float(index % 3) * 8.0,
			"move_speed": 96.0 + float(_combat_wave) * 8.0 + float(index % 2) * 10.0,
		})
	_combat_spawn_cursor += wave_size
	_set_objective("Sobreviva à onda %d de %d." % [_combat_wave + 1, COMBAT_WAVE_SIZES.size()])
	_update_enemy_label()


func _queue_next_combat_wave() -> void:
	if _wave_transition_pending:
		return
	_wave_transition_pending = true
	_set_objective("A câmara se agita. A próxima onda está chegando...")
	if skip_cinematics_for_tests:
		call_deferred("_start_next_combat_wave")
	else:
		get_tree().create_timer(1.6).timeout.connect(_start_next_combat_wave)


func _begin_boss_reveal() -> void:
	_stage = EncounterStage.BOSS_REVEAL
	_run_boss_reveal(skip_cinematics_for_tests, skip_cinematics_for_tests)


## Reutiliza a mesma cena para mobs e chefe, mantendo as diferenças em dados.
func _spawn_enemy(spawn_position: Vector2, config: Dictionary = {}) -> CharacterBody2D:
	var enemy: CharacterBody2D = preload("res://scenes/characters/enemies/placeholder_enemy.tscn").instantiate()
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	if not config.is_empty():
		enemy.setup(config)
	add_child(enemy)
	enemy.global_position = spawn_position
	enemy.defeated.connect(_on_enemy_defeated)
	_enemies_alive += 1
	return enemy


## Cria o Guardião no B, com 700 de vida, mas o mantém dormente durante a revelação.
func _spawn_boss_for_reveal() -> void:
	if _boss_spawned:
		return
	_boss_spawned = true
	_boss = _spawn_enemy(arena.get_anchor_position("boss_spawn"), {
		"display_name": "Guardião Abissal",
		"is_miniboss": true,
		"engaged": true,
		"body_size": Vector2(104, 128),
		"max_health": 700.0,
		"move_speed": 118.0,
		"attack_damage": 25.0,
		"aggro_range": 1150.0,
		"attack_range": 116.0,
		"attack_cooldown": 0.82,
		"attack_windup": 0.42,
		"boss_dash_cooldown": 3.25,
		"boss_dash_speed": 690.0,
		"boss_dash_duration": 0.54,
		"boss_dash_telegraph_time": 0.9,
		"boss_dash_damage": 40.0,
	})
	_boss.set_active(false)
	_boss.health_component.health_changed.connect(_on_boss_health_changed)
	boss_name_label.text = _boss.display_name
	_on_boss_health_changed(_boss.health_component.current_health, _boss.health_component.max_health)
	_update_enemy_label()


## Desliza a câmera até o Guardião, toca o diálogo do trio e devolve o controle ao jogador.
func _run_boss_reveal(skip_dialogue := false, instant := false) -> void:
	if _stage != EncounterStage.BOSS_REVEAL:
		return
	_spawn_boss_for_reveal()
	player.set_controls_enabled(false)
	_set_stage_text("SINAL DESCONHECIDO")
	_set_objective("Algo observa o grupo abaixo da câmara.")
	cutscene_camera.global_position = player.global_position
	cutscene_camera.enabled = true
	player.camera.enabled = false
	if instant:
		cutscene_camera.global_position = _boss.global_position
	else:
		var reveal_tween := create_tween()
		reveal_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
		reveal_tween.tween_property(cutscene_camera, "global_position", _boss.global_position, 1.45)
		await reveal_tween.finished
		await get_tree().create_timer(0.35).timeout
	if not skip_dialogue:
		await DialogueManager.play(DIALOGUE_CATALOG.get_boss_reveal(GameState.selected_character_id))
	if not instant:
		var return_tween := create_tween()
		return_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
		return_tween.tween_property(cutscene_camera, "global_position", player.global_position, 1.1)
		await return_tween.finished
	player.camera.enabled = true
	cutscene_camera.enabled = false
	player.set_controls_enabled(true)
	arena.open_boss_gate()
	_stage = EncounterStage.REACH_BOSS
	_set_stage_text("PASSAGEM PARA O GUARDIÃO")
	_set_objective("Entre no fosso quando estiver preparado.")


## Exibe o cartão de arte completa ao entrar na sala e só então desperta o mini-chefe.
func _begin_boss_fight(skip_card := false) -> void:
	if _stage != EncounterStage.REACH_BOSS or not is_instance_valid(_boss):
		return
	_stage = EncounterStage.BOSS_PRESENTATION
	player.set_controls_enabled(false)
	if not skip_card:
		await boss_intro_card.play(
			"GUARDIÃO ABISSAL",
			"(Guardião das Profundezas) — MINICHEFE",
			"Uma sentinela ancestral da caverna. Seu dash percorre toda a área marcada antes do impacto.",
			Color("9b58b5")
		)
	boss_panel.visible = true
	_boss.set_active(true)
	player.set_controls_enabled(true)
	_stage = EncounterStage.BOSS
	_set_stage_text("3/3  GUARDIÃO ABISSAL")
	_set_objective("Observe a faixa vermelha, desvie do dash e derrote o Guardião.")


## Atualiza o dispositivo de entrada, alterna fullscreen/debug e mantém atalhos globais ativos.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_objective_mouse_position = event.position
	if DialogueManager.is_playing():
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_last_input_device = "mouse"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_input_device = "controller"
	elif event is InputEventKey and event.pressed and not event.echo:
		_last_input_device = "keyboard"
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F3:
			_developer_mode = not _developer_mode
			developer_panel.visible = _developer_mode
			get_viewport().set_input_as_handled()
			return
	_refresh_action_prompt()


## Pausa o mundo mantendo a interface de pausa disponível.
func _toggle_pause() -> void:
	var should_pause := not get_tree().paused
	get_tree().paused = should_pause
	pause_panel.visible = should_pause
	settings_card.visible = false
	$Interface/PausePanel/PauseCard.visible = true
	if should_pause:
		$Interface/PausePanel/PauseCard/Resume.grab_focus()


## Fecha o menu de pausa e devolve o controle ao jogador.
func _on_pause_resume_pressed() -> void:
	if get_tree().paused:
		_toggle_pause()


## Alterna entre o menu principal da pausa e as configurações básicas.
func _on_pause_settings_pressed() -> void:
	$Interface/PausePanel/PauseCard.visible = false
	settings_card.visible = true
	$Interface/PausePanel/SettingsCard/Fullscreen.grab_focus()


## Retorna do painel de configurações para as opções da pausa.
func _on_pause_settings_close_pressed() -> void:
	settings_card.visible = false
	$Interface/PausePanel/PauseCard.visible = true
	$Interface/PausePanel/PauseCard/Settings.grab_focus()


## Alterna o modo de janela e mantém o mesmo viewport lógico 16:9.
func _on_fullscreen_pressed() -> void:
	_toggle_fullscreen()


func _on_fog_toggled(enabled: bool) -> void:
	underwater_fog.call("set_fog_enabled", enabled)


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Exibe a ação com o dispositivo de entrada usado mais recentemente.
func _refresh_action_prompt() -> void:
	if not is_instance_valid(action_label) or not is_instance_valid(controls_label):
		return
	var profile := GameState.get_selected_profile()
	var action_prompt := "Espaço / J"
	var movement_prompt := "WASD / setas"
	var sprint_prompt := "Ctrl"
	match _last_input_device:
		"mouse":
			action_prompt = "clique esquerdo"
			movement_prompt = "WASD / setas"
		"controller":
			action_prompt = "botão de ação"
			movement_prompt = "analógico esquerdo"
			sprint_prompt = "botão de corrida"
	action_label.text = "%s: %s" % [action_prompt, profile.action_name]
	controls_label.text = "%s: mover    •    %s: correr    •    %s: habilidade    •    Esc: pausa    •    F11: tela cheia" % [movement_prompt, sprint_prompt, action_prompt]


## Reinicia a recarga visual e registra o uso da habilidade no tutorial.
func _on_action_used(_action_name: String, cooldown: float) -> void:
	cooldown_bar.value = 0.0
	_cooldown_label.text = "RECARREGANDO  %.1f s" % cooldown
	if _stage == EncounterStage.MOVEMENT_TUTORIAL and not _action_done:
		_action_done = true
		_update_tutorial_panel()
		_try_complete_tutorial()


## Mantém barra e texto de vida do jogador sincronizados.
func _on_player_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "VIDA  %d / %d" % [ceili(current), ceili(maximum)]


## Mantém a barra exclusiva do Guardião sincronizada com seus 700 pontos de vida.
func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_health_bar.max_value = maximum
	boss_health_bar.value = current


## Entre ondas mantém o combate ativo; após o chefe apenas abre o caminho laranja.
func _on_enemy_defeated() -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	_update_enemy_label()
	if _round_finished:
		return
	if _stage == EncounterStage.COMBAT and _enemies_alive == 0:
		_objective_completed("Onda %d de 3 vencida" % (_combat_wave + 1))
		if _combat_wave + 1 < COMBAT_WAVE_SIZES.size():
			_queue_next_combat_wave()
		else:
			_begin_boss_reveal()
	elif _stage == EncounterStage.BOSS and _enemies_alive == 0:
		arena.mark_boss_defeated()
		_objective_completed("Guardião derrotado — selo do portão rompido")
		_stage = EncounterStage.REACH_EXIT
		boss_panel.visible = false
		_set_stage_text("SAÍDA DA GRUTA")
		_set_objective("Leve uma chave-bússola ao portão laranja." if arena.has_exit_key() else "Encontre uma chave-bússola dourada para abrir o portão laranja.")


## Abre o resultado de derrota se a fase ainda estiver ativa.
func _on_player_died() -> void:
	if not _round_finished:
		_finish_round(false)


## Atualiza a quantidade de ameaças atualmente materializadas.
func _update_enemy_label() -> void:
	enemy_label.visible = _stage == EncounterStage.COMBAT and _enemies_alive > 0
	if _stage == EncounterStage.COMBAT and _combat_wave >= 0:
		enemy_label.text = "AMEAÇAS  %d  •  ONDA %d/%d" % [_enemies_alive, _combat_wave + 1, COMBAT_WAVE_SIZES.size()]
	else:
		enemy_label.text = "AMEAÇAS  %d" % _enemies_alive


## Atualiza o texto de etapa sem espalhar acesso direto ao HUD.
func _set_stage_text(text: String) -> void:
	stage_label.text = text
	if _stage != EncounterStage.COMBAT:
		enemy_label.visible = false


## Atualiza o objetivo principal sem espalhar acesso direto ao HUD.
func _set_objective(text: String) -> void:
	objective_label.text = text
	_objective_time_left = 5.0
	_objective_pinned = false
	_objective_toggle.set_pressed_no_signal(false)
	$Interface/ObjectivePanel.get_node("Layout/TextScroll").scroll_vertical = 0
	_update_objective_visibility(0.0)


## Exibe o resultado somente na derrota ou quando o jogador realmente atravessa a saída.
func _finish_round(victory: bool) -> void:
	if victory:
		_objective_completed("Prólogo concluído")
	_feedback_label.visible = false
	_feedback_time = 0.0
	FEEDBACK.pulse(result_title, Color("83dfbe") if victory else Color("ff8d99"))
	player.set_controls_enabled(false)
	_round_finished = true
	_stage = EncounterStage.COMPLETE
	boss_panel.visible = false
	result_panel.visible = true
	$Interface/TopPanel.visible = false
	$Interface/ObjectivePanel.visible = false
	tutorial_panel.visible = false
	enemy_label.visible = false
	result_title.text = "FIM DO PRÓLOGO" if victory else "VOCÊ SE AFOGOU"
	result_detail.text = "A expedição segue além da gruta. Próxima fase em desenvolvimento." if victory else "Use tentar novamente para recomeçar a sequência."
	result_title.add_theme_color_override("font_color", Color("65d6a6") if victory else Color("e85d75"))
	_set_stage_text("CONCLUÍDO" if victory else "DERROTA")
	_set_objective("Prólogo concluído." if victory else "Recupere o fôlego e tente novamente.")
	$Interface/ResultPanel/Restart.text = "Jogar novamente" if victory else "Tentar novamente"


## Cura completamente o jogador vivo quando o botão de debug é pressionado.
func _on_heal_debug_pressed() -> void:
	if is_instance_valid(player):
		player.heal_full()


## Remove toda a vida do jogador quando o botão de debug é pressionado.
func _on_kill_debug_pressed() -> void:
	if is_instance_valid(player):
		player.debug_kill()


## Recarrega a cena atual e restaura tutorial, tiles, portões e encontros.
func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Abre novamente a seleção para testar outro perfil.
func _on_change_character_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/menus/character_select.tscn")
