extends SceneTree

const OUTPUT := "res://.godot/title_review"

func _initialize() -> void:
	call_deferred("_run")


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK)


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT + "/gif_frames"))
	if root.get_node("SceneTransition").busy:
		await root.get_node("SceneTransition").revealed
	var title: Variant = load("res://scenes/ui/menus/title_screen.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await create_timer(0.1).timeout
	await _capture("title_calm")
	title.ocean.manual_time = true
	for frame in 48:
		title.ocean.animation_time = float(frame) * 0.1
		title.ocean._update_art()
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = title.get_node("PixelOcean/OceanViewport").get_texture().get_image()
		assert(image.save_png(OUTPUT + "/gif_frames/boat_%03d.png" % frame) == OK)
	title.ocean.storm = 1.0
	title.ocean.lightning = 0.85
	title.title.hide()
	title.play_button.hide()
	title.ocean._update_art()
	await process_frame
	await _capture("title_storm")
	title.queue_free()
	await process_frame
	var selection: Variant = load("res://scenes/ui/menus/character_select.tscn").instantiate()
	root.add_child(selection)
	current_scene = selection
	await create_timer(0.15).timeout
	await _capture("selection_clean")
	selection.queue_free()
	await process_frame
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var manager: Node = root.get_node("DialogueManager")
	var catalog: Variant = load("res://scripts/narrative/dialogue_catalog.gd")
	manager.play(catalog.get_intro("sharpshooter"))
	await create_timer(0.8, true).timeout
	manager._active_overlay._finish_typing()
	await _capture("dialogue_left")
	manager._active_overlay._advance()
	await create_timer(0.3, true).timeout
	manager._active_overlay._finish_typing()
	await _capture("dialogue_right")
	manager._active_overlay._request_skip()
	await create_timer(0.4, true).timeout
	print("TITLE_VISUAL_CHECK_OK")
	quit(0)
