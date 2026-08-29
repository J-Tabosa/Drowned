extends SceneTree


## Agenda o teste para depois que a SceneTree e os autoloads estiverem disponíveis.
func _initialize() -> void:
	call_deferred("_run")


## Valida mapa em nós, três personagens, corrida, dash, encontros, chefe e debug.
func _run() -> void:
	var game_state: Variant = root.get_node_or_null("GameState")
	assert(game_state != null)
	for profile in game_state.CHARACTER_PROFILES:
		game_state.select_character(profile.id)
		var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
		root.add_child(lab)
		await process_frame
		assert(lab.player != null)
		assert(lab._enemies_alive == 0)
		var arena: Node = lab.get_node("Arena")
		var tile_counts: Dictionary = arena.get_tile_counts()
		assert(tile_counts.floor > 400)
		assert(tile_counts.wall > 80)
		assert(tile_counts.gate == 9)
		assert(arena.is_walkable(arena.get_anchor_position("player_spawn")))
		assert(arena.get_mob_spawn_positions().size() == 7)
		assert(arena.get_world_rect().size.x > 6000.0)
		assert(not arena.is_tutorial_gate_open())
		assert(not arena.is_boss_gate_open())
		assert(not arena.is_post_boss_gate_open())
		for spawn_position in arena.get_mob_spawn_positions():
			assert(arena.is_walkable(spawn_position, 24.0))
		assert(arena.is_walkable(arena.get_anchor_position("boss_spawn"), 58.0))

		Input.action_press("move_right")
		Input.action_press("sprint")
		for _sprint_frame in 3:
			await physics_frame
		assert(lab.player.is_sprinting())
		assert(lab.player.velocity.length() > float(profile.speed) * 1.4)
		Input.action_release("sprint")
		Input.action_release("move_right")

		if profile.id == "diver":
			lab.player.call("_use_primary_action")
			await physics_frame
			assert(not lab.player.get_collision_mask_value(2))
			assert(lab.player.get_collision_mask_value(5))
			await create_timer(0.22).timeout
			assert(lab.player.get_collision_mask_value(2))
		else:
			lab.player.call("_use_primary_action")
			await physics_frame

		lab.player.health_component.take_damage(20.0)
		lab._on_heal_debug_pressed()
		assert(lab.player.health_component.current_health == lab.player.health_component.max_health)
		lab.queue_free()
		await process_frame

	game_state.select_character("breaker")
	var victory_lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	victory_lab.skip_cinematics_for_tests = true
	root.add_child(victory_lab)
	await process_frame
	Input.action_press("move_right")
	Input.action_press("sprint")
	for _frame in 72:
		await physics_frame
	Input.action_release("sprint")
	Input.action_release("move_right")
	assert(victory_lab._movement_done)
	assert(victory_lab._sprint_done)
	victory_lab.player.call("_use_primary_action")
	await process_frame
	assert(victory_lab._action_done)
	assert(victory_lab.arena.is_tutorial_gate_open())

	victory_lab._start_combat_encounter()
	assert(victory_lab._enemies_alive == 7)
	for enemy in get_nodes_in_group("enemies"):
		enemy.health_component.kill()
	await process_frame
	await process_frame
	assert(victory_lab.arena.is_boss_gate_open())
	assert(is_instance_valid(victory_lab._boss))
	assert(victory_lab._boss.health_component.max_health == 700.0)
	assert(not victory_lab._boss.can_receive_damage())

	victory_lab._begin_boss_fight(true)
	await process_frame
	assert(victory_lab._boss.can_receive_damage())
	assert(victory_lab.boss_panel.visible)
	assert(victory_lab._boss.get_collision_layer_value(5))
	assert(not victory_lab._boss.get_collision_layer_value(2))
	victory_lab._boss._start_boss_dash(Vector2.RIGHT)
	await create_timer(0.12).timeout
	assert(is_instance_valid(victory_lab._boss._dash_telegraph))
	await create_timer(0.9).timeout
	assert(victory_lab._boss._boss_dashing)

	victory_lab._boss.health_component.kill()
	await process_frame
	assert(victory_lab.arena.is_post_boss_gate_open())
	assert(victory_lab.result_panel.visible)
	assert(victory_lab.result_title.text == "PASSAGEM LIBERADA")
	victory_lab.queue_free()
	await process_frame

	var death_lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	root.add_child(death_lab)
	await process_frame
	death_lab._on_kill_debug_pressed()
	await process_frame
	assert(death_lab.player.health_component.current_health == 0.0)
	assert(death_lab.result_panel.visible)
	print("COMBAT_SMOKE_TEST_OK")
	quit(0)
