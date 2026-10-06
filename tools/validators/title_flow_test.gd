extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _wait_scene(name: String) -> void:
	var deadline := Time.get_ticks_msec() + 12000
	while current_scene == null or current_scene.name != name or root.get_node("SceneTransition").busy:
		assert(Time.get_ticks_msec() < deadline, "Scene transition stalled: " + name)
		await process_frame


func _run() -> void:
	var transition: Node = root.get_node("SceneTransition")
	var music: Node = root.get_node("MusicDirector")
	var manager: Node = root.get_node("DialogueManager")
	var state: Node = root.get_node("GameState")
	var original_speed: int = state.dialogue_speed_index
	if transition.busy:
		await transition.revealed
	var title: Variant = load("res://scenes/ui/menus/title_screen.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	assert(ProjectSettings.get_setting("application/run/main_scene").ends_with("title_screen.tscn"))
	assert(title.ocean._boat.texture != null and title.ocean._sea.texture != null)
	assert(title.ocean.storm == 0.0)
	await create_timer(0.2).timeout
	assert(title.ocean.animation_time > 0.0)
	title._start_game(0.5)
	assert(title._starting and title.play_button.disabled)
	await create_timer(0.2).timeout
	assert(title.ocean.storm > 0.0 and title.ocean.storm < 1.0)
	await _wait_scene("CharacterSelect")
	var selection: Variant = current_scene
	assert(not selection.has_node("TopWater"))
	assert(selection.find_children("*", "Label", true, false).size() == 6, "Selection only displays passive and special labels")
	assert(selection._previews.size() == 3)
	selection._confirm_selection(1)
	assert(transition.busy and selection._leaving)
	selection._confirm_selection(2)
	assert(state.selected_character_id == "sharpshooter", "Double input must not select another character")
	await _wait_scene("IntroDialogue")
	var deadline := Time.get_ticks_msec() + 5000
	while not manager.is_playing():
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	await create_timer(0.7, true).timeout
	var overlay: Variant = manager._active_overlay
	assert(overlay._speaker_slot == "left")
	assert(overlay.center_texture.flip_h)
	var screen: Vector2 = overlay.get_viewport().get_visible_rect().size
	assert(absf(overlay.dialogue_box.size.x / screen.x - 0.70) < 0.01)
	assert(absf(overlay.dialogue_box.size.y / screen.y - 0.41) < 0.01)
	assert(not overlay.top_bar.visible)
	assert(overlay._cave_background.visible)
	var cave: Variant = overlay._cave_background.get_node("CaveViewport/Cave")
	assert(cave.animation_time > 0.0, "Cave animation must continue during dialogue pause")
	assert(cave._drops.is_empty(), "Drops must remain rare")
	cave._spawn_drop()
	var drop_y: float = cave._drops[0].position.y
	await create_timer(0.1, true).timeout
	assert(cave._drops[0].position.y > drop_y)
	for audio in music._players:
		assert(not audio.stream_paused, "Soundtrack should continue during dialogue")
	overlay._finish_typing()
	overlay._advance()
	await process_frame
	assert(overlay._speaker_slot == "right")
	assert(not overlay.center_texture.flip_h)
	overlay._finish_typing()
	overlay._advance()
	await process_frame
	assert(overlay._speaker_slot == "center")
	assert(not overlay.center_texture.flip_h, "Center speaker keeps its last gaze")
	overlay._request_skip()
	await _wait_scene("MovementLab")
	assert(not paused)
	assert(current_scene.player.profile.id == "sharpshooter")
	paused = true
	await process_frame
	await process_frame
	for audio in music._players:
		assert(audio.stream_paused, "Pause menu still pauses the music")
	paused = false
	state.set_dialogue_speed(original_speed)
	print("TITLE_FLOW_TEST_OK")
	quit(0)
