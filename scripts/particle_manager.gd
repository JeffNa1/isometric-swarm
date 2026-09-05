extends Node2D

const MAX_PARTICLES: int = 600

var p_pos: PackedVector2Array = PackedVector2Array()
var p_vel: PackedVector2Array = PackedVector2Array()
var p_color: PackedColorArray = PackedColorArray()
var p_life: PackedFloat32Array = PackedFloat32Array()
var p_max_life: PackedFloat32Array = PackedFloat32Array()
var p_size: PackedFloat32Array = PackedFloat32Array()

var active_count: int = 0

func _ready() -> void:
	z_index = 5 # render above ground, below HUD
	p_pos.resize(MAX_PARTICLES)
	p_vel.resize(MAX_PARTICLES)
	p_color.resize(MAX_PARTICLES)
	p_life.resize(MAX_PARTICLES)
	p_max_life.resize(MAX_PARTICLES)
	p_size.resize(MAX_PARTICLES)

func spawn_blood_burst(center: Vector2, col: Color, count: int = 14) -> void:
	for i in range(count):
		if active_count >= MAX_PARTICLES:
			break
		var idx = active_count
		p_pos[idx] = center
		var angle = randf() * TAU
		var spd = randf_range(60.0, 240.0)
		# 2:1 isometric ellipse compression
		p_vel[idx] = Vector2(cos(angle) * spd, sin(angle) * spd * 0.5)
		p_color[idx] = col
		p_life[idx] = randf_range(0.3, 0.6)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(2.5, 4.5)
		active_count += 1

func spawn_sparks(center: Vector2, col: Color, count: int = 10) -> void:
	for i in range(count):
		if active_count >= MAX_PARTICLES:
			break
		var idx = active_count
		p_pos[idx] = center
		var angle = randf() * TAU
		var spd = randf_range(120.0, 360.0)
		p_vel[idx] = Vector2(cos(angle) * spd, sin(angle) * spd)
		p_color[idx] = col
		p_life[idx] = randf_range(0.15, 0.35)
		p_max_life[idx] = p_life[idx]
		p_size[idx] = randf_range(1.5, 3.0)
		active_count += 1

func _process(delta: float) -> void:
	if active_count == 0:
		return

	var i = 0
	while i < active_count:
		p_life[i] -= delta
		if p_life[i] <= 0.0:
			# Swap with last active
			var last = active_count - 1
			if i != last:
				p_pos[i] = p_pos[last]
				p_vel[i] = p_vel[last]
				p_color[i] = p_color[last]
				p_life[i] = p_life[last]
				p_max_life[i] = p_max_life[last]
				p_size[i] = p_size[last]
			active_count -= 1
		else:
			p_pos[i] += p_vel[i] * delta
			p_vel[i] = p_vel[i].move_toward(Vector2.ZERO, 350.0 * delta) # friction
			i += 1

	queue_redraw()

func _draw() -> void:
	for i in range(active_count):
		var alpha = clamp(p_life[i] / p_max_life[i], 0.0, 1.0)
		var c = p_color[i]
		c.a *= alpha
		# Draw glowing drop
		draw_circle(p_pos[i], p_size[i] * alpha, c)
