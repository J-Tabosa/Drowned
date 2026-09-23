extends SceneTree

const OUTPUT := "res://.godot/dialogue_visual_review"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var small := OS.get_environment("DROWNED_VISUAL_SMALL") == "1"
	root.size = Vector2i(640, 360) if small else Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var game_state: Node = root.get_node("GameState")
	var catalog: Variant = load("res://scripts/narrative/dialogue_catalog.gd")
	var overlay_scene: PackedScene = load("res://scenes/ui/dialogue/dialogue_overlay.tscn")
	var suffix := "_small" if small else ""
	for character_id in ["breaker", "sharpshooter", "diver"]:
		game_state.select_character(character_id)
		var stage := Node2D.new()
		var background := ColorRect.new()
		background.size = root.size
		background.color = Color("071521")
		stage.add_child(background)
		root.add_child(stage)
		var overlay: Variant = overlay_scene.instantiate()
		stage.add_child(overlay)
		overlay.start(catalog.get_intro(character_id))
		await create_timer(0.85).timeout
		assert(overlay._line_index == 0)
		print("dialogue viewport/window: ", overlay.get_viewport().get_visible_rect().size, " / ", root.size)
		assert(absf(overlay.left_portrait.size.y / overlay.get_viewport().get_visible_rect().size.y - 0.66) < 0.01)
		assert(overlay.dialogue_box.position.y < overlay.left_portrait.position.y + overlay.left_portrait.size.y)
		assert(overlay._typing)
		print(character_id, " regions: ", (overlay.left_texture.texture as AtlasTexture).region, " / ", (overlay.center_texture.texture as AtlasTexture).region, " / ", (overlay.right_texture.texture as AtlasTexture).region)
		overlay._finish_typing()
		await _capture(character_id + "_dialogue" + suffix)
		overlay._set_speaker_mouth(true)
		await _capture(character_id + "_speaking" + suffix)
		if character_id == "breaker":
			overlay._finish_typing()
			overlay._advance()
			await process_frame
			overlay._finish_typing()
			overlay._advance()
			await process_frame
			assert(overlay._speaker_slot == "center")
			overlay._set_speaker_mouth(true)
			await _capture("breaker_mouth_open" + suffix)
		stage.queue_free()
		await process_frame
	print("DIALOGUE_VISUAL_CHECK_OK")
	quit(0)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + name + ".png")
	assert(screenshot.save_png(path) == OK)
	print(path)
