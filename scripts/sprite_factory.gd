class_name SpriteFactory
extends RefCounted

## SpriteFactory: Procedural High-Fidelity 2.5D Isometric Art Generator
## Generates crisp ImageTextures with ground shadows, specular highlights, and HDR glows.

static func create_crawler_texture() -> ImageTexture:
	var w = 48
	var h = 48
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Isometric Ground Shadow (ellipse centered at 24, 38)
	for y in range(32, 45):
		for x in range(8, 40):
			var dx = (x - 24.0) / 14.0
			var dy = (y - 38.0) / 5.0
			var dist = dx * dx + dy * dy
			if dist <= 1.0:
				var alpha = 0.45 * (1.0 - dist * 0.4)
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))

	# Helper draw pixel with blending
	var draw_p = func(px: int, py: int, col: Color):
		if px >= 0 and px < w and py >= 0 and py < h:
			var bg = img.get_pixel(px, py)
			img.set_pixel(px, py, bg.blend(col))

	# 2. Six Spider-Like Segmented Legs
	# Left legs (3)
	var left_legs = [
		[Vector2(16, 20), Vector2(10, 16), Vector2(6, 12)],   # Front left
		[Vector2(15, 24), Vector2(8, 24), Vector2(4, 26)],    # Mid left
		[Vector2(16, 28), Vector2(9, 32), Vector2(6, 38)]     # Rear left
	]
	# Right legs (3)
	var right_legs = [
		[Vector2(32, 20), Vector2(38, 16), Vector2(42, 12)],  # Front right
		[Vector2(33, 24), Vector2(40, 24), Vector2(44, 26)],  # Mid right
		[Vector2(32, 28), Vector2(39, 32), Vector2(42, 38)]   # Rear right
	]

	var leg_color_dark = Color(0.12, 0.12, 0.15, 1.0)
	var leg_joint_col = Color(0.55, 0.15, 0.18, 1.0)
	var leg_tip_col = Color(0.85, 0.2, 0.2, 1.0)

	for leg in left_legs + right_legs:
		_draw_line_on_image(img, leg[0], leg[1], leg_color_dark, 2)
		_draw_line_on_image(img, leg[1], leg[2], leg_color_dark, 1)
		draw_p.call(int(leg[1].x), int(leg[1].y), leg_joint_col)
		draw_p.call(int(leg[2].x), int(leg[2].y), leg_tip_col)

	# 3. Abdomen (Rear Chitin Shell, segmented)
	for y in range(20, 36):
		for x in range(14, 34):
			var dx = (x - 24.0) / 8.5
			var dy = (y - 28.0) / 7.5
			var r_sq = dx * dx + dy * dy
			if r_sq <= 1.0:
				var base_lum = 0.16 + (1.0 - r_sq) * 0.2
				var chitin_col = Color(base_lum * 1.1, base_lum * 0.8, base_lum * 0.85, 1.0)

				# Horizontal chitin segment borders
				if y == 23 or y == 27 or y == 31:
					chitin_col = Color(0.08, 0.08, 0.09, 1.0)
				# Specular spine highlight down center
				elif abs(x - 24) == 0:
					chitin_col = Color(0.85, 0.25, 0.25, 1.0)
				elif abs(x - 24) == 1 and r_sq < 0.6:
					chitin_col = Color(0.55, 0.18, 0.18, 1.0)

				# Bio-luminescent crimson veins
				if (abs(x - 24) == 3 or abs(x - 24) == 5) and (y >= 24 and y <= 32):
					chitin_col = Color(1.4, 0.15, 0.15, 1.0)

				img.set_pixel(x, y, chitin_col)

	# 4. Cephalothorax (Front Head & Armor Plate)
	for y in range(12, 22):
		for x in range(17, 31):
			var dx = (x - 24.0) / 6.0
			var dy = (y - 17.0) / 4.5
			var r_sq = dx * dx + dy * dy
			if r_sq <= 1.0:
				var head_lum = 0.22 + (1.0 - r_sq) * 0.25
				var head_col = Color(head_lum, head_lum * 0.75, head_lum * 0.75, 1.0)
				if abs(x - 24) <= 1 and y <= 16:
					head_col = Color(0.7, 0.75, 0.8, 1.0)
				img.set_pixel(x, y, head_col)

	# 5. Menacing Mandibles / Front Pincers
	var mandibles = [
		Vector2(20, 12), Vector2(19, 10), Vector2(18, 8), Vector2(19, 7), Vector2(21, 8),
		Vector2(28, 12), Vector2(29, 10), Vector2(30, 8), Vector2(29, 7), Vector2(27, 8)
	]
	for p in mandibles:
		draw_p.call(int(p.x), int(p.y), Color(0.9, 0.92, 0.95, 1.0))
	draw_p.call(21, 7, Color(1.5, 0.2, 0.2, 1.0))
	draw_p.call(27, 7, Color(1.5, 0.2, 0.2, 1.0))

	# 6. Cluster of 6 Glowing HDR Red Eyes
	var eyes = [
		Vector2(22, 15), Vector2(26, 15),
		Vector2(21, 16), Vector2(27, 16),
		Vector2(23, 14), Vector2(25, 14)
	]
	for ep in eyes:
		draw_p.call(int(ep.x), int(ep.y), Color(2.5, 0.3, 0.2, 1.0))
	draw_p.call(22, 15, Color(3.0, 2.0, 0.5, 1.0))
	draw_p.call(26, 15, Color(3.0, 2.0, 0.5, 1.0))

	return ImageTexture.create_from_image(img)


static func create_scout_texture() -> ImageTexture:
	var w = 40
	var h = 40
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Ground Shadow
	for y in range(28, 38):
		for x in range(10, 30):
			var dx = (x - 20.0) / 9.0
			var dy = (y - 33.0) / 4.0
			var dist = dx * dx + dy * dy
			if dist <= 1.0:
				var alpha = 0.32 * (1.0 - dist * 0.4)
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))

	# 2. Translucent Insect Wings
	for y in range(8, 22):
		for x in range(2, 38):
			if x <= 18:
				var wx = (x - 10.0) / 8.0
				var wy = (y - 15.0) / 6.0
				if wx * wx + wy * wy <= 1.0:
					var wing_alpha = 0.45
					if y == 14 or y == 16: wing_alpha = 0.65
					if x == 3 or y == 9: wing_alpha = 0.85
					var col = Color(0.6, 0.3, 1.2, wing_alpha)
					img.set_pixel(x, y, col)
			elif x >= 22:
				var wx = (x - 30.0) / 8.0
				var wy = (y - 15.0) / 6.0
				if wx * wx + wy * wy <= 1.0:
					var wing_alpha = 0.45
					if y == 14 or y == 16: wing_alpha = 0.65
					if x == 37 or y == 9: wing_alpha = 0.85
					var col = Color(0.6, 0.3, 1.2, wing_alpha)
					img.set_pixel(x, y, col)

	# 3. Slender Violet Body & Sharp Stinger
	for y in range(12, 31):
		for x in range(16, 25):
			var dx = (x - 20.0) / 3.5
			var dy = (y - 21.0) / 9.0
			var dist = dx * dx + dy * dy
			if dist <= 1.0:
				var lum = 0.25 + (1.0 - dist) * 0.4
				var body_col = Color(lum * 0.8, lum * 0.2, lum * 1.3, 1.0)
				if abs(x - 20) <= 0:
					body_col = Color(1.2, 0.5, 2.0, 1.0)
				img.set_pixel(x, y, body_col)

	# Stinger tip (Electric Plasma)
	img.set_pixel(20, 31, Color(2.5, 0.8, 3.0, 1.0))
	img.set_pixel(20, 32, Color(3.0, 1.5, 3.5, 1.0))

	# 4. Scout Visor Head & Sensor Antennae
	for y in range(7, 13):
		for x in range(17, 24):
			var dx = (x - 20.0) / 3.0
			var dy = (y - 10.0) / 2.5
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.15, 0.08, 0.22, 1.0))

	# Glowing sensor visor eyes
	img.set_pixel(19, 9, Color(2.8, 0.6, 3.2, 1.0))
	img.set_pixel(20, 9, Color(3.5, 1.8, 4.0, 1.0))
	img.set_pixel(21, 9, Color(2.8, 0.6, 3.2, 1.0))

	# Antennae
	img.set_pixel(18, 6, Color(1.8, 0.5, 2.4, 1.0))
	img.set_pixel(17, 5, Color(2.2, 0.8, 2.8, 1.0))
	img.set_pixel(22, 6, Color(1.8, 0.5, 2.4, 1.0))
	img.set_pixel(23, 5, Color(2.2, 0.8, 2.8, 1.0))

	return ImageTexture.create_from_image(img)


static func create_brute_texture() -> ImageTexture:
	var w = 72
	var h = 72
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Massive Isometric Ground Shadow
	for y in range(48, 68):
		for x in range(12, 60):
			var dx = (x - 36.0) / 23.0
			var dy = (y - 58.0) / 8.5
			var dist = dx * dx + dy * dy
			if dist <= 1.0:
				var alpha = 0.55 * (1.0 - dist * 0.4)
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))

	# 2. Hulking Obsidian Rock Armor Torso
	for y in range(18, 56):
		for x in range(16, 56):
			var dx = (x - 36.0) / 18.0
			var dy = (y - 37.0) / 17.0
			var dist = dx * dx + dy * dy
			if dist <= 1.0:
				var rock_lum = 0.12 + (1.0 - dist) * 0.18
				var col = Color(rock_lum * 1.1, rock_lum * 0.95, rock_lum * 0.9, 1.0)

				if (x < 25 or x > 47) and y < 36:
					col = Color(0.22, 0.2, 0.22, 1.0)
					if x == 17 or x == 55 or y == 20:
						col = Color(0.45, 0.42, 0.4, 1.0)

				# Lava Cracks
				var is_vein = false
				if abs((x - 36) - (y - 36) * 0.8) <= 1.2 and y > 24 and y < 50:
					is_vein = true
				if abs((x - 36) + (y - 38) * 0.7) <= 1.2 and y > 28 and y < 48:
					is_vein = true
				if y == 35 and x >= 24 and x <= 48:
					is_vein = true

				if is_vein:
					col = Color(2.8, 1.3, 0.15, 1.0)
				elif abs(x - 36) <= 2 and y >= 30 and y <= 42:
					col = Color(1.8, 0.6, 0.05, 1.0)

				img.set_pixel(x, y, col)

	# 3. Forward Battering Horns
	var left_horn = [
		Vector2(26, 22), Vector2(23, 17), Vector2(20, 12), Vector2(18, 8), Vector2(17, 6)
	]
	var right_horn = [
		Vector2(46, 22), Vector2(49, 17), Vector2(52, 12), Vector2(54, 8), Vector2(55, 6)
	]
	for p in left_horn + right_horn:
		_draw_circle_on_image(img, p, 2.5, Color(0.25, 0.24, 0.26, 1.0))
	img.set_pixel(17, 6, Color(2.5, 1.4, 0.2, 1.0))
	img.set_pixel(18, 6, Color(2.0, 0.9, 0.1, 1.0))
	img.set_pixel(55, 6, Color(2.5, 1.4, 0.2, 1.0))
	img.set_pixel(54, 6, Color(2.0, 0.9, 0.1, 1.0))

	# 4. Magma Golem Eye Slits & Burning Core
	for x in range(32, 41):
		img.set_pixel(x, 25, Color(3.5, 1.8, 0.2, 1.0))
		img.set_pixel(x, 26, Color(3.0, 1.2, 0.1, 1.0))
	for cy in range(38, 43):
		for cx in range(34, 39):
			if abs(cx - 36) + abs(cy - 40) <= 3:
				img.set_pixel(cx, cy, Color(3.8, 2.0, 0.3, 1.0))

	return ImageTexture.create_from_image(img)


static func create_player_frames() -> Array[ImageTexture]:
	var frames: Array[ImageTexture] = []
	var w = 48
	var h = 48

	for frame_idx in range(4):
		var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))

		var bob_y = -1 if (frame_idx == 1 or frame_idx == 3) else 0
		var leg_phase = 0
		if frame_idx == 0: leg_phase = 1
		elif frame_idx == 2: leg_phase = -1

		# 1. Ground Shadow
		for y in range(37, 46):
			for x in range(12, 36):
				var dx = (x - 24.0) / 11.0
				var dy = (y - 41.0) / 4.0
				var dist = dx * dx + dy * dy
				if dist <= 1.0:
					var alpha = 0.5 * (1.0 - dist * 0.35)
					img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))

		# 2. Boots & Legs
		var left_leg_x = 20 - (leg_phase * 3)
		var left_leg_y = 35 + (leg_phase * 1) + bob_y
		var right_leg_x = 28 + (leg_phase * 3)
		var right_leg_y = 36 - (leg_phase * 1) + bob_y

		for by in range(left_leg_y, left_leg_y + 4):
			for bx in range(left_leg_x - 2, left_leg_x + 3):
				if bx >= 0 and bx < w and by >= 0 and by < h:
					var boot_col = Color(0.12, 0.15, 0.22, 1.0)
					if by == left_leg_y: boot_col = Color(0.2, 0.35, 0.55, 1.0)
					img.set_pixel(bx, by, boot_col)

		for by in range(right_leg_y, right_leg_y + 4):
			for bx in range(right_leg_x - 2, right_leg_x + 3):
				if bx >= 0 and bx < w and by >= 0 and by < h:
					var boot_col = Color(0.12, 0.15, 0.22, 1.0)
					if by == right_leg_y: boot_col = Color(0.2, 0.35, 0.55, 1.0)
					img.set_pixel(bx, by, boot_col)

		# Heel Thrusters
		if frame_idx == 0 or frame_idx == 2:
			var active_heel_x = left_leg_x - 2 if leg_phase > 0 else right_leg_x - 2
			var active_heel_y = left_leg_y + 2 if leg_phase > 0 else right_leg_y + 2
			if active_heel_x >= 0 and active_heel_x < w and active_heel_y >= 0 and active_heel_y < h:
				img.set_pixel(active_heel_x, active_heel_y, Color(0.4, 2.0, 3.0, 1.0))
				img.set_pixel(active_heel_x - 1, active_heel_y, Color(0.1, 1.2, 2.5, 0.8))

		# 3. Mech Armored Torso
		var torso_y = 18 + bob_y
		for y in range(torso_y, torso_y + 16):
			for x in range(16, 32):
				var dx = (x - 24.0) / 7.5
				var dy = (y - (torso_y + 8)) / 7.5
				var dist = dx * dx + dy * dy
				if dist <= 1.0:
					var lum = 0.18 + (1.0 - dist) * 0.35
					var col = Color(lum * 0.5, lum * 0.9, lum * 1.6, 1.0)
					if abs(dx) > 0.8 or dy < -0.7:
						col = Color(0.45, 0.75, 1.0, 1.0)
					elif abs(x - 24) <= 1 and y <= torso_y + 6:
						col = Color(0.65, 0.88, 1.0, 1.0)
					img.set_pixel(x, y, col)

		# 4. Shoulder Pauldrons
		for py in range(torso_y + 1, torso_y + 7):
			for px in range(13, 18):
				img.set_pixel(px, py, Color(0.15, 0.3, 0.55, 1.0))
			for px in range(30, 35):
				img.set_pixel(px, py, Color(0.15, 0.3, 0.55, 1.0))
		img.set_pixel(13, torso_y + 1, Color(0.6, 0.85, 1.0, 1.0))
		img.set_pixel(34, torso_y + 1, Color(0.6, 0.85, 1.0, 1.0))

		# 5. Glowing Cyber Reactor Core
		for cy in range(torso_y + 7, torso_y + 11):
			for cx in range(22, 27):
				var r_dist = abs(cx - 24) + abs(cy - (torso_y + 9))
				if r_dist <= 2:
					img.set_pixel(cx, cy, Color(0.3, 2.5, 3.2, 1.0))
		img.set_pixel(24, torso_y + 9, Color(2.0, 3.5, 4.0, 1.0))

		# 6. Shoulder-Mounted Heavy Railgun Cannon
		var gun_y = torso_y + 1
		for gx in range(30, 44):
			for gy in range(gun_y - 2, gun_y + 3):
				var gun_col = Color(0.14, 0.16, 0.2, 1.0)
				if gy == gun_y - 2: gun_col = Color(0.35, 0.38, 0.45, 1.0)
				if (gx == 33 or gx == 37 or gx == 41) and abs(gy - gun_y) <= 1:
					gun_col = Color(0.3, 2.2, 3.0, 1.0)
				img.set_pixel(gx, gy, gun_col)
		img.set_pixel(44, gun_y, Color(0.5, 2.5, 3.5, 1.0))

		# 7. Cyber-Commander Armored Helm & Visor
		var helm_y = torso_y - 8
		for hy in range(helm_y, helm_y + 8):
			for hx in range(19, 29):
				var dx = (hx - 24.0) / 4.5
				var dy = (hy - (helm_y + 4)) / 4.0
				if dx * dx + dy * dy <= 1.0:
					var h_col = Color(0.82, 0.88, 0.95, 1.0)
					if dy > 0.4: h_col = Color(0.2, 0.25, 0.35, 1.0)
					img.set_pixel(hx, hy, h_col)

		for vx in range(23, 28):
			img.set_pixel(vx, helm_y + 4, Color(0.2, 3.0, 3.8, 1.0))
			img.set_pixel(vx, helm_y + 5, Color(0.1, 2.2, 3.0, 1.0))

		frames.append(ImageTexture.create_from_image(img))

	return frames


static func create_pylon_texture() -> ImageTexture:
	var w = 48
	var h = 96
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Long Ground Shadow
	for sy in range(70, 94):
		for sx in range(16, 46):
			var t = float(sy - 70) / 24.0
			var center_x = 24.0 + t * 14.0
			var half_w = 12.0 * (1.0 - t * 0.4)
			if sx >= (center_x - half_w) and sx <= (center_x + half_w):
				var dist = abs(sx - center_x) / half_w
				var alpha = 0.48 * (1.0 - dist * 0.4) * (1.0 - t * 0.3)
				img.set_pixel(sx, sy, Color(0.0, 0.0, 0.0, alpha))

	# 2. Obelisk Base & Shaft
	for y in range(72, 85):
		for x in range(12, 36):
			var col = Color(0.15, 0.17, 0.22, 1.0)
			if x == 12 or y == 72: col = Color(0.35, 0.4, 0.5, 1.0)
			img.set_pixel(x, y, col)

	for y in range(16, 72):
		var t = float(y - 16) / 56.0
		var half_w = 6.0 + t * 5.5
		var min_x = int(24.0 - half_w)
		var max_x = int(24.0 + half_w)
		for x in range(min_x, max_x + 1):
			var norm_x = float(x - 24) / half_w
			var col = Color(0.18, 0.2, 0.25, 1.0)
			if norm_x < -0.7:
				col = Color(0.35, 0.42, 0.52, 1.0)
			elif norm_x > 0.6:
				col = Color(0.1, 0.12, 0.15, 1.0)

			if abs(norm_x) < 0.2 and (y % 6 == 0 or y % 6 == 1):
				col = Color(0.2, 2.2, 2.8, 1.0)

			img.set_pixel(x, y, col)

	# 3. Levitating Power Crystal
	for y in range(28, 44):
		for x in range(20, 29):
			img.set_pixel(x, y, Color(0.06, 0.07, 0.09, 1.0))

	for y in range(30, 42):
		var dy = abs(y - 36) / 6.0
		var c_half = int((1.0 - dy) * 3.5)
		for x in range(24 - c_half, 24 + c_half + 1):
			var crystal_col = Color(0.3, 2.5, 3.2, 1.0)
			if x < 24: crystal_col = Color(1.5, 3.2, 4.0, 1.0)
			img.set_pixel(x, y, crystal_col)

	# 4. Pyramidal Peak
	for y in range(8, 16):
		var t = float(y - 8) / 8.0
		var half_w = t * 6.0
		for x in range(int(24.0 - half_w), int(24.0 + half_w) + 1):
			var p_col = Color(0.3, 0.35, 0.45, 1.0)
			if x < 24: p_col = Color(0.5, 0.6, 0.75, 1.0)
			img.set_pixel(x, y, p_col)
	img.set_pixel(24, 7, Color(0.4, 3.0, 3.8, 1.0))

	return ImageTexture.create_from_image(img)


static func create_gem_texture() -> ImageTexture:
	var w = 24
	var h = 24
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Ground Shadow
	for y in range(18, 23):
		for x in range(7, 18):
			var dx = (x - 12.0) / 5.0
			var dy = (y - 20.0) / 2.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.4))

	# 2. 3D Faceted Hexagonal Crystal
	for y in range(3, 18):
		var dy = abs(y - 10) / 7.0
		var half_w = int((1.0 - dy) * 6.0)
		for x in range(12 - half_w, 12 + half_w + 1):
			var facet_col = Color(0.1, 0.8, 0.95, 0.95)
			if x < 12 and y <= 10:
				facet_col = Color(0.6, 1.8, 2.2, 1.0)
			elif x >= 12 and y > 10:
				facet_col = Color(0.05, 0.5, 0.7, 0.95)
			if abs(x - 12) <= 1 and abs(y - 10) <= 2:
				facet_col = Color(2.0, 3.0, 3.5, 1.0)

	return ImageTexture.create_from_image(img)


static func create_crate_texture() -> ImageTexture:
	var w = 32
	var h = 32
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Ground Shadow
	for y in range(24, 30):
		for x in range(4, 28):
			var dx = (x - 16.0) / 11.0
			var dy = (y - 27.0) / 2.5
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.45))

	# 2. Metal Box Body
	for y in range(8, 26):
		for x in range(6, 26):
			var col = Color(0.18, 0.22, 0.28, 1.0)
			# Metallic beveled edges
			if x == 6 or y == 8: col = Color(0.45, 0.52, 0.62, 1.0)
			elif x == 25 or y == 25: col = Color(0.1, 0.12, 0.16, 1.0)
			# Corner rivets
			if (x == 8 or x == 23) and (y == 10 or y == 23):
				col = Color(0.7, 0.75, 0.85, 1.0)
			# Yellow/Black hazard stripe across middle
			if y >= 15 and y <= 19:
				var stripe = ((x + y) % 6 < 3)
				col = Color(1.8, 1.4, 0.1, 1.0) if stripe else Color(0.12, 0.12, 0.14, 1.0)
			# Central cyan electronic lock
			if abs(x - 16) <= 1 and abs(y - 17) <= 1:
				col = Color(0.3, 2.5, 3.5, 1.0)
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


static func create_pickup_texture(pickup_type: int) -> ImageTexture:
	var w = 24
	var h = 24
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Ground shadow
	for y in range(18, 23):
		for x in range(6, 18):
			var dx = (x - 12.0) / 5.0
			var dy = (y - 20.0) / 2.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.35))

	match pickup_type:
		0: # 0: EMP Nuke (Hazard warhead with lightning)
			for y in range(4, 18):
				for x in range(5, 19):
					var dist = Vector2(x - 12, y - 11).length()
					if dist <= 6.5:
						var col = Color(0.15, 0.7, 1.5, 0.95)
						# Trefoil / lightning symbol in center
						if abs(x - 12) <= 1 or abs(y - 11) <= 1 or dist < 2.5:
							col = Color(3.5, 3.5, 4.0, 1.0)
						img.set_pixel(x, y, col)
		1: # 1: Quantum Vacuum (Swirling purple singularity)
			for y in range(4, 18):
				for x in range(5, 19):
					var dist = Vector2(x - 12, y - 11).length()
					if dist <= 6.5:
						var col = Color(1.4, 0.3, 1.8, 0.9)
						if dist <= 3.0: col = Color(3.0, 1.2, 3.5, 1.0)
						if dist <= 1.2: col = Color(0.1, 0.05, 0.15, 1.0) # Black hole center
						img.set_pixel(x, y, col)
		2: # 2: Medkit (White capsule with green cross)
			for y in range(5, 17):
				for x in range(6, 18):
					var col = Color(0.9, 0.92, 0.95, 1.0)
					if x == 6 or y == 5: col = Color(1.0, 1.0, 1.0, 1.0)
					# Green cross
					if (abs(x - 12) <= 1 and y >= 7 and y <= 15) or (abs(y - 11) <= 1 and x >= 8 and x <= 16):
						col = Color(0.2, 2.5, 0.8, 1.0)
					img.set_pixel(x, y, col)
		3: # 3: Overclock (Turbo lightning gear)
			for y in range(4, 18):
				for x in range(5, 19):
					var dist = Vector2(x - 12, y - 11).length()
					if dist <= 6.5:
						var col = Color(2.8, 1.6, 0.1, 0.95)
						if abs((x - 12) - (y - 11) * 0.7) <= 1.2:
							col = Color(3.5, 3.5, 1.0, 1.0)
						img.set_pixel(x, y, col)
		_: # 4: Nano Gold Coin
			for y in range(5, 17):
				for x in range(6, 18):
					var dist = Vector2(x - 12, y - 11).length()
					if dist <= 5.5:
						var col = Color(2.5, 1.8, 0.2, 1.0)
						if dist <= 3.0: col = Color(3.2, 2.4, 0.6, 1.0)
						if x == 10 and y == 9: col = Color(3.5, 3.5, 3.0, 1.0)
						img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


static func create_chest_texture() -> ImageTexture:
	var w = 40
	var h = 40
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Ground Shadow
	for y in range(30, 38):
		for x in range(6, 34):
			var dx = (x - 20.0) / 13.0
			var dy = (y - 34.0) / 3.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.5))

	# 2. Golden Cyber Chest
	for y in range(12, 32):
		for x in range(8, 32):
			var col = Color(1.8, 1.3, 0.15, 1.0) # Rich Gold
			if x == 8 or y == 12: col = Color(2.5, 2.0, 0.6, 1.0) # Bevel
			elif x == 31 or y == 31: col = Color(0.8, 0.55, 0.05, 1.0) # Shade

			# Chest lid seam
			if y == 20: col = Color(0.2, 0.15, 0.05, 1.0)
			# Cyan power inlays
			if (x == 11 or x == 28) or (y == 15 and x >= 11 and x <= 28):
				col = Color(0.3, 2.5, 3.5, 1.0)
			# Central glowing lock
			if abs(x - 20) <= 2 and abs(y - 21) <= 2:
				col = Color(3.5, 3.5, 4.0, 1.0)
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


static func create_boss_texture() -> ImageTexture:
	var w = 96
	var h = 96
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Massive Ground Shadow
	for y in range(68, 92):
		for x in range(14, 82):
			var dx = (x - 48.0) / 31.0
			var dy = (y - 80.0) / 10.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.6))

	# 2. Heavy Biomechanical Carapace
	for y in range(18, 76):
		for x in range(18, 78):
			var dx = (x - 48.0) / 26.0
			var dy = (y - 48.0) / 25.0
			var dist = dx * dx + dy * dy
			if dist <= 1.0:
				var lum = 0.14 + (1.0 - dist) * 0.22
				var col = Color(lum * 0.9, lum * 0.7, lum * 1.1, 1.0) # Dark Void Carapace

				# Spiked side ridges
				if (x < 28 or x > 68) and y < 55:
					col = Color(0.35, 0.15, 0.25, 1.0)
					if x == 20 or x == 76: col = Color(0.8, 0.2, 0.3, 1.0)

				# Magma/Plasma Spinal Channels
				if abs(x - 48) <= 2 and y >= 25 and y <= 65:
					col = Color(3.5, 0.8, 0.1, 1.0)
				elif abs(x - 48) <= 6 and (y % 8 == 0):
					col = Color(2.5, 0.4, 0.1, 1.0)

				img.set_pixel(x, y, col)

	# 3. 4 Blazing Crimson HDR Eye Slits
	var eyes = [
		Vector2(42, 34), Vector2(54, 34),
		Vector2(38, 38), Vector2(58, 38)
	]
	for ep in eyes:
		_draw_circle_on_image(img, ep, 2.5, Color(3.8, 0.2, 0.2, 1.0))
		img.set_pixel(int(ep.x), int(ep.y), Color(3.8, 2.5, 0.5, 1.0))

	# 4. Massive Serrated Tusks / Horns
	var left_tusk = [Vector2(32, 28), Vector2(26, 22), Vector2(22, 14), Vector2(20, 8)]
	var right_tusk = [Vector2(64, 28), Vector2(70, 22), Vector2(74, 14), Vector2(76, 8)]
	for pt in left_tusk + right_tusk:
		_draw_circle_on_image(img, pt, 3.5, Color(0.2, 0.22, 0.28, 1.0))
	img.set_pixel(20, 8, Color(3.5, 0.4, 0.2, 1.0))
	img.set_pixel(76, 8, Color(3.5, 0.4, 0.2, 1.0))

	return ImageTexture.create_from_image(img)


static func create_mortar_canister_texture() -> ImageTexture:
	var w = 16
	var h = 16
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for y in range(2, 14):
		for x in range(4, 12):
			var col = Color(0.2, 2.5, 0.6, 1.0) # Toxic Neon Green
			if abs(x - 8) <= 1 and abs(y - 8) <= 1:
				col = Color(3.5, 3.5, 1.5, 1.0) # Glowing core
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


static func create_acid_pool_texture() -> ImageTexture:
	var w = 48
	var h = 48
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for y in range(8, 40):
		for x in range(6, 42):
			var dx = (x - 24.0) / 16.0
			var dy = (y - 24.0) / 11.0 # Isometric oval
			var dist = dx * dx + dy * dy
			if dist <= 1.0:
				var alpha = 0.65 * (1.0 - dist * 0.3)
				var col = Color(0.1, 1.8, 0.4, alpha)
				# Corrosive bubbling highlights
				if (x * y) % 11 == 0 and dist < 0.7:
					col = Color(1.5, 3.2, 0.8, alpha * 1.3)
				img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)



# --- Utility Drawing Primitives for Image ---
static func _draw_line_on_image(img: Image, p1: Vector2, p2: Vector2, col: Color, thickness: int = 1) -> void:
	var dist = p1.distance_to(p2)
	var steps = max(int(dist * 2.0), 1)
	for s in range(steps + 1):
		var p = p1.lerp(p2, float(s) / float(steps))
		for ty in range(-thickness / 2, (thickness + 1) / 2):
			for tx in range(-thickness / 2, (thickness + 1) / 2):
				var px = int(p.x) + tx
				var py = int(p.y) + ty
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, col)

static func _draw_circle_on_image(img: Image, center: Vector2, radius: float, col: Color) -> void:
	var r_sq = radius * radius
	var r_int = int(ceil(radius))
	for y in range(int(center.y) - r_int, int(center.y) + r_int + 1):
		for x in range(int(center.x) - r_int, int(center.x) + r_int + 1):
			var dx = x - center.x
			var dy = y - center.y
			if dx * dx + dy * dy <= r_sq:
				if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
					img.set_pixel(x, y, col)
