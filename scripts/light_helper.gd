class_name LightHelper
extends RefCounted

static var _cached_tex: Texture2D = null

static func get_radial_texture(size: int = 128) -> Texture2D:
	if _cached_tex:
		return _cached_tex
	
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = float(size) * 0.5
	var max_r = center
	
	for y in range(size):
		for x in range(size):
			var dist = Vector2(x - center, y - center).length()
			var norm = clamp(dist / max_r, 0.0, 1.0)
			# Smooth cosine falloff
			var alpha = 0.5 * (1.0 + cos(norm * PI)) if norm < 1.0 else 0.0
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
			
	_cached_tex = ImageTexture.create_from_image(img)
	return _cached_tex
