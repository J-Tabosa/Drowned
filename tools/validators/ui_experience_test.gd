extends SceneTree

const OUTPUT := "res://.godot/ui_review"

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	if OS.get_environment("DROWNED_UI_CAPTURE") != "1":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png")

func _settle() -> void:
	for frame in range(8):
		await process_frame

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var state: Node = root.get_node("GameState")
	var original_speed: int = state.dialogue_speed_index
	for resolution in [Vector2i(640, 360), Vector2i(960, 540), Vector2i(1152, 648), Vector2i(1920, 1080)]:
		root.size = resolution
		var selection: Control = load("res://scenes/ui/menus/character_select.tscn").instantiate()
		root.add_child(selection)
		current_scene = selection
		await _settle()
		var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		for button: Button in selection._card_buttons:
			assert(bounds.encloses(button.get_global_rect()))
		assert(not selection.get_node("Center") is ScrollContainer)
		await _capture("selection_" + str(resolution.x))
		selection.queue_free()
		await process_frame
	var scene: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	scene.skip_cinematics_for_tests = true
	root.add_child(scene)
	current_scene = scene
	for resolution in [Vector2i(640, 360), Vector2i(960, 540), Vector2i(1152, 648), Vector2i(1920, 1080), Vector2i(800, 1000)]:
		root.size = resolution
		await _settle()
		var status: Control = scene.get_node("Interface/TopPanel")
		var objective: Control = scene.get_node("Interface/ObjectivePanel")
		assert(not status.get_global_rect().intersects(objective.get_global_rect()))
		assert(not objective.get_global_rect().intersects(scene.tutorial_panel.get_global_rect()))
		scene._set_objective("Objetivo muito longo: " + "Investigue os destroços e procure os sinais do guardião. ".repeat(16))
		await _settle()
		var scroll: ScrollContainer = objective.get_node("Layout/TextScroll")
		assert(scroll.get_v_scroll_bar().max_value > scroll.size.y)
		scroll.scroll_vertical = 100000
		await _settle()
		assert(absf(status.size.x * status.scale.x / (root.get_visible_rect().size.x / root.size.x) - minf(280, root.size.x * 0.42)) < 1.0)
		await _capture("hud_" + str(resolution.x) + "x" + str(resolution.y))
		scene._set_objective("Investigue os sinais deixados entre os destroços.")
	scene._set_objective("Teste do aviso temporário.")
	assert(scene.get_node("Interface/ObjectivePanel").visible)
	scene._update_objective_visibility(5.1)
	assert(not scene.get_node("Interface/ObjectivePanel").visible)
	scene._objective_toggle.button_pressed = true
	scene._update_objective_visibility(0)
	assert(scene.get_node("Interface/ObjectivePanel").visible)
	scene._objective_toggle.button_pressed = false
	scene._update_objective_visibility(0)
	assert(not scene.get_node("Interface/ObjectivePanel").visible)
	var hover := InputEventMouseMotion.new()
	hover.position = scene._objective_toggle.get_global_rect().get_center()
	root.push_input(hover, true)
	scene._update_objective_visibility(0)
	assert(scene.get_node("Interface/ObjectivePanel").visible)
	hover.position = Vector2.ZERO
	root.push_input(hover, true)
	scene._update_objective_visibility(0)
	assert(not scene.get_node("Interface/ObjectivePanel").visible)
	scene._set_objective("A missão reaparece quando muda.")
	assert(scene.get_node("Interface/ObjectivePanel").visible)
	# Color follows the selected character, while health keeps a stable semantic color.
	for profile in state.CHARACTER_PROFILES:
		state.select_character(profile.id)
		var candidate: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
		candidate.skip_cinematics_for_tests = true
		root.add_child(candidate)
		assert(candidate.cooldown_bar.get_theme_stylebox("fill").bg_color == profile.color)
		for resolution in [Vector2i(640, 360), Vector2i(1152, 648)]:
			root.size = resolution
			await _settle()
			var status: Control = candidate.get_node("Interface/TopPanel")
			assert(status.get_global_rect().encloses(candidate._passive_label.get_global_rect()), "Passive must fit inside compact HUD")
			assert(status.get_global_rect().encloses(candidate._skill_label.get_global_rect()), "Special must fit inside compact HUD")
			await _capture("abilities_" + profile.id + "_" + str(resolution.x))
		candidate.queue_free()
		await process_frame
	scene._on_pause_settings_pressed()
	assert(scene.settings_card.get_node("TextSpeed").item_count == 4)
	scene.pause_panel.visible = true
	await _settle()
	await _capture("settings")
	scene.pause_panel.visible = false
	var manager: Node = root.get_node("DialogueManager")
	var sequence := {"actors": {}, "initial_slots": {}, "lines": [{"speaker": "Teste", "text": "Uma fala extensa. ".repeat(120)}]}
	for index in range(4):
		state.set_dialogue_speed(index)
		manager.play(sequence)
		await create_timer(0.8).timeout
		var overlay: Variant = manager._active_overlay
		assert(is_instance_valid(overlay))
		assert(overlay.dialogue_box.find_children("*", "OptionButton", true, false).is_empty())
		assert(overlay.dialogue_box.find_children("*", "Button", true, false).is_empty())
		assert(overlay.continue_indicator.modulate.a < 0.5)
		assert(overlay._characters_per_second == state.get_dialogue_speed())
		if index == 3:
			assert(not overlay._typing)
		overlay._finish_typing()
		await _settle()
		assert(overlay._text_scroll.get_v_scroll_bar().max_value > overlay._text_scroll.size.y)
		overlay._text_scroll.scroll_vertical = 100000
		await _settle()
		await _capture("dialogue_speed_" + str(index))
		overlay._request_skip()
		await create_timer(0.5).timeout
		assert(not manager.is_playing())
		assert(not paused)
	# Skip during the opening also restores control and the previous pause state.
	manager.play(sequence)
	manager._active_overlay._request_skip()
	await create_timer(1.0).timeout
	assert(not manager.is_playing())
	assert(not paused)
	paused = true
	manager.play(sequence)
	manager._active_overlay._request_skip()
	await create_timer(1.0).timeout
	assert(not manager.is_playing())
	assert(paused)
	paused = false
	state.set_dialogue_speed(original_speed)
	state.select_character("breaker")
	print("UI_EXPERIENCE_TEST_OK")
	quit(0)
