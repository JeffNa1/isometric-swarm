extends Node2D

@export var speed: float = 540.0
@export var damage: float = 55.0
@export var blast_radius: float = 80.0
@export var knockback_force: float = 380.0

var direction: Vector2 = Vector2.RIGHT
var target_pos: Vector2 = Vector2.ZERO
var lifetime: float = 2.5
var time_alive: float = 0.0

var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var camera_node: Camera2D = null

var corkscrew_phase: float = 0.0
var corkscrew_freq: float = 16.0
var corkscrew_amp: float = 32.0

func _ready() -> void:
	corkscrew_phase = randf() * TAU
	_get_managers()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		swarm_mgr = cur.get_node_or_null("SwarmManager")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		camera_node = cur.get_node_or_null("Camera2D")

func setup(dir: Vector2, target: Vector2, dmg: float) -> void:
	direction = dir.normalized()
	target_pos = target
	damage = dmg

func _process(delta: float) -> void:
	time_alive += delta
	if time_alive >= lifetime:
		_detonate()
		return

	if not swarm_mgr:
		_get_managers()

	# Steer smoothly toward target position
	if target_pos != Vector2.ZERO:
		var to_target = (target_pos - global_position).normalized()
		direction = direction.lerp(to_target, 7.0 * delta).normalized()

	# Corkscrew spiraling flight path
	var perp = Vector2(-direction.y, direction.x)
	var corkscrew_offset = perp * cos(time_alive * corkscrew_freq + corkscrew_phase) * corkscrew_amp * delta
	
	global_position += (direction * speed * delta) + corkscrew_offset

	# Rocket exhaust & smoke trail
	if particle_mgr and randf() < 0.7:
		var exhaust_p = global_position - direction * 12.0
		particle_mgr.spawn_smoke_trail(exhaust_p, -direction * 40.0, Color(0.7, 0.7, 0.8, 0.45))
		particle_mgr.spawn_sparks(exhaust_p, Color(3.5, 1.8, 0.3, 1.0), 1)

	# Check proximity to target or collision with swarm
	if target_pos != Vector2.ZERO and global_position.distance_to(target_pos) < 28.0:
		_detonate()
		return

	# Fast check against swarm
	if swarm_mgr and swarm_mgr.active_count > 0:
		var nearest_sq = 999999.0
		var sample_cnt = min(swarm_mgr.active_count, 40)
		for i in range(sample_cnt):
			var d_sq = global_position.distance_squared_to(swarm_mgr.positions[i])
			if d_sq < nearest_sq:
				nearest_sq = d_sq
		if nearest_sq < (22.0 * 22.0):
			_detonate()
			return

	queue_redraw()

func _detonate() -> void:
	if swarm_mgr:
		swarm_mgr.damage_in_radius(global_position, blast_radius, damage, knockback_force)

	if sound_mgr and sound_mgr.has_method("play_missile_explode"):
		sound_mgr.play_missile_explode()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.18)

	# Shrapnel and cluster burst
	if particle_mgr:
		particle_mgr.spawn_sparks(global_position, Color(3.5, 2.0, 0.4, 1.0), 14)
		particle_mgr.spawn_blood_burst(global_position, Color(2.5, 1.0, 0.1, 1.0), 8)

	queue_free()

func _draw() -> void:
	var rot = direction.angle()
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)

	# Missile Aerodynamic Chassis
	var body_poly = PackedVector2Array([
		Vector2(12, 0),
		Vector2(4, -3),
		Vector2(-10, -3),
		Vector2(-12, -6),
		Vector2(-12, 6),
		Vector2(-10, 3),
		Vector2(4, 3)
	])
	draw_colored_polygon(body_poly, Color(0.2, 0.25, 0.32, 1.0))

	# Glowing missile nose cone
	draw_circle(Vector2(10, 0), 3.0, Color(3.5, 1.5, 0.2, 1.0))

	# Rocket exhaust flare
	var thrust_len = randf_range(8.0, 15.0)
	var exhaust_poly = PackedVector2Array([
		Vector2(-10, -2.5),
		Vector2(-10 - thrust_len, 0),
		Vector2(-10, 2.5)
	])
	draw_colored_polygon(exhaust_poly, Color(3.5, 2.5, 0.5, 1.0))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
