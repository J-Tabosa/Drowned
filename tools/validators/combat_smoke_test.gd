extends SceneTree


## Agenda o teste para depois que a SceneTree e os autoloads estiverem disponíveis.
func _initialize() -> void:
	call_deferred("_run")


## Exercita personagens, tutorial, portões, onda inicial, mini-chefe, cura e morte.
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
		assert(arena.has_method("is_walkable"))
		assert(arena.is_walkable(lab.player.global_position))
		assert(arena.get_world_rect().size == Vector2(6900, 3600))
		assert(Geometry2D.triangulate_polygon(arena.WALKABLE_POLYGON).size() >= 3)
		assert(not arena.is_tutorial_gate_open())
		assert(not arena.is_boss_gate_open())
		assert(not arena.is_walkable(arena.TUTORIAL_GATE.get_center(), 0.0))
		assert(not arena.is_walkable(arena.BOSS_GATE.get_center(), 0.0))
		for spawn_position in lab.COMBAT_ENEMY_SPAWNS:
			assert(arena.is_walkable(spawn_position, 24.0))
		assert(arena.is_walkable(lab.BOSS_SPAWN, 60.0))
		lab.player.call("_use_primary_action")
		await physics_frame
		lab.player.health_component.take_damage(20.0)
		lab._on_heal_debug_pressed()
		assert(lab.player.health_component.current_health == lab.player.health_component.max_health)
		lab.queue_free()
		await process_frame

	game_state.select_character("breaker")
	var victory_lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	root.add_child(victory_lab)
	await process_frame
	Input.action_press("move_right")
	for _frame in 115:
		await physics_frame
	Input.action_release("move_right")
	assert(victory_lab._movement_done)
	victory_lab.player.call("_use_primary_action")
	await process_frame
	assert(victory_lab._action_done)
	assert(victory_lab.arena.is_tutorial_gate_open())
	assert(victory_lab.arena.is_walkable(victory_lab.arena.TUTORIAL_GATE.get_center(), 0.0))
	victory_lab._start_combat_encounter()
	assert(victory_lab._enemies_alive == victory_lab.COMBAT_ENEMY_SPAWNS.size())
	for enemy in get_nodes_in_group("enemies"):
		enemy.health_component.kill()
	await process_frame
	assert(victory_lab.arena.is_boss_gate_open())
	assert(victory_lab.arena.is_walkable(victory_lab.arena.BOSS_GATE.get_center(), 0.0))
	victory_lab._start_boss_encounter()
	assert(victory_lab._enemies_alive == 1)
	assert(victory_lab.boss_panel.visible)
	victory_lab._boss.health_component.kill()
	await process_frame
	assert(victory_lab.result_panel.visible)
	assert(victory_lab.result_title.text == "CAVERNA CONCLUÍDA")
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
