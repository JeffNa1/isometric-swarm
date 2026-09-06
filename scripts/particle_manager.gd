extends Node2D

const MAX_PARTICLES: int = 4000

var p_pos: PackedVector2Array = PackedVector2Array()
var p_vel: PackedVector2Array = PackedVector2Array()
var p_color: PackedColorArray = PackedColorArray()
var p_life: PackedFloat32Array = PackedFloat32Array()
var p_max_life: PackedFloat32Array = PackedFloat32Array()
var p_size: PackedFloat32Array = PackedFloat32Array()
var p_growth: PackedFloat32Array = PackedFloat32Array() # growth rate in pixels/sec
# Types:
# 0: Blood drop (Ground)
# 1: Shard (Normal Air)
# 2: Shockwave Ring (Additive Air)
# 3: Ground Decal (Ground)
# 4: Spark / Additive Flare (Additive Air)
# 5: Steam Plume / Smoke (Normal Air)
# 6: Plasma Ember (Additive Air)
# 7: Pixel Dissolve (Additive Air)
# 8: Acid Bubble (Normal Air)
var p_type: PackedInt32Array = PackedInt32Array()

var active_count: int = 0
var ground_canvas: Node2D = null
var additive_canvas: Node2D = null
var player_ref: Node2D = null

func _get_player() -> void:
	var cur = get_tree().current_scene
	if cur:
		player_ref = cur.get_node_or_null("Entities/Player")

func _ready() -> void:
	z_as_relative = false
	z_index = 4 # Normal air particles: smoke, steam, acid bubbles, shards

	# 1. Ground Canvas (Z = 1: below entities)
	ground_canvas = Node2D.new()
	ground_canvas.name = "GroundDecals"
	ground_canvas.z_as_relative = false
	ground_canvas.z_index = 1
	ground_canvas.draw.connect(_on_ground_draw)
	add_child(ground_canvas)

	# 2. Additive Neon Air Canvas (Z = 5: glowing lasers, sparks, embers, crits)
	additive_canvas = Node2D.new()
	additive_canvas.name = "AdditiveAirCanvas"
	additive_canvas.z_as_relative = false
	additive_canvas.z_index = 5
	var mat_add = CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive_canvas.material = mat_add
	additive_canvas.draw.connect(_on_additive_draw)
	add_child(additive_canvas)

	p_pos.resize(MAX_PARTICLES)
	p_vel.resize(MAX_PARTICLES)
	p_color.resize(MAX_PARTICLES)
	p_life.resize(MAX_PARTICLES)
	p_max_life.resize(MAX_PARTICLES)
	p_size.resize(MAX_PARTICLES)
	p_growth.resize(MAX_PARTICLES)
	p_type.resize(MAX_PARTICLES)

func spawn_blood_burst(center: Vector2, col: Color, count: int = 14) -> void:
	for i in range(count):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		p_pos[idx] = center
		var angle = randf() * TAU
		var spd = randf_range(70.0, 260.0)
		p_vel[idx] = Vector2(cos(angle) * spd, sin(angle) * spd * 0.5)
		p_color[idx] = col
		p_life[idx] = randf_range(0.35, 0.65)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(3.0, 5.0)
		p_growth[idx] = -3.0
		p_type[idx] = 0
		active_count += 1

func spawn_directional_blood(center: Vector2, dir: Vector2, col: Color, count: int = 12) -> void:
	var base_angle = dir.angle()
	for i in range(count):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		p_pos[idx] = center
		var angle = base_angle + randf_range(-0.55, 0.55)
		var spd = randf_range(160.0, 420.0)
		p_vel[idx] = Vector2(cos(angle) * spd, sin(angle) * spd * 0.6)
		p_color[idx] = col
		p_life[idx] = randf_range(0.3, 0.55)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(3.0, 5.5)
		p_growth[idx] = -2.5
		p_type[idx] = 0
		active_count += 1

func spawn_sparks(center: Vector2, col: Color, count: int = 10) -> void:
	for i in range(count):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		p_pos[idx] = center
		var angle = randf() * TAU
		var spd = randf_range(140.0, 380.0)
		p_vel[idx] = Vector2(cos(angle) * spd, sin(angle) * spd)
		p_color[idx] = col
		p_life[idx] = randf_range(0.15, 0.35)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(2.0, 3.8)
		p_growth[idx] = -4.0
		p_type[idx] = 4
		active_count += 1

func spawn_chitin_shards(center: Vector2, col: Color, count: int = 6) -> void:
	for i in range(count):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		p_pos[idx] = center
		var angle = randf() * TAU
		var spd = randf_range(90.0, 240.0)
		p_vel[idx] = Vector2(cos(angle) * spd, sin(angle) * spd * 0.65)
		p_color[idx] = col
		p_life[idx] = randf_range(0.25, 0.45)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(3.0, 5.0)
		p_growth[idx] = -2.0
		p_type[idx] = 1 # Shard
		active_count += 1

func spawn_shockwave_ring(center: Vector2, col: Color, radius: float = 30.0) -> void:
	if active_count >= MAX_PARTICLES: return
	var idx = active_count
	p_pos[idx] = center
	p_vel[idx] = Vector2.ZERO
	p_color[idx] = col
	p_life[idx] = 0.22
	p_max_life[idx] = 0.22
	p_size[idx] = 4.0
	p_growth[idx] = radius / 0.22 # Expands to radius in 0.22s
	p_type[idx] = 2 # Shockwave Ring
	active_count += 1

func spawn_muzzle_flare(center: Vector2, dir: Vector2, col: Color) -> void:
	var base_ang = dir.angle()
	for i in range(14):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		p_pos[idx] = center
		var ang = base_ang + randf_range(-0.35, 0.35)
		var spd = randf_range(250.0, 580.0)
		p_vel[idx] = Vector2(cos(ang) * spd, sin(ang) * spd)
		p_color[idx] = col
		p_life[idx] = randf_range(0.1, 0.22)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(2.5, 4.5)
		p_growth[idx] = -5.0
		p_type[idx] = 4
		active_count += 1

func spawn_flame_puff(center: Vector2, vel: Vector2, col: Color, init_size: float = 6.0) -> void:
	if active_count >= MAX_PARTICLES: return
	var idx = active_count
	p_pos[idx] = center
	p_vel[idx] = vel
	p_color[idx] = col
	p_life[idx] = randf_range(0.28, 0.45)
	p_max_life[idx] = p_life[idx]
	p_size[idx] = init_size
	p_growth[idx] = 32.0
	p_type[idx] = 4
	active_count += 1

func spawn_smoke_trail(center: Vector2, vel: Vector2, col: Color) -> void:
	if active_count >= MAX_PARTICLES: return
	var idx = active_count
	p_pos[idx] = center
	p_vel[idx] = vel * 0.2
	p_color[idx] = col
	p_life[idx] = randf_range(0.35, 0.6)
	p_max_life[idx] = p_life[idx]
	p_size[idx] = randf_range(3.0, 5.0)
	p_growth[idx] = 12.0
	p_type[idx] = 5
	active_count += 1

func spawn_scorch_mark(center: Vector2, col: Color) -> void:
	if active_count >= MAX_PARTICLES: return
	var idx = active_count
	p_pos[idx] = center
	p_vel[idx] = Vector2.ZERO
	p_color[idx] = col
	p_life[idx] = randf_range(0.6, 1.1)
	p_max_life[idx] = p_life[idx]
	p_size[idx] = randf_range(5.0, 9.0)
	p_growth[idx] = -2.0
	p_type[idx] = 3
	active_count += 1

func spawn_shockwave_debris(center: Vector2, radius: float, count: int = 18) -> void:
	for i in range(count):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		var angle = randf() * TAU
		p_pos[idx] = center + Vector2(cos(angle), sin(angle) * 0.5) * (radius * randf_range(0.85, 1.0))
		var spd = randf_range(160.0, 380.0)
		p_vel[idx] = Vector2(cos(angle) * spd, sin(angle) * spd * 0.5)
		p_color[idx] = Color(0.2, 0.85, 1.0, 1.0)
		p_life[idx] = randf_range(0.25, 0.45)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(2.0, 4.0)
		p_growth[idx] = -3.5
		p_type[idx] = 4
		active_count += 1

func spawn_ground_splatter(center: Vector2, col: Color) -> void:
	if active_count >= MAX_PARTICLES: return
	var idx = active_count
	p_pos[idx] = center + Vector2(randf_range(-8, 8), randf_range(-4, 4))
	p_vel[idx] = Vector2.ZERO
	p_color[idx] = Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.65)
	p_life[idx] = randf_range(6.0, 12.0)
	p_max_life[idx] = p_life[idx]
	p_size[idx] = randf_range(8.0, 15.0)
	p_growth[idx] = 0.0
	p_type[idx] = 3
	active_count += 1

## Cột hơi nước nén bốc lên từ Steam Vent hoặc ống xả (Hỗ trợ cả dir là Vector2 hoặc Color)
func spawn_steam_plume(center: Vector2, dir_or_col = Vector2(0, -1), count: int = 8) -> void:
	var move_dir = Vector2(0, -1)
	var tint_col = Color(0.85, 0.92, 1.0, 0.45)
	if dir_or_col is Vector2:
		move_dir = dir_or_col
	elif dir_or_col is Color:
		tint_col = dir_or_col

	for i in range(count):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		p_pos[idx] = center + Vector2(randf_range(-6, 6), randf_range(-3, 3))
		var spd = randf_range(70.0, 150.0)
		var spread = randf_range(-0.3, 0.3)
		var v = move_dir.rotated(spread) * spd
		p_vel[idx] = Vector2(v.x, v.y * 0.6)
		p_color[idx] = tint_col
		p_life[idx] = randf_range(0.5, 0.9)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(4.0, 7.0)
		p_growth[idx] = 22.0
		p_type[idx] = 5
		active_count += 1

## Muội than tàn tro lửa bay lượn (Hỗ trợ cả (center, col, count) và (center, vel, col))
func spawn_plasma_ember(center: Vector2, arg2 = Color(3.5, 1.8, 0.3, 1.0), arg3 = 1) -> void:
	var col = Color(3.5, 1.8, 0.3, 1.0)
	var count = 1
	var base_v = Vector2.ZERO
	if arg2 is Color:
		col = arg2
		count = int(arg3)
	elif arg2 is Vector2:
		base_v = arg2
		if arg3 is Color:
			col = arg3

	for i in range(count):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		p_pos[idx] = center + Vector2(randf_range(-6, 6), randf_range(-3, 3))
		p_vel[idx] = base_v * 0.3 + Vector2(randf_range(-40, 40), randf_range(-90, -150))
		p_color[idx] = col
		p_life[idx] = randf_range(0.4, 0.8)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(1.5, 3.0)
		p_growth[idx] = -1.5
		p_type[idx] = 6
		active_count += 1

## Đám mây hạt Ion dọc chùm Laser Railgun (Hỗ trợ cả (hit_p, col, count) và (start, end, col, count))
func spawn_ion_cloud(p1: Vector2, p2_or_col = Color(0.4, 2.4, 3.8, 1.0), p3_col_or_count = 12, p4_count: int = 18) -> void:
	if p2_or_col is Color:
		var center = p1
		var col = p2_or_col
		var count = int(p3_col_or_count)
		for i in range(count):
			if active_count >= MAX_PARTICLES: break
			var idx = active_count
			var ang = randf() * TAU
			var dist = randf_range(2.0, 16.0)
			p_pos[idx] = center + Vector2(cos(ang) * dist, sin(ang) * dist * 0.6)
			p_vel[idx] = Vector2(cos(ang) * 90.0, sin(ang) * 50.0)
			p_color[idx] = col
			p_life[idx] = randf_range(0.12, 0.25)
			p_max_life[idx] = p_life[idx]
			p_size[idx] = randf_range(2.0, 3.5)
			p_growth[idx] = -4.0
			p_type[idx] = 4
			active_count += 1
	else:
		var start_p = p1
		var end_p: Vector2 = p2_or_col
		var col: Color = p3_col_or_count
		var count = p4_count
		var dir = (end_p - start_p).normalized()
		var perp = Vector2(-dir.y, dir.x)
		var length = start_p.distance_to(end_p)
		for i in range(count):
			if active_count >= MAX_PARTICLES: break
			var idx = active_count
			var t = randf()
			var lateral_offset = perp * randf_range(-18.0, 18.0)
			p_pos[idx] = start_p + (dir * length * t) + lateral_offset
			p_vel[idx] = perp * randf_range(-60.0, 60.0) + dir * randf_range(-30.0, 30.0)
			p_color[idx] = col
			p_life[idx] = randf_range(0.12, 0.28)
			p_max_life[idx] = p_life[idx]
			p_size[idx] = randf_range(1.8, 3.5)
			p_growth[idx] = -4.0
			p_type[idx] = 4
			active_count += 1

## Bọt axit sủi bọt (Hỗ trợ thêm tham số count)
func spawn_acid_bubble(center: Vector2, col: Color = Color(0.4, 3.5, 0.3, 1.0), count: int = 1) -> void:
	for i in range(count):
		if active_count >= MAX_PARTICLES: return
		var idx = active_count
		p_pos[idx] = center + Vector2(randf_range(-14, 14), randf_range(-7, 7))
		p_vel[idx] = Vector2(randf_range(-10, 10), randf_range(-20, -45))
		p_color[idx] = col
		p_life[idx] = randf_range(0.3, 0.6)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(2.0, 4.0)
		p_growth[idx] = 4.5
		p_type[idx] = 8
		active_count += 1

## Quái vật tan chảy vỡ vụn pixel (Pixel Dissolve Splatter)
func spawn_pixel_dissolve(center: Vector2, col: Color, count: int = 16) -> void:
	for i in range(count):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		p_pos[idx] = center + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		var ang = randf() * TAU
		var spd = randf_range(60.0, 240.0)
		p_vel[idx] = Vector2(cos(ang) * spd, sin(ang) * spd * 0.65)
		p_color[idx] = col
		p_life[idx] = randf_range(0.25, 0.55)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(2.0, 3.8)
		p_growth[idx] = -2.0
		p_type[idx] = 7
		active_count += 1

func _process(delta: float) -> void:
	if active_count == 0:
		return

	var i = 0
	while i < active_count:
		p_life[i] -= delta
		if p_life[i] <= 0.0:
			var last = active_count - 1
			if i != last:
				p_pos[i] = p_pos[last]
				p_vel[i] = p_vel[last]
				p_color[i] = p_color[last]
				p_life[i] = p_life[last]
				p_max_life[i] = p_max_life[last]
				p_size[i] = p_size[last]
				p_growth[i] = p_growth[last]
				p_type[i] = p_type[last]
			active_count -= 1
		else:
			p_pos[i] += p_vel[i] * delta
			if p_type[i] != 3:
				p_vel[i] = p_vel[i].move_toward(Vector2.ZERO, 320.0 * delta)
			p_size[i] = max(0.5, p_size[i] + p_growth[i] * delta)
			i += 1

	queue_redraw()
	if is_instance_valid(ground_canvas):
		ground_canvas.queue_redraw()
	if is_instance_valid(additive_canvas):
		additive_canvas.queue_redraw()

func _on_ground_draw() -> void:
	if not is_instance_valid(ground_canvas):
		return
	if not is_instance_valid(player_ref):
		_get_player()
	var p_pos_ref = player_ref.global_position if is_instance_valid(player_ref) else Vector2.ZERO

	ground_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	for i in range(active_count):
		var ptype = p_type[i]
		if ptype == 0 or ptype == 3:
			if (p_pos[i] - p_pos_ref).length_squared() > 1562500.0:
				continue
			var alpha = clamp(p_life[i] / p_max_life[i], 0.0, 1.0)
			var c = p_color[i]
			c.a *= alpha
			ground_canvas.draw_circle(Vector2(p_pos[i].x, p_pos[i].y * 2.0), p_size[i], c)
	ground_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Vẽ các hạt phát sáng Additive (Neon, Lửa, Tia chớp, Embers)
func _on_additive_draw() -> void:
	if not is_instance_valid(additive_canvas):
		return
	if not is_instance_valid(player_ref):
		_get_player()
	var p_pos_ref = player_ref.global_position if is_instance_valid(player_ref) else Vector2.ZERO

	for i in range(active_count):
		var ptype = p_type[i]
		if ptype == 2 or ptype == 4 or ptype == 6 or ptype == 7:
			if (p_pos[i] - p_pos_ref).length_squared() > 1562500.0:
				continue
			var alpha = clamp(p_life[i] / p_max_life[i], 0.0, 1.0)
			var c = p_color[i]
			c.a *= alpha

			match ptype:
				2: # Shockwave ring
					additive_canvas.draw_arc(p_pos[i], p_size[i], 0.0, TAU, 20, c, 3.0)
				6: # Plasma Ember
					var flicker = 0.8 + 0.4 * sin(p_life[i] * 25.0)
					additive_canvas.draw_circle(p_pos[i], p_size[i] * flicker, c)
				7: # Pixel Dissolve
					var sz = p_size[i]
					additive_canvas.draw_rect(Rect2(p_pos[i] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)
				_: # Spark / Additive flare
					additive_canvas.draw_circle(p_pos[i], p_size[i], c)

## Vẽ các hạt không khí thông thường (Khói, Hơi nước, Vụn, Bọt Axit)
func _draw() -> void:
	var p_pos_ref = player_ref.global_position if is_instance_valid(player_ref) else Vector2.ZERO
	for i in range(active_count):
		var ptype = p_type[i]
		if ptype == 1 or ptype == 5 or ptype == 8:
			if (p_pos[i] - p_pos_ref).length_squared() > 1562500.0:
				continue
			var alpha = clamp(p_life[i] / p_max_life[i], 0.0, 1.0)
			var c = p_color[i]
			c.a *= alpha

			match ptype:
				1: # Shard
					var spd = p_vel[i].length()
					if spd > 0.1:
						var v_norm = p_vel[i] / spd
						var trail_len = min(14.0, spd * 0.035)
						draw_line(p_pos[i] - v_norm * trail_len, p_pos[i], c, p_size[i] * 0.75)
					else:
						draw_circle(p_pos[i], p_size[i] * 0.5, c)
				5: # Steam Plume / Smoke
					draw_circle(p_pos[i], p_size[i], c)
				8: # Acid Bubble
					draw_circle(p_pos[i], p_size[i], c)
					draw_circle(p_pos[i] + Vector2(-1, -1), p_size[i] * 0.35, Color(1.0, 1.0, 1.0, alpha * 0.8))
