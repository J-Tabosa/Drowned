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

const MOVEMENT_DISTANCE_REQUIRED := 220.0
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
var _skill_label: Label
var _skill_bar: ProgressBar
var _passive_label: Label
var _path_encounter_index := 0
var _echoes_found: Array[int] = []
var _near_echo := -1
var _skill_tree: ColorRect
var _tree_button: Button
var _boss_xp_awarded := false
var _defeats := 0
var _run_time := 0.0
var _approach_pack_spawned := false
var _guide_path := PackedVector2Array()
var _guide_target := Vector2.INF
var _guide_wait := 0.0


## Inicializa jogador e HUD usando exclusivamente marcadores fornecidos pelo blueprint do mapa.
func _ready() -> void:
	MusicDirector.set_context("cavern")
	_developer_mode = OS.get_cmdline_args().has("--debug")
	developer_panel.visible = _developer_mode
	pause_panel.visible = false
	settings_card.visible = false
	_create_feedback_labels()
	_style_hud()
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	_spawn_player()
	_skill_tree = preload("res://scripts/ui/skill_tree_panel.gd").new()
	$Interface.add_child(_skill_tree)
	_tree_button = Button.new()
	_tree_button.text = "Tab · Árvore · %d XP" % GameState.get_skill_xp(player.profile.id)
	_tree_button.theme = NauticalUI.theme(player.profile.color)
	_tree_button.add_theme_font_size_override("font_size", 12)
	_tree_button.pressed.connect(_open_skill_tree)
	$Interface.add_child(_tree_button)
	GameState.progression_changed.connect(_on_progression_changed)
	_layout_hud()
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
	_set_objective("Avance pela gruta. Shift esquiva; segure o ataque; Q usa o especial.")
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
	_notify("✓ " + text, Color("83dfbe"))
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
		_notify(arena.get_gate_hint(nearby), Color("efb46b"))
	_last_gate = nearby


func _on_action_ready() -> void:
	if _round_finished:
		return
	FEEDBACK.pulse(cooldown_bar, Color("83dfbe"))


func _on_action_rejected() -> void:
	if _round_finished or _reject_wait > 0.0:
		return
	_reject_wait = 0.4
	FEEDBACK.pulse(cooldown_bar, Color("efb46b"))
	FEEDBACK.pulse(_cooldown_label, Color("efb46b"))


func _on_invulnerability_changed(active: bool) -> void:
	if active:
		FEEDBACK.burst(self, player.global_position, Color("80e5ec"))


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
	_hud_columns["status"] = NauticalUI.column($Interface/TopPanel, [character_label, health_label, health_bar, action_label, cooldown_bar, _cooldown_label])
	_cooldown_label.add_theme_font_size_override("font_size", 10)
	_skill_label = Label.new()
	_skill_label.add_theme_font_size_override("font_size", 12)
	_skill_label.tooltip_text = GameState.get_selected_profile().skill_description
	_hud_columns["status"].add_child(_skill_label)
	_skill_bar = ProgressBar.new()
	_skill_bar.show_percentage = false
	_skill_bar.custom_minimum_size.y = 5
	_hud_columns["status"].add_child(_skill_bar)
	_style_bar(_skill_bar, accent)
	_passive_label = Label.new()
	_passive_label.add_theme_font_size_override("font_size", 11)
	_passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passive_label.tooltip_text = GameState.get_selected_profile().passive_description
	_hud_columns["status"].add_child(_passive_label)
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
	var music_row := HBoxContainer.new()
	music_row.name = "MusicVolume"
	settings_card.add_child(music_row)
	music_row.position = Vector2(24, 226)
	music_row.size = Vector2(300, 32)
	var music_label := Label.new()
	music_label.text = "Música"
	music_row.add_child(music_label)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = MusicDirector.music_volume
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_row.add_child(volume)
	volume.value_changed.connect(MusicDirector.set_music_volume)
	settings_card.offset_top = -174.0
	settings_card.offset_bottom = 174.0
	var close_settings: Button = settings_card.get_node("CloseSettings")
	close_settings.position.y = 280.0
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
	_place_compact_panel($Interface/TopPanel, Rect2(margin, margin, width, 184))
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
	if is_instance_valid(_tree_button):
		_place_compact_panel(_tree_button, Rect2(margin, screen.y - 62, 210, 28))
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
	_feedback_label.position = Vector2(margin, 206) * _hud_pixel_scale
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
	_refresh_skill_status()
	_check_gate_interaction()
	if player._controls_enabled:
		_run_time += delta
	_guide_wait = maxf(0.0, _guide_wait - delta)
	if _stage in [EncounterStage.REACH_COMBAT, EncounterStage.REACH_BOSS, EncounterStage.REACH_EXIT]:
		_check_story_echoes()
		if get_tree().paused:
			return
	queue_redraw()
	if _stage == EncounterStage.MOVEMENT_TUTORIAL:
		_track_tutorial()
	elif _stage == EncounterStage.REACH_COMBAT:
		_check_path_encounter()
		if player.global_position.distance_to(arena.get_anchor_position("combat_trigger")) <= COMBAT_TRIGGER_RADIUS:
			_start_combat_encounter()
	elif _stage == EncounterStage.REACH_BOSS:
		var distance: float = player.global_position.distance_to(arena.get_anchor_position("boss_spawn"))
		if not _approach_pack_spawned and distance < 2400.0 and distance > 800.0:
			_approach_pack_spawned = true
			MusicDirector.set_context("waves")
			for index in 2:
				_spawn_warned_enemy(_nearby_spawn(index, 2), _enemy_profile("hunter" if index == 0 else "sailor"))
			_notify("A guarda do fosso se aproxima", Color("efb46b"))
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
	player.skill_used.connect(_on_skill_used)
	player.skill_rejected.connect(_on_skill_rejected)
	player.passive_triggered.connect(_on_passive_triggered)
	character_label.text = profile.name
	character_label.add_theme_color_override("font_color", profile.color)
	cooldown_bar.value = 100.0
	_on_player_health_changed(player.health_component.current_health, player.health_component.max_health)
	_refresh_action_prompt()
	_refresh_skill_status()


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


## Movimento já abre a rota; corrida e ataques são aprendidos enquanto se joga.
func _try_complete_tutorial() -> void:
	if _stage != EncounterStage.MOVEMENT_TUTORIAL or not _movement_done:
		return
	_stage = EncounterStage.REACH_COMBAT
	arena.open_tutorial_gate()
	_objective_completed("Rota liberada")
	_set_objective("Siga para a Câmara dos Afogados. Ecos são opcionais: E para investigar.")
	tutorial_title.text = "LUTE EM MOVIMENTO"
	tutorial_step.text = "Shift: esquiva • segure o ataque • Q: especial."
	tutorial_progress.value = 100.0
	get_tree().create_timer(4.0, false).timeout.connect(func() -> void:
		if is_instance_valid(tutorial_panel):
			tutorial_panel.hide()
	)


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


## Os ecos mantêm a narrativa, mas exigem interação e não travam a rota principal.
func _check_story_echoes() -> void:
	var positions: Array[Vector2] = arena.get_story_echo_positions()
	var nearby := -1
	for index in positions.size():
		if not _echoes_found.has(index) and player.global_position.distance_to(positions[index]) < STORY_ECHO_RADIUS:
			nearby = index
			break
	if nearby != _near_echo and nearby >= 0:
		_notify("E: investigar eco • história opcional", Color("83dfbe"))
	_near_echo = nearby
	if nearby < 0 or not Input.is_action_just_pressed("interact") or not player._controls_enabled:
		return
	if _enemies_alive > 0:
		_notify("Afaste as ameaças antes de investigar.", Color("efb46b"))
		return
	_echoes_found.append(nearby)
	_story_echo_index = _echoes_found.size()
	arena.complete_story_echo(nearby)
	player.health_component.heal(10.0)
	player.skill_cooldown_remaining = 0.0
	if not skip_cinematics_for_tests:
		await DialogueManager.play(DIALOGUE_CATALOG.get_exploration_echo(GameState.selected_character_id, nearby))
	_notify("Eco %d/3 • +10 vida e especial pronto" % _story_echo_index, Color("83dfbe"))


func _check_path_encounter() -> void:
	if _path_encounter_index >= 2 or _enemies_alive > 0:
		return
	var reached := player.global_position.distance_to(arena.get_anchor_position("player_spawn")) > 520.0 if _path_encounter_index == 0 else player.global_position.distance_to(arena.get_story_echo_positions()[2]) < 720.0
	if not reached:
		return
	var count := 2 if _path_encounter_index == 0 else 3
	_path_encounter_index += 1
	MusicDirector.set_context("waves")
	for index in count:
		_spawn_warned_enemy(_nearby_spawn(index, count), _enemy_profile("hunter" if index == 0 and count == 3 else "sailor"))
	_notify("Afogados à vista • Shift para esquivar", Color("efb46b"))


## Posições próximas, no piso e com rota aberta; não cria inimigos atrás de portões.
func _nearby_spawn(index: int, total: int) -> Vector2:
	for attempt in 24:
		var angle := TAU * float(index) / maxf(total, 1.0) + float(attempt) * 0.48
		var radius := 340.0 + float(attempt % 3) * 80.0
		var candidate := player.global_position + Vector2.from_angle(angle) * radius
		if not arena.is_walkable(candidate, 38.0):
			continue
		if arena.get_farthest_walkable_position(candidate, player.global_position, 20.0).distance_to(player.global_position) > 24.0:
			continue
		var occupied := false
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(candidate) < 95.0:
				occupied = true
		if not occupied:
			return candidate
	# Em corredores muito estreitos, usa a ponta de um trajeto aberto.
	# Nunca recorre a um marcador distante atrás de um portão fechado.
	var best := player.global_position
	for attempt in 16:
		var angle := TAU * float(index) / maxf(total, 1.0) + float(attempt) * 0.4
		var candidate: Vector2 = arena.get_farthest_walkable_position(player.global_position, player.global_position + Vector2.from_angle(angle) * 480.0, 38.0)
		if candidate.distance_squared_to(player.global_position) > best.distance_squared_to(player.global_position):
			best = candidate
	return best


func _enemy_profile(kind: String) -> Dictionary:
	var config := {"enemy_kind": kind, "engaged": true, "max_health": 78.0, "move_speed": 135.0, "attack_damage": 12.0, "attack_windup": 0.38}
	if kind == "hunter":
		config.merge({"display_name": "Afogado Caçador", "can_charge": true, "max_health": 62.0, "move_speed": 172.0, "body_color": Color("b0dfd0"), "boss_dash_cooldown": 3.8, "boss_dash_speed": 480.0, "boss_dash_duration": 0.42, "boss_dash_telegraph_time": 0.65, "boss_dash_damage": 17.0}, true)
	elif kind == "brute":
		config.merge({"display_name": "Afogado Pesado", "max_health": 138.0, "move_speed": 112.0, "attack_damage": 22.0, "attack_range": 88.0, "attack_windup": 0.65, "attack_cooldown": 1.1, "body_color": Color("dec9ad"), "body_size": Vector2(48, 68)}, true)
	return config


func _spawn_warned_enemy(position: Vector2, config: Dictionary) -> void:
	var enemy := _spawn_enemy(position, config)
	enemy.emerge_from_ground()


## Inicia uma sequência de ondas para dar peso à câmara sem despejar tudo ao mesmo tempo.
func _start_combat_encounter() -> void:
	if _combat_spawned or _round_finished:
		return
	_combat_spawned = true
	MusicDirector.set_context("waves")
	_stage = EncounterStage.COMBAT
	tutorial_panel.visible = false
	_set_stage_text("2/3  CÂMARA DOS AFOGADOS")
	_start_next_combat_wave()


func _start_next_combat_wave() -> void:
	if _stage != EncounterStage.COMBAT or _round_finished:
		return
	_wave_transition_pending = false
	_feedback_time = 0.0
	_feedback_label.hide()
	_combat_wave += 1
	if _combat_wave >= COMBAT_WAVE_SIZES.size():
		_begin_boss_reveal()
		return
	var wave_size: int = COMBAT_WAVE_SIZES[_combat_wave]
	var patterns := [
		["sailor", "sailor", "sailor", "hunter"],
		["hunter", "sailor", "brute", "hunter", "sailor"],
		["hunter", "brute", "sailor", "hunter", "brute", "sailor"],
	]
	for index in wave_size:
		_spawn_warned_enemy(_nearby_spawn(index, wave_size), _enemy_profile(patterns[_combat_wave][index]))
	_combat_spawn_cursor += wave_size
	var names := ["PRIMEIRO CONTATO", "CAÇADORES E PESADOS", "MARÉ ALTA"]
	_set_stage_text("ONDA %d/3 • %s" % [_combat_wave + 1, names[_combat_wave]])
	_set_objective("Derrote a onda %d/3. Caçadores investem; pesados deixam aberturas após o golpe." % (_combat_wave + 1))
	_update_enemy_label()


func _queue_next_combat_wave() -> void:
	if _wave_transition_pending:
		return
	_wave_transition_pending = true
	player.health_component.heal(player.health_component.max_health * 0.12)
	player.skill_cooldown_remaining = 0.0
	_set_objective("Recupere o fôlego. A próxima onda chega em instantes.")
	if skip_cinematics_for_tests:
		call_deferred("_start_next_combat_wave")
	else:
		get_tree().create_timer(1.0, false).timeout.connect(_start_next_combat_wave)


func _begin_boss_reveal() -> void:
	MusicDirector.set_context("cavern")
	player.health_component.heal(player.health_component.max_health * 0.20)
	player.skill_cooldown_remaining = 0.0
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
	enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
	_enemies_alive += 1
	return enemy


## Cria o colosso no B e o mantém dormente durante a revelação.
func _spawn_boss_for_reveal() -> void:
	if _boss_spawned:
		return
	_boss_spawned = true
	_boss = _spawn_enemy(arena.get_anchor_position("boss_spawn"), {
		"display_name": "Guardião Abissal",
		"is_miniboss": true,
		"engaged": true,
		"body_size": Vector2(160, 170),
		"max_health": 1100.0,
		"move_speed": 148.0,
		"attack_damage": 25.0,
		"aggro_range": 1150.0,
		"attack_range": 138.0,
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
		reveal_tween.tween_property(cutscene_camera, "global_position", _boss.global_position, 0.85)
		await reveal_tween.finished
		await get_tree().create_timer(0.2, false).timeout
	if not skip_dialogue:
		await DialogueManager.play(DIALOGUE_CATALOG.get_boss_reveal(GameState.selected_character_id))
	if not instant:
		var return_tween := create_tween()
		return_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
		return_tween.tween_property(cutscene_camera, "global_position", player.global_position, 0.65)
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
	MusicDirector.set_context("boss")
	player.set_controls_enabled(false)
	var suspended_enemies: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != _boss and enemy.get("_active") == true:
			suspended_enemies.append(enemy)
			enemy.set_active(false)
	if not skip_card:
		await boss_intro_card.play(
			"GUARDIÃO ABISSAL",
			"(Guardião das Profundezas) — MINICHEFE",
			"Um colosso afogado. Seus rugidos derrubam estalactites: mova-se, desvie da investida e ataque na recuperação.",
			Color("9b58b5"), 2.7, _boss.body.texture
		)
	for enemy in suspended_enemies:
		if is_instance_valid(enemy):
			enemy.set_active(true)
	boss_panel.visible = true
	_boss.set_active(true)
	player.set_controls_enabled(true)
	_stage = EncounterStage.BOSS
	_set_stage_text("3/3  GUARDIÃO ABISSAL")
	_set_objective("Saia das sombras das estalactites, desvie da investida e ataque após os golpes.")


## Atualiza o dispositivo de entrada, alterna fullscreen/debug e mantém atalhos globais ativos.
func _input(event: InputEvent) -> void:
	if SceneTransition.busy:
		return
	if event is InputEventMouseMotion:
		_objective_mouse_position = event.position
	if DialogueManager.is_playing():
		return
	if event.is_action_pressed("skill_tree") and not event.is_echo():
		if _skill_tree.visible:
			_skill_tree.close()
		else:
			_open_skill_tree()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _skill_tree.visible:
			_skill_tree.close()
		else:
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
	if _skill_tree.visible:
		_skill_tree.close()
		return
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
	controls_label.text = "%s: mover  •  %s: correr  •  %s: ataque  •  Q / botão direito: especial  •  Shift: esquiva  •  E: eco  •  Tab: árvore  •  Esc: pausa  •  F11: tela cheia" % [movement_prompt, sprint_prompt, action_prompt]


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


## Mantém a barra exclusiva do Guardião sincronizada com sua vida.
func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_health_bar.max_value = maximum
	boss_health_bar.value = current


## Entre ondas mantém o combate ativo; após o chefe apenas abre o caminho laranja.
func _on_enemy_defeated(enemy: Node2D = null) -> void:
	_defeats += 1
	if is_instance_valid(enemy) and not enemy.is_miniboss and _defeats % 2 == 0 and not _round_finished:
		var pickup := preload("res://scripts/gameplay/breath_pickup.gd").new()
		pickup.player = player
		pickup.arena = arena
		add_child(pickup)
		pickup.global_position = enemy.global_position
	_enemies_alive = maxi(0, _enemies_alive - 1)
	_update_enemy_label()
	if _round_finished:
		return
	if _stage == EncounterStage.REACH_COMBAT and _enemies_alive == 0:
		MusicDirector.set_context("cavern")
		_notify("Caminho livre • recolha os brilhos verdes para recuperar fôlego", Color("83dfbe"))
	elif _stage == EncounterStage.REACH_BOSS and _enemies_alive == 1:
		MusicDirector.set_context("cavern")
	if _stage == EncounterStage.COMBAT and _enemies_alive == 0:
		_objective_completed("Onda %d de 3 vencida" % (_combat_wave + 1))
		if _combat_wave + 1 < COMBAT_WAVE_SIZES.size():
			_queue_next_combat_wave()
		else:
			_begin_boss_reveal()
	elif _stage == EncounterStage.BOSS and is_instance_valid(enemy) and enemy.is_miniboss:
		MusicDirector.set_context("cavern")
		arena.mark_boss_defeated()
		_objective_completed("Guardião derrotado — selo do portão rompido")
		_stage = EncounterStage.REACH_EXIT
		boss_panel.visible = false
		if not _boss_xp_awarded:
			_boss_xp_awarded = true
			GameState.collect_boss_xp(player.profile.id, 100, "guardian_prologue")
			for index in 6:
				var mote := preload("res://scripts/gameplay/breath_pickup.gd").new()
				mote.player = player
				mote.arena = arena
				mote.is_boss_xp = true
				add_child(mote)
				mote.global_position = enemy.global_position + Vector2.from_angle(TAU * index / 6.0) * 32.0
			_notify("100 XP · Tab para evoluir uma habilidade", Color("e8c36d"), "protect")
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
	MusicDirector.set_context("cavern")
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
	result_detail.text = "%d:%02d • %d inimigos derrotados • %d habilidades aprendidas\n%s" % [int(_run_time) / 60, int(_run_time) % 60, _defeats, GameState.get_learned_skills(player.profile.id).size(), "A expedição segue além da gruta." if victory else "Desvie dos ataques e busque os brilhos verdes."]
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
	MusicDirector.set_context("cavern")
	get_tree().change_scene_to_file("res://scenes/ui/menus/character_select.tscn")


## Encerra a partida e retorna à abertura sem deixar a árvore nem a música pausadas.
func _on_return_title_pressed() -> void:
	if SceneTransition.busy:
		return
	player.set_controls_enabled(false)
	pause_panel.hide()
	get_tree().paused = false
	MusicDirector.set_context("cavern")
	SceneTransition.transition_to("res://scenes/ui/menus/title_screen.tscn")


func _refresh_skill_status() -> void:
	var remaining: float = player.skill_cooldown_remaining
	_skill_bar.value = 100.0 * (1.0 - remaining / (float(player.profile.skill_cooldown) * player.skill_recharge_multiplier))
	_skill_label.text = "Q · %s · %s" % [player.profile.skill_name, "PRONTA" if remaining == 0.0 else "%.1f s" % remaining]
	_skill_label.add_theme_color_override("font_color", player.profile.color if remaining == 0.0 else Color("bdcbd4"))
	_passive_label.text = player.get_passive_status()


func _open_skill_tree() -> void:
	if get_tree().paused or SceneTransition.busy:
		return
	if not _round_finished and not player._controls_enabled:
		return
	_skill_tree.present(player.profile)


func _on_progression_changed(character_id: String) -> void:
	if character_id == player.profile.id:
		_tree_button.text = "Tab · Árvore · %d XP" % GameState.get_skill_xp(character_id)


func _on_skill_used(skill_name: String, _cooldown: float) -> void:
	_notify(skill_name, player.profile.color, "protect")
	FEEDBACK.pulse(_skill_label, player.profile.color)


func _on_skill_rejected() -> void:
	if _reject_wait <= 0.0:
		_notify("Especial recarregando ou ataque em andamento.", Color("efb46b"))
		_reject_wait = 0.45


func _on_passive_triggered(_passive_name: String) -> void:
	FEEDBACK.pulse(_passive_label, player.profile.color)


## Guia curto junto ao personagem: evita andar sem saber para onde seguir.
func _draw() -> void:
	if not is_instance_valid(player) or not player._controls_enabled or _round_finished or get_tree().paused:
		return
	var target := Vector2.INF
	if _stage == EncounterStage.MOVEMENT_TUTORIAL or _stage == EncounterStage.REACH_COMBAT:
		target = arena.get_anchor_position("combat_trigger")
	elif _stage == EncounterStage.REACH_BOSS:
		target = arena.get_anchor_position("boss_spawn")
	elif _stage == EncounterStage.COMBAT:
		var nearest := INF
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var distance: float = player.global_position.distance_squared_to(enemy.global_position)
			if distance < nearest:
				nearest = distance
				target = enemy.global_position
	elif _stage == EncounterStage.REACH_EXIT:
		if arena.has_exit_key() or arena.is_post_boss_gate_open():
			target = arena.get_anchor_position("post_boss_exit")
		else:
			var nearest := INF
			for position in arena.get_item_positions():
				var distance: float = position.distance_squared_to(player.global_position)
				if distance < nearest:
					nearest = distance
					target = position
	if not target.is_finite() or player.global_position.distance_to(target) < 210.0:
		return
	if _guide_wait <= 0.0 or _guide_target.distance_squared_to(target) > 160.0 * 160.0:
		_guide_wait = 0.5
		_guide_target = target
		_guide_path = arena.get_enemy_path(player.global_position, target, 26.0)
	while not _guide_path.is_empty() and player.global_position.distance_to(_guide_path[0]) < 115.0:
		_guide_path.remove_at(0)
	var waypoint := _guide_path[0] if not _guide_path.is_empty() else target
	var direction := player.global_position.direction_to(waypoint)
	var center := to_local(player.global_position) + direction * 90.0
	var side := direction.orthogonal()
	draw_polyline(PackedVector2Array([center - direction * 9 + side * 8, center + direction * 5, center - direction * 9 - side * 8]), Color("83dfbe"), 3.0, true)
