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
var player_ref: CharacterBody2D = null
var current_aim_dir: Vector2 = Vector2.RIGHT

# Dynamic flame puff data
const MAX_PUFFS: int = 140
var puff_offset: PackedVector2Array = PackedVector2Array()
var puff_dist_ratio: PackedFloat32Array = PackedFloat32Array()
var puff_size: PackedFloat32Array = PackedFloat32Array()
var puff_color: PackedColorArray = PackedColorArray()
var puff_life: PackedFloat32Array = PackedFloat32Array()
var puff_count: int = 0

var is_evolved: bool = false
var swirl_angle: float = 0.0

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
		player_ref = cur.get_node_or_null("Entities/Player")

func _process(delta: float) -> void:
	if not swarm_mgr or not player_ref:
		_get_managers()

	# Smart Aiming: Find closest enemy in 360 degree vicinity
	if not is_evolved and swarm_mgr and swarm_mgr.active_count > 0:
		var origin = global_position
		var nearby = swarm_mgr.spatial_grid.get_nearby(origin, flame_range * 1.4)
		var closest_target: Vector2 = Vector2.ZERO
		var min_dist_sq: float = (flame_range * 1.4) * (flame_range * 1.4)
		for idx in nearby:
			if idx < swarm_mgr.active_count:
				var ep = swarm_mgr.positions[idx]
				var d_sq = origin.distance_squared_to(ep)
				if d_sq < min_dist_sq:
					min_dist_sq = d_sq
					closest_target = ep

		if closest_target != Vector2.ZERO:
			var desired_dir = (closest_target - origin).normalized()
			current_aim_dir = current_aim_dir.slerp(desired_dir, 14.0 * delta)
		else:
			# Fallback to velocity
			if player_ref and player_ref.velocity.length_squared() > 10.0:
				current_aim_dir = current_aim_dir.slerp(player_ref.velocity.normalized(), 8.0 * delta)
	elif is_evolved:
		swirl_angle += delta * 6.0

	# Flickering flame light
	if flame_light:
		var light_pos = Vector2(0, -12) + (current_aim_dir * (flame_range * 0.42) if not is_evolved else Vector2.ZERO)
		flame_light.position = light_pos
		flame_light.energy = randf_range(1.0, 1.6)

	# Update existing puffs O(1)
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

	var cd_mult = player_ref.cooldown_reduction if (player_ref and "cooldown_reduction" in player_ref) else 0.0
	var actual_interval = max(0.03, tick_interval * (1.0 - cd_mult))

	tick_timer += delta
	if tick_timer >= actual_interval:
		tick_timer = 0.0
		_burn_and_emit_stream()

	queue_redraw()

func _burn_and_emit_stream() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	var half_angle_rad = deg_to_rad(flame_angle * 0.5)
	var dir_angle = current_aim_dir.angle()

	var num_puffs = 10 if is_evolved else 5
	for p in range(num_puffs):
		if puff_count >= MAX_PUFFS:
			break
		var idx = puff_count
		var dist_r = randf_range(0.15, 1.0)
		puff_dist_ratio[idx] = dist_r

		var spread_angle = 0.0
		if is_evolved:
			spread_angle = randf() * TAU
		else:
			spread_angle = dir_angle + randf_range(-half_angle_rad, half_angle_rad) * dist_r

		var dist = flame_range * dist_r
		var stream_vec = Vector2(cos(spread_angle) * dist, sin(spread_angle) * dist * 0.75)
		puff_offset[idx] = Vector2(0, -14) + stream_vec
		puff_size[idx] = lerp(8.0, 34.0, dist_r) * randf_range(0.85, 1.15)
		puff_life[idx] = randf_range(0.8, 1.0)

		if dist_r < 0.35:
			puff_color[idx] = Color(3.5, 2.5, 0.8, 0.85)
		elif dist_r < 0.7:
			puff_color[idx] = Color(2.8, 1.1, 0.1, 0.75)
		else:
			puff_color[idx] = Color(1.4, 0.25, 0.05, 0.5)

		puff_count += 1

	var dmg_mult = player_ref.damage_multiplier if (player_ref and "damage_multiplier" in player_ref) else 1.0
	var final_dmg = damage_per_tick * dmg_mult

	var hits = 0
	if is_evolved:
		hits = swarm_mgr.damage_in_radius(global_position, flame_range, final_dmg, 45.0)
	else:
		hits = swarm_mgr.damage_in_cone(global_position, current_aim_dir, flame_range, flame_angle, final_dmg)

	if hits > 0 and player_ref and player_ref.has_method("record_weapon_damage"):
		player_ref.record_weapon_damage("flame", final_dmg * hits)

	if sound_mgr and randf() < 0.38:
		sound_mgr.play_flame()

	if particle_mgr and hits > 0:
		for s in range(2):
			var dist = randf_range(40.0, flame_range * 0.9)
			var a = (randf() * TAU) if is_evolved else (dir_angle + randf_range(-half_angle_rad, half_angle_rad))
			var ground_p = global_position + Vector2(cos(a) * dist, sin(a) * dist * 0.5)
			particle_mgr.spawn_scorch_mark(ground_p, Color(2.2, 0.8, 0.1, 0.85))
			particle_mgr.spawn_sparks(ground_p, Color(2.5, 1.2, 0.2, 1.0), 3)
			if particle_mgr.has_method("spawn_plasma_ember") and randf() < 0.7:
				particle_mgr.spawn_plasma_ember(ground_p, Color(3.5, 1.8, 0.3, 1.0), 2)

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
	for i in range(puff_count):
		var alpha = clamp(puff_life[i], 0.0, 1.0)
		var c = puff_color[i]
		c.a *= alpha
		var off = puff_offset[i]
		var sz = puff_size[i]
		draw_circle(off, sz, Color(c.r * 0.6, c.g * 0.4, c.b * 0.4, c.a * 0.4))
		draw_circle(off, sz * 0.65, c)
		if puff_dist_ratio[i] < 0.35:
			draw_circle(off, sz * 0.35, Color(3.5, 3.5, 2.0, c.a))
