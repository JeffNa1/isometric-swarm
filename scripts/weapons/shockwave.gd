extends Node2D

const LightHelper = preload("res://scripts/light_helper.gd")

@export var damage: float = 110.0
@export var cooldown: float = 1.6
@export var blast_radius: float = 260.0
@export var knockback: float = 500.0

var blast_timer: float = 0.0
var anim_timer: float = 0.0
var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var camera_node: Camera2D = null
var player_ref: CharacterBody2D = null

# Lightning arc jagged points around the blast ring
var arc_ring_points: PackedVector2Array = PackedVector2Array()

var is_evolved: bool = false
var vortex_timer: float = 0.0

@onready var blast_light: PointLight2D = $BlastLight

func _ready() -> void:
	_get_managers()
	if blast_light:
		blast_light.texture = LightHelper.get_radial_texture(128)
		blast_light.energy = 0.0
		blast_light.texture_scale = 5.2

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		swarm_mgr = cur.get_node_or_null("SwarmManager")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		camera_node = cur.get_node_or_null("Camera2D")
		player_ref = cur.get_node_or_null("Entities/Player")

func _process(delta: float) -> void:
	if not swarm_mgr or not player_ref:
		_get_managers()

	if anim_timer > 0.0:
		anim_timer -= delta
		if blast_light:
			var light_progress = anim_timer / 0.35
			blast_light.energy = light_progress * 4.5
		queue_redraw()
	else:
		if blast_light and blast_light.energy > 0.0:
			blast_light.energy = 0.0

	# Vortex suction logic for Supernova
	if is_evolved and vortex_timer > 0.0:
		vortex_timer -= delta
		_apply_vortex_suction(delta)
		if vortex_timer <= 0.0:
			_detonate_blast()

	var cd_mult = player_ref.cooldown_reduction if (player_ref and "cooldown_reduction" in player_ref) else 0.0
	var actual_cd = max(0.4, cooldown * (1.0 - cd_mult))

	blast_timer += delta
	if blast_timer >= actual_cd:
		blast_timer = 0.0
		if is_evolved:
			vortex_timer = 0.25 # Suck in for 0.25s before explosion
		else:
			_detonate_blast()

func _apply_vortex_suction(delta: float) -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0: return
	var origin = global_position
	var candidates = swarm_mgr.spatial_grid.get_nearby(origin, blast_radius * 1.2)
	for idx in candidates:
		if idx < swarm_mgr.active_count:
			var p = swarm_mgr.positions[idx]
			var to_center = origin - p
			var d = to_center.length()
			if d < blast_radius * 1.2 and d > 10.0:
				swarm_mgr.velocities[idx] += to_center.normalized() * (900.0 * delta)

func _detonate_blast() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	anim_timer = 0.35
	_generate_arc_ring()

	var crit_info = player_ref.roll_crit(damage) if (player_ref and player_ref.has_method("roll_crit")) else {"damage": damage, "is_crit": false}
	var final_damage = float(crit_info["damage"])

	var hits = swarm_mgr.damage_in_radius(global_position, blast_radius, final_damage, knockback)

	if hits > 0 and player_ref and player_ref.has_method("record_weapon_damage"):
		player_ref.record_weapon_damage("shockwave", final_damage * hits)

	if sound_mgr:
		if sound_mgr.has_method("play_shockwave"):
			sound_mgr.play_shockwave()
		if sound_mgr.has_method("play_sub_bass_impact") and is_evolved:
			sound_mgr.play_sub_bass_impact()

	if camera_node:
		if camera_node.has_method("add_trauma"):
			camera_node.add_trauma(0.58 if is_evolved else 0.48)
		if camera_node.has_method("trigger_zoom_punch"):
			camera_node.trigger_zoom_punch(0.08 if is_evolved else 0.05, 0.22)

	var cur = get_tree().current_scene
	if cur and cur.has_method("trigger_shockwave"):
		cur.trigger_shockwave(global_position, 0.055 if is_evolved else 0.04)

	if particle_mgr:
		particle_mgr.spawn_shockwave_debris(global_position, blast_radius * 0.45, 26)
		if hits > 0:
			for s in range(8):
				var a = randf() * TAU
				var p = global_position + Vector2(cos(a) * (blast_radius * 0.7), sin(a) * (blast_radius * 0.35))
				particle_mgr.spawn_sparks(p, Color(3.5, 2.2, 0.4, 1.0), 8)
				if particle_mgr.has_method("spawn_plasma_ember") and randf() < 0.5:
					particle_mgr.spawn_plasma_ember(p, Color(3.5, 2.2, 0.4, 1.0), 2)

	queue_redraw()

func _generate_arc_ring() -> void:
	arc_ring_points.clear()
	var segments = 36
	for i in range(segments + 1):
		var a = (TAU / float(segments)) * float(i)
		var jitter = randf_range(0.92, 1.08)
		var p = Vector2(cos(a) * jitter, sin(a) * 0.5 * jitter)
		arc_ring_points.append(p)

func evolve_supernova() -> void:
	is_evolved = true
	blast_radius = 450.0
	damage = 380.0
	cooldown = 0.90
	knockback = 750.0

func upgrade_blast() -> void:
	blast_radius += 35.0
	damage += 30.0
	cooldown = max(0.85, cooldown * 0.88)

func _draw() -> void:
	if anim_timer <= 0.0 and vortex_timer <= 0.0:
		return

	# Draw vortex suction inward spiral
	if vortex_timer > 0.0:
		var v_alpha = (vortex_timer / 0.35) * 0.7
		draw_set_transform(Vector2(0, -10), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, blast_radius * (vortex_timer / 0.35), 0.0, TAU, 32, Color(3.0, 1.2, 2.8, v_alpha), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if anim_timer > 0.0:
		var progress = 1.0 - (anim_timer / 0.35)
		var current_r = blast_radius * (sqrt(progress))
		var alpha = (1.0 - progress) * 0.95

		draw_set_transform(Vector2(0, -10), 0.0, Vector2.ONE)
		if arc_ring_points.size() > 1:
			var scaled_arcs = PackedVector2Array()
			for pt in arc_ring_points:
				scaled_arcs.append(pt * current_r)
			draw_polyline(scaled_arcs, Color(3.5, 2.2, 0.5, alpha), 4.0)

		draw_set_transform(Vector2(0, -10), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, current_r, 0.0, TAU, 48, Color(2.8, 1.0, 0.15, alpha), 8.5)
		draw_arc(Vector2.ZERO, current_r * 0.92, 0.0, TAU, 48, Color(3.5, 2.8, 0.8, alpha * 0.9), 4.5)
		draw_arc(Vector2.ZERO, current_r * 0.7, 0.0, TAU, 36, Color(1.8, 0.4, 0.05, alpha * 0.4), 14.0)

		if progress < 0.25:
			var flash_alpha = (1.0 - progress / 0.25) * 0.85
			draw_circle(Vector2.ZERO, current_r * 0.8, Color(3.5, 3.5, 3.5, flash_alpha))

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
