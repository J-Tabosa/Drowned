extends SceneTree

# Source sheets have a strict 6 x 4 grid of 256 px cells: idle, walk, attack, hurt.
# Keep the grid and the registration of each pose when reducing it for the game.
const NAMES := ["quebra_mar", "vigia", "mergulhador"]
const COLUMNS := 6
const ROWS := 4
const SOURCE_CELL := 256
const OUTPUT_SIZES := [96, 64, 32]
const ALPHA_CUTOFF := 0.12


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	for character_name in NAMES:
		var directory := "res://assets/sprites/characters/animations/"
		var source := Image.load_from_file(directory + character_name + "_sheet_source.png")
		if source == null or source.get_size() != Vector2i(1536, 1024):
			push_error("Invalid source sheet: " + character_name)
			quit(1)
			return
		print(character_name)
		for row in ROWS:
			var bounds_line := "  %d:" % row
			for column in COLUMNS:
				var bounds := _opaque_bounds(source, column, row)
				bounds_line += " (%d,%d)-(%d,%d)" % [bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y]
			print(bounds_line)
		for output_size in OUTPUT_SIZES:
			var output := Image.create(COLUMNS * output_size, ROWS * output_size, false, Image.FORMAT_RGBA8)
			for row in ROWS:
				for column in COLUMNS:
					var cell := _extract_cell(source, character_name, row, column)
					_clean_alpha(cell, character_name, row, column)
					cell.resize(output_size, output_size, Image.INTERPOLATE_NEAREST)
					if row == 1:
						_remove_small_fragments(cell, maxi(4, output_size / 4))
					output.blit_rect(cell, Rect2i(0, 0, output_size, output_size), Vector2i(column * output_size, row * output_size))
			var path: String = directory + character_name + "_sheet_%d.png" % output_size
			var error := output.save_png(ProjectSettings.globalize_path(path))
			if error != OK:
				push_error("Could not write " + path + ": " + str(error))
				quit(1)
				return
	quit(0)


func _extract_cell(source: Image, character_name: String, row: int, column: int) -> Image:
	var cell := Image.create(SOURCE_CELL, SOURCE_CELL, false, Image.FORMAT_RGBA8)
	# The Breaker's walking anchor crosses the generated cell border by about
	# 16 source pixels. Shift the sampling window consistently for all six poses.
	var shift := 16 if character_name == "quebra_mar" and row == 1 else 0
	var source_width := mini(SOURCE_CELL, source.get_width() - column * SOURCE_CELL - shift)
	var source_rect := Rect2i(column * SOURCE_CELL + shift, row * SOURCE_CELL, source_width, SOURCE_CELL)
	cell.blit_rect(source, source_rect, Vector2i.ZERO)
	return cell


func _clean_alpha(image: Image, character_name: String, row: int, column: int) -> void:
	var left_trim := 0
	# The long harpoon flash in one pose spilled into the next generated cell.
	# These cuts affect only that spill, well before the character silhouette.
	if character_name == "vigia":
		if row == 2 and column == 3:
			left_trim = 45
		elif row == 2 and column == 1:
			left_trim = 30
		elif row == 3 and column == 3:
			left_trim = 35
		elif row == 3 and column == 5:
			left_trim = 30
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < ALPHA_CUTOFF or x < left_trim or (character_name == "quebra_mar" and row == 1 and y < 20):
				image.set_pixel(x, y, Color.TRANSPARENT)


func _remove_small_fragments(image: Image, minimum_pixels: int) -> void:
	# Remove disconnected cell-edge crumbs, not the actual body/anchor silhouette.
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	for y in height:
		for x in width:
			var start := y * width + x
			if visited[start] != 0 or image.get_pixel(x, y).a < ALPHA_CUTOFF:
				continue
			var pending := [Vector2i(x, y)]
			var component: Array[Vector2i] = []
			visited[start] = 1
			while not pending.is_empty():
				var point: Vector2i = pending.pop_back()
				component.append(point)
				for neighbor in [point + Vector2i.LEFT, point + Vector2i.RIGHT, point + Vector2i.UP, point + Vector2i.DOWN]:
					if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= width or neighbor.y >= height:
						continue
					var offset: int = neighbor.y * width + neighbor.x
					if visited[offset] != 0 or image.get_pixelv(neighbor).a < ALPHA_CUTOFF:
						continue
					visited[offset] = 1
					pending.append(neighbor)
			if component.size() < minimum_pixels:
				for point in component:
					image.set_pixelv(point, Color.TRANSPARENT)


func _opaque_bounds(source: Image, column: int, row: int) -> Rect2i:
	var min_x := SOURCE_CELL
	var min_y := SOURCE_CELL
	var max_x := -1
	var max_y := -1
	for y in SOURCE_CELL:
		for x in SOURCE_CELL:
			if source.get_pixel(column * SOURCE_CELL + x, row * SOURCE_CELL + y).a <= 0.5:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
