extends SceneTree

const OUTPUT := "res://.godot/enemy_visual_review/"
var _lab: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_lab = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	_lab.skip_cinematics_for_tests = true
	root.add_child(_lab)
	await process_frame
	_lab.set_process(false)
	_lab.player.set_controls_enabled(false)
	_lab.arena.open_tutorial_gate()
	_lab.arena.open_boss_gate()
	var center: Vector2 = _lab.arena.get_anchor_position("boss_spawn")
	_lab.player.global_position = center + Vector2(-190, 75)
	_lab.player.camera.position_smoothing_enabled = false
	_lab.player.camera.zoom = Vector2(1.65, 1.65)
	_lab.player.camera.offset = Vector2(170, -40)
	_lab.objective_label.text = "AFOGADOS E GUARDIÃO ABISSAL"
	_lab.stage_label.text = "PRÉVIA DOS INIMIGOS"
	var enemies: Array[Node2D] = []
	for offset in [Vector2(-60, 100), Vector2(35, 55), Vector2(150, -35)]:
		var enemy: Variant = load("res://scenes/characters/enemies/placeholder_enemy.tscn").instantiate()
		if offset.x > 100:
			enemy.setup({"is_miniboss": true, "max_health": 700.0, "body_size": Vector2(104, 128)})
		_lab.add_child(enemy)
		enemy.global_position = center + offset
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await create_timer(0.2, false).timeout
	await _capture("idle")
	enemies[0].body.set_locomotion(true)
	enemies[1]._attack(Vector2.LEFT)
	enemies[2]._start_boss_dash(Vector2.LEFT)
	await create_timer(0.3, false).timeout
	await _capture("attack_warning")
	enemies[0].health_component.take_damage(10.0, _lab.player.global_position)
	paused = true
	await _capture("damage_impact")
	paused = false
	enemies[0].health_component.kill()
	enemies[1].health_component.kill()
	await create_timer(0.64, false).timeout
	await _capture("death")
	_lab.queue_free()
	await process_frame
	print("ENEMY_VISUAL_CHECK_OK")
	quit(0)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png(ProjectSettings.globalize_path(OUTPUT + name + ".png")) == OK)
