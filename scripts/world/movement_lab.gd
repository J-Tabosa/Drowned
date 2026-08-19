extends Node2D

const ENEMY_SPAWNS := [
	Vector2(690, 465),
	Vector2(790, 930),
	Vector2(1040, 610),
	Vector2(1220, 910),
	Vector2(1450, 430),
	Vector2(1690, 670),
	Vector2(1830, 980),
	Vector2(2010, 690),
]

@onready var player_spawn: Marker2D = %PlayerSpawn
@onready var character_label: Label = %CharacterLabel
@onready var action_label: Label = %ActionLabel
@onready var cooldown_bar: ProgressBar = %CooldownBar
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var enemy_label: Label = %EnemyLabel
@onready var result_panel: ColorRect = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_detail: Label = %ResultDetail

var player: CharacterBody2D
var _enemies_alive := 0
var _round_finished := false


## Inicializa jogador, encontros e painel de resultado da área inicial.
func _ready() -> void:
	_spawn_player()
	_spawn_enemies()
	result_panel.visible = false


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
	action_label.text = "Espaço / clique: %s" % profile.action_name
	cooldown_bar.value = 100.0
	_on_player_health_changed(player.health_component.current_health, player.health_component.max_health)


## Distribui inimigos pelos pontos definidos em ENEMY_SPAWNS e inicia o contador.
func _spawn_enemies() -> void:
	var enemy_scene := preload("res://scenes/characters/enemies/placeholder_enemy.tscn")
	for spawn_position in ENEMY_SPAWNS:
		var enemy := enemy_scene.instantiate()
		add_child(enemy)
		enemy.global_position = spawn_position
		enemy.defeated.connect(_on_enemy_defeated)
		_enemies_alive += 1
	_update_enemy_label()


## Retorna à seleção de personagem quando a ação configurada para Escape é recebida.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_selection"):
		get_tree().change_scene_to_file("res://scenes/ui/menus/character_select.tscn")


## Reinicia a barra visual de recarga sempre que o jogador usa sua habilidade.
func _on_action_used(_action_name: String, cooldown: float) -> void:
	cooldown_bar.value = 0.0
	var tween := create_tween()
	tween.tween_property(cooldown_bar, "value", 100.0, cooldown)


## Mantém barra e texto de vida sincronizados com o HealthComponent.
func _on_player_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "VIDA  %d / %d" % [ceili(current), ceili(maximum)]


## Reduz o contador e conclui a sala quando o último inimigo morre.
func _on_enemy_defeated() -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	_update_enemy_label()
	if _enemies_alive == 0 and not _round_finished:
		_finish_round(true)


## Abre o resultado de derrota se a rodada ainda estiver ativa.
func _on_player_died() -> void:
	if not _round_finished:
		_finish_round(false)


## Atualiza no HUD a quantidade restante de inimigos.
func _update_enemy_label() -> void:
	enemy_label.text = "INIMIGOS  %d" % _enemies_alive


## Bloqueia um segundo resultado e configura o painel para vitória ou derrota.
func _finish_round(victory: bool) -> void:
	_round_finished = true
	result_panel.visible = true
	result_title.text = "SALA CONCLUÍDA" if victory else "VOCÊ SE AFOGOU"
	result_detail.text = "Todos os inimigos foram derrotados." if victory else "Use reiniciar para testar novamente."
	result_title.add_theme_color_override("font_color", Color("65d6a6") if victory else Color("e85d75"))


## Cura completamente o jogador vivo quando o botão de debug é pressionado.
func _on_heal_debug_pressed() -> void:
	if is_instance_valid(player):
		player.heal_full()


## Remove toda a vida do jogador quando o botão de debug é pressionado.
func _on_kill_debug_pressed() -> void:
	if is_instance_valid(player):
		player.debug_kill()


## Recarrega a cena atual para restaurar jogador, inimigos e estado da rodada.
func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


## Abre novamente a seleção para testar outro perfil.
func _on_change_character_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/menus/character_select.tscn")
