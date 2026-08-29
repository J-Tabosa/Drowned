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
	if _dead:
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node2D
		return

	var offset := _target.global_position - global_position
	var distance := offset.length()
	var direction := offset.normalized() if distance > 1.0 else Vector2.ZERO
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
	z_index = 3 if is_miniboss else 1


## Informa à Hurtbox se o inimigo ainda pode ser atingido.
func can_receive_damage() -> bool:
	return not _dead


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
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(body, "scale", Vector2(1.7, 0.12), 0.35 if is_miniboss else 0.2)
	tween.tween_property(body, "modulate:a", 0.0, 0.35 if is_miniboss else 0.2)
	defeated.emit()
	await tween.finished
	queue_free()
