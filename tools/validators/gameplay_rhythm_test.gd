extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1152, 648)
	var state: Variant = root.get_node("GameState")
	# Todos os perfis esquivam, bloqueiam dano e respeitam paredes/pausa.
	for profile in state.CHARACTER_PROFILES:
		state.select_character(profile.id)
		var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
		lab.skip_cinematics_for_tests = true
		root.add_child(lab)
		await process_frame
		var player: Variant = lab.player
		player.facing = Vector2.RIGHT
		var start: Vector2 = player.global_position
		player._use_evade()
		assert(not player.can_receive_damage())
		assert(not player.get_node("Hurtbox").receive_hit(20.0, start))
		var remaining: float = player.evade_cooldown
		lab._toggle_pause()
		await create_timer(0.2, true).timeout
		assert(player.evade_cooldown == remaining)
		assert(player._evade_time > 0.0)
		lab._toggle_pause()
		await create_timer(0.23, false).timeout
		assert(player.can_receive_damage())
		assert(player.global_position.distance_to(start) > 110.0)
		assert(lab.arena.is_walkable(player.global_position, 26.0))
		player._use_evade()
		assert(player._evade_time == 0.0, "Recarga impede repetir esquiva")
		await create_timer(1.0, false).timeout
		player.global_position = lab.arena._gate_nodes.tutorial[2].global_position + Vector2(-80, 0)
		player._use_evade()
		await create_timer(0.23, false).timeout
		assert(not lab.arena.is_tutorial_gate_open())
		assert(player.global_position.x < lab.arena._gate_nodes.tutorial[2].global_position.x)
		# Segurar o ataque produz mais de uma ação, sem cliques repetidos.
		player.global_position = start
		var actions := [0]
		player.action_used.connect(func(_name: String, _cooldown: float) -> void: actions[0] += 1)
		Input.action_press("primary_action")
		await create_timer(1.25, false).timeout
		Input.action_release("primary_action")
		assert(actions[0] >= 2)
		lab.queue_free()
		await process_frame

	state.select_character("breaker")
	var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	lab.skip_cinematics_for_tests = true
	root.add_child(lab)
	await process_frame
	# Sem corrida ou ataque obrigatório, movimento abre a rota.
	lab._movement_done = true
	lab._try_complete_tutorial()
	assert(lab.arena.is_tutorial_gate_open())
	assert(lab._stage == lab.EncounterStage.REACH_COMBAT)
	assert(lab._story_echo_index == 0)
	assert(not lab._sprint_done and not lab._action_done)
	lab.player.global_position += Vector2(550, 0)
	lab._check_path_encounter()
	assert(lab._enemies_alive == 2)
	for enemy in get_nodes_in_group("enemies"):
		assert(enemy.global_position.distance_to(lab.player.global_position) >= 180.0)
		assert(lab.arena.is_walkable(enemy.global_position, 38.0))
		assert(not enemy._active)
	lab._toggle_pause()
	await create_timer(0.8, true).timeout
	for enemy in get_nodes_in_group("enemies"):
		assert(not enemy._active)
	lab._toggle_pause()
	await create_timer(1.0, false).timeout
	for enemy in get_nodes_in_group("enemies"):
		assert(enemy._active)
		enemy.health_component.kill()
	await process_frame
	# Eco opcional pode ser investigado fora da ordem, sem fechar o portão.
	lab.player.global_position = lab.arena.get_story_echo_positions()[1]
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	assert(lab._echoes_found.has(1))
	assert(lab.arena.is_tutorial_gate_open())
	# Recompensa de inimigo cura e antecipa o especial ao ser recolhida.
	var pickup: Variant = get_nodes_in_group("breath_pickups")[0]
	lab.player.health_component.take_damage(20.0)
	lab.player.skill_cooldown_remaining = 4.0
	lab.player.global_position = pickup.global_position
	var health: float = lab.player.health_component.current_health
	await process_frame
	assert(lab.player.health_component.current_health == health + 5.0)
	assert(lab.player.skill_cooldown_remaining < 3.3)
	# Waves progress without a reward popup; normal enemies never grant skill XP.
	var xp_before: int = state.get_skill_xp("breaker")
	lab.player.global_position = lab.arena.get_anchor_position("combat_trigger")
	lab.player.camera.reset_smoothing()
	lab._start_combat_encounter()
	for wave in 3:
		assert(lab._combat_wave == wave)
		assert(lab._enemies_alive == [4, 5, 6][wave])
		var has_hunter := false
		var has_brute := false
		for enemy in get_nodes_in_group("enemies"):
			assert(enemy.global_position.distance_to(lab.player.global_position) < 750.0)
			assert(lab.arena.is_walkable(enemy.global_position, 38.0))
			has_hunter = has_hunter or enemy.can_charge
			has_brute = has_brute or enemy.display_name == "Afogado Pesado"
		assert(has_hunter)
		assert(has_brute == (wave > 0))
		if OS.get_environment("DROWNED_RHYTHM_CAPTURE") == "1" and wave == 0:
			await create_timer(0.85, false).timeout
			await process_frame
			DirAccess.make_dir_recursive_absolute("res://.godot/rhythm_review")
			root.get_texture().get_image().save_png("res://.godot/rhythm_review/combat.png")
		for enemy in get_nodes_in_group("enemies"):
			enemy.health_component.kill()
		await process_frame
		assert(lab.player._controls_enabled)
		assert(not lab._skill_tree.visible)
		assert(state.get_skill_xp("breaker") == xp_before)
		await process_frame
		await process_frame
	assert(is_equal_approx(lab.player.damage_multiplier, 1.0))
	assert(is_equal_approx(lab.player.health_component.max_health, 140.0))
	assert(lab._boss != null)
	assert(lab._stage == lab.EncounterStage.REACH_BOSS)
	lab.player.global_position = lab.arena.get_anchor_position("boss_spawn") + Vector2(-1800, 0)
	await process_frame
	assert(lab._approach_pack_spawned)
	assert(lab._enemies_alive == 3)
	for enemy in get_nodes_in_group("enemies"):
		if not enemy.is_miniboss:
			enemy.health_component.kill()
	await process_frame
	assert(lab._enemies_alive == 1)
	# A melhoria de recarga afeta a recarga real e a barra do HUD.
	lab.player.skill_recharge_multiplier = 0.8
	lab.player.skill_cooldown_remaining = 0.0
	lab.player._use_special_action()
	assert(is_equal_approx(lab.player.skill_cooldown_remaining, 5.6))
	lab._refresh_skill_status()
	assert(lab._skill_bar.value < 1.0)
	await create_timer(0.6, false).timeout
	lab._begin_boss_fight(true)
	lab._boss.health_component.kill()
	await process_frame
	assert(lab._stage == lab.EncounterStage.REACH_EXIT)
	assert(state.get_skill_xp("breaker") == xp_before + 100)
	state._progression.breaker.xp = xp_before
	state._save_progression()
	assert(not lab.arena.open_post_boss_gate(), "Chefe não elimina a exigência da chave")
	lab.queue_free()
	await process_frame
	print("GAMEPLAY_RHYTHM_TEST_OK")
	quit(0)
