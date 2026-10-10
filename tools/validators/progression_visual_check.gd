extends SceneTree

const OUTPUT := "res://.godot/progression_review"


func _initialize() -> void:
	call_deferred("_run")


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + file_name + ".png") == OK)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var state: Node = root.get_node("GameState")
	var original: Dictionary = state._progression.duplicate(true)
	var original_id: String = state.selected_character_id
	state.select_character("sharpshooter")
	state._progression.sharpshooter = {"xp": 100, "learned": []}
	if root.get_node("SceneTransition").busy:
		await root.get_node("SceneTransition").revealed
	root.size = Vector2i(1152, 648)
	var lab: Variant = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	lab.skip_cinematics_for_tests = true
	root.add_child(lab)
	current_scene = lab
	await process_frame
	lab._open_skill_tree()
	for resolution in [Vector2i(640, 360), Vector2i(1152, 648), Vector2i(800, 1000)]:
		root.size = resolution
		await process_frame
		await process_frame
		await _capture("tree_" + str(resolution.x))
		assert(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(lab._skill_tree._card.get_global_rect()))
	lab._skill_tree.close()
	root.size = Vector2i(1152, 648)
	lab.arena.open_tutorial_gate()
	lab.arena.open_boss_gate()
	var center: Vector2 = lab.arena.get_anchor_position("boss_spawn")
	lab.player.global_position = center
	lab.player.camera.reset_smoothing()
	lab.player.set_controls_enabled(false)
	var normal: Variant = lab._spawn_enemy(center + Vector2(-160, 15), lab._enemy_profile("sailor"))
	var heavy: Variant = lab._spawn_enemy(center + Vector2(160, 15), lab._enemy_profile("brute"))
	normal.set_physics_process(false)
	heavy.set_physics_process(false)
	await create_timer(0.2).timeout
	await _capture("enemy_types")
	heavy.emerge_from_ground()
	await create_timer(0.4).timeout
	assert(heavy._emerging and heavy.body.material != null)
	assert(heavy.find_children("*", "Label", true, false).is_empty())
	await _capture("emergence")
	await create_timer(0.55).timeout
	assert(heavy._active and not heavy._emerging)
	normal.queue_free()
	heavy.queue_free()
	await process_frame
	lab._spawn_boss_for_reveal()
	lab._stage = lab.EncounterStage.REACH_BOSS
	lab._begin_boss_fight(true)
	lab._boss.set_physics_process(false)
	lab.player.global_position = center + Vector2(-190, 80)
	lab.player.camera.reset_smoothing()
	lab.player.set_controls_enabled(false)
	lab._boss._start_roar()
	await create_timer(0.38).timeout
	lab._boss._release_roar()
	await create_timer(0.1).timeout
	await _capture("boss_roar")
	lab._boss.health_component.kill()
	await create_timer(0.25).timeout
	await _capture("boss_xp")
	lab.queue_free()
	await process_frame
	state._progression = original
	state._save_progression()
	state.select_character(original_id)
	print("PROGRESSION_VISUAL_CHECK_OK")
	quit(0)
