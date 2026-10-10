extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _dummy(lab: Node2D, position: Vector2) -> CharacterBody2D:
	var enemy: CharacterBody2D = lab._spawn_enemy(position, {"max_health": 1000.0, "move_speed": 0.0, "aggro_range": 0.0})
	enemy.set_physics_process(false)
	return enemy


func _run() -> void:
	var state: Node = root.get_node("GameState")
	var music: Node = root.get_node("MusicDirector")
	var original_volume: float = music.music_volume
	assert(InputMap.has_action("special_action"))
	for profile in state.CHARACTER_PROFILES:
		state.select_character(profile.id)
		var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
		root.add_child(lab)
		current_scene = lab
		await physics_frame
		var player: Variant = lab.player
		var origin: Vector2 = player.global_position
		var direction: Vector2 = player._get_cursor_direction(player.facing)
		match profile.id:
			"breaker":
				var enemy := _dummy(lab, origin + direction * 72.0)
				await physics_frame
				for hit in 3:
					player._use_primary_action()
					await create_timer(0.5).timeout
					assert(player._momentum == hit + 1, "Momentum requires real hitbox contact")
				assert(is_equal_approx(player._primary_damage(), 58.5))
				var before: float = enemy.health_component.current_health
				player._use_special_action()
				assert(player._momentum == 0)
				await create_timer(0.3).timeout
				assert(is_equal_approx(before - enemy.health_component.current_health, 135.0))
				var cooldown: float = player.skill_cooldown_remaining
				player._use_special_action()
				assert(player.skill_cooldown_remaining == cooldown)
				paused = true
				await create_timer(0.2, true).timeout
				assert(player.skill_cooldown_remaining == cooldown)
				paused = false
				await create_timer(0.35).timeout
				assert(not player._skill_busy)
				# Expiration clears stacks and control locks reject both actions.
				player._momentum = 3
				player._momentum_time = 0.02
				await create_timer(0.05).timeout
				assert(player._momentum == 0)
				player.set_controls_enabled(false)
				player.skill_cooldown_remaining = 0.0
				player._use_special_action()
				assert(player.skill_cooldown_remaining == 0.0)
			"sharpshooter":
				await create_timer(1.3).timeout
				assert(player._steady_ready)
				direction = player._get_cursor_direction(player.facing)
				var muzzle: Vector2 = player.body.to_global(Vector2(-52.0 if direction.x < -0.08 else 52.0, -14.0))
				var first := _dummy(lab, muzzle + direction * 100.0)
				var second := _dummy(lab, muzzle + direction * 170.0)
				assert(lab.arena.get_farthest_walkable_position(muzzle, second.global_position, 4.0).distance_to(second.global_position) < 1.0)
				await physics_frame
				player._use_primary_action()
				assert(not player._steady_ready)
				await create_timer(0.55).timeout
				assert(is_equal_approx(first.health_component.current_health, 960.0))
				assert(is_equal_approx(second.health_component.current_health, 960.0), "Aimed harpoon must pierce")
				player._use_special_action()
				await create_timer(0.23).timeout
				var harpoons: Array[Node] = lab.find_children("*", "Area2D", false, false)
				var count := 0
				for harpoon in harpoons:
					if harpoon.get_script() == load("res://scripts/combat/placeholder_projectile.gd"):
						count += 1
				assert(count == 5, "Fan must create five projectiles")
				await create_timer(1.0).timeout
				Input.action_press("move_right")
				await physics_frame
				await process_frame
				Input.action_release("move_right")
				assert(not player._steady_ready)
			"diver":
				player.health_component.take_damage(30.0)
				var distance: float = clampf(origin.distance_to(player.get_global_mouse_position()), 120.0, 300.0)
				var landing: Vector2 = player._find_dive_target(origin + direction * distance)
				var first := _dummy(lab, landing + Vector2(30, 0))
				var second := _dummy(lab, landing + Vector2(-30, 0))
				await physics_frame
				player._use_primary_action()
				assert(not player.can_receive_damage())
				await create_timer(0.5).timeout
				assert(is_equal_approx(player.health_component.current_health, 91.0), "One heal per dive, even with two victims")
				assert(first.health_component.current_health < 1000.0 and second.health_component.current_health < 1000.0)
				assert(player._flow_time > 0.0)
				assert(player.can_receive_damage())
				var current_direction: Vector2 = player._get_cursor_direction(player.facing)
				var current_distance: float = minf(360.0, player.global_position.distance_to(player.get_global_mouse_position()))
				var center: Vector2 = player._find_dive_target(player.global_position + current_direction * current_distance)
				first.global_position = center + Vector2(30, 0)
				var before: float = first.health_component.current_health
				player._use_special_action()
				await create_timer(3.1).timeout
				assert(is_equal_approx(before - first.health_component.current_health, 80.0), "Current must deliver all five pulses")
				assert(first._knockback_velocity.dot(center - first.global_position) > 0.0)
		# Death never revives a cooldown or creates delayed attacks.
		player.health_component.kill()
		player._use_special_action()
		assert(player._dead and not player._skill_busy)
		lab.queue_free()
		await process_frame
		await process_frame
	# PCM stereo loop bounds must cover the entire 53.33 s composition.
	for audio: AudioStreamPlayer in music._players:
		assert(audio.stream.format == AudioStreamWAV.FORMAT_16_BITS)
		assert(audio.stream.stereo)
		assert(absf(audio.stream.get_length() - 53.333333) < 0.001)
		assert(audio.stream.loop_end == 1176000)
		assert(audio.playing)
	music.set_music_volume(1.0)
	music.set_context("waves", 0.01)
	await create_timer(0.05).timeout
	assert(music._players[1].volume_db > -20.0 and music._players[2].volume_db <= -59.0)
	music.set_context("boss", 0.01)
	await create_timer(0.05).timeout
	assert(music._players[2].volume_db > -20.0)
	music.set_context("cavern", 0.01)
	await create_timer(0.05).timeout
	assert(music._players[1].volume_db <= -59.0 and music._players[2].volume_db <= -59.0)
	music.set_music_volume(0.0)
	await create_timer(0.15).timeout
	for audio in music._players:
		assert(audio.volume_db <= -59.0)
	music.set_music_volume(original_volume)
	state.select_character("breaker")
	print("ABILITIES_MUSIC_TEST_OK")
	quit(0)
