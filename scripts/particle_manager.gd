extends Node2D

const MAX_PARTICLES: int = 3500

var p_pos: PackedVector2Array = PackedVector2Array()
var p_vel: PackedVector2Array = PackedVector2Array()
var p_color: PackedColorArray = PackedColorArray()
var p_life: PackedFloat32Array = PackedFloat32Array()
var p_max_life: PackedFloat32Array = PackedFloat32Array()
var p_size: PackedFloat32Array = PackedFloat32Array()
var p_growth: PackedFloat32Array = PackedFloat32Array() # growth rate in pixels/sec
var p_type: PackedInt32Array = PackedInt32Array() # 0: Circle, 1: Shard/Line, 2: Shockwave Ring

var active_count: int = 0

func _ready() -> void:
	z_index = 5 # render above ground, below HUD
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
		active_count += 1

func spawn_muzzle_flare(center: Vector2, dir: Vector2, col: Color) -> void:
	# High-velocity directional spark spray at muzzle
	var base_ang = dir.angle()
	for i in range(12):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		p_pos[idx] = center
		var ang = base_ang + randf_range(-0.35, 0.35)
		var spd = randf_range(250.0, 550.0)
		p_vel[idx] = Vector2(cos(ang) * spd, sin(ang) * spd)
		p_color[idx] = col
		p_life[idx] = randf_range(0.1, 0.22)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(2.5, 4.5)
		p_growth[idx] = -5.0
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
	p_growth[idx] = 32.0 # Expanding fireball
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
	p_growth[idx] = 12.0 # Gently expanding smoke
	active_count += 1

func spawn_scorch_mark(center: Vector2, col: Color) -> void:
	if active_count >= MAX_PARTICLES: return
	var idx = active_count
	p_pos[idx] = center
	p_vel[idx] = Vector2.ZERO
	p_color[idx] = col
	p_life[idx] = randf_range(0.6, 1.1) # Lingers on ground
	p_max_life[idx] = p_life[idx]
	p_size[idx] = randf_range(5.0, 9.0)
	p_growth[idx] = -2.0
	active_count += 1

func spawn_shockwave_debris(center: Vector2, radius: float, count: int = 18) -> void:
	for i in range(count):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		var a = randf() * TAU
		p_pos[idx] = center + Vector2(cos(a) * radius, sin(a) * radius * 0.5)
		var spd = randf_range(180.0, 420.0)
		p_vel[idx] = Vector2(cos(a) * spd, sin(a) * spd * 0.5)
		p_color[idx] = Color(1.8, 1.2, 0.3, 1.0)
		p_life[idx] = randf_range(0.2, 0.45)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(2.5, 4.5)
		p_growth[idx] = -3.0
		active_count += 1

func spawn_chitin_shards(center: Vector2, col: Color, count: int = 14) -> void:
	for i in range(count):
		if active_count >= MAX_PARTICLES: break
		var idx = active_count
		p_pos[idx] = center
		var ang = randf() * TAU
		var spd = randf_range(180.0, 520.0)
		p_vel[idx] = Vector2(cos(ang) * spd, sin(ang) * spd * 0.65)
		p_color[idx] = col
		p_life[idx] = randf_range(0.25, 0.5)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(3.0, 6.0)
		p_growth[idx] = -4.0
		p_type[idx] = 1 # Shard
		active_count += 1

func spawn_shockwave_ring(center: Vector2, col: Color, max_radius: float = 42.0) -> void:
	if active_count >= MAX_PARTICLES: return
	var idx = active_count
	p_pos[idx] = center
	p_vel[idx] = Vector2.ZERO
	p_color[idx] = col
	p_life[idx] = 0.22
	p_max_life[idx] = 0.22
	p_size[idx] = 4.0
	p_growth[idx] = max_radius / 0.22 # expand to max radius
	p_type[idx] = 2 # Shockwave ring
	active_count += 1

func spawn_ground_splatter(center: Vector2, col: Color) -> void:
	if active_count >= MAX_PARTICLES: return
	var idx = active_count
	p_pos[idx] = center + Vector2(randf_range(-12, 12), randf_range(-6, 6))
	p_vel[idx] = Vector2.ZERO
	p_color[idx] = Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.65)
	p_life[idx] = randf_range(8.0, 14.0) # Long lingering splatter on floor
	p_max_life[idx] = p_life[idx]
	p_size[idx] = randf_range(8.0, 16.0)
	p_growth[idx] = 0.0
	p_type[idx] = 3 # Ground splatter
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
			if p_type[i] != 3: # decals don't experience drag
				p_vel[i] = p_vel[i].move_toward(Vector2.ZERO, 340.0 * delta) # friction
			p_size[i] = max(0.5, p_size[i] + p_growth[i] * delta)
			i += 1

	queue_redraw()

func _draw() -> void:
	for i in range(active_count):
		var alpha = clamp(p_life[i] / p_max_life[i], 0.0, 1.0)
		var c = p_color[i]
		c.a *= alpha

		var ptype = p_type[i]
		match ptype:
			1: # Shard
				var v_norm = p_vel[i].normalized()
				var trail_len = min(14.0, p_vel[i].length() * 0.035)
				draw_line(p_pos[i] - v_norm * trail_len, p_pos[i], c, p_size[i] * 0.75)
			2: # Shockwave ring
				draw_arc(p_pos[i], p_size[i], 0.0, TAU, 16, c, 2.5)
			3: # Ground splatter
				draw_set_transform(p_pos[i], 0.0, Vector2(1.0, 0.5))
				draw_circle(Vector2.ZERO, p_size[i], c)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_: # Default circle
				draw_circle(p_pos[i], p_size[i], c)
