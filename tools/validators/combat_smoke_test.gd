extends SceneTree


## Agenda o teste para depois que a SceneTree e os autoloads estiverem disponíveis.
func _initialize() -> void:
	call_deferred("_run")


## Exercita personagens, habilidades, cura, vitória e morte; encerra com código zero se tudo passar.
func _run() -> void:
	var game_state: Variant = root.get_node_or_null("GameState")
	assert(game_state != null)
	for profile in game_state.CHARACTER_PROFILES:
		game_state.select_character(profile.id)
		var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
		root.add_child(lab)
		await process_frame
		assert(lab.player != null)
		assert(lab._enemies_alive == lab.ENEMY_SPAWNS.size())
		var arena: Node = lab.get_node("Arena")
		assert(arena.has_method("is_walkable"))
		assert(arena.is_walkable(lab.player.global_position))
		for spawn_position in lab.ENEMY_SPAWNS:
			assert(arena.is_walkable(spawn_position, 24.0))
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
	for enemy in get_nodes_in_group("enemies"):
		enemy.health_component.kill()
	await process_frame
	assert(victory_lab._enemies_alive == 0)
	assert(victory_lab.result_panel.visible)
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
