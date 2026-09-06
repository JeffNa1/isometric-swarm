class_name LightHelper
extends RefCounted

static var _cached_radial: Texture2D = null
static var _cached_anamorphic: Texture2D = null
static var _cached_spotlight: Texture2D = null
static var _cached_ring: Texture2D = null

## Tạo Texture ánh sáng tỏa tròn mềm mại
static func get_radial_texture(size: int = 128) -> Texture2D:
	if _cached_radial:
		return _cached_radial

	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var dist = Vector2(x - center, y - center).length()
			var norm = clamp(dist / center, 0.0, 1.0)
			var alpha = 0.5 * (1.0 + cos(norm * PI)) if norm < 1.0 else 0.0
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	_cached_radial = ImageTexture.create_from_image(img)
	return _cached_radial

## Tạo Texture vệt lóa ngang Cyberpunk (Anamorphic Lens Flare)
static func get_anamorphic_flare_texture(width: int = 256, height: int = 64) -> Texture2D:
	if _cached_anamorphic:
		return _cached_anamorphic

	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var cx = float(width) * 0.5
	var cy = float(height) * 0.5
	for y in range(height):
		for x in range(width):
			var dx = abs(x - cx) / cx
			var dy = abs(y - cy) / cy
			var alpha_x = pow(clamp(1.0 - dx, 0.0, 1.0), 2.5)
			var alpha_y = pow(clamp(1.0 - dy, 0.0, 1.0), 8.0)
			var alpha = alpha_x * alpha_y
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	_cached_anamorphic = ImageTexture.create_from_image(img)
	return _cached_anamorphic

## Tạo Texture đèn pha hình nón định hướng (Conic Tactical Spotlight)
static func get_conic_spotlight_texture(size: int = 128) -> Texture2D:
	if _cached_spotlight:
		return _cached_spotlight

	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size * 0.5, size * 0.1) # Nguồn sáng ở đỉnh trên
	for y in range(size):
		for x in range(size):
			var delta = Vector2(x, y) - center
			var dist = delta.length()
			var max_dist = float(size) * 0.9
			if dist > max_dist or dist < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var angle = abs(atan2(delta.x, delta.y)) # Góc lệch so với hướng thẳng xuống
			var cone_limit = 0.55 # ~31 độ
			if angle > cone_limit:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var falloff_dist = pow(clamp(1.0 - dist / max_dist, 0.0, 1.0), 1.5)
			var falloff_angle = pow(clamp(1.0 - angle / cone_limit, 0.0, 1.0), 2.0)
			var alpha = falloff_dist * falloff_angle
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	_cached_spotlight = ImageTexture.create_from_image(img)
	return _cached_spotlight

## Tạo Texture vòng phát quang mượt mà (Smooth Shockwave Ring)
static func get_smooth_ring_texture(size: int = 128) -> Texture2D:
	if _cached_ring:
		return _cached_ring

	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = float(size) * 0.5
	var r_inner = center * 0.65
	var r_outer = center * 0.95
	var r_mid = (r_inner + r_outer) * 0.5
	var half_w = (r_outer - r_inner) * 0.5

	for y in range(size):
		for x in range(size):
			var dist = Vector2(x - center, y - center).length()
			if dist < r_inner or dist > r_outer:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var d_norm = abs(dist - r_mid) / half_w
				var alpha = 0.5 * (1.0 + cos(d_norm * PI))
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	_cached_ring = ImageTexture.create_from_image(img)
	return _cached_ring
