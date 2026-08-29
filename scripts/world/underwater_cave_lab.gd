extends Node2D

enum EncounterStage {
	MOVEMENT_TUTORIAL,
	REACH_COMBAT,
	COMBAT,
	REACH_BOSS,
	BOSS,
	COMPLETE,
}

const MOVEMENT_DISTANCE_REQUIRED := 420.0
const COMBAT_TRIGGER_X := 2180.0
const BOSS_TRIGGER_X := 4680.0
const BOSS_SPAWN := Vector2(5680, 1840)

const COMBAT_ENEMY_SPAWNS := [
	Vector2(2510, 1420),
	Vector2(2680, 2310),
	Vector2(2960, 1130),
	Vector2(3200, 1880),
	Vector2(3450, 2470),
	Vector2(3690, 1370),
	Vector2(3890, 2110),
]

@onready var arena: Node2D = $Arena
@onready var player_spawn: Marker2D = %PlayerSpawn
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
var _stage := EncounterStage.MOVEMENT_TUTORIAL
var _enemies_alive := 0
var _movement_distance := 0.0
var _last_player_position := Vector2.ZERO
var _movement_done := false
var _action_done := false
var _combat_spawned := false
var _boss_spawned := false
var _round_finished := false
var _boss: CharacterBody2D


## Inicializa o jogador e apresenta somente o tutorial; encontros surgem ao avançar pelo mapa.
func _ready() -> void:
	_spawn_player()
	result_panel.visible = false
	boss_panel.visible = false
	tutorial_panel.visible = true
	_last_player_position = player.global_position
	_update_enemy_label()
	_update_tutorial_panel()
	_set_stage_text("1/3  TREINAMENTO")
	_set_objective("Aprenda a se mover e use a habilidade do personagem.")


## Monitora a progressão espacial e inicia cada encontro apenas ao entrar em sua câmara.
func _process(_delta: float) -> void:
	if _round_finished or not is_instance_valid(player):
		return
	if _stage == EncounterStage.MOVEMENT_TUTORIAL:
		_track_tutorial_movement()
	elif _stage == EncounterStage.REACH_COMBAT and player.global_position.x >= COMBAT_TRIGGER_X:
		_start_combat_encounter()
	elif _stage == EncounterStage.REACH_BOSS and player.global_position.x >= BOSS_TRIGGER_X:
		_start_boss_encounter()


## Instancia o perfil escolhido, conecta seus sinais e preenche o HUD.
func _spawn_player() -> void:
	var profile := GameState.get_selected_profile()
	player = preload("res://scenes/characters/playable/placeholder_player.tscn").instantiate()
	player.setup(profile)
	add_child(player)
	player.global_position = player_spawn.global_position
	player.action_used.connect(_on_action_used)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	character_label.text = "%s  —  %s" % [profile.name, profile.role]
	character_label.add_theme_color_override("font_color", profile.color)
	action_label.text = "Espaço / J / clique: %s" % profile.action_name
	cooldown_bar.value = 100.0
	_on_player_health_changed(player.health_component.current_health, player.health_component.max_health)


## Soma somente deslocamentos normais entre quadros e conclui o exercício ao atingir a distância mínima.
func _track_tutorial_movement() -> void:
	var frame_distance := player.global_position.distance_to(_last_player_position)
	_last_player_position = player.global_position
	if frame_distance > 0.0 and frame_distance < 160.0:
		_movement_distance = minf(MOVEMENT_DISTANCE_REQUIRED, _movement_distance + frame_distance)
	if not _movement_done and _movement_distance >= MOVEMENT_DISTANCE_REQUIRED:
		_movement_done = true
		_update_tutorial_panel()
		_try_complete_tutorial()
	elif not _movement_done:
		_update_tutorial_panel()


## Marca a habilidade como praticada, abre o primeiro portão quando ambos os exercícios terminam.
func _try_complete_tutorial() -> void:
	if _stage != EncounterStage.MOVEMENT_TUTORIAL or not _movement_done or not _action_done:
		return
	_stage = EncounterStage.REACH_COMBAT
	arena.open_tutorial_gate()
	tutorial_title.text = "PASSAGEM LIBERADA"
	tutorial_step.text = "Siga o brilho verde até a Câmara dos Afogados."
	tutorial_progress.value = 100.0
	_set_objective("Atravesse o portão de coral e entre na câmara central.")
	get_tree().create_timer(2.4).timeout.connect(func() -> void:
		if is_instance_valid(tutorial_panel) and _stage != EncounterStage.MOVEMENT_TUTORIAL:
			tutorial_panel.visible = false
	)


## Atualiza os dois requisitos do tutorial e usa a barra para mostrar o deslocamento acumulado.
func _update_tutorial_panel() -> void:
	var movement_state := "OK" if _movement_done else "%d%%" % int((_movement_distance / MOVEMENT_DISTANCE_REQUIRED) * 100.0)
	var action_state := "OK" if _action_done else "PENDENTE"
	tutorial_step.text = "[%s] Mova-se com WASD ou setas\n[%s] Use %s" % [
		movement_state,
		action_state,
		GameState.get_selected_profile().action_name,
	]
	tutorial_progress.value = (_movement_distance / MOVEMENT_DISTANCE_REQUIRED) * 100.0


## Cria a primeira onda somente uma vez, depois que o jogador cruza o corredor do tutorial.
func _start_combat_encounter() -> void:
	if _combat_spawned or _round_finished:
		return
	_combat_spawned = true
	_stage = EncounterStage.COMBAT
	tutorial_panel.visible = false
	_set_stage_text("2/3  PRIMEIRO COMBATE")
	_set_objective("Derrote os Afogados para romper o selo roxo.")
	for index in COMBAT_ENEMY_SPAWNS.size():
		_spawn_enemy(COMBAT_ENEMY_SPAWNS[index], {
			"body_color": Color("7850a3") if index % 2 == 0 else Color("436f9a"),
			"max_health": 72.0 + float(index % 3) * 10.0,
			"move_speed": 96.0 + float(index % 2) * 12.0,
		})
	_update_enemy_label()


## Reutiliza a cena básica de inimigo e conecta sua derrota ao diretor do encontro.
func _spawn_enemy(spawn_position: Vector2, config: Dictionary = {}) -> CharacterBody2D:
	var enemy: CharacterBody2D = preload("res://scenes/characters/enemies/placeholder_enemy.tscn").instantiate()
	if not config.is_empty():
		enemy.setup(config)
	add_child(enemy)
	enemy.global_position = spawn_position
	enemy.defeated.connect(_on_enemy_defeated)
	_enemies_alive += 1
	return enemy


## Instancia o Guardião Abissal como uma versão maior, resistente e com segunda fase.
func _start_boss_encounter() -> void:
	if _boss_spawned or _round_finished:
		return
	_boss_spawned = true
	_stage = EncounterStage.BOSS
	_set_stage_text("3/3  MINI-CHEFE")
	_set_objective("Derrote o Guardião Abissal. Ele se enfurece na metade da vida.")
	_boss = _spawn_enemy(BOSS_SPAWN, {
		"display_name": "Guardião Abissal",
		"is_miniboss": true,
		"body_color": Color("9b58b5"),
		"body_size": Vector2(104, 128),
		"max_health": 460.0,
		"move_speed": 118.0,
		"attack_damage": 24.0,
		"aggro_range": 1100.0,
		"attack_range": 116.0,
		"attack_cooldown": 0.82,
	})
	_boss.health_component.health_changed.connect(_on_boss_health_changed)
	boss_name_label.text = _boss.display_name
	boss_panel.visible = true
	_on_boss_health_changed(_boss.health_component.current_health, _boss.health_component.max_health)
	_update_enemy_label()


## Retorna à seleção de personagem quando Escape é recebido.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_selection"):
		get_tree().change_scene_to_file("res://scenes/ui/menus/character_select.tscn")


## Reinicia a recarga visual e registra o uso da habilidade durante o tutorial.
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


## Mantém a barra exclusiva do mini-chefe sincronizada.
func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_health_bar.max_value = maximum
	boss_health_bar.value = current


## Avança para o corredor final após a onda ou conclui a fase após o mini-chefe.
func _on_enemy_defeated() -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	_update_enemy_label()
	if _enemies_alive > 0 or _round_finished:
		return
	if _stage == EncounterStage.COMBAT:
		_stage = EncounterStage.REACH_BOSS
		arena.open_boss_gate()
		_set_stage_text("PASSAGEM ABERTA")
		_set_objective("Siga pelo selo roxo até o Fosso do Guardião.")
	elif _stage == EncounterStage.BOSS:
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


## Bloqueia um segundo resultado e configura o painel para vitória ou derrota.
func _finish_round(victory: bool) -> void:
	_round_finished = true
	_stage = EncounterStage.COMPLETE
	boss_panel.visible = false
	result_panel.visible = true
	result_title.text = "CAVERNA CONCLUÍDA" if victory else "VOCÊ SE AFOGOU"
	result_detail.text = "O Guardião Abissal foi derrotado. O caminho para Atlântida se abriu." if victory else "Use reiniciar para tentar a sequência novamente."
	result_title.add_theme_color_override("font_color", Color("65d6a6") if victory else Color("e85d75"))
	_set_stage_text("CONCLUÍDO" if victory else "DERROTA")
	_set_objective("Tutorial e encontro inicial finalizados." if victory else "Recupere o fôlego e tente novamente.")


## Cura completamente o jogador vivo quando o botão de debug é pressionado.
func _on_heal_debug_pressed() -> void:
	if is_instance_valid(player):
		player.heal_full()


## Remove toda a vida do jogador quando o botão de debug é pressionado.
func _on_kill_debug_pressed() -> void:
	if is_instance_valid(player):
		player.debug_kill()


## Recarrega a cena atual e restaura tutorial, portões e encontros.
func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


## Abre novamente a seleção para testar outro perfil.
func _on_change_character_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/menus/character_select.tscn")
