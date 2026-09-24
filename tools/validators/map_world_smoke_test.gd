extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab: Node2D = load("res://scenes/world/areas/movement_lab.tscn").instantiate()
	root.add_child(lab)
	await physics_frame
	var cave: Node2D = lab.arena
	var counts: Dictionary = cave.get_tile_counts()
	assert(cave._map_rows.size() == 43)
	assert(counts.floor > 1000)
	assert(counts.wall > 80)
	assert(counts.gate == 26)
	assert(counts.items == 3)
	assert(cave.floor_tiles.get_child(0).top_shape.texture.get_size() == Vector2(16, 16))
	assert(cave.wall_tiles.get_child(0).top_shape.texture.get_size() == Vector2(32, 32))
	var water_tile: Node2D = cave.floor_tiles.get_node("Floor_21_60")
	assert(water_tile.top_shape.texture.get_size() == Vector2(32, 32))
	assert(water_tile.top_shape.material is ShaderMaterial)
	assert(cave._exit_gate_art.texture.get_size() == Vector2(96, 64))
	assert(cave.items.get_child(0).get_node("Sprite2D").texture.get_size() == Vector2(32, 32))
	assert(cave.get_mob_spawn_positions().size() == 7)
	assert(cave.get_story_echo_positions().size() == 3)
	assert(cave.get_item_positions().size() == 3)
	assert(cave.get_world_rect().size.x > 12000.0)
	assert(cave.get_story_echo_positions()[0].x < cave.get_story_echo_positions()[1].x)
	assert(cave.get_story_echo_positions()[1].x < cave.get_story_echo_positions()[2].x)
	assert(_can_reach(cave, "P", "L", ""))
	assert(not _can_reach(cave, "P", "C", ""))
	assert(not _can_reach(cave, "P", "B", ""))
	assert(not _can_reach(cave, "P", "E", ""))
	for cell in cave._floor_cells:
		if cave._floor_cells[cell] in ["~", "r", "1", "2", "3"]:
			assert(not cave.is_walkable(cave.to_global(cave._cell_to_local(cell)), 0.0))
	for position in cave.get_mob_spawn_positions():
		assert(cave.is_walkable(position, 24.0))
	cave.open_tutorial_gate()
	assert(_can_reach(cave, "P", "C", "1"))
	assert(not _can_reach(cave, "P", "B", "1"))
	cave.open_boss_gate()
	assert(_can_reach(cave, "P", "B", "12"))
	assert(not _can_reach(cave, "P", "E", "12"))
	cave.open_post_boss_gate()
	await physics_frame
	assert(_can_reach(cave, "P", "E", "123"))
	var item_position: Vector2 = cave.get_item_positions()[0]
	lab.player.global_position = item_position
	await physics_frame
	await physics_frame
	assert(cave.get_collected_item_count() == 1)
	assert(lab.relic_label.text == "RELÍQUIAS  1/3")
	print("MAP_WORLD_SMOKE_TEST_OK")
	quit(0)


func _can_reach(cave: Node2D, start_symbol: String, target_symbol: String, open_gates: String) -> bool:
	var start := Vector2i(-1, -1)
	var target := Vector2i(-1, -1)
	for cell in cave._floor_cells:
		if cave._floor_cells[cell] == start_symbol:
			start = cell
		if cave._floor_cells[cell] == target_symbol:
			target = cell
	assert(start.x >= 0 and target.x >= 0)
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var index := 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		if current == target:
			return true
		for neighbour in cave._neighbours(current):
			if seen.has(neighbour) or not cave._floor_cells.has(neighbour):
				continue
			var symbol: String = cave._floor_cells[neighbour]
			if symbol in ["~", "r"] or symbol in ["1", "2", "3"] and not open_gates.contains(symbol):
				continue
			seen[neighbour] = true
			queue.append(neighbour)
	return false
