extends RefCounted

## Mantém as imagens geradas em 32 pixels lógicos na renderização do jogo.
## O PNG de origem permanece intacto; a versão pequena é criada uma vez em memória.
static var _cache: Dictionary = {}


static func pixel_texture(source: Texture2D, size: Vector2i, opaque_base := Color.TRANSPARENT) -> Texture2D:
	var cache_key := "%s:%dx%d:%s" % [source.resource_path, size.x, size.y, opaque_base.to_html(true)]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var image := source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	for y in size.y:
		for x in size.x:
			var color := image.get_pixel(x, y)
			if opaque_base.a > 0.0:
				color = opaque_base.lerp(Color(color.r, color.g, color.b, 1.0), color.a)
				color.a = 1.0
			elif color.a < 0.5:
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			else:
				color.a = 1.0
			color.r = roundf(color.r * 12.0) / 12.0
			color.g = roundf(color.g * 12.0) / 12.0
			color.b = roundf(color.b * 12.0) / 12.0
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_cache[cache_key] = texture
	return texture
