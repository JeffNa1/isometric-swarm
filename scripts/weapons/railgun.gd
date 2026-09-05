extends Node2D

const LightHelper = preload("res://scripts/light_helper.gd")

@export var damage: float = 75.0
@export var fire_rate: float = 0.85
@export var beam_length: float = 800.0
@export var beam_width: float = 32.0

var fire_timer: float = 0.0
var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var floating_txt_mgr: Node2D = null
var camera_node: Camera2D = null
var player_ref: CharacterBody2D = null

var beam_draw_timer: float = 0.0
var beam_start: Vector2 = Vector2.ZERO
var beam_end: Vector2 = Vector2.ZERO
var fire_direction: Vector2 = Vector2.RIGHT

# Helical lightning points
var helix_points: PackedVector2Array = PackedVector2Array()

@onready var muzzle_light: PointLight2D = $MuzzleLight

func _ready() -> void:
	_get_managers()
	if muzzle_light:
		muzzle_light.texture = LightHelper.get_radial_texture(128)
		muzzle_light.energy = 0.0

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		swarm_mgr = cur.get_node_or_null("SwarmManager")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		floating_txt_mgr = cur.get_node_or_null("FloatingTextManager")
		camera_node = cur.get_node_or_null("Camera2D")
		player_ref = cur.get_node_or_null("Entities/Player")

func _process(delta: float) -> void:
	if not swarm_mgr or not player_ref:
		_get_managers()

	if beam_draw_timer > 0.0:
		beam_draw_timer -= delta
		if muzzle_light:
			muzzle_light.energy = (beam_draw_timer / 0.2) * 3.8
			muzzle_light.position = beam_start
		queue_redraw()
	else:
		if muzzle_light and muzzle_light.energy > 0.0:
			muzzle_light.energy = 0.0

	fire_timer += delta
	if fire_timer >= fire_rate:
		fire_timer = 0.0
		_fire_piercing_beam()

func _fire_piercing_beam() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	var origin_pos = global_position
	var best_target: Vector2 = Vector2.ZERO
	var min_dist: float = beam_length

	var sample_count = min(swarm_mgr.active_count, 80)
	for i in range(sample_count):
		var ep = swarm_mgr.positions[i]
		var d = origin_pos.distance_to(ep)
		if d < min_dist:
			min_dist = d
			best_target = ep

	if best_target != Vector2.ZERO:
		fire_direction = (best_target - origin_pos).normalized()
	else:
		fire_direction = Vector2(1.0, 0.5).normalized()

	# Align with shoulder cannon
	var facing_r = fire_direction.x >= 0.0
	beam_start = Vector2(8.0 if facing_r else -8.0, -22.0)
	beam_end = beam_start + fire_direction * beam_length
	beam_draw_timer = 0.22

	# Generate helical electric arc points along beam
	_generate_helix_points()

	var world_start = global_position + beam_start
	var world_end = global_position + beam_end

	# Player Recoil Kickback
	if player_ref and player_ref.has_method("apply_recoil"):
		player_ref.apply_recoil(-fire_direction, 7.5)

	# Execute piercing damage
	var hits = swarm_mgr.damage_along_beam(world_start, world_end, beam_width, damage, 320.0)

	# Sound & Screen shake
	if sound_mgr and sound_mgr.has_method("play_laser"):
		sound_mgr.play_laser()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.24)

	# Muzzle blast particles
	if particle_mgr:
		particle_mgr.spawn_muzzle_flare(world_start, fire_direction, Color(0.4, 2.4, 3.8, 1.0))
		if hits > 0:
			for s in range(min(hits, 6)):
				var t_hit = randf_range(0.15, 0.85)
				var hit_p = lerp(world_start, world_end, t_hit)
				particle_mgr.spawn_directional_blood(hit_p, fire_direction, Color(1.8, 0.2, 0.2, 1.0), 8)
				particle_mgr.spawn_sparks(hit_p, Color(0.3, 2.0, 3.5, 1.0), 6)

	# Micro hit-stop for visceral satisfaction when cleaving a large crowd
	if hits >= 8 and player_ref and player_ref.has_method("trigger_hit_stop"):
		player_ref.trigger_hit_stop(0.03)

	queue_redraw()

func _generate_helix_points() -> void:
	helix_points.clear()
	var steps = 28
	var perp = Vector2(-fire_direction.y, fire_direction.x)
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var base_p = lerp(beam_start, beam_end, t)
		var wave = sin(t * TAU * 4.5) * 10.0 * (1.0 - t * 0.3)
		helix_points.append(base_p + perp * wave)

func upgrade_damage(multiplier: float) -> void:
	damage *= multiplier

func upgrade_speed(multiplier: float) -> void:
	fire_rate = max(0.2, fire_rate * multiplier)

func upgrade_beam() -> void:
	beam_width += 12.0
	beam_length += 120.0
	damage += 25.0

func _draw() -> void:
	if beam_draw_timer <= 0.0:
		return

	var progress = 1.0 - (beam_draw_timer / 0.22)
	var alpha = clamp(beam_draw_timer / 0.22, 0.0, 1.0)
	var width_scale = 1.0 - (progress * 0.4)

	# 1. Outer Cyan Ion Halo
	draw_line(beam_start, beam_end, Color(0.1, 0.6, 2.0, 0.35 * alpha), beam_width * width_scale)

	# 2. Helical Electric Arcs
	if helix_points.size() > 1 and alpha > 0.3:
		draw_polyline(helix_points, Color(0.4, 2.0, 3.5, 0.75 * alpha), 2.5)

	# 3. Mid Plasma Core
	draw_line(beam_start, beam_end, Color(0.5, 1.5, 3.0, 0.9 * alpha), beam_width * 0.45 * width_scale)

	# 4. White-Hot Center Ray
	draw_line(beam_start, beam_end, Color(3.5, 3.5, 3.5, 1.0 * alpha), 4.5 * width_scale)

	# 5. Cinematic 4-Point Star Muzzle Flare
	var flare_size = 28.0 * (1.0 - progress)
	var flare_col = Color(3.0, 3.5, 4.0, alpha)
	var cyan_col = Color(0.2, 2.2, 3.5, 0.8 * alpha)
	
	# Horizontal diamond
	var h_diamond = PackedVector2Array([
		beam_start + Vector2(-flare_size, 0),
		beam_start + Vector2(0, -flare_size * 0.25),
		beam_start + Vector2(flare_size, 0),
		beam_start + Vector2(0, flare_size * 0.25)
	])
	# Vertical diamond
	var v_diamond = PackedVector2Array([
		beam_start + Vector2(-flare_size * 0.25, 0),
		beam_start + Vector2(0, -flare_size),
		beam_start + Vector2(flare_size * 0.25, 0),
		beam_start + Vector2(0, flare_size)
	])
	draw_colored_polygon(h_diamond, cyan_col)
	draw_colored_polygon(v_diamond, cyan_col)
	draw_circle(beam_start, flare_size * 0.4, flare_col)
