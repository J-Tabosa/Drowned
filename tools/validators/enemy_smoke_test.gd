extends SceneTree

const ENEMY := preload("res://scenes/characters/enemies/placeholder_enemy.tscn")
const FEEDBACK := preload("res://scripts/components/gameplay_feedback.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	lab.skip_cinematics_for_tests = true
	root.add_child(lab)
	await physics_frame
	lab.player.set_controls_enabled(false)
	var cave: Variant = lab.arena
	var spawns: Array[Vector2] = cave.get_mob_spawn_positions()
	var boss_position: Vector2 = cave.get_anchor_position("boss_spawn")
	assert(cave.get_enemy_path(spawns[0], boss_position, 20.0).is_empty(), "Closed boss gate must block the path")
	cave.open_tutorial_gate()
	cave.open_boss_gate()
	var path: PackedVector2Array = cave.get_enemy_path(spawns[0], boss_position, 20.0)
	assert(path.size() > 2, "A path must continue through the winding cave")
	var previous: Vector2 = spawns[0]
	for point in path:
		assert(cave.is_walkable(point, 20.0))
		assert(cave.get_farthest_walkable_position(previous, point, 20.0).distance_to(point) < 1.0)
		previous = point
	print("PATH_AND_GATES_OK")

	# Detecta perto e continua seguindo bem além do raio inicial.
	lab.player.global_position = boss_position + Vector2(55, 0)
	var enemy: Variant = _spawn(lab, boss_position, {"aggro_range": 65.0})
	await physics_frame
	await physics_frame
	assert(enemy._aggro)
	enemy._cancel_attack()
	lab.player.global_position = boss_position + Vector2(400, 0)
	var distance: float = enemy.global_position.distance_to(lab.player.global_position)
	await create_timer(0.4, false).timeout
	assert(enemy.global_position.distance_to(lab.player.global_position) < distance - 20.0)
	assert(enemy.body.frame >= 6 and enemy.body.frame < 12)
	assert(enemy.get_collision_mask_value(5))
	assert(not enemy.get_collision_mask_value(2))
	enemy.queue_free()
	await process_frame
	print("PERSISTENT_CHASE_OK")

	# Separação de duas criaturas que nasceram na mesma posição.
	var first: Variant = _spawn(lab, boss_position, {"engaged": true})
	var second: Variant = _spawn(lab, boss_position, {"engaged": true})
	await create_timer(0.5, false).timeout
	assert(first.global_position.distance_to(second.global_position) > 15.0)
	assert(cave.is_walkable(first.global_position, 20.0))
	assert(cave.is_walkable(second.global_position, 20.0))
	first.queue_free()
	second.queue_free()
	await process_frame
	print("SEPARATION_OK")

	# O jogador desliza em diagonal por um inimigo sem prender nas quinas do corpo.
	lab.player.global_position = boss_position + Vector2(-55, 0)
	enemy = _spawn(lab, boss_position, {"move_speed": 0.0})
	enemy.set_physics_process(false)
	lab.player.set_controls_enabled(true)
	Input.action_press("move_right")
	Input.action_press("move_up")
	for index in 14:
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("move_up")
	assert(lab.player.global_position.y < boss_position.y - 25.0)
	assert(lab.player.global_position.x > boss_position.x - 50.0)
	lab.player.set_controls_enabled(false)
	enemy.queue_free()
	await process_frame
	print("PLAYER_SLIDE_OK")

	# Antecipação sem dano, pausa preservada, um único acerto e cancelamento por dano.
	lab.player.global_position = boss_position + Vector2(50, 0)
	enemy = _spawn(lab, boss_position, {"move_speed": 0.0, "aggro_range": 0.0})
	enemy.set_physics_process(false)
	assert(enemy.body.texture.get_size() == Vector2(576, 480))
	assert(enemy.body.vframes == 5)
	var health: float = lab.player.health_component.current_health
	enemy._attack(Vector2.RIGHT)
	assert(enemy.body.frame == 12)
	assert(not enemy.attack_hitbox.monitoring)
	enemy._process_attack(0.1)
	assert(lab.player.health_component.current_health == health)
	paused = true
	var timer: float = enemy._attack_timer
	var frame: int = enemy.body.frame
	await create_timer(0.1, true).timeout
	assert(enemy._attack_timer == timer and enemy.body.frame == frame)
	paused = false
	enemy._process_attack(0.21)
	for index in 3:
		await physics_frame
	assert(lab.player.health_component.current_health == health - enemy.attack_damage)
	var after: float = lab.player.health_component.current_health
	for index in 4:
		await physics_frame
	assert(lab.player.health_component.current_health == after)
	enemy._cancel_attack()
	await process_frame
	enemy._attack(Vector2.RIGHT)
	enemy.get_node("Hurtbox").receive_hit(10.0, enemy.global_position - Vector2(50, 0))
	assert(enemy._attack_state == "")
	assert(enemy.body.frame == 18)
	assert(enemy.body.self_modulate == Color("ff626c"))
	assert(get_nodes_in_group("hit_impacts").size() > 0)
	enemy._attack(Vector2.RIGHT)
	enemy.health_component.kill()
	assert(enemy.body.frame == 24)
	assert(not enemy.is_in_group("enemies"))
	assert(not enemy.can_receive_damage())
	await create_timer(0.75, false).timeout
	assert(enemy.body.frame == 29)
	assert(not enemy.attack_hitbox.monitoring)
	assert(enemy.get_node("CollisionShape2D").disabled)
	await create_timer(0.8, false).timeout
	assert(not is_instance_valid(enemy))
	print("ATTACK_DAMAGE_DEATH_PAUSE_OK")

	# Chefe: visual próprio, pausa na antecipação, dash cancelado na parede e na morte.
	var boss: Variant = _spawn(lab, boss_position, {"is_miniboss": true, "body_size": Vector2(104, 128), "max_health": 700.0})
	boss.set_physics_process(false)
	assert(boss.body.texture != load("res://assets/sprites/enemies/afogado_sheet_96.png"))
	assert(boss.body.scale == Vector2(3, 3))
	boss._start_boss_dash(Vector2.RIGHT)
	assert(boss._boss_telegraphing)
	paused = true
	await create_timer(0.1, true).timeout
	assert(boss._boss_telegraphing and not boss._boss_dashing)
	paused = false
	boss._begin_boss_dash()
	boss._finish_boss_dash(true)
	await process_frame
	assert(not boss._boss_dashing and not boss.attack_hitbox.monitoring)
	assert(boss.attack_hitbox.damage == boss.attack_damage)
	assert(boss._attack_state == "recovery")
	boss._cancel_attack()
	boss._start_boss_dash(Vector2.RIGHT)
	boss.health_component.take_damage(360.0)
	assert(boss._enraged)
	boss.health_component.kill()
	assert(not boss._boss_dashing and not boss._boss_telegraphing)
	assert(boss._dash_telegraph == null)
	await create_timer(0.3, false).timeout
	assert(get_nodes_in_group("hit_impacts").is_empty())
	assert(FEEDBACK._sounds.has("hit") and FEEDBACK._sounds.has("heavy_hit"))
	assert(FEEDBACK._sounds.hit.get_length() > 0.1)
	lab.queue_free()
	await process_frame
	print("ENEMY_SMOKE_TEST_OK")
	quit(0)


func _spawn(parent: Node2D, position: Vector2, config: Dictionary) -> Node2D:
	var enemy: Variant = ENEMY.instantiate()
	enemy.setup(config)
	parent.add_child(enemy)
	enemy.global_position = position
	return enemy
