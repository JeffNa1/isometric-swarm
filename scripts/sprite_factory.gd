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
			var facet_col = Color(0.15, 0.95, 0.45, 1.0)
			if x < 12 and y <= 10:
				facet_col = Color(0.8, 2.4, 1.3, 1.0)
			elif x >= 12 and y > 10:
				facet_col = Color(0.06, 0.55, 0.22, 1.0)
			if abs(x - 12) <= 1 and abs(y - 10) <= 2:
				facet_col = Color(2.2, 3.6, 2.4, 1.0)

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


static func create_pickup_texture(pickup_type = 0) -> ImageTexture:
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

	var type_int: int = 0
	if typeof(pickup_type) == TYPE_STRING:
		match pickup_type:
			"nuke": type_int = 0
			"vacuum": type_int = 1
			"medkit": type_int = 2
			"overclock": type_int = 3
			_: type_int = 4
	else:
		type_int = int(pickup_type)

	match type_int:
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


static func create_menu_icon(icon_name: String) -> ImageTexture:
	var w = 28
	var h = 28
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match icon_name:
		"play":
			# Glowing neon cyan play triangle with plasma white core
			for y in range(5, 24):
				var progress = float(y - 5) / 18.0
				var max_x = int(lerp(7.0, 23.0, 1.0 - abs(progress - 0.5) * 2.0))
				for x in range(7, max_x + 1):
					var col = Color(0.1, 0.8, 1.8, 0.9)
					if x == 7 or x == max_x or y == 5 or y == 23:
						col = Color(0.3, 2.8, 3.8, 1.0)
					if x >= 9 and x <= max_x - 2 and abs(y - 14) <= 4:
						col = Color(3.5, 3.5, 4.0, 1.0) # White hot core
					img.set_pixel(x, y, col)

		"settings":
			# Precision cyber cogwheel gear with 6 teeth and central glowing blue micro-reactor
			var center = Vector2(14, 14)
			# Gear body
			for y in range(3, 26):
				for x in range(3, 26):
					var diff = Vector2(x, y) - center
					var dist = diff.length()
					var angle = diff.angle()
					var tooth = cos(angle * 6.0)
					var radius_limit = 8.5 + tooth * 2.5
					if dist <= radius_limit and dist >= 3.5:
						var col = Color(2.5, 1.8, 0.4, 1.0) # Amber metallic
						if dist > radius_limit - 1.2: col = Color(3.2, 2.4, 0.8, 1.0)
						img.set_pixel(x, y, col)
					elif dist < 3.5:
						# Cyan central core
						var col = Color(0.2, 2.5, 3.8, 1.0) if dist > 1.2 else Color(3.8, 3.8, 4.0, 1.0)
						img.set_pixel(x, y, col)

		"how_to_play":
			# Holographic combat HUD helmet with cyan/green scanning visor
			for y in range(4, 24):
				for x in range(5, 24):
					var dx = (x - 14.0) / 8.5
					var dy = (y - 14.0) / 9.0
					var d = dx * dx + dy * dy
					if d <= 1.0:
						var col = Color(0.12, 0.18, 0.28, 0.95)
						if d > 0.75: col = Color(0.2, 1.4, 2.2, 1.0)
						# Neon scanning visor slit
						if y >= 12 and y <= 15 and abs(x - 14) <= 6:
							col = Color(0.2, 3.5, 1.8, 1.0)
							if x == 14: col = Color(3.8, 3.8, 2.0, 1.0) # Scan dot
						img.set_pixel(x, y, col)

		"credits":
			# Golden laurel victory medallion with sparkling star core
			var center = Vector2(14, 12)
			for y in range(3, 21):
				for x in range(5, 24):
					var dist = (Vector2(x, y) - center).length()
					if dist <= 7.5:
						var col = Color(2.8, 2.0, 0.3, 0.95)
						if dist > 6.0: col = Color(3.5, 2.8, 0.8, 1.0)
						# 4-pointed star in center
						if abs(x - 14) <= 1 or abs(y - 12) <= 1:
							col = Color(3.8, 3.8, 3.5, 1.0)
						img.set_pixel(x, y, col)
			# Ribbon hanging
			for y in range(19, 26):
				var r_w = (y - 19)
				img.set_pixel(11 - r_w, y, Color(0.2, 1.5, 2.8, 1.0))
				img.set_pixel(17 + r_w, y, Color(0.2, 1.5, 2.8, 1.0))

		"quit":
			# Crimson nuclear power shutdown glyph
			var center = Vector2(14, 14)
			for y in range(4, 25):
				for x in range(4, 25):
					var diff = Vector2(x, y) - center
					var dist = diff.length()
					if dist >= 6.0 and dist <= 9.0:
						# Gap at top for vertical line
						if not (abs(x - 14) <= 2 and y < 14):
							var col = Color(3.5, 0.3, 0.4, 1.0)
							img.set_pixel(x, y, col)
			# Vertical stroke
			for y in range(4, 15):
				for x in range(13, 16):
					img.set_pixel(x, y, Color(3.8, 2.0, 2.2, 1.0))

		"sound_on":
			# Cyber speaker with emitting concentric cyan waves
			# Speaker body
			for y in range(8, 21):
				for x in range(5, 13):
					var in_cone = (x >= 8 and abs(y - 14) <= (x - 7) * 2) or (x < 8 and abs(y - 14) <= 3)
					if in_cone:
						var col = Color(0.25, 1.2, 2.0, 1.0)
						if x == 5 or abs(y - 14) == 3: col = Color(0.4, 2.0, 3.2, 1.0)
						img.set_pixel(x, y, col)
			# Sound waves
			for y in range(6, 23):
				for x in range(15, 25):
					var d1 = abs(Vector2(x - 12, y - 14).length() - 5.5)
					var d2 = abs(Vector2(x - 12, y - 14).length() - 9.0)
					if (d1 < 0.9 or d2 < 0.9) and x > 12:
						img.set_pixel(x, y, Color(0.3, 2.8, 3.8, 1.0))

		"sound_off":
			# Speaker body with bright red laser strike
			for y in range(8, 21):
				for x in range(5, 13):
					var in_cone = (x >= 8 and abs(y - 14) <= (x - 7) * 2) or (x < 8 and abs(y - 14) <= 3)
					if in_cone:
						img.set_pixel(x, y, Color(0.18, 0.22, 0.28, 0.8))
			# Red diagonal slash
			for i in range(5, 23):
				img.set_pixel(i, i, Color(3.8, 0.4, 0.5, 1.0))
				img.set_pixel(i + 1, i, Color(3.0, 0.2, 0.3, 0.8))

		"wasd":
			# 4 glowing cyber keycaps: W (top), A (left), S (center), D (right)
			var keys = [Vector2(14, 8), Vector2(7, 18), Vector2(14, 18), Vector2(21, 18)]
			for kp in keys:
				for y in range(int(kp.y) - 3, int(kp.y) + 4):
					for x in range(int(kp.x) - 3, int(kp.x) + 4):
						if abs(x - kp.x) <= 3 and abs(y - kp.y) <= 3:
							var col = Color(0.12, 0.16, 0.25, 1.0)
							if abs(x - kp.x) == 3 or abs(y - kp.y) == 3:
								col = Color(0.3, 2.2, 3.5, 1.0)
							if x == int(kp.x) and y == int(kp.y):
								col = Color(3.5, 3.5, 4.0, 1.0) # Key label dot
							img.set_pixel(x, y, col)

		"auto_aim":
			# Tactical military reticle crosshair with 4 brackets & laser dot
			var center = Vector2(14, 14)
			for y in range(4, 25):
				for x in range(4, 25):
					var dist = (Vector2(x, y) - center).length()
					if abs(dist - 8.0) <= 0.8:
						# 4 gaps in circle
						if abs(x - 14) > 2 and abs(y - 14) > 2:
							img.set_pixel(x, y, Color(0.3, 2.5, 3.8, 0.9))
			# Center red laser dot
			_draw_circle_on_image(img, center, 2.0, Color(3.8, 0.3, 0.3, 1.0))
			img.set_pixel(14, 14, Color(3.8, 3.0, 2.0, 1.0))

		"chest":
			# Golden relic treasure chest icon
			for y in range(8, 22):
				for x in range(6, 23):
					var col = Color(2.5, 1.8, 0.3, 0.95)
					if x == 6 or x == 22 or y == 8 or y == 21:
						col = Color(3.5, 2.8, 0.8, 1.0)
					if y == 14: col = Color(0.2, 0.15, 0.05, 1.0) # Lid seam
					if abs(x - 14) <= 1 and abs(y - 15) <= 1:
						col = Color(3.8, 3.8, 4.0, 1.0) # Lock
					img.set_pixel(x, y, col)

		"evolution":
			# Crown of super evolution with dual lightning bolts
			for y in range(6, 17):
				for x in range(5, 24):
					var in_crown = (y >= 14 and abs(x - 14) <= 8) or (y < 14 and (abs(x - 14) <= 2 or abs(x - 7) <= 2 or abs(x - 21) <= 2))
					if in_crown:
						var col = Color(3.5, 0.8, 1.8, 1.0) # Neon magenta
						if y == 6: col = Color(3.8, 3.5, 1.0, 1.0) # Jewels on tips
						img.set_pixel(x, y, col)
			# Symmetrical lightning below
			for y in range(18, 25):
				img.set_pixel(11, y, Color(0.4, 2.8, 3.8, 1.0))
				img.set_pixel(17, y, Color(0.4, 2.8, 3.8, 1.0))

		"back":
			# Left-pointing cyber chevron with trailing glow
			for y in range(6, 23):
				var target_x = int(lerp(8.0, 20.0, abs(float(y - 14) / 8.0)))
				for thick in range(3):
					var px = target_x + thick
					if px >= 0 and px < w:
						var col = Color(0.3, 2.5, 3.8, 1.0) if thick == 0 else Color(0.1, 1.2, 2.2, 0.6)
						img.set_pixel(px, y, col)
			img.set_pixel(23, 14, Color(0.3, 2.5, 3.8, 0.8))
			img.set_pixel(25, 14, Color(0.2, 1.8, 3.0, 0.4))

		_:
			# Default glowing dot
			_draw_circle_on_image(img, Vector2(14, 14), 6.0, Color(0.3, 2.5, 3.8, 1.0))

	return ImageTexture.create_from_image(img)


static var _item_icon_cache: Dictionary = {}

static func create_item_icon(item_id: String) -> ImageTexture:
	if _item_icon_cache.has(item_id):
		return _item_icon_cache[item_id]

	var w = 32
	var h = 32
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Subtle dark cyber-frame background for all icons
	for y in range(2, 30):
		for x in range(2, 30):
			var is_edge = (x == 2 or x == 29 or y == 2 or y == 29)
			var is_corner = (x <= 3 or x >= 28) and (y <= 3 or y >= 28)
			if not is_corner:
				if is_edge:
					img.set_pixel(x, y, Color(0.18, 0.28, 0.42, 0.8))
				else:
					img.set_pixel(x, y, Color(0.04, 0.07, 0.13, 0.75))

	var is_evo = item_id.ends_with("_evo")

	match item_id:
		"railgun":
			# Twin heavy rail barrels firing high-energy cyan laser beam
			for y in range(13, 19):
				for x in range(5, 27):
					img.set_pixel(x, y, Color(0.2, 0.35, 0.5, 1.0))
			# Center high-voltage beam
			for x in range(3, 29):
				img.set_pixel(x, 15, Color(1.5, 3.5, 4.0, 1.0))
				img.set_pixel(x, 16, Color(0.4, 2.5, 3.8, 1.0))
			# Rail emitters
			for y in range(11, 21):
				img.set_pixel(10, y, Color(0.4, 2.5, 3.8, 1.0))
				img.set_pixel(21, y, Color(0.4, 2.5, 3.8, 1.0))

		"railgun_evo":
			# Hyperion Tachyon: Dual rainbow tachyon beams with solar crown
			for x in range(3, 29):
				img.set_pixel(x, 13, Color(3.8, 0.5, 1.5, 1.0))
				img.set_pixel(x, 14, Color(3.8, 3.5, 4.0, 1.0))
				img.set_pixel(x, 17, Color(3.8, 3.5, 4.0, 1.0))
				img.set_pixel(x, 18, Color(0.3, 2.8, 3.8, 1.0))
			# Golden power crown
			for y in range(7, 12):
				for x in range(8, 24):
					if y == 7 and (x == 8 or x == 16 or x == 23):
						img.set_pixel(x, y, Color(3.8, 2.8, 0.5, 1.0))
					elif y >= 9:
						img.set_pixel(x, y, Color(2.8, 1.8, 0.3, 1.0))

		"flame":
			# Plasma flame thrower nozzle spitting conical infernal fire
			for y in range(12, 20):
				for x in range(5, 12):
					img.set_pixel(x, y, Color(0.25, 0.3, 0.38, 1.0))
			# Nozzle band
			for y in range(10, 22):
				img.set_pixel(11, y, Color(3.5, 1.5, 0.2, 1.0))
			# Flame tongues
			for x in range(12, 28):
				var spread = int((x - 12) * 0.65)
				for y in range(16 - spread, 16 + spread + 1):
					if y >= 4 and y < 28:
						var dist_center = abs(y - 16)
						if dist_center <= 1:
							img.set_pixel(x, y, Color(3.8, 3.5, 1.0, 1.0))
						elif dist_center <= spread * 0.5:
							img.set_pixel(x, y, Color(3.8, 1.8, 0.2, 0.95))
						else:
							img.set_pixel(x, y, Color(3.5, 0.4, 0.1, 0.85))

		"flame_evo":
			# Infernal Sunstorm: 360 degree sunburst spiral
			var center = Vector2(16, 16)
			for y in range(5, 27):
				for x in range(5, 27):
					var dist = (Vector2(x, y) - center).length()
					if dist <= 10.0:
						var ang = atan2(y - 16, x - 16)
						var spiral = sin(ang * 4.0 + dist * 0.8)
						if spiral > 0.0 or dist <= 4.0:
							var col = Color(3.8, 3.5, 1.0, 1.0) if dist <= 4.0 else Color(3.8, 0.8, 0.1, 0.95)
							img.set_pixel(x, y, col)
					elif dist <= 12.0 and int(dist * 2.0) % 2 == 0:
						img.set_pixel(x, y, Color(3.8, 0.2, 0.2, 0.8))

		"shockwave":
			# Nova shockwave: Central sphere pulsing with concentric energetic rings
			var center = Vector2(16, 16)
			for y in range(5, 27):
				for x in range(5, 27):
					var dist = (Vector2(x, y) - center).length()
					if dist <= 4.0:
						img.set_pixel(x, y, Color(3.5, 3.8, 4.0, 1.0))
					elif abs(dist - 7.5) <= 1.0:
						img.set_pixel(x, y, Color(0.4, 2.5, 3.8, 0.95))
					elif abs(dist - 11.0) <= 0.9:
						img.set_pixel(x, y, Color(0.2, 1.5, 3.0, 0.75))

		"shockwave_evo":
			# Supernova Zero: Black hole singularity with accretion disk
			var center = Vector2(16, 16)
			for y in range(4, 28):
				for x in range(4, 28):
					var dist = (Vector2(x, y) - center).length()
					if dist <= 3.5:
						img.set_pixel(x, y, Color(0.02, 0.02, 0.04, 1.0)) # Event horizon
					elif abs(dist - 6.0) <= 1.5:
						img.set_pixel(x, y, Color(3.8, 0.6, 1.8, 1.0)) # Violent magenta burst
					elif abs(dist - 10.5) <= 1.2:
						img.set_pixel(x, y, Color(3.8, 2.5, 0.4, 0.9)) # Golden accretion flare

		"missile":
			# Dual micro-missiles with red guidance cones and exhaust fire
			var m_offsets = [-4, 4]
			for dy in m_offsets:
				var cy = 16 + dy
				# Body
				for x in range(8, 20):
					for y in range(cy - 2, cy + 3):
						img.set_pixel(x, y, Color(0.85, 0.9, 0.95, 1.0))
				# Red Seeker nosecone
				for x in range(20, 25):
					var span = 24 - x
					for y in range(cy - span, cy + span + 1):
						img.set_pixel(x, y, Color(3.8, 0.3, 0.3, 1.0))
				# Wings/Fins
				for y in range(cy - 4, cy + 5):
					img.set_pixel(9, y, Color(0.3, 0.4, 0.55, 1.0))
				# Exhaust flame
				for x in range(4, 8):
					img.set_pixel(x, cy, Color(3.8, 2.5, 0.3, 1.0))

		"missile_evo":
			# Apocalypse Barrage: 4 clustered warheads with nuclear glow
			var coords = [Vector2(11, 11), Vector2(21, 11), Vector2(11, 21), Vector2(21, 21)]
			for c in coords:
				_draw_circle_on_image(img, c, 3.5, Color(3.8, 0.35, 0.4, 1.0))
				img.set_pixel(int(c.x), int(c.y), Color(3.8, 3.5, 3.0, 1.0))
			# Center radioactive symbol cross
			for i in range(13, 19):
				img.set_pixel(16, i, Color(3.8, 2.8, 0.3, 1.0))
				img.set_pixel(i, 16, Color(3.8, 2.8, 0.3, 1.0))

		"blade":
			# Tri-blade orbital energetic shuriken
			var center = Vector2(16, 16)
			for i in range(3):
				var ang = i * TAU / 3.0
				for step in range(3, 12):
					var p = center + Vector2(cos(ang), sin(ang)) * step
					var side = Vector2(-sin(ang), cos(ang)) * (step * 0.35)
					var p1 = p + side
					if p1.x >= 0 and p1.x < w and p1.y >= 0 and p1.y < h:
						img.set_pixel(int(p1.x), int(p1.y), Color(0.3, 2.5, 3.8, 1.0))
			_draw_circle_on_image(img, center, 3.0, Color(3.5, 3.5, 4.0, 1.0))

		"blade_evo":
			# Omni-Scythe Vortex: 4 massive glowing magenta scythes
			var center = Vector2(16, 16)
			for i in range(4):
				var ang = i * TAU / 4.0
				for step in range(4, 13):
					var p = center + Vector2(cos(ang + step * 0.15), sin(ang + step * 0.15)) * step
					if p.x >= 0 and p.x < w and p.y >= 0 and p.y < h:
						img.set_pixel(int(p.x), int(p.y), Color(3.8, 0.4, 1.5, 1.0))
						var p_inner = p + Vector2(cos(ang), sin(ang))
						if p_inner.x >= 0 and p_inner.x < w and p_inner.y >= 0 and p_inner.y < h:
							img.set_pixel(int(p_inner.x), int(p_inner.y), Color(3.8, 2.8, 3.5, 1.0))
			_draw_circle_on_image(img, center, 3.5, Color(3.8, 2.0, 3.8, 1.0))

		"tesla":
			# High-voltage Tesla coil top with branching lightning
			for y in range(16, 26):
				for x in range(13, 19):
					img.set_pixel(x, y, Color(0.3, 0.38, 0.5, 1.0))
			# High-voltage sphere
			_draw_circle_on_image(img, Vector2(16, 12), 5.0, Color(0.4, 2.8, 3.8, 1.0))
			img.set_pixel(16, 12, Color(3.8, 3.8, 4.0, 1.0))
			# Lightning arcs
			var arcs = [Vector2(7, 7), Vector2(25, 7), Vector2(5, 16), Vector2(27, 16)]
			for a in arcs:
				var path = [Vector2(16, 12), (Vector2(16, 12) + a) * 0.5 + Vector2(randf_range(-2, 2), randf_range(-2, 2)), a]
				for p in path:
					img.set_pixel(int(p.x), int(p.y), Color(3.8, 3.5, 1.0, 1.0))

		"tesla_evo":
			# Mjolnir Stormcore: Storm hammer surrounded by furious divine thunder
			# Hammer head
			for y in range(8, 16):
				for x in range(9, 23):
					img.set_pixel(x, y, Color(0.4, 0.5, 0.65, 1.0))
					if x == 9 or x == 22 or y == 8 or y == 15:
						img.set_pixel(x, y, Color(0.8, 2.8, 3.8, 1.0))
			# Handle
			for y in range(16, 26):
				for x in range(14, 18):
					img.set_pixel(x, y, Color(2.5, 1.8, 0.4, 1.0))
			# Golden lightning rune in center
			for i in range(10, 15):
				img.set_pixel(16, i, Color(3.8, 3.5, 4.0, 1.0))

		"mortar":
			# Heavy cyber mortar cannon launching green corrosive shell
			for y in range(14, 25):
				for x in range(10, 22):
					var is_barrel = (x - y <= 4 and x - y >= -4)
					if is_barrel:
						img.set_pixel(x, y, Color(0.2, 0.35, 0.25, 1.0))
			# Toxic shell emerging
			_draw_circle_on_image(img, Vector2(22, 9), 3.5, Color(0.4, 3.5, 0.8, 1.0))
			img.set_pixel(22, 9, Color(2.5, 3.8, 1.5, 1.0))

		"mortar_evo":
			# Corrosive Chernobyl: Radioactive quad-mortar with biohazard glow
			var center = Vector2(16, 16)
			_draw_circle_on_image(img, center, 8.0, Color(0.1, 0.4, 0.2, 0.95))
			# Biohazard clover
			for i in range(3):
				var ang = i * TAU / 3.0 - PI * 0.5
				var p = center + Vector2(cos(ang), sin(ang)) * 5.0
				_draw_circle_on_image(img, p, 3.0, Color(0.5, 3.8, 0.6, 1.0))
			_draw_circle_on_image(img, center, 2.5, Color(3.8, 3.5, 0.2, 1.0))

		"energy_core":
			# High-tech cylindrical energy cell with glowing cyan plasma
			for y in range(7, 25):
				for x in range(11, 21):
					img.set_pixel(x, y, Color(0.08, 0.12, 0.2, 1.0))
					if x == 11 or x == 20 or y == 7 or y == 24:
						img.set_pixel(x, y, Color(0.5, 0.6, 0.75, 1.0))
			# Top & bottom terminals
			for x in range(13, 19):
				img.set_pixel(x, 5, Color(3.5, 2.5, 0.4, 1.0))
				img.set_pixel(x, 6, Color(3.5, 2.5, 0.4, 1.0))
			# Core lightning bolt
			var bolt = [Vector2(16, 9), Vector2(14, 14), Vector2(18, 14), Vector2(15, 21)]
			for p in bolt:
				_draw_circle_on_image(img, p, 1.5, Color(0.4, 3.2, 4.0, 1.0))

		"nano_armor":
			# Heavy titanium cyber-shield with emerald nanite healing cross
			for y in range(6, 26):
				var dy = float(y - 6) / 20.0
				var half_w = int(lerp(8.0, 1.0, dy * dy))
				for x in range(16 - half_w, 16 + half_w + 1):
					var col = Color(0.12, 0.18, 0.25, 1.0)
					if x == 16 - half_w or x == 16 + half_w or y == 6:
						col = Color(0.4, 0.7, 0.9, 1.0)
					img.set_pixel(x, y, col)
			# Emerald healing cross in center
			for i in range(12, 20):
				img.set_pixel(16, i, Color(0.3, 3.5, 0.8, 1.0))
				img.set_pixel(15, i, Color(0.3, 3.5, 0.8, 1.0))
			for i in range(13, 19):
				img.set_pixel(i, 15, Color(0.3, 3.5, 0.8, 1.0))
				img.set_pixel(i, 16, Color(0.3, 3.5, 0.8, 1.0))

		"thrusters":
			# Rocket thruster boot with ion drive plume
			for y in range(8, 20):
				for x in range(10, 22):
					img.set_pixel(x, y, Color(0.2, 0.25, 0.35, 1.0))
					if x == 10 or x == 21 or y == 8:
						img.set_pixel(x, y, Color(0.5, 0.65, 0.8, 1.0))
			# Dual nozzle bells
			for x in range(11, 21):
				img.set_pixel(x, 20, Color(3.5, 2.0, 0.3, 1.0))
			# Blue ion flame blast
			for y in range(21, 28):
				var span = 27 - y
				for x in range(16 - span, 16 + span + 1):
					img.set_pixel(x, y, Color(0.4, 2.8, 3.8, 1.0))

		"magnet":
			# Horseshoe magnet with red/blue poles and magnetic gem
			for y in range(7, 22):
				for x in range(7, 25):
					var in_outer = (abs(x - 16) <= 9 and y >= 7)
					var in_inner = (abs(x - 16) <= 4 and y >= 12)
					if in_outer and not in_inner:
						var col = Color(3.8, 0.3, 0.3, 1.0) if x < 16 else Color(0.3, 1.8, 3.8, 1.0)
						if y >= 19:
							col = Color(0.8, 0.85, 0.9, 1.0) # Metal tips
						img.set_pixel(x, y, col)
			# Central floating crystal gem
			_draw_circle_on_image(img, Vector2(16, 16), 2.5, Color(3.5, 2.8, 0.5, 1.0))

		"amp":
			# Overclock amplifier CPU chip with gold circuit traces
			for y in range(9, 23):
				for x in range(9, 23):
					img.set_pixel(x, y, Color(0.08, 0.12, 0.16, 1.0))
					if x == 9 or x == 22 or y == 9 or y == 22:
						img.set_pixel(x, y, Color(3.5, 2.5, 0.4, 1.0))
			# Gold pins
			var pins = [11, 14, 17, 20]
			for p in pins:
				img.set_pixel(p, 7, Color(3.5, 2.5, 0.4, 1.0))
				img.set_pixel(p, 8, Color(3.5, 2.5, 0.4, 1.0))
				img.set_pixel(p, 23, Color(3.5, 2.5, 0.4, 1.0))
				img.set_pixel(p, 24, Color(3.5, 2.5, 0.4, 1.0))
				img.set_pixel(7, p, Color(3.5, 2.5, 0.4, 1.0))
				img.set_pixel(8, p, Color(3.5, 2.5, 0.4, 1.0))
				img.set_pixel(23, p, Color(3.5, 2.5, 0.4, 1.0))
				img.set_pixel(24, p, Color(3.5, 2.5, 0.4, 1.0))
			# Glowing amplifier core
			_draw_circle_on_image(img, Vector2(16, 16), 3.0, Color(3.8, 1.0, 0.3, 1.0))

		_:
			# Default glowing power orb
			_draw_circle_on_image(img, Vector2(16, 16), 6.0, Color(0.3, 2.5, 3.8, 1.0))

	# If evolution, overlay a subtle golden laurel corner badge
	if is_evo:
		for y in range(3, 7):
			for x in range(3, 7):
				if (x + y) % 2 == 0:
					img.set_pixel(x, y, Color(3.8, 3.0, 0.6, 1.0))
					img.set_pixel(31 - x, y, Color(3.8, 3.0, 0.6, 1.0))

	var tex = ImageTexture.create_from_image(img)
	_item_icon_cache[item_id] = tex
	return tex


static var _pixel_panel_cache: Dictionary = {}
static var _pixel_bar_cache: Dictionary = {}

static func create_pixel_panel_texture(border_col: Color, bg_col: Color, accent_col: Color = Color.TRANSPARENT, corner_bolts: bool = true) -> ImageTexture:
	var key = "%s_%s_%s_%s" % [border_col.to_html(), bg_col.to_html(), accent_col.to_html(), str(corner_bolts)]
	if _pixel_panel_cache.has(key):
		return _pixel_panel_cache[key]

	var size = 24
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Fill interior with subtle dithered graphite
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			var dither = ((x + y) % 2 == 0)
			var col = bg_col.lightened(0.04) if dither else bg_col
			img.set_pixel(x, y, col)

	# 2. Outer dark pixel outline with 45-degree chamfered corners (vát góc)
	var outline_col = Color(0.01, 0.02, 0.04, 0.98)
	for i in range(2, size - 2):
		img.set_pixel(i, 0, outline_col)
		img.set_pixel(i, size - 1, outline_col)
		img.set_pixel(0, i, outline_col)
		img.set_pixel(size - 1, i, outline_col)

	# Cut corner diagonals
	img.set_pixel(1, 1, outline_col)
	img.set_pixel(size - 2, 1, outline_col)
	img.set_pixel(1, size - 2, outline_col)
	img.set_pixel(size - 2, size - 2, outline_col)

	# 3. Main neon / metal border (inner 1px)
	var highlight_col = border_col.lightened(0.25)
	var shadow_col = border_col.darkened(0.35)

	for i in range(2, size - 2):
		img.set_pixel(i, 1, highlight_col) # Top highlight
		img.set_pixel(1, i, highlight_col) # Left highlight
		img.set_pixel(i, size - 2, shadow_col) # Bottom shadow
		img.set_pixel(size - 2, i, shadow_col) # Right shadow

	# 4. Inset border line (2px from edge)
	for i in range(3, size - 3):
		img.set_pixel(i, 2, border_col)
		img.set_pixel(2, i, border_col)
		img.set_pixel(i, size - 3, border_col * 0.8)
		img.set_pixel(size - 3, i, border_col * 0.8)

	# 5. Corner bolts (rivet pixel studs)
	if corner_bolts:
		var bolt_col = accent_col if accent_col.a > 0.0 else Color(0.9, 0.95, 1.0, 1.0)
		var bolt_corners = [
			Vector2i(3, 3), Vector2i(size - 5, 3),
			Vector2i(3, size - 5), Vector2i(size - 5, size - 5)
		]
		for c in bolt_corners:
			img.set_pixel(c.x, c.y, Color(1.0, 1.0, 1.0, 1.0))
			img.set_pixel(c.x + 1, c.y, bolt_col)
			img.set_pixel(c.x, c.y + 1, bolt_col.darkened(0.3))
			img.set_pixel(c.x + 1, c.y + 1, Color(0.05, 0.08, 0.12, 1.0))

	var tex = ImageTexture.create_from_image(img)
	_pixel_panel_cache[key] = tex
	return tex

static func create_pixel_button_texture(border_col: Color, bg_col: Color, is_pressed: bool = false, is_hover: bool = false) -> ImageTexture:
	var key = "btn_%s_%s_%s_%s" % [border_col.to_html(), bg_col.to_html(), str(is_pressed), str(is_hover)]
	if _pixel_panel_cache.has(key):
		return _pixel_panel_cache[key]

	var size = 16
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cur_bg = bg_col.lightened(0.12) if is_hover else bg_col
	img.fill(cur_bg)

	var outer_dark = Color(0.01, 0.02, 0.04, 0.98)
	var hi = Color(1.0, 1.0, 1.0, 0.95) if is_hover else border_col.lightened(0.35)
	var sh = outer_dark if is_pressed else border_col.darkened(0.4)

	# 1px Outer border
	for i in range(size):
		img.set_pixel(i, 0, outer_dark)
		img.set_pixel(i, size - 1, outer_dark)
		img.set_pixel(0, i, outer_dark)
		img.set_pixel(size - 1, i, outer_dark)

	# 3D Raised Bevel or Pressed Inset
	var top_left_col = sh if is_pressed else hi
	var bot_right_col = hi if is_pressed else sh

	for i in range(1, size - 1):
		img.set_pixel(i, 1, top_left_col)
		img.set_pixel(1, i, top_left_col)
		img.set_pixel(i, size - 2, bot_right_col)
		img.set_pixel(size - 2, i, bot_right_col)

	var tex = ImageTexture.create_from_image(img)
	_pixel_panel_cache[key] = tex
	return tex

static func create_pixel_bar_fill_texture(fill_col: Color, groove_col: Color = Color(0.02, 0.04, 0.08, 1.0)) -> ImageTexture:
	var key = "bar_fill_%s_%s" % [fill_col.to_html(), groove_col.to_html()]
	if _pixel_bar_cache.has(key):
		return _pixel_bar_cache[key]

	# Repeating 8-pixel segment (6px colored bar + 2px groove)
	var w = 8
	var h = 16
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		for x in range(w):
			if x < 6:
				# Active pixel LED block
				if y == 0 or y == 1:
					# Top highlight
					img.set_pixel(x, y, fill_col.lightened(0.4))
				elif y == h - 1 or y == h - 2:
					# Bottom shadow
					img.set_pixel(x, y, fill_col.darkened(0.4))
				elif x == 0:
					# Left bevel
					img.set_pixel(x, y, fill_col.lightened(0.2))
				elif x == 5:
					# Right bevel
					img.set_pixel(x, y, fill_col.darkened(0.2))
				else:
					# Center glowing body
					img.set_pixel(x, y, fill_col)
			else:
				# 2px dark groove between notches
				if x == 6:
					img.set_pixel(x, y, groove_col.darkened(0.3))
				else:
					img.set_pixel(x, y, groove_col.lightened(0.1))

	var tex = ImageTexture.create_from_image(img)
	_pixel_bar_cache[key] = tex
	return tex

static func create_pixel_bar_bg_texture(bg_col: Color = Color(0.02, 0.04, 0.08, 0.95), border_col: Color = Color(0.12, 0.22, 0.35, 0.8)) -> ImageTexture:
	var key = "bar_bg_%s_%s" % [bg_col.to_html(), border_col.to_html()]
	if _pixel_bar_cache.has(key):
		return _pixel_bar_cache[key]

	var size = 16
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(bg_col)

	# Indented groove border: dark on top/left, subtle highlight on bottom/right
	var outer_dark = Color(0.01, 0.01, 0.02, 0.95)
	var inner_shadow = Color(0.0, 0.0, 0.0, 0.8)
	var inner_hi = border_col * 0.4

	for i in range(size):
		img.set_pixel(i, 0, outer_dark)
		img.set_pixel(i, size - 1, outer_dark)
		img.set_pixel(0, i, outer_dark)
		img.set_pixel(size - 1, i, outer_dark)

	for i in range(1, size - 1):
		img.set_pixel(i, 1, inner_shadow)
		img.set_pixel(1, i, inner_shadow)
		img.set_pixel(i, size - 2, inner_hi)
		img.set_pixel(size - 2, i, inner_hi)

	var tex = ImageTexture.create_from_image(img)
	_pixel_bar_cache[key] = tex
	return tex

static func create_pixel_stylebox(tex: Texture2D, margin: int = 6) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb

static func create_pixel_bar_stylebox(tex: Texture2D) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static var _plasma_cache: Dictionary = {}

static func create_glossy_plasma_fluid_texture(fill_col: Color, is_ghost: bool = false) -> ImageTexture:
	var key = "plasma_%s_%s" % [fill_col.to_html(), str(is_ghost)]
	if _plasma_cache.has(key):
		return _plasma_cache[key]

	var w = 16
	var h = 18
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		for x in range(w):
			if x == w - 1:
				# Glass capsule seam / metal rib divider
				if y == 0 or y == h - 1:
					img.set_pixel(x, y, Color(0.01, 0.02, 0.04, 0.95))
				elif y == 1:
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.8))
				else:
					img.set_pixel(x, y, Color(0.03, 0.06, 0.10, 0.95))
			else:
				if is_ghost:
					# Amber ember lag trail with soft sparkle
					if y == 0 or y == h - 1:
						img.set_pixel(x, y, Color(0.02, 0.03, 0.05, 0.9))
					elif y == 1 or y == 2:
						img.set_pixel(x, y, Color(1.0, 0.9, 0.4, 0.85))
					elif y >= h - 3:
						img.set_pixel(x, y, Color(0.5, 0.25, 0.05, 0.8))
					else:
						var dither = ((x + y) % 3 == 0)
						var c = Color(1.0, 0.65, 0.1, 0.9) if dither else Color(0.85, 0.5, 0.08, 0.85)
						img.set_pixel(x, y, c)
				else:
					# Rich plasma fluid with top glossy glass reflection (from Ref Image 1)
					if y == 0:
						# Top glass dark rim
						img.set_pixel(x, y, Color(0.01, 0.02, 0.05, 0.95))
					elif y == 1:
						# Pure white specular gloss reflection streak
						img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.96))
					elif y == 2:
						# Soft light bleed from specular highlight
						img.set_pixel(x, y, fill_col.lightened(0.55))
					elif y >= h - 3 and y < h - 1:
						# Bottom curve shadow of glass cylinder
						img.set_pixel(x, y, fill_col.darkened(0.45))
					elif y == h - 1:
						# Bottom glass dark rim
						img.set_pixel(x, y, Color(0.01, 0.02, 0.05, 0.95))
					else:
						# Luminous core with subtle micro-sparkle
						var spark = ((x * 3 + y * 7) % 7 == 0)
						var c = fill_col.lightened(0.18) if spark else fill_col
						img.set_pixel(x, y, c)

	var tex = ImageTexture.create_from_image(img)
	_plasma_cache[key] = tex
	return tex

static var _cell_cache: Dictionary = {}

static func create_energy_cell_texture(is_active: bool) -> ImageTexture:
	var key = "cell_%s" % str(is_active)
	if _cell_cache.has(key):
		return _cell_cache[key]

	var w = 8
	var h = 12
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var outer_dark = Color(0.01, 0.02, 0.04, 0.98)
	for y in range(h):
		for x in range(w):
			var is_edge = (x == 0 or x == w - 1 or y == 0 or y == h - 1)
			if is_edge:
				img.set_pixel(x, y, outer_dark)
			else:
				if is_active:
					# Golden battery / bullet capsule (Ref Image 1)
					if y == 1 and x < w - 2:
						img.set_pixel(x, y, Color(1.0, 1.0, 0.85, 1.0)) # Gloss highlight
					elif x == 1:
						img.set_pixel(x, y, Color(1.0, 0.92, 0.4, 1.0))
					elif y == h - 2 or x == w - 2:
						img.set_pixel(x, y, Color(0.65, 0.42, 0.05, 1.0)) # Shadow
					else:
						img.set_pixel(x, y, Color(1.0, 0.82, 0.18, 1.0)) # Rich gold
				else:
					# Inactive dark slate socket
					if y == 1 or x == 1:
						img.set_pixel(x, y, Color(0.08, 0.12, 0.16, 1.0))
					else:
						img.set_pixel(x, y, Color(0.14, 0.18, 0.24, 1.0))

	var tex = ImageTexture.create_from_image(img)
	_cell_cache[key] = tex
	return tex

static var _mech_cache: Dictionary = {}

static func create_mech_reactor_pod_texture(border_col: Color, bg_col: Color) -> ImageTexture:
	var key = "pod_%s_%s" % [border_col.to_html(), bg_col.to_html()]
	if _mech_cache.has(key):
		return _mech_cache[key]

	var size = 48
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var outer_dark = Color(0.01, 0.02, 0.04, 0.98)
	var steel_hi = Color(0.28, 0.38, 0.52, 1.0)
	var steel_body = Color(0.14, 0.18, 0.26, 1.0)
	var steel_sh = Color(0.06, 0.08, 0.12, 1.0)

	# 1. Fill base with heavy steel slate
	for y in range(size):
		for x in range(size):
			var cut = (x + y < 4) or (x - y > size - 5) or (y - x > size - 5) or (x + y > size * 2 - 6)
			if not cut:
				img.set_pixel(x, y, steel_body)

	# 2. Beveled outer edge
	for i in range(4, size - 4):
		img.set_pixel(i, 0, outer_dark)
		img.set_pixel(i, 1, steel_hi)
		img.set_pixel(0, i, outer_dark)
		img.set_pixel(1, i, steel_hi)
		img.set_pixel(i, size - 1, outer_dark)
		img.set_pixel(i, size - 2, steel_sh)
		img.set_pixel(size - 1, i, outer_dark)
		img.set_pixel(size - 2, i, steel_sh)

	# 3. Corner Rivets / Screws
	var rivets = [Vector2i(4, 4), Vector2i(size - 6, 4), Vector2i(4, size - 6), Vector2i(size - 6, size - 6)]
	for r in rivets:
		img.set_pixel(r.x, r.y, Color(1.0, 1.0, 1.0, 1.0))
		img.set_pixel(r.x + 1, r.y, Color(0.6, 0.7, 0.8, 1.0))
		img.set_pixel(r.x, r.y + 1, Color(0.4, 0.5, 0.6, 1.0))
		img.set_pixel(r.x + 1, r.y + 1, outer_dark)

	# 4. Central Recessed Reactor Core Chamber (Circular Pod)
	var center = Vector2(size * 0.5, size * 0.5)
	for y in range(8, size - 8):
		for x in range(8, size - 8):
			var d = (Vector2(x, y) - center).length()
			if d <= 15.0:
				if d >= 13.5:
					# Inner metal rim
					img.set_pixel(x, y, border_col * 0.8)
				elif d >= 12.0:
					# Dark recessed ring
					img.set_pixel(x, y, outer_dark)
				else:
					# Core glow chamber
					var glow = 1.0 - (d / 12.0)
					var col = bg_col.lerp(border_col * 0.35, glow)
					img.set_pixel(x, y, col)

	var tex = ImageTexture.create_from_image(img)
	_mech_cache[key] = tex
	return tex

static var _crt_cache: Dictionary = {}

static func create_industrial_crt_frame(border_col: Color, bg_col: Color) -> ImageTexture:
	var key = "crt_%s_%s" % [border_col.to_html(), bg_col.to_html()]
	if _crt_cache.has(key):
		return _crt_cache[key]

	var size = 32
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(bg_col)

	var outer_dark = Color(0.01, 0.02, 0.04, 1.0)
	var steel_hi = Color(0.28, 0.38, 0.52, 1.0)
	var steel_mid = Color(0.14, 0.18, 0.26, 1.0)
	var steel_sh = Color(0.06, 0.08, 0.12, 1.0)

	# 1. 3px Heavy Bezel (Ref Image 2)
	for i in range(size):
		img.set_pixel(i, 0, outer_dark)
		img.set_pixel(i, size - 1, outer_dark)
		img.set_pixel(0, i, outer_dark)
		img.set_pixel(size - 1, i, outer_dark)

		img.set_pixel(i, 1, steel_hi)
		img.set_pixel(1, i, steel_hi)
		img.set_pixel(i, size - 2, steel_sh)
		img.set_pixel(size - 2, i, steel_sh)

		img.set_pixel(i, 2, steel_mid)
		img.set_pixel(2, i, steel_mid)
		img.set_pixel(i, size - 3, steel_mid)
		img.set_pixel(size - 3, i, steel_mid)

	# 2. Inner 1px neon trim line
	for i in range(3, size - 3):
		img.set_pixel(i, 3, border_col)
		img.set_pixel(3, i, border_col)
		img.set_pixel(i, size - 4, border_col * 0.7)
		img.set_pixel(size - 4, i, border_col * 0.7)

	# 3. Subtle CRT diagonal scratch marks across glass
	for d in range(6, size - 6):
		if d % 5 == 0:
			img.set_pixel(d, d, Color(1.0, 1.0, 1.0, 0.08))
			if d + 1 < size - 6:
				img.set_pixel(d + 1, d, Color(1.0, 1.0, 1.0, 0.05))

	var tex = ImageTexture.create_from_image(img)
	_crt_cache[key] = tex
	return tex

static var _btn_cache: Dictionary = {}

static func create_industrial_button_texture(border_col: Color, bg_col: Color, is_pressed: bool = false, is_hover: bool = false) -> ImageTexture:
	var key = "ibtn_%s_%s_%s_%s" % [border_col.to_html(), bg_col.to_html(), str(is_pressed), str(is_hover)]
	if _btn_cache.has(key):
		return _btn_cache[key]

	var size = 20
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cur_bg = bg_col.lightened(0.1) if is_hover else bg_col
	img.fill(cur_bg)

	var outer_dark = Color(0.01, 0.02, 0.04, 1.0)
	var hi = Color(1.0, 1.0, 1.0, 0.95) if is_hover else Color(0.35, 0.48, 0.65, 1.0)
	var sh = outer_dark if is_pressed else Color(0.04, 0.06, 0.10, 1.0)

	# 1px Outer dark
	for i in range(size):
		img.set_pixel(i, 0, outer_dark)
		img.set_pixel(i, size - 1, outer_dark)
		img.set_pixel(0, i, outer_dark)
		img.set_pixel(size - 1, i, outer_dark)

	# 2px Deep Mechanical Raised Bevel / Pressed Inset (Ref Image 2)
	var top_col = sh if is_pressed else hi
	var bot_col = hi if is_pressed else sh

	for i in range(1, size - 1):
		img.set_pixel(i, 1, top_col)
		img.set_pixel(1, i, top_col)
		img.set_pixel(i, size - 2, bot_col)
		img.set_pixel(size - 2, i, bot_col)

		img.set_pixel(i, 2, top_col * 0.8)
		img.set_pixel(2, i, top_col * 0.8)
		img.set_pixel(i, size - 3, bot_col * 0.8)
		img.set_pixel(size - 3, i, bot_col * 0.8)

	var tex = ImageTexture.create_from_image(img)
	_btn_cache[key] = tex
	return tex

static func create_close_btn_texture(is_hover: bool = false) -> ImageTexture:
	var key = "close_btn_%s" % str(is_hover)
	if _btn_cache.has(key):
		return _btn_cache[key]

	var size = 18
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bg = Color(0.9, 0.22, 0.26, 1.0) if is_hover else Color(0.72, 0.12, 0.16, 1.0)
	img.fill(bg)

	var outer_dark = Color(0.01, 0.02, 0.04, 1.0)
	for i in range(size):
		img.set_pixel(i, 0, outer_dark)
		img.set_pixel(i, size - 1, outer_dark)
		img.set_pixel(0, i, outer_dark)
		img.set_pixel(size - 1, i, outer_dark)

		img.set_pixel(i, 1, Color(1.0, 0.6, 0.6, 1.0) if is_hover else Color(0.9, 0.4, 0.4, 1.0))
		img.set_pixel(1, i, Color(1.0, 0.6, 0.6, 1.0) if is_hover else Color(0.9, 0.4, 0.4, 1.0))
		img.set_pixel(i, size - 2, Color(0.35, 0.05, 0.08, 1.0))
		img.set_pixel(size - 2, i, Color(0.35, 0.05, 0.08, 1.0))

	# Crisp White 'X' in center (Ref Image 2)
	for p in range(4, size - 4):
		img.set_pixel(p, p, Color(1.0, 1.0, 1.0, 1.0))
		img.set_pixel(p + 1, p, Color(1.0, 1.0, 1.0, 1.0))
		img.set_pixel(size - 1 - p, p, Color(1.0, 1.0, 1.0, 1.0))
		img.set_pixel(size - 2 - p, p, Color(1.0, 1.0, 1.0, 1.0))

	var tex = ImageTexture.create_from_image(img)
	_btn_cache[key] = tex
	return tex

static func create_steam_vent_texture() -> ImageTexture:
	var w = 48
	var h = 28
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Isometric diamond plate on floor
	for y in range(h):
		for x in range(w):
			# Map to 2:1 diamond coords
			var dx = abs(float(x - 24) / 22.0)
			var dy = abs(float(y - 14) / 12.0)
			if (dx + dy) <= 1.0:
				var rim = (dx + dy) >= 0.82
				var col = Color(0.22, 0.26, 0.35, 1.0) if rim else Color(0.04, 0.05, 0.08, 1.0)
				# 3D edge highlight
				if rim and y < 14:
					col = Color(0.45, 0.55, 0.72, 1.0)
				elif rim and y >= 14:
					col = Color(0.12, 0.15, 0.22, 1.0)
				
				# Grate slats
				if not rim and (x % 4 == 0 or x % 4 == 1):
					col = Color(0.18, 0.22, 0.28, 1.0)
				# Thermal sub-glow
				if not rim and (x % 4 == 2):
					col = Color(1.6, 0.45, 0.1, 0.85)

				img.set_pixel(x, y, col)

	# 4 Corner hex bolts
	var bolts = [Vector2(24, 3), Vector2(24, 25), Vector2(5, 14), Vector2(43, 14)]
	for b in bolts:
		img.set_pixel(int(b.x), int(b.y), Color(0.65, 0.75, 0.9, 1.0))

	return ImageTexture.create_from_image(img)

static func create_generator_texture() -> ImageTexture:
	var w = 64
	var h = 112
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Base Ground Shadow (Isometric Ellipse)
	for sy in range(88, 110):
		for sx in range(12, 52):
			var norm_x = float(sx - 32) / 18.0
			var norm_y = float(sy - 98) / 9.0
			if (norm_x * norm_x + norm_y * norm_y) <= 1.0:
				var alpha = 0.52 * (1.0 - (norm_x * norm_x + norm_y * norm_y))
				img.set_pixel(sx, sy, Color(0.0, 0.0, 0.0, alpha))

	# 2. Base Pedestal with Hazard Chevrons (y=80..96)
	for y in range(80, 96):
		var t = float(y - 80) / 16.0
		var half_w = 18.0 + t * 4.0
		var min_x = int(32.0 - half_w)
		var max_x = int(32.0 + half_w)
		for x in range(min_x, max_x + 1):
			var is_stripe = ((x + y) / 5) % 2 == 0
			var col = Color(1.5, 1.0, 0.15, 1.0) if is_stripe else Color(0.1, 0.11, 0.14, 1.0)
			if x == min_x or y == 80:
				col = col * 1.3
			img.set_pixel(x, y, col)

	# 3. Main Reactor Column (y=32..80)
	for y in range(32, 80):
		var t = float(y - 32) / 48.0
		var half_w = 14.0
		var min_x = int(32.0 - half_w)
		var max_x = int(32.0 + half_w)
		for x in range(min_x, max_x + 1):
			var norm_x = float(x - 32) / half_w
			var col = Color(0.18, 0.22, 0.28, 1.0)
			if norm_x < -0.7:
				col = Color(0.38, 0.46, 0.58, 1.0)
			elif norm_x > 0.65:
				col = Color(0.08, 0.10, 0.14, 1.0)

			# Central Core Glass Tube (x in 26..38)
			if x >= 26 and x <= 38:
				var core_x = float(x - 32) / 6.0
				var plasma = 1.0 - abs(core_x)
				var pulse = 0.8 + 0.3 * sin(float(y) * 0.4)
				col = Color(0.2 * pulse, 2.2 * pulse, 3.8 * pulse, 1.0) * plasma
				if abs(core_x) < 0.3:
					col = Color(2.5, 3.5, 5.0, 1.0) # White-hot plasma core

			img.set_pixel(x, y, col)

	# 4. Twin Side Tesla Coils (Windings)
	for y in range(40, 72):
		if y % 4 == 0 or y % 4 == 1:
			for x in range(12, 18):
				img.set_pixel(x, y, Color(1.4, 0.7, 0.2, 1.0)) # Copper coil
			for x in range(46, 52):
				img.set_pixel(x, y, Color(1.4, 0.7, 0.2, 1.0))

	# 5. Top Dome & High-Voltage Electrode Sphere (y=10..32)
	for y in range(16, 32):
		var dy = float(y - 24) / 8.0
		var r = sqrt(max(0.0, 1.0 - dy * dy)) * 12.0
		var min_x = int(32.0 - r)
		var max_x = int(32.0 + r)
		for x in range(min_x, max_x + 1):
			var norm_x = float(x - 32) / 12.0
			var col = Color(0.25, 0.30, 0.38, 1.0)
			if norm_x < -0.4:
				col = Color(0.55, 0.65, 0.80, 1.0)
			img.set_pixel(x, y, col)

	# Glowing Apex Lightning Rod (y=4..16)
	for y in range(4, 16):
		img.set_pixel(32, y, Color(0.3, 2.5, 4.0, 1.0))
		img.set_pixel(31, y, Color(0.2, 1.5, 2.8, 1.0))
		img.set_pixel(33, y, Color(0.2, 1.5, 2.8, 1.0))
	img.set_pixel(32, 3, Color(3.5, 4.5, 6.0, 1.0))

	return ImageTexture.create_from_image(img)

static func create_hazard_barrier_texture() -> ImageTexture:
	var w = 56
	var h = 36
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Shadow
	for sy in range(24, 34):
		for sx in range(6, 50):
			var norm = float(sx - 28) / 22.0
			if abs(norm) <= 1.0:
				img.set_pixel(sx, sy, Color(0.0, 0.0, 0.0, 0.4 * (1.0 - abs(norm))))

	# Heavy Barricade Beam with Hazard Chevrons (y=10..24)
	for y in range(10, 24):
		for x in range(8, 48):
			var stripe = ((x * 2 + y) / 6) % 2 == 0
			var col = Color(1.5, 1.0, 0.15, 1.0) if stripe else Color(0.12, 0.14, 0.18, 1.0)
			if y == 10: col = col * 1.3
			if y == 23: col = Color(0.05, 0.06, 0.08, 1.0)
			img.set_pixel(x, y, col)

	# Twin Industrial Support Legs
	for y in range(18, 30):
		for x in range(12, 16):
			img.set_pixel(x, y, Color(0.25, 0.3, 0.38, 1.0))
		for x in range(40, 44):
			img.set_pixel(x, y, Color(0.25, 0.3, 0.38, 1.0))

	# Amber Warning Strobe Beacon on top
	for y in range(3, 9):
		for x in range(26, 30):
			img.set_pixel(x, y, Color(1.8, 0.9, 0.1, 1.0))
	img.set_pixel(28, 2, Color(3.5, 2.5, 0.8, 1.0))

	return ImageTexture.create_from_image(img)


