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
var player_ref: CharacterBody2D = null

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
		player_ref = cur.get_node_or_null("Entities/Player")

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
	if particle_mgr:
		var exhaust_p = global_position - direction * 12.0
		if randf() < 0.65:
			particle_mgr.spawn_smoke_trail(exhaust_p, -direction * 40.0, Color(0.7, 0.7, 0.8, 0.45))
			particle_mgr.spawn_sparks(exhaust_p, Color(3.5, 1.8, 0.3, 1.0), 1)
		if randf() < 0.35 and particle_mgr.has_method("spawn_plasma_ember"):
			particle_mgr.spawn_plasma_ember(exhaust_p, Color(3.5, 1.8, 0.3, 1.0), 1)

	# Check proximity to target
	if target_pos != Vector2.ZERO and global_position.distance_to(target_pos) < 28.0:
		_detonate()
		return

	# Fast O(1) collision check against any nearby swarm enemy
	if swarm_mgr and swarm_mgr.active_count > 0:
		var nearby = swarm_mgr.spatial_grid.get_nearby(global_position, 28.0)
		for idx in nearby:
			if idx < swarm_mgr.active_count:
				if global_position.distance_squared_to(swarm_mgr.positions[idx]) <= (24.0 * 24.0):
					_detonate()
					return

	queue_redraw()

func _detonate() -> void:
	if swarm_mgr:
		var hits = swarm_mgr.damage_in_radius(global_position, blast_radius, damage, knockback_force)
		if hits > 0 and player_ref and player_ref.has_method("record_weapon_damage"):
			player_ref.record_weapon_damage("missile", damage * hits)

	if sound_mgr and sound_mgr.has_method("play_missile_explode"):
		sound_mgr.play_missile_explode()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.24)

	if particle_mgr:
		particle_mgr.spawn_sparks(global_position, Color(3.5, 2.0, 0.4, 1.0), 14)
		particle_mgr.spawn_blood_burst(global_position, Color(2.5, 1.0, 0.1, 1.0), 8)
		if particle_mgr.has_method("spawn_shockwave_debris"):
			particle_mgr.spawn_shockwave_debris(global_position, 35.0, 6)
		if particle_mgr.has_method("spawn_scorch_mark"):
			particle_mgr.spawn_scorch_mark(global_position, Color(1.8, 0.9, 0.2, 0.8))

	queue_free()

func _draw() -> void:
	# Rocket body: slender supersonic missile
	var rot = direction.angle()
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)

	# Main fuselage
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color(0.85, 0.9, 0.95, 1.0), 4.0)
	# Warhead
	draw_circle(Vector2(10, 0), 2.5, Color(3.5, 1.2, 0.2, 1.0))
	# Stabilizer fins
	draw_line(Vector2(-8, -5), Vector2(-4, 0), Color(0.3, 0.4, 0.6, 1.0), 2.0)
	draw_line(Vector2(-8, 5), Vector2(-4, 0), Color(0.3, 0.4, 0.6, 1.0), 2.0)
	# Glowing rocket engine nozzle
	draw_circle(Vector2(-10, 0), 3.0, Color(3.5, 2.5, 0.5, 1.0))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
