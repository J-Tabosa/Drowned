extends SceneTree
## Importa as duas folhas geradas, preserva transparência e registra os pés por linha.

const DIRECTORY := "res://assets/sprites/enemies/"
const NAMES := ["afogado", "guardiao_abissal", "afogado_pesado", "colosso_afogado"]


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	for enemy_name in NAMES:
		var source := Image.load_from_file(ProjectSettings.globalize_path(DIRECTORY + enemy_name + "_sheet_source.png"))
		assert(source != null)
		var rows := _cuts(source, 5, false)
		var row_columns: Array[Array] = []
		var reference_size := 0
		for row in 5:
			reference_size = maxi(reference_size, rows[row + 1] - rows[row])
			var row_image := source.get_region(Rect2i(0, rows[row], source.get_width(), rows[row + 1] - rows[row]))
			var columns := _cuts(row_image, 6, true)
			row_columns.append(columns)
			for column in 6:
				reference_size = maxi(reference_size, columns[column + 1] - columns[column])
		for size in [64, 96]:
			var output := Image.create(size * 6, size * 5, false, Image.FORMAT_RGBA8)
			for row in 5:
				var columns: Array = row_columns[row]
				var cells: Array[Image] = []
				var baseline := 0
				var cell_height := rows[row + 1] - rows[row]
				for column in 6:
					var rect := Rect2i(columns[column], rows[row], columns[column + 1] - columns[column], cell_height)
					var cell := source.get_region(rect)
					# Discard only almost-transparent fringe; retain the generated alpha.
					for y in cell.get_height():
						for x in cell.get_width():
							if cell.get_pixel(x, y).a < 0.12:
								cell.set_pixel(x, y, Color(0, 0, 0, 0))
					_remove_spill(cell)
					baseline = maxi(baseline, cell.get_used_rect().end.y)
					cells.append(cell)
				var ratio := float(size - 4) / float(reference_size)
				for column in 6:
					var cell := cells[column]
					var bounds := cell.get_used_rect()
					var crop := cell.get_region(bounds)
					crop.resize(maxi(1, roundi(bounds.size.x * ratio)), maxi(1, roundi(bounds.size.y * ratio)), Image.INTERPOLATE_NEAREST)
					var x: int = column * size + (size - crop.get_width()) / 2
					var y: int = row * size + size - 3 - roundi((baseline - bounds.position.y) * ratio)
					output.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(x, y))
			var path: String = DIRECTORY + enemy_name + "_sheet_%d.png" % size
			assert(output.save_png(path) == OK)
			print(path)
	print("ENEMY_SPRITES_OK")
	quit(0)


## Finds transparent gutters near the generated grid without slicing off boots.
func _cuts(source: Image, count: int, vertical: bool) -> Array[int]:
	var length := source.get_width() if vertical else source.get_height()
	var cross := source.get_height() if vertical else source.get_width()
	var cuts: Array[int] = [0]
	for index in range(1, count):
		var expected := roundi(float(length * index) / count)
		var best := expected
		var best_weight := INF
		var search := mini(90, length / count / 2 - 4) if vertical else 40
		for candidate in range(maxi(3, expected - search), mini(length - 3, expected + search + 1)):
			var weight := 0.0
			for offset in range(-2, 3):
				for point in cross:
					var color := source.get_pixel(candidate + offset, point) if vertical else source.get_pixel(point, candidate + offset)
					if color.a > 0.5:
						weight += 1.0
			weight += absf(candidate - expected) * 0.01
			if weight < best_weight:
				best_weight = weight
				best = candidate
		cuts.append(best)
	cuts.append(length)
	return cuts


## Remove fragmentos de uma pose vizinha que o gerador deixou cruzar a grade.
func _remove_spill(cell: Image) -> void:
	var visited := PackedByteArray()
	visited.resize(cell.get_width() * cell.get_height())
	var pieces: Array[Array] = []
	var largest := 0
	for y in cell.get_height():
		for x in cell.get_width():
			var id := y * cell.get_width() + x
			if visited[id] or cell.get_pixel(x, y).a < 0.5:
				continue
			var pending: Array[Vector2i] = [Vector2i(x, y)]
			var piece: Array[Vector2i] = []
			visited[id] = 1
			while not pending.is_empty():
				var point: Vector2i = pending.pop_back()
				piece.append(point)
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = point + offset
					if next.x < 0 or next.y < 0 or next.x >= cell.get_width() or next.y >= cell.get_height():
						continue
					var next_id := next.y * cell.get_width() + next.x
					if visited[next_id] or cell.get_pixelv(next).a < 0.5:
						continue
					visited[next_id] = 1
					pending.append(next)
			largest = maxi(largest, piece.size())
			pieces.append(piece)
	for piece in pieces:
		if piece.size() < largest:
			for point in piece:
				cell.set_pixelv(point, Color(0, 0, 0, 0))
