extends SceneTree

const OUTPUT := "res://.godot/animation_visual_review"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var small := OS.get_environment("DROWNED_VISUAL_SMALL") == "1"
	root.size = Vector2i(640, 360) if small else Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var game_state: Node = root.get_node("GameState")
	var suffix := "_small" if small else ""
	var selection: Control = load("res://scenes/ui/menus/character_select.tscn").instantiate()
	root.add_child(selection)
	await process_frame
	await _capture("character_selection" + suffix)
	selection.queue_free()
	await process_frame
	var lab_scene: PackedScene = load("res://scenes/world/areas/movement_lab.tscn")
	for character_id in ["breaker", "sharpshooter", "diver"]:
		game_state.select_character(character_id)
		var lab: Variant = lab_scene.instantiate()
		lab.skip_cinematics_for_tests = true
		root.add_child(lab)
		await create_timer(0.9, false).timeout
		await _capture(character_id + "_idle" + suffix)
		if character_id == "breaker":
			lab.underwater_fog.call("set_fog_enabled", false)
			await _capture(character_id + "_no_fog" + suffix)
			lab.underwater_fog.call("set_fog_enabled", true)
			Input.action_press("move_right")
			for pose in 6:
				await create_timer(0.09, false).timeout
				await _capture("breaker_walk_%d" % pose + suffix)
			Input.action_release("move_right")
		Input.warp_mouse(Vector2i(int(root.size.x * 0.78), int(root.size.y * 0.52)))
		await process_frame
		lab.player.call("_use_primary_action")
		await create_timer(0.27, false).timeout
		await _capture(character_id + "_attack" + suffix)
		lab.queue_free()
		await process_frame
	print("ANIMATION_VISUAL_CHECK_OK")
	quit(0)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + name + ".png")
	var error := screenshot.save_png(path)
	assert(error == OK)
	print(path)
