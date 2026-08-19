extends SceneTree


## Agenda o teste depois que os autoloads do projeto estiverem disponíveis.
func _initialize() -> void:
	call_deferred("_run")


## Aguarda a conclusão de entradas, saídas e substituições antes de inspecionar o palco.
func _wait_for_transition(overlay: Variant) -> void:
	while is_instance_valid(overlay) and overlay._transitioning:
		await process_frame


## Valida três slots, roteiros por jogador, troca pelo monstro e fechamento do overlay.
func _run() -> void:
	var game_state: Variant = root.get_node_or_null("GameState")
	var dialogue_manager: Variant = root.get_node_or_null("DialogueManager")
	var catalog: Variant = load("res://scripts/narrative/dialogue_catalog.gd")
	assert(game_state != null)
	assert(dialogue_manager != null)
	for profile in game_state.CHARACTER_PROFILES:
		var candidate: Dictionary = catalog.get_intro(profile.id)
		assert(candidate.actors.size() == 4)
		assert(candidate.initial_slots.size() == 3)
		assert(candidate.initial_slots.center == "player")
		assert(candidate.actors.player.id == profile.id)
		assert(candidate.lines.size() == 7)

	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var sequence: Dictionary = catalog.get_intro("breaker")
	dialogue_manager.play(sequence)
	await create_timer(0.8).timeout
	var overlay: Variant = dialogue_manager._active_overlay
	assert(is_instance_valid(overlay))
	assert(overlay._line_index == 0)
	assert(overlay._slots.left == "friend_left")
	assert(overlay._slots.center == "player")
	assert(overlay._slots.right == "friend_right")
	assert(overlay.left_portrait.visible)
	assert(overlay.center_portrait.visible)
	assert(overlay.right_portrait.visible)

	for next_line_index in range(1, sequence.lines.size()):
		overlay._finish_typing()
		overlay._advance()
		await _wait_for_transition(overlay)
		assert(overlay._line_index == next_line_index)
		if next_line_index == 4:
			assert(overlay._slots.left == "")
			assert(overlay._slots.center == "player")
			assert(overlay._slots.right == "monster")
			assert(not overlay.left_portrait.visible)
			assert(overlay.center_portrait.visible)
			assert(overlay.right_portrait.visible)

	overlay._finish_typing()
	overlay._advance()
	await _wait_for_transition(overlay)
	assert(not dialogue_manager.is_playing())
	assert(not paused)
	print("DIALOGUE_SMOKE_TEST_OK")
	quit(0)
