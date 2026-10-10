extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _dummy(lab: Node2D, position: Vector2) -> CharacterBody2D:
	var enemy: CharacterBody2D = lab._spawn_enemy(position,
		{"max_health": 2000.0, "move_speed": 0.0, "aggro_range": 0.0})
	enemy.set_physics_process(false)
	return enemy


func _run() -> void:
	var state: Node = root.get_node("GameState")
	var original: Dictionary = state._progression.duplicate(true)
	var original_character: String = state.selected_character_id
	if root.get_node("SceneTransition").busy:
		await root.get_node("SceneTransition").revealed
	for profile in state.CHARACTER_PROFILES:
		state._progression[profile.id] = {"xp": 0, "learned": []}
	assert(InputMap.has_action("skill_tree"))
	assert(not state.collect_boss_xp("breaker", 100, "ordinary_enemy"))
	assert(not state.learn_skill("breaker", "held_spin"))
	assert(not state.can_learn_skill("breaker", "power"))
	for profile in state.CHARACTER_PROFILES:
		state.select_character(profile.id)
		var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
		lab.skip_cinematics_for_tests = true
		root.add_child(lab)
		current_scene = lab
		await process_frame
		var player: Variant = lab.player
		var origin: Vector2 = player.global_position
		# The tree cannot conjure XP; it freezes the world and restores pause.
		lab._open_skill_tree()
		assert(paused and lab._skill_tree.visible)
		assert(lab._skill_tree._buttons.size() == 6)
		assert(lab._skill_tree._buttons.values()[0].disabled)
		lab._skill_tree.close()
		assert(not paused)
		# Two real mob deaths spawn only a breath mote and never skill XP.
		for index in 2:
			var mob := _dummy(lab, origin + Vector2(90, 0))
			mob.health_component.kill()
		assert(state.get_skill_xp(profile.id) == 0)
		var mote: Variant = get_nodes_in_group("breath_pickups")[0]
		var mote_start: Vector2 = mote.global_position
		player.health_component.take_damage(20.0)
		var hp: float = player.health_component.current_health
		await create_timer(0.35).timeout
		assert(is_instance_valid(mote) and mote.global_position != mote_start, "Mote must fly toward player")
		await create_timer(0.5).timeout
		assert(player.health_component.current_health > hp)
		assert(state.get_skill_xp(profile.id) == 0)
		# XP is awarded atomically only on a boss defeat, once per encounter.
		lab._boss = lab._spawn_enemy(origin + Vector2(150, 0), {"is_miniboss": true, "max_health": 2000})
		lab._boss.set_physics_process(false)
		lab._stage = lab.EncounterStage.BOSS
		lab._boss.health_component.kill()
		assert(state.get_skill_xp(profile.id) == 100)
		assert(get_nodes_in_group("boss_xp_motes").size() == 6)
		lab._on_enemy_defeated(lab._boss)
		assert(state.get_skill_xp(profile.id) == 100)
		var catalog: Variant = load("res://scripts/gameplay/skill_catalog.gd")
		var signature: String = catalog.SIGNATURES[profile.id][0]
		assert(state.learn_skill(profile.id, signature))
		assert(state.get_skill_xp(profile.id) == 0)
		assert(not state.learn_skill(profile.id, signature))
		assert(not state.learn_skill(profile.id, "power"))
		assert(player._learned.has(signature), "Learned ability applies to current player")
		state._load_progression()
		assert(state.has_skill(profile.id, signature), "Progression survives reload")
		lab._stage = lab.EncounterStage.MOVEMENT_TUTORIAL
		player.global_position = origin
		player.skill_cooldown_remaining = 0
		match profile.id:
			"breaker":
				var enemy := _dummy(lab, origin + Vector2(80, 0))
				Input.action_press("special_action")
				player._use_special_action()
				await create_timer(0.75).timeout
				assert(player._spinning)
				assert(enemy.health_component.current_health <= 2000 - 54)
				var frozen: float = player._spin_time
				paused = true
				await create_timer(0.15, true).timeout
				assert(player._spin_time == frozen)
				paused = false
				Input.action_release("special_action")
				await physics_frame
				await physics_frame
				assert(not player._spinning and player.body.rotation == 0)
			"sharpshooter":
				player._use_primary_action()
				await create_timer(0.26).timeout
				var count := 0
				for child in lab.get_children():
					if child.get_script() == load("res://scripts/combat/placeholder_projectile.gd"):
						count += 1
				assert(count == 2, "Double shot must launch two actual projectiles")
			"diver":
				var direction: Vector2 = player._get_cursor_direction(player.facing)
				var distance: float = clampf(origin.distance_to(player.get_global_mouse_position()), 120, 300)
				var landing: Vector2 = player._find_dive_target(origin + direction * distance)
				var enemy := _dummy(lab, landing + Vector2(15, 0))
				await physics_frame
				player._use_primary_action()
				await create_timer(0.85).timeout
				assert(is_equal_approx(2000 - enemy.health_component.current_health, 38 * (1.35 + 0.70)),
					"Dive plus two echoes must deal three distinct impacts")
		# Later boss victories can unlock the relocated original improvements.
		for award in 7:
			assert(state.collect_boss_xp(profile.id, 100, "guardian_prologue"))
		assert(state.learn_skill(profile.id, "power"))
		assert(is_equal_approx(player.damage_multiplier, 1.2))
		assert(not state.can_learn_skill(profile.id, "recharge"))
		assert(state.learn_skill(profile.id, "passive_mastery"))
		assert(state.learn_skill(profile.id, "recharge"))
		assert(is_equal_approx(player.skill_recharge_multiplier, 0.8))
		assert(state.learn_skill(profile.id, "evade_mastery"))
		var before_vitality: float = player.health_component.current_health
		assert(state.learn_skill(profile.id, "vitality"))
		var increase: float = float(profile.max_health) * 0.25
		assert(is_equal_approx(player.health_component.max_health, float(profile.max_health) * 1.25))
		assert(is_equal_approx(player.health_component.current_health, before_vitality + increase))
		assert(state.get_skill_xp(profile.id) == 50)
		assert(not state.learn_skill(profile.id, "vitality"))
		var after_vitality: float = player.health_component.current_health
		player.refresh_progression()
		assert(player.health_component.current_health == after_vitality, "Refreshing the tree must not heal again")
		lab.queue_free()
		await process_frame
		await process_frame
	# Boss hazards punish standing still; a stationary ranged player can't ignore roar.
	state.select_character("sharpshooter")
	var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	lab.skip_cinematics_for_tests = true
	root.add_child(lab)
	current_scene = lab
	await process_frame
	var center: Vector2 = lab.arena.get_anchor_position("boss_spawn")
	lab.arena.open_tutorial_gate()
	lab.arena.open_boss_gate()
	lab.player.global_position = center
	lab.player.set_controls_enabled(false)
	var boss: Variant = lab._spawn_enemy(center + Vector2(200, 0),
		{"is_miniboss": true, "max_health": 1100, "engaged": true})
	boss.set_physics_process(false)
	assert(boss.body.texture == load("res://assets/sprites/enemies/colosso_afogado_sheet_64.png"))
	var hp: float = lab.player.health_component.current_health
	boss._start_roar()
	boss._release_roar()
	assert(get_nodes_in_group("boss_hazards").size() >= 1)
	paused = true
	var hazard: Variant = get_nodes_in_group("boss_hazards")[0]
	var age: float = hazard._age
	await create_timer(0.2, true).timeout
	assert(hazard._age == age)
	paused = false
	await create_timer(1.4).timeout
	assert(lab.player.health_component.current_health < hp, "Standing still must be hit by falling rock")
	await create_timer(0.8).timeout
	hp = lab.player.health_component.current_health
	boss._start_roar()
	boss._release_roar()
	lab.player.global_position = center + Vector2(0, 230)
	await create_timer(1.8).timeout
	assert(lab.player.health_component.current_health == hp, "Leaving warned shadows must avoid the strike")
	boss.health_component.take_damage(600)
	assert(boss._enraged)
	lab.player.global_position = center
	boss._start_roar()
	boss._release_roar()
	await process_frame
	assert(get_nodes_in_group("boss_hazards").size() > 0)
	boss.health_component.kill()
	await process_frame
	await process_frame
	assert(get_nodes_in_group("boss_hazards").is_empty(), "Boss death must clear hazards")
	lab.queue_free()
	await process_frame
	# Full AI and real projectiles: even generous stationary ranged damage loses.
	state._progression.sharpshooter = {"xp": 0, "learned": []}
	lab = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	lab.skip_cinematics_for_tests = true
	root.add_child(lab)
	current_scene = lab
	await process_frame
	center = lab.arena.get_anchor_position("boss_spawn")
	lab.arena.open_tutorial_gate()
	lab.arena.open_boss_gate()
	lab.player.global_position = center + Vector2(-350, 0)
	lab._spawn_boss_for_reveal()
	lab._stage = lab.EncounterStage.REACH_BOSS
	lab._begin_boss_fight(true)
	lab.player.set_controls_enabled(false)
	for shot in 26:
		if lab.player._dead or lab._boss._dead:
			break
		var direction: Vector2 = lab.player.global_position.direction_to(lab._boss.global_position)
		var origin: Vector2 = lab.player.global_position + direction * 52
		lab.player._fire_harpoon(direction, 40, 1, origin)
		if shot % 8 == 0:
			for fan in 5:
				lab.player._fire_harpoon(direction.rotated((fan - 2) * 0.14), 22, 3, origin)
		await create_timer(0.78).timeout
	assert(lab.player._dead and not lab._boss._dead, "Stationary sharpshooter must lose against active boss AI")
	lab._open_skill_tree()
	assert(paused and lab._skill_tree.visible, "Tree remains accessible on the result screen")
	lab._skill_tree.close()
	assert(not paused and lab.player._dead)
	lab.queue_free()
	await process_frame
	state._progression = original
	state._save_progression()
	state.select_character(original_character)
	print("PROGRESSION_BOSS_TEST_OK")
	quit(0)
