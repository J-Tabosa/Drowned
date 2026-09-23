extends SceneTree


## Agenda o teste para depois que a SceneTree e os autoloads estiverem disponíveis.
func _initialize() -> void:
	call_deferred("_run")


## Valida mapa em nós, três personagens, corrida, habilidades, encontros, chefe e debug.
func _run() -> void:
	var game_state: Variant = root.get_node_or_null("GameState")
	assert(game_state != null)
	for profile in game_state.CHARACTER_PROFILES:
		game_state.select_character(profile.id)
		var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
		root.add_child(lab)
		await process_frame
		assert(lab.player != null)
		assert(lab.player.body.texture != null)
		assert(lab.player.body.texture.get_width() == 576)
		assert(lab.player.body.texture.get_height() == 384)
		assert(lab.player.body.hframes == 6)
		assert(lab.player.body.vframes == 4)
		assert(lab._enemies_alive == 0)
		var arena: Node = lab.get_node("Arena")
		assert(not arena.map_layout.strip_edges().is_empty())
		assert(arena._map_rows.size() == 34)
		var tile_counts: Dictionary = arena.get_tile_counts()
		assert(tile_counts.floor > 400)
		assert(tile_counts.wall > 80)
		assert(tile_counts.gate == 9)
		assert(arena.is_walkable(arena.get_anchor_position("player_spawn")))
		assert(arena.get_mob_spawn_positions().size() == 7)
		assert(arena.get_story_echo_positions().size() == 3)
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
		await create_timer(0.06, false).timeout
		assert(lab.player.body.frame >= 6 and lab.player.body.frame < 12)
		Input.action_release("sprint")
		Input.action_release("move_right")

		if profile.id == "diver":
			var tutorial_gate: Node2D = arena._gate_nodes.tutorial[1]
			var before_gate := tutorial_gate.global_position - Vector2(192.0, 0.0)
			var after_gate: Vector2 = arena.get_anchor_position("combat_trigger")
			assert(arena.is_walkable(before_gate, 20.0))
			assert(arena.is_walkable(after_gate, 20.0))
			lab.player.global_position = before_gate
			var blocked_dive_target: Vector2 = lab.player.call("_find_dive_target", after_gate)
			assert(blocked_dive_target.distance_to(after_gate) > 80.0)
			lab.player.call("_use_primary_action")
			await physics_frame
			assert(lab.player._diving)
			assert(not lab.player.can_receive_damage())
			await create_timer(0.5).timeout
			assert(not lab.player._diving)
			assert(lab.player.get_collision_mask_value(2))
		else:
			lab.player.call("_use_primary_action")
			await physics_frame
			assert(lab.player.body.frame / 6 == 2)
			if profile.id == "breaker":
				assert(is_equal_approx(lab.player.melee_hitbox.position.length(), 72.0))
				var wind_found := false
				for child in lab.player.get_children():
					if child is Sprite2D and child.texture == load("res://assets/sprites/effects/anchor_wind_sweep.png"):
						assert(is_equal_approx(child.position.length(), 84.0))
						wind_found = true
				assert(wind_found)
			elif profile.id == "sharpshooter":
				assert(is_equal_approx(float(profile.cooldown), 0.68))
				await create_timer(0.255, false).timeout
				var projectile: Variant = lab.get_node_or_null("PlaceholderProjectile")
				assert(is_instance_valid(projectile))
				assert(is_equal_approx(projectile.speed, 1480.0))
				var muzzle := Vector2(-52.0 if lab.player.body.flip_h else 52.0, -14.0)
				assert(projectile.global_position.distance_to(lab.player.body.to_global(muzzle)) < 65.0)

		lab.player.health_component.take_damage(20.0)
		assert(lab.player.body.frame / 6 == 3)
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
	assert(not victory_lab.arena.is_tutorial_gate_open())
	for echo_position in victory_lab.arena.get_story_echo_positions():
		victory_lab.player.global_position = echo_position
		await process_frame
	assert(victory_lab.arena.is_tutorial_gate_open())

	victory_lab._start_combat_encounter()
	for expected_wave_size in [4, 5, 6]:
		assert(victory_lab._enemies_alive == expected_wave_size)
		for enemy in get_nodes_in_group("enemies"):
			if enemy.get_parent() == victory_lab:
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
	assert(not victory_lab.result_panel.visible)
	victory_lab.player.global_position = victory_lab.arena.get_anchor_position("post_boss_exit")
	await process_frame
	assert(victory_lab.result_panel.visible)
	assert(victory_lab.result_title.text == "FIM DO PRÓLOGO")
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
