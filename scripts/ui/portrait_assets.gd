class_name PortraitAssets
extends RefCounted

static var _cache: Dictionary = {}


static func resolve(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value
	if not value is String or value.is_empty() or not ResourceLoader.exists(value):
		return null
	if _cache.has(value):
		return _cache[value]
	var original: Texture2D = load(value)
	var image := original.get_image()
	var min_point := image.get_size()
	var max_point := Vector2i(-1, -1)
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			if image.get_pixel(x, y).a < 0.45:
				continue
			min_point.x = mini(min_point.x, x)
			min_point.y = mini(min_point.y, y)
			max_point.x = maxi(max_point.x, x)
			max_point.y = maxi(max_point.y, y)
	if max_point.x < min_point.x:
		_cache[value] = original
		return original
	var bounds := Rect2i(min_point, max_point - min_point + Vector2i(3, 3)).grow(16)
	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var atlas := AtlasTexture.new()
	atlas.atlas = original
	atlas.region = Rect2(bounds)
	_cache[value] = atlas
	return atlas
