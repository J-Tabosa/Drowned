extends SceneTree

const OUTPUT := "res://.godot/map_debug_review"


func _initialize() -> void:
	call_deferred("_run")


func _key(code: int, pressed := true, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	Input.parse_input_event(event)


func _chord() -> void:
	_key(KEY_CTRL, true, true)
	_key(KEY_H, true, true)
	_key(KEY_J, true, true)
	await process_frame
	_key(KEY_J, false, true)
	_key(KEY_H, false, true)
	_key(KEY_CTRL, false)
	await process_frame


func _capture(name: String) -> void:
	if OS.get_environment("DROWNED_MAP_CAPTURE") != "1": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK)


func _run() -> void:
	var transition: Node = root.get_node("SceneTransition")
	var state: Node = root.get_node("GameState")
	if transition.busy: await transition.revealed
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1152, 648)
	var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	lab.skip_cinematics_for_tests = true
	root.add_child(lab)
	current_scene = lab
	await process_frame
	var exploration: Node = lab._exploration
	var initial_count: int = exploration.explored.size()
	assert(initial_count > 0 and initial_count < lab.arena._floor_cells.size())
	var before_gate: Vector2 = lab.arena._cell_to_local(Vector2i(39, 13))
	var after_gate: Vector2 = lab.arena._cell_to_local(Vector2i(41, 13))
	assert(not exploration._has_sight(before_gate, after_gate), "Closed gates must stop discovery beyond them")
	assert(not exploration.debug_reveal)
	assert(not lab._debug_tools.visible and not lab._map_panel.visible)
	assert(not lab.has_node("Interface/DeveloperPanel"))
	_key(KEY_F3)
	await process_frame
	_key(KEY_F3, false)
	assert(not lab._debug_tools.visible)
	_key(KEY_CTRL, true, true)
	_key(KEY_H, true, true)
	await process_frame
	assert(not lab._debug_tools.visible, "Ctrl+H alone cannot expose tools")
	_key(KEY_H, false, true)
	_key(KEY_CTRL, false)
	Input.action_press("move_right")
	await create_timer(0.6).timeout
	Input.action_release("move_right")
	assert(exploration.explored.size() > initial_count, "Walking must expose more cells")
	var visited_before_menu: Dictionary = exploration.explored.duplicate()
	_key(KEY_M)
	await process_frame
	_key(KEY_M, false)
	assert(lab._map_panel.visible and paused)
	assert(not lab._map_panel.map_view.teleport_mode)
	for resolution in [Vector2i(1152, 648), Vector2i(640, 360), Vector2i(800, 1000)]:
		root.size = resolution
		await process_frame
		var panel: Variant = lab._map_panel
		panel._layout()
		var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		assert(bounds.encloses(panel._card.get_global_rect()))
		assert(bounds.encloses(panel._close.get_global_rect()))
		var view: Variant = panel.map_view
		var rectangle: Rect2 = lab.arena.get_world_rect()
		for point in [rectangle.position, rectangle.end]:
			assert(Rect2(Vector2.ZERO, view.size).has_point(view.world_to_map(point)))
		var point: Vector2 = lab.player.global_position
		assert(view.map_to_world(view.world_to_map(point)).distance_to(point) < 0.01)
		await _capture("explored_" + str(resolution.x))
	_key(KEY_ESCAPE)
	await process_frame
	_key(KEY_ESCAPE, false)
	assert(not paused and not lab.pause_panel.visible)
	lab._toggle_pause()
	assert(paused)
	lab._open_map()
	assert(lab._map_panel.visible)
	lab._map_panel.close()
	assert(paused, "Closing a map opened from pause must preserve pause")
	lab._toggle_pause()
	assert(not paused)
	await _chord()
	assert(lab._debug_tools.visible and paused, "Full Ctrl+H+J chord must open debug")
	await _capture("debug_panel")
	await _chord()
	assert(not lab._debug_tools.visible and not paused)
	await _chord()
	var original: Dictionary = state._progression.duplicate(true)
	var save_before := FileAccess.get_file_as_string(state.PROGRESSION_FILE) if FileAccess.file_exists(state.PROGRESSION_FILE) else ""
	lab._debug_test_tree()
	assert(lab._skill_tree.visible and paused)
	assert(not lab._debug_tools.visible)
	assert(state.get_skill_xp(lab.player.profile.id) == int(original[lab.player.profile.id].xp) + 1000)
	var catalog: Script = load("res://scripts/gameplay/skill_catalog.gd")
	for branch in catalog.branches(lab.player.profile.id):
		for skill in branch.nodes:
			if not state.has_skill(lab.player.profile.id, skill.id):
				assert(state.learn_skill(lab.player.profile.id, skill.id))
	assert(lab.player.damage_multiplier == 1.2)
	assert(lab.player.skill_recharge_multiplier == 0.8)
	var save_after := FileAccess.get_file_as_string(state.PROGRESSION_FILE) if FileAccess.file_exists(state.PROGRESSION_FILE) else ""
	assert(save_before == save_after, "Debug purchases must not write the real save")
	await _capture("tree_test")
	lab._skill_tree.close()
	assert(not paused)
	state.restore_debug_progression()
	assert(state._progression == original)
	assert(lab.player._learned == original[lab.player.profile.id].learned)
	await _chord()
	lab._debug_tools.teleport_requested.emit()
	assert(not lab._debug_tools.visible and lab._map_panel.visible and paused)
	assert(lab._map_panel.map_view.teleport_mode)
	var view: Variant = lab._map_panel.map_view
	var mouse_point: Vector2 = view.size * 0.6
	var anchor_before: Vector2 = view.map_to_world(mouse_point)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.position = mouse_point
	wheel.pressed = true
	view._gui_input(wheel)
	assert(view.zoom > 1.0)
	assert(view.map_to_world(mouse_point).distance_to(anchor_before) < 0.01, "Zoom must preserve the cursor location")
	view.reset_view()
	var before: Vector2 = lab.player.global_position
	lab._debug_teleport(lab.arena.get_world_rect().position - Vector2(100, 100))
	assert(lab.player.global_position == before, "Invalid destinations cannot move the player")
	var destination: Vector2 = lab.arena.get_anchor_position("boss_spawn")
	assert(lab.arena.is_walkable(destination, 26))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = view.world_to_map(destination)
	view._gui_input(click)
	assert(lab.player.global_position.distance_to(destination) < 0.01)
	assert(lab._last_player_position.distance_to(destination) < 0.01)
	assert(exploration.explored.size() > initial_count)
	var discovered: Dictionary = exploration.explored.duplicate()
	for cell in visited_before_menu:
		assert(discovered.has(cell), "Exploration must survive leaving an area")
	await _capture("teleport")
	lab._map_panel.close()
	await _chord()
	lab._debug_tools.reveal_requested.emit()
	assert(exploration.debug_reveal and lab._map_panel.visible)
	assert(exploration.explored == discovered, "Debug reveal must not falsify explored cells")
	for cell in lab.arena._floor_cells:
		assert(exploration.is_revealed(cell))
	root.size = Vector2i(1152, 648)
	await process_frame
	await _capture("full_map")
	lab._map_panel.close()
	exploration.toggle_debug_reveal()
	assert(not exploration.debug_reveal and exploration.explored == discovered)
	state.debug_skill_xp(lab.player.profile.id)
	lab.queue_free()
	await process_frame
	assert(state._progression == original, "Leaving the level must restore real progression")
	assert(not paused)
	print("MAP_DEBUG_TEST_OK")
	quit(0)
