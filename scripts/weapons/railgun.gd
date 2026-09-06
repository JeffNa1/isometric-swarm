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

# Hyperion Twin Beam offsets
var is_evolved: bool = false

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

	var cd_mult = player_ref.cooldown_reduction if (player_ref and "cooldown_reduction" in player_ref) else 0.0
	var actual_rate = max(0.18, fire_rate * (1.0 - cd_mult))

	fire_timer += delta
	if fire_timer >= actual_rate:
		fire_timer = 0.0
		_fire_piercing_beam()

func _fire_piercing_beam() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	var origin_pos = global_position
	var best_target: Vector2 = Vector2.ZERO
	var min_dist: float = beam_length

	# Query spatial grid for truly nearby enemies anywhere in active horde
	var candidates = swarm_mgr.spatial_grid.get_nearby(origin_pos, beam_length)
	for idx in candidates:
		if idx < swarm_mgr.active_count:
			var ep = swarm_mgr.positions[idx]
			var d = origin_pos.distance_to(ep)
			if d < min_dist:
				min_dist = d
				best_target = ep

	if best_target != Vector2.ZERO:
		fire_direction = (best_target - origin_pos).normalized()
	else:
		fire_direction = Vector2(1.0, 0.5).normalized()

	var facing_r = fire_direction.x >= 0.0
	beam_start = Vector2(8.0 if facing_r else -8.0, -22.0)
	beam_end = beam_start + fire_direction * beam_length
	beam_draw_timer = 0.22

	_generate_helix_points()

	var world_start = global_position + beam_start
	var world_end = global_position + beam_end

	# Player Recoil
	if player_ref and player_ref.has_method("apply_recoil"):
		player_ref.apply_recoil(-fire_direction, 7.5)

	var crit_info = player_ref.roll_crit(damage) if (player_ref and player_ref.has_method("roll_crit")) else {"damage": damage, "is_crit": false}
	var final_damage = float(crit_info["damage"])

	# Execute piercing beam damage
	var hits = swarm_mgr.damage_along_beam(world_start, world_end, beam_width, final_damage, 320.0)

	# Hyperion Super Evolution: True Twin Secondary Beam!
	if is_evolved:
		var perp = Vector2(-fire_direction.y, fire_direction.x)
		var b2_start = world_start + perp * 24.0
		var b2_end = world_end + perp * 24.0
		var b3_start = world_start - perp * 24.0
		var b3_end = world_end - perp * 24.0
		hits += swarm_mgr.damage_along_beam(b2_start, b2_end, beam_width * 0.8, final_damage * 0.5, 250.0)
		hits += swarm_mgr.damage_along_beam(b3_start, b3_end, beam_width * 0.8, final_damage * 0.5, 250.0)

	# Record weapon damage for Run Debriefing
	if hits > 0 and player_ref and player_ref.has_method("record_weapon_damage"):
		player_ref.record_weapon_damage("railgun", final_damage * hits)

	if sound_mgr and sound_mgr.has_method("play_laser"):
		sound_mgr.play_laser()

	if camera_node:
		if camera_node.has_method("add_directional_trauma"):
			camera_node.add_directional_trauma(0.38 if is_evolved else 0.28, -fire_direction)
		elif camera_node.has_method("add_trauma"):
			camera_node.add_trauma(0.32 if is_evolved else 0.24)
		if camera_node.has_method("trigger_zoom_punch"):
			camera_node.trigger_zoom_punch(0.04, 0.16)

	var cur = get_tree().current_scene
	if cur and hits >= 10 and cur.has_method("trigger_shockwave"):
		cur.trigger_shockwave(world_start + fire_direction * (beam_length * 0.4), 0.025)

	# Muzzle blast particles & Ion cloud trails
	if particle_mgr:
		var flare_col = Color(3.5, 1.8, 0.4, 1.0) if is_evolved else Color(0.4, 2.4, 3.8, 1.0)
		particle_mgr.spawn_muzzle_flare(world_start, fire_direction, flare_col)
		for s in range(min(hits, 6)):
			var t_hit = randf_range(0.15, 0.85)
			var hit_p = lerp(world_start, world_end, t_hit)
			particle_mgr.spawn_directional_blood(hit_p, fire_direction, Color(1.8, 0.2, 0.2, 1.0), 8)
			particle_mgr.spawn_sparks(hit_p, flare_col, 6)
			if particle_mgr.has_method("spawn_ion_cloud") and randf() < 0.65:
				particle_mgr.spawn_ion_cloud(hit_p, flare_col, 2)

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

func evolve_hyperion() -> void:
	is_evolved = true
	damage = 180.0
	fire_rate = 0.55
	beam_width = 46.0
	beam_length = 950.0

func upgrade_damage(multiplier: float) -> void:
	damage *= multiplier

func upgrade_speed(multiplier: float) -> void:
	fire_rate = max(0.2, fire_rate * multiplier)

func upgrade_beam() -> void:
	beam_width += 10.0
	beam_length += 80.0
	damage += 30.0

func _draw() -> void:
	if beam_draw_timer <= 0.0:
		return

	var progress = 1.0 - (beam_draw_timer / 0.22)
	var alpha = clamp(beam_draw_timer / 0.22, 0.0, 1.0)
	var width_scale = 1.0 - (progress * 0.4)

	var halo_col = Color(1.5, 0.8, 0.2, 0.35 * alpha) if is_evolved else Color(0.1, 0.6, 2.0, 0.35 * alpha)
	var core_col = Color(3.5, 2.0, 0.4, 0.9 * alpha) if is_evolved else Color(0.5, 1.5, 3.0, 0.9 * alpha)

	# 1. Outer Ion Halo
	draw_line(beam_start, beam_end, halo_col, beam_width * width_scale)

	# 2. Helical Electric Arcs
	if helix_points.size() > 1 and alpha > 0.3:
		draw_polyline(helix_points, core_col, 2.5)

	# 3. Mid Plasma Core
	draw_line(beam_start, beam_end, core_col, beam_width * 0.45 * width_scale)

	# 4. White-Hot Center Ray
	draw_line(beam_start, beam_end, Color(3.5, 3.5, 3.5, 1.0 * alpha), 4.5 * width_scale)

	# Hyperion Twin Beams Visuals
	if is_evolved:
		var perp = Vector2(-fire_direction.y, fire_direction.x)
		var p1 = beam_start + perp * 20.0
		var p2 = beam_end + perp * 20.0
		var p3 = beam_start - perp * 20.0
		var p4 = beam_end - perp * 20.0
		draw_line(p1, p2, core_col * 0.8, beam_width * 0.3 * width_scale)
		draw_line(p3, p4, core_col * 0.8, beam_width * 0.3 * width_scale)

	# 5. Muzzle Flare
	var flare_size = 28.0 * (1.0 - progress)
	draw_circle(beam_start, flare_size * 0.4, Color(3.5, 3.5, 3.5, alpha))
