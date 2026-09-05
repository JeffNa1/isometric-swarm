extends Node2D

const LightHelper = preload("res://scripts/light_helper.gd")

@export var damage: float = 85.0
@export var cooldown: float = 2.0
@export var blast_radius: float = 240.0
@export var knockback: float = 460.0

var blast_timer: float = 0.0
var anim_timer: float = 0.0
var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var camera_node: Camera2D = null

# Lightning arc jagged points around the blast ring
var arc_ring_points: PackedVector2Array = PackedVector2Array()

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

func _process(delta: float) -> void:
	if not swarm_mgr:
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

	blast_timer += delta
	if blast_timer >= cooldown:
		blast_timer = 0.0
		_trigger_blast()

func _trigger_blast() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	anim_timer = 0.35
	_generate_arc_ring()

	var hits = swarm_mgr.damage_in_radius(global_position, blast_radius, damage, knockback)

	if sound_mgr and sound_mgr.has_method("play_shockwave"):
		sound_mgr.play_shockwave()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.48)

	# Radial debris & electrical sparks
	if particle_mgr:
		particle_mgr.spawn_shockwave_debris(global_position, blast_radius * 0.45, 22)
		if hits > 0:
			for s in range(8):
				var a = randf() * TAU
				var p = global_position + Vector2(cos(a) * (blast_radius * 0.7), sin(a) * (blast_radius * 0.35))
				particle_mgr.spawn_sparks(p, Color(2.5, 1.8, 0.4, 1.0), 8)

	queue_redraw()

func _generate_arc_ring() -> void:
	arc_ring_points.clear()
	var segments = 36
	for i in range(segments + 1):
		var a = (TAU / float(segments)) * float(i)
		var jitter = randf_range(0.92, 1.08)
		# 2:1 isometric ellipse with jagged offsets
		var p = Vector2(cos(a) * jitter, sin(a) * 0.5 * jitter)
		arc_ring_points.append(p)

var is_evolved: bool = false

func evolve_supernova() -> void:
	is_evolved = true
	blast_radius = 380.0
	damage = 260.0
	cooldown = 1.35
	knockback = 650.0

func upgrade_blast() -> void:
	blast_radius += 40.0
	damage += 25.0
	cooldown = max(1.1, cooldown * 0.85)

func _draw() -> void:
	if anim_timer <= 0.0:
		return

	var progress = 1.0 - (anim_timer / 0.35)
	var current_r = blast_radius * (sqrt(progress))
	var alpha = (1.0 - progress) * 0.95

	# Draw with isometric compression at player feet
	draw_set_transform(Vector2(0, -10), 0.0, Vector2.ONE)

	# 1. Outer Jagged Lightning Arc Ring
	if arc_ring_points.size() > 1:
		var scaled_arcs = PackedVector2Array()
		for pt in arc_ring_points:
			scaled_arcs.append(pt * current_r)
		draw_polyline(scaled_arcs, Color(3.5, 2.2, 0.5, alpha), 4.0)

	# 2. Primary Expanding Pressure Wave Ring (2:1 isometric ellipse)
	draw_set_transform(Vector2(0, -10), 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, current_r, 0.0, TAU, 48, Color(2.8, 1.0, 0.15, alpha), 8.5)
	draw_arc(Vector2.ZERO, current_r * 0.92, 0.0, TAU, 48, Color(3.5, 2.8, 0.8, alpha * 0.9), 4.5)
	draw_arc(Vector2.ZERO, current_r * 0.7, 0.0, TAU, 36, Color(1.8, 0.4, 0.05, alpha * 0.4), 14.0)

	# 3. Blinding White-Hot Flash at onset (progress < 0.25)
	if progress < 0.25:
		var flash_alpha = (1.0 - progress / 0.25) * 0.85
		draw_circle(Vector2.ZERO, current_r * 0.8, Color(3.5, 3.5, 3.5, flash_alpha))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
