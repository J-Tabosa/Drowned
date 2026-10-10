extends SceneTree

const OUTPUT := "res://.godot/boss_menu_review"


func _initialize() -> void:
	call_deferred("_run")


func _capture(name: String) -> void:
	if OS.get_environment("DROWNED_FLOW_CAPTURE") != "1":
		return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK)


func _run() -> void:
	var transition: Node = root.get_node("SceneTransition")
	var music: Node = root.get_node("MusicDirector")
	var original_volume: float = music.music_volume
	if transition.busy:
		await transition.revealed
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1152, 648)
	var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	lab.skip_cinematics_for_tests = true
	root.add_child(lab)
	current_scene = lab
	await process_frame
	lab._boss = lab._spawn_enemy(lab.arena.get_anchor_position("boss_spawn"),
		{"is_miniboss": true, "max_health": 700.0})
	lab._boss.set_active(false)
	lab._boss.set_physics_process(false)
	var guard: Variant = lab._spawn_enemy(lab.player.global_position + Vector2(50, 0), {})
	guard.set_active(true)
	var presentation_health: float = lab.player.health_component.current_health
	lab._stage = lab.EncounterStage.REACH_BOSS
	lab._begin_boss_fight()
	await create_timer(0.7).timeout
	var card: Variant = lab.boss_intro_card
	assert(card.curtain.visible)
	assert(lab._stage == lab.EncounterStage.BOSS_PRESENTATION)
	assert(not lab._boss.can_receive_damage())
	assert(not guard._active, "Nearby guards must wait during the presentation")
	assert(lab.player.health_component.current_health == presentation_health)
	assert(card.portrait_sprite.texture == lab._boss.body.texture,
		"Presentation must use the actual combat boss sheet")
	assert(card.portrait_sprite.hframes == 6 and card.portrait_sprite.vframes == 5)
	assert(card.find_children("PortraitBody", "ColorRect", true, false).is_empty())
	assert(card.find_children("PortraitHead", "ColorRect", true, false).is_empty())
	var idle_frame: int = card.portrait_sprite.frame
	await create_timer(0.2).timeout
	assert(card.portrait_sprite.frame != idle_frame, "Boss portrait must animate")
	for resolution in [Vector2i(640, 360), Vector2i(1152, 648)]:
		root.size = resolution
		await process_frame
		card._layout_card()
		await process_frame
		var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		assert(bounds.encloses(card.portrait_panel.get_global_rect()))
		assert(bounds.encloses(card.information_panel.get_global_rect()))
		await _capture("boss_" + str(resolution.x))
	var deadline := Time.get_ticks_msec() + 6000
	while lab._stage != lab.EncounterStage.BOSS:
		assert(Time.get_ticks_msec() < deadline, "Boss presentation stalled")
		await process_frame
	assert(not card.curtain.visible)
	assert(lab._boss.can_receive_damage() and lab.boss_panel.visible)
	assert(lab.player._controls_enabled)
	assert(guard._active, "Guards must resume after the presentation")
	assert(lab.player.health_component.current_health == presentation_health)
	guard.set_active(false)
	# Esc opens the pause menu; both destinations remain reachable from it.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	await process_frame
	assert(paused and lab.pause_panel.visible)
	var return_button: Button = lab.get_node("Interface/PausePanel/PauseCard/ReturnTitle")
	assert(return_button.visible)
	assert(lab.get_node("Interface/PausePanel/PauseCard/ChangeCharacter").visible)
	for resolution in [Vector2i(640, 360), Vector2i(1152, 648)]:
		root.size = resolution
		await process_frame
		await process_frame
		assert(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(return_button.get_global_rect()))
		await _capture("pause_" + str(resolution.x))
	for audio in music._players:
		assert(audio.stream_paused)
	music.set_music_volume(0.65)
	return_button.pressed.emit()
	assert(not paused and transition.busy)
	return_button.pressed.emit()
	await transition.revealed
	assert(current_scene.name == "TitleScreen", "Return button must open title, not selection")
	await create_timer(0.2).timeout
	assert(not paused and music.context == "cavern")
	assert(music._players[0].playing and not music._players[0].stream_paused)
	assert(music._players[0].volume_db > -60.0, "Menu music must resume")
	assert(not current_scene.play_button.disabled and current_scene.ocean.storm == 0.0)
	await _capture("returned_title")
	music.set_music_volume(original_volume)
	print("BOSS_PRESENTATION_AND_MENU_TEST_OK")
	quit(0)
