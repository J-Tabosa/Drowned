extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1152, 648)
	var lab: Node2D = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	for _frame in 4:
		await process_frame
	var start_image := root.get_texture().get_image()
	start_image.save_png(ProjectSettings.globalize_path("res://.godot/map_start.png"))
	lab.boss_intro_card.play(
		"GUARDIÃO ABISSAL",
		"(Guardião das Profundezas) — MINICHEFE",
		"Uma sentinela ancestral da caverna. Seu dash percorre toda a área marcada antes do impacto.",
		Color("9b58b5"),
		0.7
	)
	await create_timer(0.62).timeout
	var card_image := root.get_texture().get_image()
	card_image.save_png(ProjectSettings.globalize_path("res://.godot/boss_card.png"))
	await create_timer(1.1).timeout
	lab.player.camera.enabled = false
	var overview_camera := Camera2D.new()
	lab.add_child(overview_camera)
	var world_rect: Rect2 = lab.arena.get_world_rect()
	overview_camera.global_position = world_rect.get_center()
	var viewport_size := Vector2(root.size)
	var fit_zoom := minf(viewport_size.x / world_rect.size.x, viewport_size.y / world_rect.size.y) * 0.92
	overview_camera.zoom = Vector2.ONE * fit_zoom
	overview_camera.enabled = true
	for _frame in 4:
		await process_frame
	var overview_image := root.get_texture().get_image()
	overview_image.save_png(ProjectSettings.globalize_path("res://.godot/map_overview.png"))
	print("MAP_SNAPSHOT_OK")
	quit(0)
