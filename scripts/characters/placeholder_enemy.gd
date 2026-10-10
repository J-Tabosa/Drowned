extends CharacterBody2D

signal defeated

const FEEDBACK := preload("res://scripts/components/gameplay_feedback.gd")
const NORMAL_SHEET := preload("res://assets/sprites/enemies/afogado_sheet_96.png")
const BOSS_SHEET := preload("res://assets/sprites/enemies/colosso_afogado_sheet_64.png")
const HEAVY_SHEET := preload("res://assets/sprites/enemies/afogado_pesado_sheet_64.png")
const STALACTITE := preload("res://scripts/combat/falling_stalactite.gd")

@export var move_speed := 105.0
@export var attack_damage := 18.0
@export var max_health := 80.0
@export var aggro_range := 650.0
@export var attack_range := 74.0
@export var attack_cooldown := 0.9
@export var attack_windup := 0.30
@export var display_name := "Afogado"
@export var body_color := Color.WHITE
@export var body_size := Vector2(42, 58)
@export var boss_dash_cooldown := 3.4
@export var boss_dash_speed := 670.0
@export var boss_dash_duration := 0.52
@export var boss_dash_telegraph_time := 0.85
@export var boss_dash_damage := 38.0

@onready var body: EnemyAnimation = %Body
@onready var shadow: Polygon2D = $Shadow
@onready var health_component: Node = %HealthComponent
@onready var attack_hitbox: Area2D = %AttackHitbox

var is_miniboss := false
var can_charge := false
var _target: Node2D
var _can_attack := true
var _dead := false
var _enraged := false
var _active := true
var _aggro := false
var _boss_dashing := false
var _boss_telegraphing := false
var _boss_dash_timer := 2.2
var _boss_dash_direction := Vector2.DOWN
var _dash_telegraph: Polygon2D
var _melee_telegraph: Polygon2D
var _knockback_velocity := Vector2.ZERO
var _arena: Node2D
var _radius := 20.0
var _path := PackedVector2Array()
var _path_timer := 0.0
var _path_target := Vector2.INF
var _separation := Vector2.ZERO
var _separation_timer := 0.0
var _attack_state := ""
var _attack_timer := 0.0
var _attack_direction := Vector2.DOWN
var _dash_elapsed := 0.0
var _hurt_timer := 0.0
var _damage_tween: Tween
var enemy_kind := "sailor"
var _emerging := false
var _roar_timer := 1.8
var _roaring := false
var _roar_elapsed := 0.0
var _boss_attack_index := 0


func setup(config: Dictionary) -> void:
	display_name = String(config.get("display_name", display_name))
	is_miniboss = bool(config.get("is_miniboss", is_miniboss))
	can_charge = bool(config.get("can_charge", false))
	enemy_kind = String(config.get("enemy_kind", enemy_kind))
	_aggro = bool(config.get("engaged", _aggro))
	for property in ["move_speed", "attack_damage", "max_health", "aggro_range", "attack_range", "attack_cooldown", "boss_dash_cooldown", "boss_dash_speed", "boss_dash_duration", "boss_dash_telegraph_time", "boss_dash_damage"]:
		set(property, float(config.get(property, get(property))))
	attack_windup = float(config.get("attack_windup", 0.42 if is_miniboss else attack_windup))
	body_color = config.get("body_color", body_color)
	body_size = config.get("body_size", body_size)
	if is_node_ready():
		_apply_variant()


func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_arena = get_tree().get_first_node_in_group("walkable_area") as Node2D
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	_apply_variant()
	_target = get_tree().get_first_node_in_group("player") as Node2D
	_path_timer = float(get_instance_id() % 7) * 0.04


func _physics_process(delta: float) -> void:
	if _dead or not _active:
		velocity = Vector2.ZERO
		body.set_locomotion(false)
		return
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node2D
		return
	if _target.get("_dead") == true:
		velocity = Vector2.ZERO
		body.set_locomotion(false)
		_cancel_attack()
		return
	var offset := _target.global_position - global_position
	var distance := offset.length()
	var direction := offset.normalized() if distance > 1.0 else Vector2.DOWN
	_aggro = _aggro or distance <= aggro_range
	if is_miniboss and _aggro:
		_roar_timer -= delta
		if _roaring:
			_roar_elapsed += delta
			velocity = Vector2.ZERO
			if _roar_elapsed >= 0.85:
				_release_roar()
			return
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_boss_dash_timer -= delta if _aggro else 0.0
	if _boss_telegraphing:
		_dash_elapsed += delta
		velocity = Vector2.ZERO
		if _dash_elapsed >= boss_dash_telegraph_time:
			_begin_boss_dash()
		return
	if _boss_dashing:
		_process_boss_dash_motion(delta)
		return
	if _attack_state != "":
		_process_attack(delta)
		_move_actor(_knockback_velocity, delta)
		body.set_locomotion(false)
		return
	if is_miniboss and _aggro and _roar_timer <= 0.0:
		_start_roar()
		return
	if _hurt_timer > 0.0:
		_move_actor(_knockback_velocity, delta)
		return
	if _aggro and (is_miniboss or can_charge) and _boss_dash_timer <= 0.0 and distance > attack_range * 1.3 and distance < 980.0 and _has_clear_route(_target.global_position):
		_start_boss_dash(direction)
		return
	if _aggro and distance <= attack_range and _can_attack and _has_clear_route(_target.global_position):
		_attack(direction)
		return
	var chase := Vector2.ZERO
	if _aggro and distance > attack_range * 0.72:
		chase = _chase_direction(delta) * move_speed
	_update_separation(delta)
	var before := global_position
	_move_actor(chase + _separation + _knockback_velocity, delta)
	var moved := global_position - before
	body.set_locomotion(moved.length_squared() > 0.05, _enraged)
	if absf(moved.x) > 0.05:
		body.flip_h = moved.x < 0.0


func _apply_variant() -> void:
	body.configure(BOSS_SHEET if is_miniboss else HEAVY_SHEET if enemy_kind == "brute" else NORMAL_SHEET)
	body.scale = Vector2.ONE * (3.0 if is_miniboss else 1.6 if enemy_kind == "brute" else 1.0)
	body.position = Vector2(0, -20 if is_miniboss else -6)
	body.modulate = body_color
	if not is_miniboss and enemy_kind != "brute":
		body.scale *= body_size.y / 58.0
	_radius = 42.0 if is_miniboss else 20.0
	var shape := CircleShape2D.new()
	shape.radius = _radius
	$CollisionShape2D.shape = shape
	var hurtbox_shape := RectangleShape2D.new()
	hurtbox_shape.size = body_size * 0.94
	$Hurtbox/CollisionShape2D.shape = hurtbox_shape
	var attack_shape := RectangleShape2D.new()
	attack_shape.size = Vector2(120, 112) if is_miniboss else Vector2(64, 56) if enemy_kind == "brute" else Vector2(50, 44)
	$AttackHitbox/CollisionShape2D.shape = attack_shape
	shadow.position.y = 43.0 if is_miniboss else 30.0
	shadow.scale = Vector2(1.6, 1.3) if is_miniboss else Vector2.ONE
	health_component.configure(max_health)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = 390.0 if is_miniboss else 250.0
	# Mobs usam separação suave; colisões físicas ficam com jogador, chefe e mundo.
	collision_layer = 16 if is_miniboss else 2
	collision_mask = 17
	z_index = 3 if is_miniboss else 1


## Mantém o alvo além do raio inicial e recalcula a rota pelos corredores.
func _chase_direction(delta: float) -> Vector2:
	_path_timer -= delta
	if _has_clear_route(_target.global_position):
		_path.clear()
		return global_position.direction_to(_target.global_position)
	if _path_timer <= 0.0 or _path_target.distance_squared_to(_target.global_position) > 128.0 * 128.0:
		_path_timer = 0.45
		_path_target = _target.global_position
		if is_instance_valid(_arena) and _arena.has_method("get_enemy_path"):
			_path = _arena.get_enemy_path(global_position, _path_target, _radius)
	while not _path.is_empty() and global_position.distance_squared_to(_path[0]) < 18.0 * 18.0:
		_path.remove_at(0)
	if _path.is_empty():
		return Vector2.ZERO
	while _path.size() > 1 and _has_clear_route(_path[1]):
		_path.remove_at(0)
	return global_position.direction_to(_path[0])


func _has_clear_route(target: Vector2) -> bool:
	if not is_instance_valid(_arena):
		return true
	return _arena.get_farthest_walkable_position(global_position, target, _radius).distance_squared_to(target) < 1.0


func _update_separation(delta: float) -> void:
	_separation_timer -= delta
	if _separation_timer > 0.0:
		return
	_separation_timer = 0.1
	_separation = Vector2.ZERO
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or enemy.get("_dead") == true or not enemy.get("_active"):
			continue
		var offset: Vector2 = global_position - enemy.global_position
		var limit: float = _radius + enemy._radius + 14.0
		if offset.length_squared() >= limit * limit:
			continue
		if offset.length_squared() < 25.0:
			# Saída lateral determinística evita dois mobs sobrepostos seguirem
			# com a mesma velocidade antes de conseguirem se separar.
			var lateral := global_position.direction_to(_target.global_position).orthogonal()
			if lateral.length_squared() < 0.01:
				lateral = Vector2.UP
			offset = lateral if get_instance_id() > enemy.get_instance_id() else -lateral
		_separation += offset.normalized() * (1.0 - minf(offset.length() / limit, 1.0)) * move_speed
	_separation = _separation.limit_length(move_speed * 0.7)


func _move_actor(desired: Vector2, delta: float) -> void:
	velocity = desired
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 720.0 * delta)
	var previous := global_position
	move_and_slide()
	if is_instance_valid(_arena) and not _arena.is_walkable(global_position, _radius):
		var candidate := global_position
		global_position = previous
		# Desliza em um eixo nas quinas, preservando a margem do ator.
		for axis in [Vector2(candidate.x, previous.y), Vector2(previous.x, candidate.y)]:
			if _arena.is_walkable(axis, _radius):
				global_position = axis
				break


func can_receive_damage() -> bool:
	return not _dead and _active and not _emerging


func emerge_from_ground() -> void:
	_emerging = true
	set_active(false)
	$CollisionShape2D.set_deferred("disabled", true)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/enemy_emergence.gdshader")
	material.set_shader_parameter("reveal", 0.0)
	body.material = material
	body.modulate = body_color
	# Mud fragments, no enemy name or circular spawn UI.
	var dirt := Node2D.new()
	dirt.name = "MudFragments"
	add_child(dirt)
	dirt.position.y = 26
	dirt.draw.connect(func() -> void:
		for index in 7:
			dirt.draw_rect(Rect2(index * 9 - 29, (index % 3) * 3, 6, 3), Color("536052"))
	)
	var rising := create_tween()
	rising.tween_method(func(value: float) -> void: material.set_shader_parameter("reveal", value),
		0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	await rising.finished
	if is_instance_valid(dirt):
		dirt.queue_free()
	if _dead:
		return
	body.material = null
	_emerging = false
	$CollisionShape2D.set_deferred("disabled", false)
	set_active(true)


func is_small_enemy() -> bool:
	return not is_miniboss


func set_active(active: bool) -> void:
	_active = active and not _dead
	velocity = Vector2.ZERO
	body.modulate = body_color if _active else Color(0.5, 0.6, 0.65, 0.8)
	if not _active:
		_cancel_attack()
		body.set_locomotion(false)
	if _active and is_miniboss:
		_aggro = true
		_boss_dash_timer = 1.6
		_roar_timer = 1.8


func receive_knockback(source_position: Vector2, force: float) -> void:
	if _dead:
		return
	var direction := global_position - source_position
	if direction.length_squared() < 1.0:
		direction = Vector2.DOWN
	_knockback_velocity = direction.normalized() * force * (0.0 if is_miniboss else 0.5 if enemy_kind == "brute" else 1.0)


## Direção travada na antecipação: o jogador pode sair antes do acerto.
func _attack(direction: Vector2) -> void:
	_can_attack = false
	_attack_direction = direction.normalized()
	_attack_state = "windup"
	_attack_timer = attack_windup
	velocity = Vector2.ZERO
	if absf(direction.x) > 0.08:
		body.flip_h = direction.x < 0.0
	body.play_attack(attack_windup * 2.0)
	_melee_telegraph = Polygon2D.new()
	_melee_telegraph.polygon = PackedVector2Array([Vector2(18, -22), Vector2(attack_range + 15, -30), Vector2(attack_range + 15, 30), Vector2(18, 22)])
	_melee_telegraph.color = Color(1.0, 0.45, 0.33, 0.24)
	_melee_telegraph.rotation = direction.angle()
	_melee_telegraph.z_index = -1
	add_child(_melee_telegraph)


func _process_attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	match _attack_state:
		"windup":
			_clear_melee_telegraph()
			_attack_state = "strike"
			_attack_timer = 0.12
			attack_hitbox.position = _attack_direction * (84.0 if is_miniboss else 43.0)
			attack_hitbox.rotation = _attack_direction.angle()
			attack_hitbox.damage = attack_damage
			attack_hitbox.activate(0.12)
			FEEDBACK.sound(self, "heavy_swing" if is_miniboss else "swish")
		"strike":
			attack_hitbox.deactivate()
			_attack_state = "recovery"
			_attack_timer = attack_cooldown
		"recovery":
			_attack_state = ""
			_can_attack = true


func _start_boss_dash(direction: Vector2) -> void:
	if _boss_telegraphing or _boss_dashing or _dead or not _active or _attack_state != "":
		return
	_boss_telegraphing = true
	_dash_elapsed = 0.0
	_boss_dash_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.DOWN
	if absf(direction.x) > 0.08:
		body.flip_h = direction.x < 0.0
	body.play_attack(boss_dash_telegraph_time * 2.0)
	_show_dash_telegraph(_boss_dash_direction)
	FEEDBACK.sound(self, "boss_warning")


func _begin_boss_dash() -> void:
	_clear_dash_telegraph()
	_boss_telegraphing = false
	_boss_dashing = true
	_dash_elapsed = 0.0
	body.cancel_attack()
	body.set_locomotion(true, true)
	attack_hitbox.position = Vector2.ZERO
	attack_hitbox.rotation = 0.0
	attack_hitbox.damage = boss_dash_damage
	attack_hitbox.knockback_force = 520.0
	attack_hitbox.activate(boss_dash_duration)
	FEEDBACK.sound(self, "heavy_swing")


func _process_boss_dash_motion(delta: float) -> void:
	_dash_elapsed += delta
	var previous := global_position
	velocity = _boss_dash_direction * boss_dash_speed
	move_and_slide()
	var hit_wall := false
	if is_instance_valid(_arena):
		var safe: Vector2 = _arena.get_farthest_walkable_position(previous, global_position, _radius)
		hit_wall = safe.distance_squared_to(global_position) > 1.0
		global_position = safe
	if global_position.distance_squared_to(previous) < pow(boss_dash_speed * delta * 0.3, 2):
		hit_wall = true
	if hit_wall or _dash_elapsed >= boss_dash_duration:
		_finish_boss_dash(hit_wall)


func _finish_boss_dash(hit_wall: bool) -> void:
	_boss_dashing = false
	_boss_dash_timer = boss_dash_cooldown
	attack_hitbox.deactivate()
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = 390.0
	velocity = Vector2.ZERO
	body.set_locomotion(false)
	_attack_state = "recovery"
	_attack_timer = 0.72 if hit_wall else 0.50
	_can_attack = false
	if hit_wall:
		FEEDBACK.impact(get_parent(), global_position, -_boss_dash_direction, true)
		FEEDBACK.sound(self, "heavy_hit")


func _show_dash_telegraph(direction: Vector2) -> void:
	_clear_dash_telegraph()
	var distance := boss_dash_speed * boss_dash_duration
	if is_instance_valid(_arena):
		distance = global_position.distance_to(_arena.get_farthest_walkable_position(global_position, global_position + direction * distance, _radius))
	var half_width := _radius + 8.0
	_dash_telegraph = Polygon2D.new()
	_dash_telegraph.polygon = PackedVector2Array([Vector2(0, -half_width), Vector2(distance, -half_width), Vector2(distance, half_width), Vector2(0, half_width)])
	_dash_telegraph.color = Color(0.95, 0.28, 0.30, 0.28)
	get_parent().add_child(_dash_telegraph)
	_dash_telegraph.global_position = global_position
	_dash_telegraph.rotation = direction.angle()
	_dash_telegraph.z_index = 0
	var outline := Line2D.new()
	outline.points = PackedVector2Array([Vector2(0, -half_width), Vector2(distance, -half_width), Vector2(distance, half_width), Vector2(0, half_width), Vector2(0, -half_width)])
	outline.width = 3.0
	outline.default_color = Color(1.0, 0.48, 0.32, 0.9)
	_dash_telegraph.add_child(outline)
	var warning := _dash_telegraph.create_tween().set_loops()
	warning.tween_property(_dash_telegraph, "modulate:a", 0.5, 0.18)
	warning.tween_property(_dash_telegraph, "modulate:a", 1.0, 0.18)


func _clear_dash_telegraph() -> void:
	if is_instance_valid(_dash_telegraph):
		_dash_telegraph.queue_free()
	_dash_telegraph = null


func _clear_melee_telegraph() -> void:
	if is_instance_valid(_melee_telegraph):
		_melee_telegraph.queue_free()
	_melee_telegraph = null


func _cancel_attack() -> void:
	body.cancel_attack()
	_clear_melee_telegraph()
	_clear_dash_telegraph()
	attack_hitbox.deactivate()
	_attack_state = ""
	_boss_dashing = false
	_boss_telegraphing = false
	_roaring = false
	_can_attack = true
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = 390.0 if is_miniboss else 250.0


func _on_damaged(_amount: float, source: Vector2) -> void:
	_aggro = true
	_path_timer = 0.0
	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()
	body.self_modulate = Color("ff626c")
	_damage_tween = create_tween()
	_damage_tween.tween_property(body, "self_modulate", Color.WHITE, 0.22)
	if not is_miniboss:
		_cancel_attack()
		_hurt_timer = 0.18
		body.play_hurt()
	elif not _boss_dashing and not _boss_telegraphing and not _roaring and _attack_state == "":
		body.play_hurt()
	FEEDBACK.impact(get_parent(), global_position + Vector2(0, -8), source.direction_to(global_position), is_miniboss)
	FEEDBACK.sound(self, "heavy_hit" if is_miniboss else "hit")
	if is_miniboss and not _enraged and health_component.current_health > 0.0 and health_component.current_health <= health_component.max_health * 0.5:
		_enter_enraged_phase()


func _enter_enraged_phase() -> void:
	_enraged = true
	move_speed *= 1.28
	attack_damage *= 1.22
	attack_cooldown *= 0.72
	boss_dash_cooldown *= 0.82
	_roar_timer = minf(_roar_timer, 1.0)
	body.modulate = Color("c2edf0")
	FEEDBACK.burst(get_parent(), global_position, Color("83ded7"))
	FEEDBACK.sound(self, "boss_warning")


func _start_roar() -> void:
	if _dead or not _active or not is_instance_valid(_target):
		return
	_roaring = true
	_roar_elapsed = 0.0
	velocity = Vector2.ZERO
	body.play_attack(1.0)
	FEEDBACK.sound(self, "boss_warning")
	FEEDBACK.burst(get_parent(), global_position, Color("86b7bc"))


func _release_roar() -> void:
	_roaring = false
	_roar_timer = 4.6 if _enraged else 6.0
	_boss_attack_index += 1
	var center := _target.global_position
	# Locked shadows: staying still is punished; movement opens a safe route.
	var offsets: Array[Vector2] = [Vector2.ZERO, Vector2(110, 0), Vector2(-110, 0)]
	if _enraged:
		offsets.append(Vector2(0, 110))
		offsets.append(Vector2(0, -110))
	for index in offsets.size():
		var position := center + offsets[index].rotated(_boss_attack_index * 0.65)
		if is_instance_valid(_arena) and not _arena.is_walkable(position, 20.0):
			continue
		var hazard := STALACTITE.new()
		hazard.target = _target
		hazard.boss = self
		hazard.warning_time = (0.85 if _enraged else 1.1) + index * 0.12
		hazard.damage = 28.0 if _enraged else 24.0
		get_parent().add_child(hazard)
		hazard.global_position = position
	_attack_state = "recovery"
	_attack_timer = 0.65
	_can_attack = false
	FEEDBACK.sound(self, "heavy_death")


## Remove dano e colisão imediatamente; a animação termina antes da liberação do nó.
func _on_died() -> void:
	if _dead:
		return
	_dead = true
	_emerging = false
	body.material = null
	_active = false
	velocity = Vector2.ZERO
	_cancel_attack()
	remove_from_group("enemies")
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	var duration := 0.90 if is_miniboss else 0.65
	body.play_death(duration)
	FEEDBACK.sound(self, "heavy_death" if is_miniboss else "death")
	defeated.emit()
	var tween := create_tween()
	tween.tween_interval(duration + 0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_callback(queue_free)
