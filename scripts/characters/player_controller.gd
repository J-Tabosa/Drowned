extends CharacterBody2D

signal action_used(action_name: String, cooldown: float)
signal health_changed(current: float, maximum: float)
signal died

@onready var body: Polygon2D = %Body
@onready var shadow: Polygon2D = %Shadow
@onready var health_component: Node = %HealthComponent
@onready var melee_hitbox: Area2D = %MeleeHitbox
@onready var dash_hitbox: Area2D = %DashHitbox
@onready var camera: Camera2D = %Camera2D

var profile: Dictionary = {}
var facing := Vector2.DOWN
var _can_act := true
var _dashing := false
var _dead := false
var _dash_direction := Vector2.DOWN
var _knockback_velocity := Vector2.ZERO
var _arena: Node2D


## Recebe o perfil selecionado antes ou depois da entrada do jogador na árvore da cena.
func setup(character_profile: Dictionary) -> void:
	profile = character_profile
	if is_node_ready():
		_apply_profile()


## Conecta vida, registra o grupo do jogador, encontra a arena e aplica os atributos escolhidos.
func _ready() -> void:
	add_to_group("player")
	_arena = get_tree().get_first_node_in_group("walkable_area") as Node2D
	if profile.is_empty():
		profile = GameState.get_selected_profile()
	health_component.health_changed.connect(func(current: float, maximum: float) -> void: health_changed.emit(current, maximum))
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	_apply_profile()
	_configure_camera()


## Lê movimento em oito direções, processa dash/recuo, limita ao mapa e recebe ações.
func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length_squared() > 0.01:
		facing = input_vector.normalized()

	if _dashing:
		velocity = _dash_direction * 760.0
	else:
		velocity = input_vector.normalized() * float(profile.speed) + _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 850.0 * delta)

	var previous_position := global_position
	move_and_slide()
	if is_instance_valid(_arena) and not _arena.is_walkable(global_position):
		global_position = previous_position
		_knockback_velocity = Vector2.ZERO

	if Input.is_action_just_pressed("primary_action") and _can_act:
		_use_primary_action()


## Transfere cor, vida, velocidade e dano do perfil para os componentes do jogador.
func _apply_profile() -> void:
	body.color = profile.color
	body.polygon = PackedVector2Array([Vector2(-23, -34), Vector2(23, -34), Vector2(23, 34), Vector2(-23, 34)])
	shadow.polygon = PackedVector2Array([Vector2(-28, -8), Vector2(28, -8), Vector2(28, 8), Vector2(-28, 8)])
	health_component.configure(float(profile.max_health))
	melee_hitbox.damage = float(profile.damage)
	dash_hitbox.damage = float(profile.damage)


## Ajusta a câmera ao tamanho informado pela arena, evitando duplicar limites no script.
func _configure_camera() -> void:
	if not is_instance_valid(_arena):
		return
	var world_rect: Rect2 = _arena.get_world_rect()
	camera.limit_left = int(world_rect.position.x)
	camera.limit_top = int(world_rect.position.y)
	camera.limit_right = int(world_rect.end.x)
	camera.limit_bottom = int(world_rect.end.y)


## Bloqueia dano durante o dash ou após a morte.
func can_receive_damage() -> bool:
	return not _dead and not _dashing


## Calcula um impulso para longe da fonte do ataque recebido.
func receive_knockback(source_position: Vector2, force: float) -> void:
	var direction := global_position - source_position
	if direction.length_squared() < 1.0:
		direction = -facing
	_knockback_velocity = direction.normalized() * force


## Expõe a cura completa ao HUD de debug sem revelar detalhes internos do componente.
func heal_full() -> void:
	health_component.heal_full()


## Expõe a morte imediata ao HUD de debug.
func debug_kill() -> void:
	health_component.kill()


## Escolhe a habilidade do perfil, emite cooldown e impede uso repetido até ela recarregar.
func _use_primary_action() -> void:
	_can_act = false
	action_used.emit(profile.action_name, float(profile.cooldown))
	match profile.action:
		"melee":
			_animate_melee()
		"shoot":
			_animate_shoot()
		"dash":
			_animate_dash()
	get_tree().create_timer(float(profile.cooldown)).timeout.connect(func() -> void:
		if not _dead:
			_can_act = true
	)


## Ativa o golpe frontal e executa a deformação visual placeholder de ataque corpo a corpo.
func _animate_melee() -> void:
	melee_hitbox.position = facing * 58.0
	melee_hitbox.rotation = facing.angle()
	melee_hitbox.activate(0.12)
	var slash := Polygon2D.new()
	slash.color = Color(profile.color, 0.55)
	slash.polygon = PackedVector2Array([Vector2(-12, -28), Vector2(70, -20), Vector2(86, 20), Vector2(-12, 28)])
	slash.rotation = facing.angle()
	add_child(slash)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(body, "scale", Vector2(1.5, 0.78), 0.08)
	tween.tween_property(body, "modulate", Color.WHITE * 1.8, 0.05)
	await get_tree().create_timer(0.09).timeout
	body.scale = Vector2.ONE
	body.modulate = Color.WHITE
	var slash_tween := create_tween().set_parallel(true)
	slash_tween.tween_property(slash, "scale", Vector2(1.35, 1.35), 0.1)
	slash_tween.tween_property(slash, "modulate:a", 0.0, 0.1)
	slash_tween.chain().tween_callback(slash.queue_free)


## Mira no cursor, cria um projétil com dano do perfil e comprime o placeholder.
func _animate_shoot() -> void:
	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() < 100.0:
		direction = facing
	direction = direction.normalized()
	facing = direction
	var projectile := preload("res://scenes/gameplay/combat/placeholder_projectile.tscn").instantiate()
	projectile.setup(profile.color, direction, float(profile.damage))
	get_parent().add_child(projectile)
	projectile.global_position = global_position + direction * 42.0
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector2(0.72, 1.2), 0.06)
	tween.tween_property(body, "scale", Vector2(1.18, 0.9), 0.06)
	tween.tween_property(body, "scale", Vector2.ONE, 0.08)


## Ativa movimento veloz, dano de contato e invulnerabilidade durante a investida.
func _animate_dash() -> void:
	_dash_direction = facing
	_dashing = true
	dash_hitbox.damage = float(profile.damage)
	dash_hitbox.activate(0.17)
	_spawn_trail()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(body, "scale", Vector2(0.72, 1.75), 0.08)
	tween.tween_property(body, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.05)
	await get_tree().create_timer(0.17).timeout
	_dashing = false
	body.scale = Vector2.ONE
	body.modulate = Color.WHITE


## Cria cópias temporárias do retângulo para representar o rastro do dash.
func _spawn_trail() -> void:
	for index in 4:
		get_tree().create_timer(index * 0.035).timeout.connect(func() -> void:
			if _dead:
				return
			var trail := Polygon2D.new()
			trail.color = Color(profile.color, 0.38)
			trail.polygon = body.polygon
			trail.global_position = global_position
			get_parent().add_child(trail)
			var tween := trail.create_tween().set_parallel(true)
			tween.tween_property(trail, "scale", Vector2(0.5, 0.5), 0.22)
			tween.tween_property(trail, "modulate:a", 0.0, 0.22)
			tween.chain().tween_callback(trail.queue_free)
		)


## Pisca o corpo do jogador quando a vida é reduzida.
func _on_damaged(_amount: float, _source_position: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color.WHITE * 2.2, 0.04)
	tween.tween_property(body, "modulate", Color.WHITE, 0.12)


## Interrompe controles, achata o placeholder e comunica a derrota à arena.
func _on_died() -> void:
	_dead = true
	_can_act = false
	velocity = Vector2.ZERO
	body.modulate = Color("5d6872")
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector2(1.35, 0.35), 0.22)
	died.emit()
