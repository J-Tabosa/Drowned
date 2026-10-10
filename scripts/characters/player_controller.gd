extends CharacterBody2D

signal action_used(action_name: String, cooldown: float)
signal health_changed(current: float, maximum: float)
signal died
signal action_ready
signal action_rejected
signal invulnerability_changed(active: bool)
signal skill_used(skill_name: String, cooldown: float)
signal skill_rejected
signal passive_triggered(passive_name: String)

const SPRINT_MULTIPLIER := 1.55
const BASE_VISUAL_SCALE := Vector2.ONE
const ANCHOR_WIND_TEXTURE := preload("res://assets/sprites/effects/anchor_wind_sweep.png")
const FEEDBACK := preload("res://scripts/components/gameplay_feedback.gd")
const PROJECTILE := preload("res://scenes/gameplay/combat/placeholder_projectile.tscn")

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
var cooldown_remaining := 0.0
var _invulnerability_visible := false
var _damage_tween: Tween
var skill_cooldown_remaining := 0.0
var _skill_busy := false
var _momentum := 0
var _momentum_time := 0.0
var _steady_time := 0.0
var _steady_ready := false
var _dive_healed := false
var _flow_time := 0.0
var evade_cooldown := 0.0
var _evade_time := 0.0
var _evade_direction := Vector2.DOWN
var damage_multiplier := 1.0
var skill_recharge_multiplier := 1.0
var _learned: Array = []
var _spinning := false
var _spin_time := 0.0
var _spin_pulse := 0.0


func _process(delta: float) -> void:
	if _dead:
		return
	if not _controls_enabled:
		return
	skill_cooldown_remaining = maxf(0.0, skill_cooldown_remaining - delta)
	evade_cooldown = maxf(0.0, evade_cooldown - delta)
	_momentum_time = maxf(0.0, _momentum_time - delta)
	_flow_time = maxf(0.0, _flow_time - delta)
	if _momentum_time == 0.0:
		_momentum = 0
	if profile.id == "sharpshooter":
		var moving := Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.01
		if moving or _knockback_velocity.length() > 5.0 or _evade_time > 0.0:
			_steady_time = 0.0
			_steady_ready = false
		elif not body.is_action_playing() and not _skill_busy:
			_steady_time += delta
			if _steady_time >= 1.2 and not _steady_ready:
				_steady_ready = true
				passive_triggered.emit(profile.passive_name)
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		if cooldown_remaining == 0.0:
			_can_act = true
			action_ready.emit()
	var protected := not can_receive_damage()
	if protected != _invulnerability_visible:
		_invulnerability_visible = protected
		invulnerability_changed.emit(protected)
		queue_redraw()


func _draw() -> void:
	if _invulnerability_visible and not _dead:
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 48, Color("80e5ec"), 3.0, true)


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
	for hitbox in [melee_hitbox, dash_hitbox, dive_hitbox]:
		hitbox.hit_confirmed.connect(_on_primary_hit.bind(hitbox == dive_hitbox))
	_apply_profile()
	GameState.progression_changed.connect(_on_progression_changed)
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
	if _spinning:
		_process_spin(delta)
	if Input.is_action_just_pressed("evade"):
		_use_evade()
	if _evade_time > 0.0:
		_evade_time = maxf(0.0, _evade_time - delta)
		var before := global_position
		velocity = _evade_direction * 920.0
		move_and_slide()
		if is_instance_valid(_arena):
			global_position = _arena.get_farthest_walkable_position(before, global_position, 26.0)
		body.set_locomotion(true, true)
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
		var flow_multiplier := 1.2 if _flow_time > 0.0 else 1.0
		var spin_speed := 0.65 if _spinning else 1.0
		velocity = input_vector.normalized() * float(profile.speed) * sprint_multiplier * flow_multiplier * spin_speed + _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 850.0 * delta)

	var previous_position := global_position
	move_and_slide()
	if is_instance_valid(_arena) and not _arena.is_walkable(global_position):
		var candidate := global_position
		global_position = previous_position
		_knockback_velocity = Vector2.ZERO
		for axis in [Vector2(candidate.x, previous_position.y), Vector2(previous_position.x, candidate.y)]:
			if _arena.is_walkable(axis):
				global_position = axis
				break
	body.set_locomotion(global_position.distance_squared_to(previous_position) > 1.0, Input.is_action_pressed("sprint"))

	if Input.is_action_pressed("primary_action") and _can_act and not _skill_busy:
		_use_primary_action()
	if Input.is_action_just_pressed("special_action"):
		_use_special_action()


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
	refresh_progression()


func _on_progression_changed(character_id: String) -> void:
	if character_id == profile.id:
		refresh_progression()


func refresh_progression() -> void:
	_learned = GameState.get_learned_skills(profile.id)
	damage_multiplier = 1.2 if _learned.has("power") else 1.0
	skill_recharge_multiplier = 0.8 if _learned.has("recharge") else 1.0
	var maximum: float = float(profile.max_health) * (1.25 if _learned.has("vitality") else 1.0)
	var increase: float = maximum - health_component.max_health
	health_component.max_health = maximum
	if increase > 0.0:
		health_component.heal(increase)
	else:
		health_component.current_health = minf(health_component.current_health, maximum)
		health_component.health_changed.emit(health_component.current_health, maximum)


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
	return not _dead and not _dashing and not _diving and _evade_time <= 0.0


## Esquiva curta, sem dano: reposiciona todos os personagens sem atravessar paredes.
func _use_evade() -> void:
	if _dead or not _controls_enabled or evade_cooldown > 0.0 or _diving or _dashing or _skill_busy or body.is_action_playing():
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_evade_direction = direction.normalized() if direction.length_squared() > 0.01 else facing
	_evade_time = 0.18
	evade_cooldown = 0.8 if _learned.has("evade_mastery") else 1.1
	_knockback_velocity = Vector2.ZERO
	FEEDBACK.burst(get_parent(), global_position, Color("80e5ec"))
	FEEDBACK.sound(self, "swish")


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
		_stop_spin()
		velocity = Vector2.ZERO
		body.set_locomotion(false, false)


## Informa se o modificador de corrida está pressionado para HUD e testes.
func is_sprinting() -> bool:
	return _controls_enabled and not _dashing and Input.is_action_pressed("sprint")


## Escolhe a habilidade do perfil, emite cooldown e impede uso repetido até ela recarregar.
func _use_primary_action() -> void:
	if _dead or not _controls_enabled:
		return
	if not _can_act or _skill_busy or _evade_time > 0.0:
		action_rejected.emit()
		return
	_can_act = false
	cooldown_remaining = float(profile.cooldown)
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


## Ativa o golpe quando a âncora alcança o arco principal da animação.
func _animate_melee() -> void:
	melee_hitbox.damage = _primary_damage()
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
	var aimed := _steady_ready
	_steady_ready = false
	_steady_time = 0.0
	var direction := _get_cursor_direction(facing)
	facing = direction
	body.flip_h = direction.x < -0.08
	await get_tree().create_timer(0.24, false).timeout
	if _dead:
		return
	# The animation faces horizontally: emit from the drawn harpoon muzzle,
	# while keeping the flight direction aimed at the cursor.
	var muzzle := Vector2(-52.0 if body.flip_h else 52.0, -14.0)
	var damage: float = float(profile.damage) * (1.25 if aimed else 1.0)
	var targets := (3 if _learned.has("passive_mastery") else 2) if aimed else 1
	var origin := body.to_global(muzzle)
	if _learned.has("double_shot"):
		for side in [-1, 1]:
			_fire_harpoon(direction, damage * 0.65, targets, origin + direction.orthogonal() * side * 9)
	else:
		_fire_harpoon(direction, damage, targets, origin)


## Marca um ponto no cursor e mergulha até ele, causando dano em área ao retornar.
func _animate_dive() -> void:
	_dive_healed = false
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
	dive_hitbox.damage = float(profile.damage) * damage_multiplier * 1.35
	dive_hitbox.activate(0.18)
	_create_dive_splash()
	if _learned.has("double_echo"):
		_dive_echoes(global_position)
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
	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()
	body.self_modulate = Color("ff8d99")
	body.scale = BASE_VISUAL_SCALE * Vector2(1.06, 0.95)
	_damage_tween = create_tween().set_parallel(true)
	_damage_tween.tween_property(body, "self_modulate", Color.WHITE, 0.2)
	_damage_tween.tween_property(body, "scale", BASE_VISUAL_SCALE, 0.2)


## Interrompe controles, achata o placeholder e comunica a derrota à arena.
func _on_died() -> void:
	_dead = true
	_stop_spin()
	_evade_time = 0.0
	_skill_busy = false
	for hitbox in [melee_hitbox, dash_hitbox, dive_hitbox]:
		hitbox.deactivate()
	_invulnerability_visible = false
	queue_redraw()
	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()
	body.self_modulate = Color.WHITE
	body.scale = BASE_VISUAL_SCALE
	_can_act = false
	collision_mask = _base_collision_mask
	velocity = Vector2.ZERO
	body.modulate = Color("5d6872")
	body.play_death()
	died.emit()


func _primary_damage() -> float:
	return float(profile.damage) * damage_multiplier * (1.0 + 0.1 * _momentum)


## Passivas só respondem a dano confirmado, nunca a golpes no vazio.
func _on_primary_hit(_actor: Node2D, _amount: float, dive_hit := false) -> void:
	if _dead:
		return
	if profile.id == "breaker":
		var max_stacks := 4 if _learned.has("passive_mastery") else 3
		_momentum = mini(max_stacks, _momentum + 1)
		_momentum_time = 12.0 if _learned.has("passive_mastery") else 8.0
		if _momentum == max_stacks:
			passive_triggered.emit(profile.passive_name)
	elif profile.id == "diver" and dive_hit and not _dive_healed:
		_dive_healed = true
		health_component.heal(9.0 if _learned.has("passive_mastery") else 6.0)
		_flow_time = 3.0 if _learned.has("passive_mastery") else 2.0
		passive_triggered.emit(profile.passive_name)
		FEEDBACK.burst(get_parent(), global_position, Color("83dfbe"))


func get_passive_status() -> String:
	match profile.id:
		"breaker":
			return "%s · %d/%d" % [profile.passive_name, _momentum, 4 if _learned.has("passive_mastery") else 3]
		"sharpshooter":
			return "%s · %s" % [profile.passive_name, "PRONTA" if _steady_ready else "firme a mira"]
		"diver":
			return "%s · %s" % [profile.passive_name, "+20% velocidade" if _flow_time > 0.0 else "acerte um mergulho"]
	return ""


func _fire_harpoon(direction: Vector2, damage: float, targets: int, origin: Vector2) -> void:
	var projectile := PROJECTILE.instantiate()
	projectile.setup(profile.color, direction, damage * damage_multiplier, 1160.0, 100.0)
	projectile.pierce_count = targets
	get_parent().add_child(projectile)
	projectile.global_position = origin


## A habilidade tem recarga própria e não pode interromper um ataque ou mergulho.
func _use_special_action() -> void:
	if _dead or not _controls_enabled:
		return
	if skill_cooldown_remaining > 0.0 or _skill_busy or _diving or _dashing or _evade_time > 0.0 or body.is_action_playing():
		skill_rejected.emit()
		return
	skill_cooldown_remaining = float(profile.skill_cooldown) * skill_recharge_multiplier
	_skill_busy = true
	skill_used.emit(profile.skill_name, skill_cooldown_remaining)
	body.play_action(0.55)
	match profile.id:
		"breaker":
			_anchor_vortex()
		"sharpshooter":
			_harpoon_fan()
		"diver":
			_tidal_current()


func _anchor_vortex() -> void:
	if _learned.has("held_spin"):
		_spinning = true
		_spin_time = 0.0
		_spin_pulse = 0.0
		_momentum = 0
		_momentum_time = 0.0
		return
	var power := 90.0 + 15.0 * _momentum
	_momentum = 0
	_momentum_time = 0.0
	_skill_ring(global_position, 210.0, profile.color, 0.4)
	await get_tree().create_timer(0.22, false).timeout
	if _dead:
		return
	_damage_nearby(global_position, 210.0, power, false)
	FEEDBACK.sound(self, "heavy_swing")
	await get_tree().create_timer(0.33, false).timeout
	_skill_busy = false


func _harpoon_fan() -> void:
	var direction := _get_cursor_direction(facing)
	facing = direction
	body.flip_h = direction.x < -0.08
	_steady_ready = false
	_steady_time = 0.0
	await get_tree().create_timer(0.2, false).timeout
	if _dead:
		return
	var muzzle := body.to_global(Vector2(-52.0 if body.flip_h else 52.0, -14.0))
	for index in 5:
		_fire_harpoon(direction.rotated((index - 2) * 0.14), 22.0, 3, muzzle)
	FEEDBACK.burst(get_parent(), muzzle, profile.color)
	FEEDBACK.sound(self, "swish")
	await get_tree().create_timer(0.35, false).timeout
	_skill_busy = false


func _tidal_current() -> void:
	var direction := _get_cursor_direction(facing)
	var distance := minf(360.0, global_position.distance_to(get_global_mouse_position()))
	var center := _find_dive_target(global_position + direction * distance)
	await get_tree().create_timer(0.2, false).timeout
	if _dead:
		return
	_skill_busy = false
	for pulse in 5:
		if _dead:
			return
		_skill_ring(center, 210.0, profile.color, 0.6, true)
		_damage_nearby(center, 210.0, 16.0, true)
		FEEDBACK.sound(self, "protect")
		await get_tree().create_timer(0.65, false).timeout


func _dive_echoes(center: Vector2) -> void:
	for echo in 2:
		await get_tree().create_timer(0.28, false).timeout
		if _dead or not _controls_enabled:
			return
		_skill_ring(center, 100.0, profile.color, 0.24)
		_damage_nearby(center, 100.0, float(profile.damage) * 0.35, false)
		FEEDBACK.sound(self, "protect")


func _process_spin(delta: float) -> void:
	_spin_time += delta
	_spin_pulse -= delta
	# Always deliver the opening pulse; subsequent pulses require holding Q.
	if _spin_time >= 0.30 and (not Input.is_action_pressed("special_action") or _spin_time >= 2.1):
		_stop_spin()
		return
	body.rotation += delta * TAU * 1.8
	if _spin_pulse <= 0.0:
		_spin_pulse = 0.35
		_skill_ring(global_position, 150.0, profile.color, 0.24)
		_damage_nearby(global_position, 150.0, 27.0, false)
		FEEDBACK.sound(self, "heavy_swing")


func _stop_spin() -> void:
	if not _spinning:
		return
	_spinning = false
	_skill_busy = false
	body.rotation = 0.0


func _damage_nearby(center: Vector2, radius: float, damage: float, pull: bool) -> void:
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(center) > radius:
			continue
		if is_instance_valid(_arena) and _arena.has_method("get_farthest_walkable_position"):
			var reachable: Vector2 = _arena.get_farthest_walkable_position(center, enemy.global_position, 4.0)
			if reachable.distance_to(enemy.global_position) > 12.0:
				continue
		var hurtbox := enemy.get_node_or_null("Hurtbox")
		if hurtbox == null:
			continue
		var source := enemy.global_position + (enemy.global_position - center) if pull else center
		hurtbox.receive_hit(damage * damage_multiplier, source, 140.0 if pull else 520.0)


func _skill_ring(center: Vector2, radius: float, tint: Color, duration: float, inward := false) -> void:
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = tint
	ring.antialiased = true
	ring.process_mode = Node.PROCESS_MODE_PAUSABLE
	for index in 49:
		ring.add_point(Vector2.from_angle(TAU * index / 48.0) * radius)
	get_parent().add_child(ring)
	ring.global_position = center
	ring.scale = Vector2.ONE if inward else Vector2.ONE * 0.15
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * (0.1 if inward else 1.0), duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)
