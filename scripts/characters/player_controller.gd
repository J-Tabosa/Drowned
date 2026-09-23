extends CharacterBody2D

signal action_used(action_name: String, cooldown: float)
signal health_changed(current: float, maximum: float)
signal died

const SPRINT_MULTIPLIER := 1.55
const BASE_VISUAL_SCALE := Vector2.ONE
const ANCHOR_WIND_TEXTURE := preload("res://assets/sprites/effects/anchor_wind_sweep.png")

@onready var body: CharacterAnimation = %Body
@onready var shadow: Polygon2D = %Shadow
@onready var health_component: Node = %HealthComponent
@onready var melee_hitbox: Area2D = %MeleeHitbox
@onready var dash_hitbox: Area2D = %DashHitbox
@onready var dive_hitbox: Area2D = %DiveHitbox
@onready var camera: Camera2D = %Camera2D

var profile: Dictionary = {}
var facing := Vector2.DOWN
var _can_act := true
var _dashing := false
var _diving := false
var _dead := false
var _dash_direction := Vector2.DOWN
var _knockback_velocity := Vector2.ZERO
var _arena: Node2D
var _controls_enabled := true
var _base_collision_mask := 0


## Recebe o perfil selecionado antes ou depois da entrada do jogador na árvore da cena.
func setup(character_profile: Dictionary) -> void:
	profile = character_profile
	if is_node_ready():
		_apply_profile()


## Conecta vida, registra o grupo do jogador, encontra a arena e aplica os atributos escolhidos.
func _ready() -> void:
	add_to_group("player")
	_base_collision_mask = collision_mask
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
	if _dead or not _controls_enabled:
		velocity = Vector2.ZERO
		body.set_locomotion(false, false)
		return
	if _diving:
		velocity = Vector2.ZERO
		body.set_locomotion(false, false)
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length_squared() > 0.01:
		facing = input_vector.normalized()
		if absf(facing.x) > 0.08 and not body.is_action_playing():
			body.flip_h = facing.x < 0.0

	if _dashing:
		velocity = _dash_direction * 760.0
	else:
		var sprint_multiplier := SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1.0
		velocity = input_vector.normalized() * float(profile.speed) * sprint_multiplier + _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 850.0 * delta)

	var previous_position := global_position
	move_and_slide()
	if is_instance_valid(_arena) and not _arena.is_walkable(global_position):
		global_position = previous_position
		_knockback_velocity = Vector2.ZERO
	body.set_locomotion(global_position.distance_squared_to(previous_position) > 1.0, Input.is_action_pressed("sprint"))

	if Input.is_action_just_pressed("primary_action") and _can_act:
		_use_primary_action()


## Transfere cor, vida, velocidade e dano do perfil para os componentes do jogador.
func _apply_profile() -> void:
	var sprite_path := String(profile.get("animation_sheet", profile.get("sprite", "")))
	var sheet: Texture2D = null
	if ResourceLoader.exists(sprite_path):
		sheet = load(sprite_path) as Texture2D
	body.configure(sheet)
	body.visible = body.texture != null
	body.scale = BASE_VISUAL_SCALE
	body.modulate = Color.WHITE
	shadow.polygon = PackedVector2Array([Vector2(-28, -8), Vector2(28, -8), Vector2(28, 8), Vector2(-28, 8)])
	health_component.configure(float(profile.max_health))
	melee_hitbox.damage = float(profile.damage)
	dash_hitbox.damage = float(profile.damage)
	dive_hitbox.damage = float(profile.damage)


## Ajusta a câmera ao tamanho informado pela arena, evitando duplicar limites no script.
func _configure_camera() -> void:
	if not is_instance_valid(_arena):
		return
	var world_rect: Rect2 = _arena.get_world_rect()
	camera.limit_left = int(world_rect.position.x)
	camera.limit_top = int(world_rect.position.y)
	camera.limit_right = int(world_rect.end.x)
	camera.limit_bottom = int(world_rect.end.y)


## Bloqueia dano durante dash, mergulho ou após a morte.
func can_receive_damage() -> bool:
	return not _dead and not _dashing and not _diving


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


## Permite que diálogos e apresentações cinematográficas suspendam o controle sem pausar o mundo.
func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled and not _dead
	if not _controls_enabled:
		velocity = Vector2.ZERO
		body.set_locomotion(false, false)


## Informa se o modificador de corrida está pressionado para HUD e testes.
func is_sprinting() -> bool:
	return _controls_enabled and not _dashing and Input.is_action_pressed("sprint")


## Escolhe a habilidade do perfil, emite cooldown e impede uso repetido até ela recarregar.
func _use_primary_action() -> void:
	_can_act = false
	action_used.emit(profile.action_name, float(profile.cooldown))
	match profile.action:
		"melee":
			body.play_action(0.42)
		"shoot":
			body.play_action(0.48)
		"dive":
			body.play_action(0.50)
		_:
			body.play_action(0.40)
	match profile.action:
		"melee":
			_animate_melee()
		"shoot":
			_animate_shoot()
		"dash":
			_animate_dash()
		"dive":
			_animate_dive()
	get_tree().create_timer(float(profile.cooldown), false).timeout.connect(func() -> void:
		if not _dead:
			_can_act = true
	)


## Ativa o golpe quando a âncora alcança o arco principal da animação.
func _animate_melee() -> void:
	var attack_direction := _get_cursor_direction(facing)
	facing = attack_direction
	body.flip_h = attack_direction.x < -0.08
	melee_hitbox.position = attack_direction * 72.0
	melee_hitbox.rotation = facing.angle()
	var wind := Sprite2D.new()
	wind.texture = ANCHOR_WIND_TEXTURE
	wind.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wind.position = attack_direction * 84.0
	wind.rotation = facing.angle()
	wind.scale = Vector2.ONE * 0.045
	wind.modulate.a = 0.0
	wind.z_index = 1
	add_child(wind)
	var wind_entry := create_tween().set_parallel(true)
	wind_entry.tween_property(wind, "scale", Vector2.ONE * 0.075, 0.14).set_delay(0.08)
	wind_entry.tween_property(wind, "modulate:a", 0.84, 0.08).set_delay(0.12)
	await get_tree().create_timer(0.21, false).timeout
	if _dead:
		wind.queue_free()
		return
	melee_hitbox.activate(0.12)
	await get_tree().create_timer(0.12, false).timeout
	var wind_exit := create_tween().set_parallel(true)
	wind_exit.tween_property(wind, "scale", Vector2.ONE * 0.09, 0.12)
	wind_exit.tween_property(wind, "modulate:a", 0.0, 0.12)
	wind_exit.chain().tween_callback(wind.queue_free)


## Mira no cursor e lança o arpão quando a pose de disparo chega ao impacto.
func _animate_shoot() -> void:
	var direction := _get_cursor_direction(facing)
	facing = direction
	body.flip_h = direction.x < -0.08
	await get_tree().create_timer(0.24, false).timeout
	if _dead:
		return
	var projectile := preload("res://scenes/gameplay/combat/placeholder_projectile.tscn").instantiate()
	projectile.setup(profile.color, direction, float(profile.damage), 1480.0, 300.0)
	get_parent().add_child(projectile)
	# The animation faces horizontally: emit from the drawn harpoon muzzle,
	# while keeping the flight direction aimed at the cursor.
	var muzzle := Vector2(-52.0 if body.flip_h else 52.0, -14.0)
	projectile.global_position = body.to_global(muzzle)


## Marca um ponto no cursor e mergulha até ele, causando dano em área ao retornar.
func _animate_dive() -> void:
	_diving = true
	set_collision_mask_value(2, false)
	var direction := _get_cursor_direction(facing)
	var mouse_distance := global_position.distance_to(get_global_mouse_position())
	var dive_distance := clampf(mouse_distance, 120.0, 300.0)
	var target := _find_dive_target(global_position + direction * dive_distance)
	var marker := _create_dive_marker(target)
	var marker_tween := create_tween().set_parallel(true)
	marker_tween.tween_property(marker, "scale", Vector2(0.7, 0.7), 0.2)
	marker_tween.tween_property(marker, "modulate:a", 0.85, 0.2)
	var body_tween := create_tween()
	body_tween.tween_property(body, "modulate:a", 0.0, 0.18)
	await get_tree().create_timer(0.2, false).timeout
	if is_instance_valid(marker):
		marker.queue_free()
	if _dead:
		_diving = false
		collision_mask = _base_collision_mask
		body.modulate.a = 1.0
		return
	global_position = target
	body.jump_to_action_frame(4)
	dive_hitbox.position = Vector2.ZERO
	dive_hitbox.damage = float(profile.damage) * 1.35
	dive_hitbox.activate(0.18)
	_create_dive_splash()
	var return_tween := create_tween()
	return_tween.tween_property(body, "modulate:a", 1.0, 0.16)
	await get_tree().create_timer(0.22, false).timeout
	_diving = false
	collision_mask = _base_collision_mask
	body.modulate = Color.WHITE


func _get_cursor_direction(default_direction: Vector2) -> Vector2:
	var cursor_offset := get_global_mouse_position() - global_position
	if cursor_offset.length_squared() < 100.0:
		return default_direction.normalized()
	return cursor_offset.normalized()


func _find_dive_target(requested_target: Vector2) -> Vector2:
	if not is_instance_valid(_arena):
		return requested_target
	if _arena.has_method("get_farthest_walkable_position"):
		return _arena.get_farthest_walkable_position(global_position, requested_target, 28.0)
	var direction := (requested_target - global_position).normalized()
	var distance := global_position.distance_to(requested_target)
	var last_walkable := global_position
	for step in range(12, ceili(distance) + 12, 12):
		var candidate := global_position + direction * minf(float(step), distance)
		if not _arena.is_walkable(candidate, 28.0):
			break
		last_walkable = candidate
	return last_walkable


func _create_dive_marker(target: Vector2) -> Polygon2D:
	var marker := Polygon2D.new()
	var points := PackedVector2Array()
	for index in 20:
		points.append(Vector2.from_angle(TAU * float(index) / 20.0) * 92.0)
	marker.polygon = points
	marker.color = Color(profile.color, 0.18)
	marker.global_position = target
	marker.z_index = -1
	get_parent().add_child(marker)
	return marker


func _create_dive_splash() -> void:
	var splash := Line2D.new()
	var points := PackedVector2Array()
	for index in 25:
		points.append(Vector2.from_angle(TAU * float(index) / 24.0) * 72.0)
	splash.points = points
	splash.width = 5.0
	splash.antialiased = true
	splash.default_color = Color(profile.color, 0.76)
	splash.global_position = global_position
	get_parent().add_child(splash)
	var tween := splash.create_tween().set_parallel(true)
	tween.tween_property(splash, "scale", Vector2(1.55, 1.55), 0.24)
	tween.tween_property(splash, "modulate:a", 0.0, 0.24)
	tween.chain().tween_callback(splash.queue_free)


## Ativa movimento veloz e ignora somente a camada física dos inimigos pequenos durante o dash.
func _animate_dash() -> void:
	_dash_direction = facing
	_dashing = true
	set_collision_mask_value(2, false)
	dash_hitbox.damage = float(profile.damage)
	dash_hitbox.activate(0.17)
	_spawn_trail()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(body, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.05)
	await get_tree().create_timer(0.17, false).timeout
	_dashing = false
	collision_mask = _base_collision_mask
	body.modulate = Color.WHITE


## Cria cópias temporárias do retângulo para representar o rastro do dash.
func _spawn_trail() -> void:
	for index in 4:
		get_tree().create_timer(index * 0.035).timeout.connect(func() -> void:
			if _dead:
				return
			var trail := Sprite2D.new()
			trail.texture = body.texture
			trail.hframes = body.hframes
			trail.vframes = body.vframes
			trail.frame = body.frame
			trail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			trail.flip_h = body.flip_h
			trail.modulate = Color(profile.color, 0.38)
			get_parent().add_child(trail)
			trail.global_position = global_position + body.position
			trail.scale = BASE_VISUAL_SCALE
			var tween := trail.create_tween().set_parallel(true)
			tween.tween_property(trail, "scale", BASE_VISUAL_SCALE * 0.5, 0.22)
			tween.tween_property(trail, "modulate:a", 0.0, 0.22)
			tween.chain().tween_callback(trail.queue_free)
		)


## Pisca o corpo do jogador quando a vida é reduzida.
func _on_damaged(_amount: float, _source_position: Vector2) -> void:
	body.play_hurt()
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color.WHITE * 2.2, 0.04)
	tween.tween_property(body, "modulate", Color.WHITE, 0.12)


## Interrompe controles, achata o placeholder e comunica a derrota à arena.
func _on_died() -> void:
	_dead = true
	_can_act = false
	collision_mask = _base_collision_mask
	velocity = Vector2.ZERO
	body.modulate = Color("5d6872")
	body.play_death()
	died.emit()
