extends CharacterBody2D

signal defeated

@export var move_speed := 105.0
@export var attack_damage := 18.0

@onready var body: Polygon2D = %Body
@onready var health_component: Node = %HealthComponent
@onready var attack_hitbox: Area2D = %AttackHitbox

var _target: Node2D
var _can_attack := true
var _dead := false
var _knockback_velocity := Vector2.ZERO
var _arena: Node2D


## Registra o inimigo, conecta seus sinais e localiza jogador e arena atuais.
func _ready() -> void:
	add_to_group("enemies")
	_arena = get_tree().get_first_node_in_group("walkable_area") as Node2D
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	attack_hitbox.damage = attack_damage
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
	if distance < 470.0 and distance > 64.0:
		velocity = direction * move_speed + _knockback_velocity
	else:
		velocity = _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 720.0 * delta)
	var previous_position := global_position
	move_and_slide()
	if is_instance_valid(_arena) and not _arena.is_walkable(global_position, 24.0):
		global_position = previous_position
		_knockback_velocity = Vector2.ZERO

	if distance <= 74.0 and _can_attack:
		_attack(direction)


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
	attack_hitbox.position = direction * 42.0
	attack_hitbox.rotation = direction.angle()
	attack_hitbox.activate(0.12)
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector2(1.35, 0.75), 0.08)
	tween.tween_property(body, "scale", Vector2.ONE, 0.12)
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if not _dead:
			_can_attack = true
	)


## Pisca o retângulo para comunicar que o dano foi recebido.
func _on_damaged(_amount: float, _source_position: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color.WHITE * 2.2, 0.04)
	tween.tween_property(body, "modulate", Color.WHITE, 0.12)


## Desativa colisões, toca a animação placeholder e avisa a arena antes de se remover.
func _on_died() -> void:
	_dead = true
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(body, "scale", Vector2(1.45, 0.15), 0.2)
	tween.tween_property(body, "modulate:a", 0.0, 0.2)
	defeated.emit()
	await tween.finished
	queue_free()
