extends Node2D

const LightHelper = preload("res://scripts/light_helper.gd")

@export var damage_per_tick: float = 9.0
@export var tick_interval: float = 0.075
@export var flame_range: float = 260.0
@export var flame_angle: float = 58.0

var tick_timer: float = 0.0
var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var current_aim_dir: Vector2 = Vector2.RIGHT

# Dynamic flame puff data for rendering rolling turbulent fireballs (zero-allocation)
const MAX_PUFFS: int = 120
var puff_offset: PackedVector2Array = PackedVector2Array()
var puff_dist_ratio: PackedFloat32Array = PackedFloat32Array()
var puff_size: PackedFloat32Array = PackedFloat32Array()
var puff_color: PackedColorArray = PackedColorArray()
var puff_life: PackedFloat32Array = PackedFloat32Array()
var puff_count: int = 0

@onready var flame_light: PointLight2D = $FlameLight

func _ready() -> void:
	_get_managers()
	puff_offset.resize(MAX_PUFFS)
	puff_dist_ratio.resize(MAX_PUFFS)
	puff_size.resize(MAX_PUFFS)
	puff_color.resize(MAX_PUFFS)
	puff_life.resize(MAX_PUFFS)

	if flame_light:
		flame_light.texture = LightHelper.get_radial_texture(128)
		flame_light.energy = 1.0
		flame_light.texture_scale = 3.6

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		swarm_mgr = cur.get_node_or_null("SwarmManager")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")

func _process(delta: float) -> void:
	if not swarm_mgr:
		_get_managers()

	var parent_body = get_parent().get_parent()
	if parent_body and "velocity" in parent_body and parent_body.velocity.length_squared() > 10.0:
		current_aim_dir = parent_body.velocity.normalized()

	# Flickering dynamic flame light
	if flame_light:
		var light_pos = Vector2(0, -12) + current_aim_dir * (flame_range * 0.42)
		flame_light.position = light_pos
		flame_light.energy = randf_range(0.9, 1.45)

	# Update existing puffs with swap-and-pop O(1)
	var i = 0
	while i < puff_count:
		puff_life[i] -= delta * 3.5
		if puff_life[i] <= 0.0:
			var last = puff_count - 1
			if i != last:
				puff_offset[i] = puff_offset[last]
				puff_dist_ratio[i] = puff_dist_ratio[last]
				puff_size[i] = puff_size[last]
				puff_color[i] = puff_color[last]
				puff_life[i] = puff_life[last]
			puff_count -= 1
		else:
			i += 1

	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		_burn_and_emit_stream()

	queue_redraw()

func _burn_and_emit_stream() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	# Emit new rolling fireball puffs along cone
	var half_angle_rad = deg_to_rad(flame_angle * 0.5)
	var dir_angle = current_aim_dir.angle()

	for p in range(5):
		if puff_count >= MAX_PUFFS:
			break
		var idx = puff_count
		var dist_r = randf_range(0.15, 1.0)
		puff_dist_ratio[idx] = dist_r
		var spread_angle = dir_angle + randf_range(-half_angle_rad, half_angle_rad) * dist_r
		var dist = flame_range * dist_r

		# 2:1 isometric compression
		var stream_vec = Vector2(cos(spread_angle) * dist, sin(spread_angle) * dist * 0.75)
		puff_offset[idx] = Vector2(0, -14) + stream_vec
		puff_size[idx] = lerp(8.0, 32.0, dist_r) * randf_range(0.85, 1.15)
		puff_life[idx] = randf_range(0.8, 1.0)

		# Color temperature curve: White-Yellow core -> Orange flame -> Dark smoke
		if dist_r < 0.35:
			puff_color[idx] = Color(3.5, 2.5, 0.8, 0.85) # Incandescent White-Gold
		elif dist_r < 0.7:
			puff_color[idx] = Color(2.8, 1.1, 0.1, 0.75) # Fiery Orange
		else:
			puff_color[idx] = Color(1.4, 0.25, 0.05, 0.5) # Outer Crimson Embers

		puff_count += 1

	# Execute cone damage
	var hits = swarm_mgr.damage_in_cone(global_position, current_aim_dir, flame_range, flame_angle, damage_per_tick)

	if sound_mgr and randf() < 0.38:
		sound_mgr.play_flame()

	# Spawn scorch marks and sparks on ground
	if particle_mgr and hits > 0:
		for s in range(2):
			var dist = randf_range(50.0, flame_range * 0.9)
			var spread = randf_range(-half_angle_rad, half_angle_rad) * (dist / flame_range)
			var ground_p = global_position + Vector2(cos(dir_angle + spread) * dist, sin(dir_angle + spread) * dist * 0.5)
			particle_mgr.spawn_scorch_mark(ground_p, Color(2.2, 0.8, 0.1, 0.85))
			particle_mgr.spawn_sparks(ground_p, Color(2.5, 1.2, 0.2, 1.0), 3)

var is_evolved: bool = false

func evolve_sunstorm() -> void:
	is_evolved = true
	flame_range = 360.0
	flame_angle = 360.0
	damage_per_tick = 22.0
	tick_interval = 0.05

func upgrade_flame() -> void:
	flame_range += 35.0
	flame_angle += 8.0
	damage_per_tick += 3.0

func _draw() -> void:
	# Draw turbulent rolling fireball puffs
	for i in range(puff_count):
		var alpha = clamp(puff_life[i], 0.0, 1.0)
		var c = puff_color[i]
		c.a *= alpha
		var off = puff_offset[i]
		var sz = puff_size[i]
		# Outer soft flame halo
		draw_circle(off, sz, Color(c.r * 0.6, c.g * 0.4, c.b * 0.4, c.a * 0.4))
		# Hot flame core
		draw_circle(off, sz * 0.65, c)
		# Ultra-hot center if near base
		if puff_dist_ratio[i] < 0.35:
			draw_circle(off, sz * 0.35, Color(3.5, 3.5, 2.0, c.a))
