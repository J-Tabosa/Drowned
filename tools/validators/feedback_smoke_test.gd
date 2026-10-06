extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").select_character("diver")
	var lab = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.skip_cinematics_for_tests = true
	await process_frame
	var player = lab.player
	var hurtbox = player.get_node("Hurtbox")
	var health: float = player.health_component.current_health
	assert(hurtbox.receive_hit(10.0, player.global_position))
	assert(player.health_component.current_health == health - 10.0)
	assert(lab._feedback_label.text == "−10 VIDA")
	player._use_primary_action()
	await process_frame
	await process_frame
	assert(player._invulnerability_visible)
	assert(not hurtbox.receive_hit(10.0, player.global_position))
	assert(player.health_component.current_health == health - 10.0)
	assert(lab._cooldown_label.text.contains("INVULNERÁVEL"))
	var remaining: float = player.cooldown_remaining
	player._use_primary_action()
	assert(player.cooldown_remaining == remaining)
	assert(lab._reject_wait > 0.0)
	lab._toggle_pause()
	await create_timer(0.2, true).timeout
	assert(player.cooldown_remaining == remaining)
	assert(player._diving)
	lab._toggle_pause()
	await create_timer(remaining + 0.1).timeout
	assert(player._can_act)
	assert(not player._invulnerability_visible)
	assert(lab._cooldown_label.text == "HABILIDADE PRONTA")
	assert(lab.cooldown_bar.value == 100.0)
	assert(hurtbox.receive_hit(10.0, player.global_position))
	# Contato com portão fechado informa o requisito uma vez por aproximação.
	player.global_position = lab.arena._gate_nodes.tutorial[2].global_position + Vector2(-100, 0)
	await process_frame
	await process_frame
	assert(lab._feedback_label.text.contains("três ecos"))
	var notification: float = lab._feedback_time
	await create_timer(0.1).timeout
	assert(lab._feedback_time < notification)
	lab._movement_done = true
	lab._sprint_done = true
	lab._action_done = true
	lab._try_complete_tutorial()
	assert(lab._feedback_label.text.contains("Treinamento concluído"))
	# Morte não deixa o anel nem reativa a habilidade ao terminar a recarga.
	player._use_primary_action()
	player.health_component.kill()
	assert(not player._invulnerability_visible)
	await create_timer(float(player.profile.cooldown) + 0.1).timeout
	assert(not player._can_act)
	assert(lab.result_panel.visible)
	lab.queue_free()
	await process_frame
	var fresh = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	assert(fresh.arena.get_collected_item_count() == 0)
	assert(not fresh.arena.is_post_boss_gate_open())
	assert(not fresh.arena._boss_defeated)
	assert(fresh.player._can_act)
	fresh.queue_free()
	await process_frame
	print("FEEDBACK_SMOKE_TEST_OK")
	quit(0)
