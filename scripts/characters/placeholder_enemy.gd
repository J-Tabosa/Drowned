extends CharacterBody2D

signal defeated

@export var move_speed := 105.0
@export var attack_damage := 18.0
@export var max_health := 80.0
@export var aggro_range := 470.0
@export var attack_range := 74.0
@export var attack_cooldown := 0.9
@export var display_name := "Afogado"
@export var body_color := Color("8c52ad")
@export var body_size := Vector2(42, 58)
@export var boss_dash_cooldown := 3.4
@export var boss_dash_speed := 670.0
@export var boss_dash_duration := 0.52
@export var boss_dash_telegraph_time := 0.85
@export var boss_dash_damage := 38.0

@onready var body: Polygon2D = %Body
@onready var shadow: Polygon2D = $Shadow
@onready var eye: Polygon2D = $Body/Eye
@onready var health_component: Node = %HealthComponent
@onready var attack_hitbox: Area2D = %AttackHitbox

var is_miniboss := false
var _target: Node2D
var _can_attack := true
var _dead := false
var _enraged := false
var _active := true
var _boss_dashing := false
var _boss_telegraphing := false
var _boss_dash_timer := 2.2
var _boss_dash_direction := Vector2.DOWN
var _dash_telegraph: Polygon2D
var _knockback_velocity := Vector2.ZERO
var _arena: Node2D


## Recebe uma variação antes da entrada na árvore, permitindo reutilizar a mesma cena como mini-chefe.
func setup(config: Dictionary) -> void:
	display_name = String(config.get("display_name", display_name))
	is_miniboss = bool(config.get("is_miniboss", is_miniboss))
	move_speed = float(config.get("move_speed", move_speed))
	attack_damage = float(config.get("attack_damage", attack_damage))
	max_health = float(config.get("max_health", max_health))
	aggro_range = float(config.get("aggro_range", aggro_range))
	attack_range = float(config.get("attack_range", attack_range))
	attack_cooldown = float(config.get("attack_cooldown", attack_cooldown))
	body_color = config.get("body_color", body_color)
	body_size = config.get("body_size", body_size)
	boss_dash_cooldown = float(config.get("boss_dash_cooldown", boss_dash_cooldown))
	boss_dash_speed = float(config.get("boss_dash_speed", boss_dash_speed))
	boss_dash_duration = float(config.get("boss_dash_duration", boss_dash_duration))
	boss_dash_telegraph_time = float(config.get("boss_dash_telegraph_time", boss_dash_telegraph_time))
	boss_dash_damage = float(config.get("boss_dash_damage", boss_dash_damage))
	if is_node_ready():
		_apply_variant()


## Registra o inimigo, aplica sua variação, conecta sinais e localiza jogador e arena atuais.
func _ready() -> void:
	add_to_group("enemies")
	_arena = get_tree().get_first_node_in_group("walkable_area") as Node2D
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	_apply_variant()
	_target = get_tree().get_first_node_in_group("player") as Node2D


## Persegue o jogador próximo, respeita o contorno irregular e ataca dentro do alcance.
func _physics_process(delta: float) -> void:
	if _dead or not _active:
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node2D
		return

	var offset := _target.global_position - global_position
	var distance := offset.length()
	var direction := offset.normalized() if distance > 1.0 else Vector2.ZERO
	if is_miniboss:
		_boss_dash_timer -= delta
		if _boss_dashing:
			_process_boss_dash_motion()
			return
		if _boss_telegraphing:
			velocity = Vector2.ZERO
			return
		if _boss_dash_timer <= 0.0 and distance > attack_range * 1.3 and distance < 980.0:
			_start_boss_dash(direction)
			return
	if distance < aggro_range and distance > attack_range - 10.0:
		velocity = direction * move_speed + _knockback_velocity
	else:
		velocity = _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 720.0 * delta)
	var previous_position := global_position
	move_and_slide()
	if is_instance_valid(_arena) and not _arena.is_walkable(global_position, 24.0):
		global_position = previous_position
		_knockback_velocity = Vector2.ZERO

	if distance <= attack_range and _can_attack:
		_attack(direction)


## Ajusta aparência, colisões, alcance e vida conforme a configuração recebida.
func _apply_variant() -> void:
	body.color = body_color
	var half_size := body_size * 0.5
	body.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y),
	])
	shadow.position.y = half_size.y + 4.0
	shadow.polygon = PackedVector2Array([
		Vector2(-half_size.x * 1.15, -8), Vector2(half_size.x * 1.15, -8),
		Vector2(half_size.x * 1.15, 8), Vector2(-half_size.x * 1.15, 8),
	])
	eye.position.y = -half_size.y * 0.28
	eye.scale = Vector2.ONE * (1.8 if is_miniboss else 1.0)

	var body_shape := $CollisionShape2D.shape.duplicate() as RectangleShape2D
	body_shape.size = body_size
	$CollisionShape2D.shape = body_shape
	var hurtbox_shape := $Hurtbox/CollisionShape2D.shape.duplicate() as RectangleShape2D
	hurtbox_shape.size = body_size * 0.94
	$Hurtbox/CollisionShape2D.shape = hurtbox_shape
	var attack_shape := $AttackHitbox/CollisionShape2D.shape.duplicate() as RectangleShape2D
	attack_shape.size = Vector2(maxf(58.0, body_size.x * 1.35), maxf(44.0, body_size.y * 0.78))
	$AttackHitbox/CollisionShape2D.shape = attack_shape
	health_component.configure(max_health)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = 390.0 if is_miniboss else 250.0
	collision_layer = 16 if is_miniboss else 2
	z_index = 3 if is_miniboss else 1


## Informa à Hurtbox se o inimigo ainda pode ser atingido.
func can_receive_damage() -> bool:
	return not _dead and _active


## Identifica a categoria física usada pelo dash do Mergulhador.
func is_small_enemy() -> bool:
	return not is_miniboss


## Ativa ou adormece o inimigo; o Guardião usa isso durante a revelação da câmera.
func set_active(active: bool) -> void:
	_active = active and not _dead
	velocity = Vector2.ZERO
	body.modulate = Color.WHITE if _active else Color(0.38, 0.42, 0.52, 0.72)
	if _active and is_miniboss:
		_boss_dash_timer = 1.6


## Converte a origem do golpe em impulso para afastar o inimigo.
func receive_knockback(source_position: Vector2, force: float) -> void:
	var direction := global_position - source_position
	if direction.length_squared() < 1.0:
		direction = Vector2.DOWN
	_knockback_velocity = direction.normalized() * force


## Posiciona a Hitbox na direção do jogador, anima o corpo e inicia o intervalo do ataque.
func _attack(direction: Vector2) -> void:
	_can_attack = false
	attack_hitbox.position = direction * (body_size.x * 0.65)
	attack_hitbox.rotation = direction.angle()
	attack_hitbox.activate(0.12)
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector2(1.35, 0.75), 0.08 if not is_miniboss else 0.13)
	tween.tween_property(body, "scale", Vector2.ONE, 0.12)
	get_tree().create_timer(attack_cooldown).timeout.connect(func() -> void:
		if not _dead:
			_can_attack = true
	)


## Exibe uma faixa de perigo, espera o jogador reagir e então inicia o dash do mini-chefe.
func _start_boss_dash(direction: Vector2) -> void:
	if _boss_telegraphing or _boss_dashing or _dead or not _active:
		return
	_boss_telegraphing = true
	_boss_dash_direction = direction if direction.length_squared() > 0.01 else Vector2.DOWN
	_show_dash_telegraph(_boss_dash_direction)
	await get_tree().create_timer(boss_dash_telegraph_time).timeout
	_clear_dash_telegraph()
	if _dead or not _active:
		_boss_telegraphing = false
		return
	_boss_telegraphing = false
	_boss_dashing = true
	attack_hitbox.position = Vector2.ZERO
	attack_hitbox.damage = boss_dash_damage
	attack_hitbox.knockback_force = 520.0
	attack_hitbox.activate(boss_dash_duration)
	var stretch_tween := create_tween().set_parallel(true)
	stretch_tween.tween_property(body, "scale", Vector2(0.68, 1.62), 0.1)
	stretch_tween.tween_property(body, "modulate", Color(1.8, 1.35, 2.0, 1.0), 0.1)
	await get_tree().create_timer(boss_dash_duration).timeout
	_boss_dashing = false
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = 390.0
	body.scale = Vector2.ONE
	body.modulate = Color.WHITE
	_boss_dash_timer = boss_dash_cooldown


## Move o Guardião durante o dash e interrompe a investida ao alcançar uma parede do mapa.
func _process_boss_dash_motion() -> void:
	velocity = _boss_dash_direction * boss_dash_speed
	var previous_position := global_position
	move_and_slide()
	if is_instance_valid(_arena) and not _arena.is_walkable(global_position, 58.0):
		global_position = previous_position
		velocity = Vector2.ZERO
		_boss_dashing = false
		_boss_dash_timer = boss_dash_cooldown


## Cria no mundo o retângulo translúcido que antecipa direção, largura e alcance da investida.
func _show_dash_telegraph(direction: Vector2) -> void:
	_clear_dash_telegraph()
	var dash_distance := boss_dash_speed * boss_dash_duration
	var half_width := body_size.x * 0.72
	_dash_telegraph = Polygon2D.new()
	_dash_telegraph.polygon = PackedVector2Array([
		Vector2(0, -half_width), Vector2(dash_distance, -half_width),
		Vector2(dash_distance, half_width), Vector2(0, half_width),
	])
	_dash_telegraph.color = Color(0.87, 0.22, 0.52, 0.30)
	_dash_telegraph.global_position = global_position
	_dash_telegraph.rotation = direction.angle()
	_dash_telegraph.z_index = 2
	get_parent().add_child(_dash_telegraph)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([
		Vector2(0, -half_width), Vector2(dash_distance, -half_width),
		Vector2(dash_distance, half_width), Vector2(0, half_width),
		Vector2(0, -half_width),
	])
	outline.width = 5.0
	outline.default_color = Color(1.0, 0.35, 0.55, 0.82)
	_dash_telegraph.add_child(outline)
	var warning_tween := _dash_telegraph.create_tween().set_loops()
	warning_tween.tween_property(_dash_telegraph, "modulate:a", 0.35, 0.13)
	warning_tween.tween_property(_dash_telegraph, "modulate:a", 1.0, 0.13)


## Remove a previsão do dash sem deixar nós temporários na cena.
func _clear_dash_telegraph() -> void:
	if is_instance_valid(_dash_telegraph):
		_dash_telegraph.queue_free()
	_dash_telegraph = null


## Pisca o retângulo para comunicar que o dano foi recebido.
func _on_damaged(_amount: float, _source_position: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color.WHITE * 2.2, 0.04)
	tween.tween_property(body, "modulate", Color.WHITE, 0.12)
	if is_miniboss and not _enraged and health_component.current_health <= health_component.max_health * 0.5:
		_enter_enraged_phase()


## Acelera o Guardião na metade da vida e usa a troca de cor como aviso de segunda fase.
func _enter_enraged_phase() -> void:
	_enraged = true
	move_speed *= 1.28
	attack_damage *= 1.22
	attack_cooldown *= 0.72
	attack_hitbox.damage = attack_damage
	body.color = Color("e75480")
	var tween := create_tween()
	for _pulse in 3:
		tween.tween_property(body, "scale", Vector2(1.18, 1.18), 0.08)
		tween.tween_property(body, "scale", Vector2.ONE, 0.08)


## Desativa colisões, toca a animação placeholder e avisa a arena antes de se remover.
func _on_died() -> void:
	_dead = true
	_active = false
	_boss_dashing = false
	_boss_telegraphing = false
	_clear_dash_telegraph()
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(body, "scale", Vector2(1.7, 0.12), 0.35 if is_miniboss else 0.2)
	tween.tween_property(body, "modulate:a", 0.0, 0.35 if is_miniboss else 0.2)
	defeated.emit()
	await tween.finished
	queue_free()
