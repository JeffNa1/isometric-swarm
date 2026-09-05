extends Node2D

const LightHelper = preload("res://scripts/light_helper.gd")

@export var damage: float = 65.0
@export var fire_rate: float = 0.85
@export var beam_length: float = 750.0
@export var beam_width: float = 28.0

var fire_timer: float = 0.0
var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var floating_txt_mgr: Node2D = null
var camera_node: Camera2D = null

var beam_draw_timer: float = 0.0
var beam_start: Vector2 = Vector2.ZERO
var beam_end: Vector2 = Vector2.ZERO

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

func _process(delta: float) -> void:
	if not swarm_mgr:
		_get_managers()

	if beam_draw_timer > 0.0:
		beam_draw_timer -= delta
		if muzzle_light:
			muzzle_light.energy = (beam_draw_timer / 0.15) * 2.5
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

	var player_pos = global_position
	var best_target: Vector2 = Vector2.ZERO
	var min_dist: float = beam_length

	var sample_count = min(swarm_mgr.active_count, 70)
	for i in range(sample_count):
		var ep = swarm_mgr.positions[i]
		var d = player_pos.distance_to(ep)
		if d < min_dist:
			min_dist = d
			best_target = ep

	var fire_dir = Vector2.RIGHT
	if best_target != Vector2.ZERO:
		fire_dir = (best_target - player_pos).normalized()
	else:
		fire_dir = Vector2(1, 0.5).normalized()

	beam_start = Vector2(0, -14)
	beam_end = beam_start + fire_dir * beam_length
	beam_draw_timer = 0.15

	var world_start = global_position + beam_start
	var world_end = global_position + beam_end
	
	# Execute piercing damage
	var hits = swarm_mgr.damage_along_beam(world_start, world_end, beam_width, damage, 260.0)

	# Sound & Screen shake
	if sound_mgr and sound_mgr.has_method("play_laser"):
		sound_mgr.play_laser()
	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.18)

	# Sparks along the beam
	if particle_mgr and hits > 0:
		for s in range(4):
			var spark_p = lerp(world_start, world_end, randf_range(0.1, 0.8))
			particle_mgr.spawn_sparks(spark_p, Color(0.4, 0.9, 1.5, 1.0), 8)

	queue_redraw()

func upgrade_damage(multiplier: float) -> void:
	damage *= multiplier

func upgrade_speed(multiplier: float) -> void:
	fire_rate = max(0.2, fire_rate * multiplier)

func upgrade_beam() -> void:
	beam_width += 10.0
	beam_length += 100.0
	damage += 20.0

func _draw() -> void:
	if beam_draw_timer > 0.0:
		var alpha = clamp(beam_draw_timer / 0.15, 0.0, 1.0)
		# HDR Glowing Beam
		draw_line(beam_start, beam_end, Color(0.1, 0.7, 1.8, 0.4 * alpha), beam_width)
		draw_line(beam_start, beam_end, Color(0.6, 1.1, 2.0, 0.85 * alpha), beam_width * 0.45)
		draw_line(beam_start, beam_end, Color(2.5, 2.5, 2.5, 1.0 * alpha), 3.5)
