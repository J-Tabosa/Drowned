extends Node2D

const DIALOGUE_CATALOG := preload("res://scripts/narrative/dialogue_catalog.gd")

enum EncounterStage {
	MOVEMENT_TUTORIAL,
	REACH_COMBAT,
	COMBAT,
	BOSS_REVEAL,
	REACH_BOSS,
	BOSS_PRESENTATION,
	BOSS,
	COMPLETE,
}

const MOVEMENT_DISTANCE_REQUIRED := 420.0
const SPRINT_DISTANCE_REQUIRED := 180.0
const COMBAT_TRIGGER_RADIUS := 260.0
const BOSS_TRIGGER_RADIUS := 430.0

@export var skip_cinematics_for_tests := false

@onready var arena: Node2D = $Arena
@onready var cutscene_camera: Camera2D = %CutsceneCamera
@onready var boss_intro_card: CanvasLayer = %BossIntroCard
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
var _combat_spawned := false
var _boss_spawned := false
var _round_finished := false


## Inicializa jogador e HUD usando exclusivamente marcadores fornecidos pelo blueprint do mapa.
func _ready() -> void:
	_spawn_player()
	result_panel.visible = false
	boss_panel.visible = false
	tutorial_panel.visible = true
	_last_player_position = player.global_position
	_update_enemy_label()
	_update_tutorial_panel()
	_set_stage_text("1/3  EXPLORAÇÃO")
	_set_objective("Explore a gruta e pratique os controles antes de avançar.")


## Monitora requisitos e proximidade dos marcadores C e B desenhados no blueprint.
func _process(_delta: float) -> void:
	if _round_finished or not is_instance_valid(player):
		return
	if _stage == EncounterStage.MOVEMENT_TUTORIAL:
		_track_tutorial()
	elif _stage == EncounterStage.REACH_COMBAT:
		if player.global_position.distance_to(arena.get_anchor_position("combat_trigger")) <= COMBAT_TRIGGER_RADIUS:
			_start_combat_encounter()
	elif _stage == EncounterStage.REACH_BOSS:
		if player.global_position.distance_to(arena.get_anchor_position("boss_spawn")) <= BOSS_TRIGGER_RADIUS:
			_begin_boss_fight()


## Instancia o personagem no P do blueprint e conecta seus sinais ao HUD.
func _spawn_player() -> void:
	var profile := GameState.get_selected_profile()
	player = preload("res://scenes/characters/playable/placeholder_player.tscn").instantiate()
	player.setup(profile)
	add_child(player)
	player.global_position = arena.get_anchor_position("player_spawn")
	player.action_used.connect(_on_action_used)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	character_label.text = "%s  —  %s" % [profile.name, profile.role]
	character_label.add_theme_color_override("font_color", profile.color)
	action_label.text = "Espaço / J / clique: %s" % profile.action_name
	cooldown_bar.value = 100.0
	_on_player_health_changed(player.health_component.current_health, player.health_component.max_health)


## Acompanha deslocamento, corrida com Ctrl e habilidade sem depender de uma posição específica.
func _track_tutorial() -> void:
	var frame_distance := player.global_position.distance_to(_last_player_position)
	_last_player_position = player.global_position
	if frame_distance > 0.0 and frame_distance < 180.0:
		_movement_distance = minf(MOVEMENT_DISTANCE_REQUIRED, _movement_distance + frame_distance)
	if player.is_sprinting() and frame_distance > 0.25:
		_sprint_time = minf(SPRINT_DISTANCE_REQUIRED, _sprint_time + frame_distance)
	_movement_done = _movement_distance >= MOVEMENT_DISTANCE_REQUIRED
	_sprint_done = _sprint_time >= SPRINT_DISTANCE_REQUIRED
	_update_tutorial_panel()
	_try_complete_tutorial()


## Libera os tiles 1 quando movimento, corrida e habilidade foram praticados.
func _try_complete_tutorial() -> void:
	if _stage != EncounterStage.MOVEMENT_TUTORIAL:
		return
	if not _movement_done or not _sprint_done or not _action_done:
		return
	_stage = EncounterStage.REACH_COMBAT
	arena.open_tutorial_gate()
	tutorial_title.text = "CAMINHO LIBERADO"
	tutorial_step.text = "Siga o corredor até a grande câmara."
	tutorial_progress.value = 100.0
	_set_objective("Entre na Câmara dos Afogados e investigue os ruídos.")
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		if is_instance_valid(tutorial_panel):
			tutorial_panel.visible = false
	)


## Atualiza os três itens de treinamento no painel inferior.
func _update_tutorial_panel() -> void:
	var movement_state := "OK" if _movement_done else "%d%%" % int((_movement_distance / MOVEMENT_DISTANCE_REQUIRED) * 100.0)
	var sprint_state := "OK" if _sprint_done else "%d%%" % int((_sprint_time / SPRINT_DISTANCE_REQUIRED) * 100.0)
	var action_state := "OK" if _action_done else "PENDENTE"
	tutorial_step.text = "[%s] Mova-se com WASD ou setas\n[%s] Corra segurando Ctrl\n[%s] Use %s" % [
		movement_state,
		sprint_state,
		action_state,
		GameState.get_selected_profile().action_name,
	]
	var movement_ratio := _movement_distance / MOVEMENT_DISTANCE_REQUIRED
	var sprint_ratio := _sprint_time / SPRINT_DISTANCE_REQUIRED
	tutorial_progress.value = ((movement_ratio + sprint_ratio + (1.0 if _action_done else 0.0)) / 3.0) * 100.0


## Materializa os inimigos somente nos M do blueprint quando o jogador alcança C.
func _start_combat_encounter() -> void:
	if _combat_spawned or _round_finished:
		return
	_combat_spawned = true
	_stage = EncounterStage.COMBAT
	tutorial_panel.visible = false
	_set_stage_text("2/3  CÂMARA DOS AFOGADOS")
	_set_objective("Derrote todas as criaturas que cercaram o grupo.")
	var spawn_positions: Array[Vector2] = arena.get_mob_spawn_positions()
	for index in spawn_positions.size():
		_spawn_enemy(spawn_positions[index], {
			"body_color": Color("7850a3") if index % 2 == 0 else Color("436f9a"),
			"max_health": 72.0 + float(index % 3) * 10.0,
			"move_speed": 96.0 + float(index % 2) * 12.0,
		})
	_update_enemy_label()


## Reutiliza a mesma cena para mobs e chefe, mantendo as diferenças em dados.
func _spawn_enemy(spawn_position: Vector2, config: Dictionary = {}) -> CharacterBody2D:
	var enemy: CharacterBody2D = preload("res://scenes/characters/enemies/placeholder_enemy.tscn").instantiate()
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
		"body_color": Color("9b58b5"),
		"body_size": Vector2(104, 128),
		"max_health": 700.0,
		"move_speed": 118.0,
		"attack_damage": 25.0,
		"aggro_range": 1150.0,
		"attack_range": 116.0,
		"attack_cooldown": 0.82,
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


## Retorna à seleção de personagem quando Escape é recebido.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_selection"):
		get_tree().change_scene_to_file("res://scenes/ui/menus/character_select.tscn")


## Reinicia a recarga visual e registra o uso da habilidade no tutorial.
func _on_action_used(_action_name: String, cooldown: float) -> void:
	cooldown_bar.value = 0.0
	var tween := create_tween()
	tween.tween_property(cooldown_bar, "value", 100.0, cooldown)
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


## Após os mobs inicia a câmera narrativa; após o chefe abre o portão pós-chefe.
func _on_enemy_defeated() -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	_update_enemy_label()
	if _round_finished:
		return
	if _stage == EncounterStage.COMBAT and _enemies_alive == 0:
		_stage = EncounterStage.BOSS_REVEAL
		_run_boss_reveal(skip_cinematics_for_tests, skip_cinematics_for_tests)
	elif _stage == EncounterStage.BOSS and _enemies_alive == 0:
		arena.open_post_boss_gate()
		_finish_round(true)


## Abre o resultado de derrota se a fase ainda estiver ativa.
func _on_player_died() -> void:
	if not _round_finished:
		_finish_round(false)


## Atualiza a quantidade de ameaças atualmente materializadas.
func _update_enemy_label() -> void:
	enemy_label.text = "AMEAÇAS  %d" % _enemies_alive


## Atualiza o texto de etapa sem espalhar acesso direto ao HUD.
func _set_stage_text(text: String) -> void:
	stage_label.text = text


## Atualiza o objetivo principal sem espalhar acesso direto ao HUD.
func _set_objective(text: String) -> void:
	objective_label.text = text


## Configura vitória ou derrota e mantém o portão pós-chefe visível como próximo destino.
func _finish_round(victory: bool) -> void:
	_round_finished = true
	_stage = EncounterStage.COMPLETE
	boss_panel.visible = false
	result_panel.visible = true
	result_title.text = "PASSAGEM LIBERADA" if victory else "VOCÊ SE AFOGOU"
	result_detail.text = "O Guardião caiu. O portão laranja abaixo da arena está aberto." if victory else "Use reiniciar para tentar a sequência novamente."
	result_title.add_theme_color_override("font_color", Color("65d6a6") if victory else Color("e85d75"))
	_set_stage_text("CONCLUÍDO" if victory else "DERROTA")
	_set_objective("Atravesse o portão pós-chefe." if victory else "Recupere o fôlego e tente novamente.")


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
	get_tree().reload_current_scene()


## Abre novamente a seleção para testar outro perfil.
func _on_change_character_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/menus/character_select.tscn")
