extends Node2D

@export var blade_count: int = 2
@export var damage: float = 32.0
@export var rotation_speed: float = 4.2
@export var orbit_radius: float = 85.0
@export var knockback_force: float = 240.0

var current_angle: float = 0.0
var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null

# Blade trail history: Array of Arrays of Vector2
var blade_trails: Array = []
const TRAIL_LENGTH: int = 8

var player_ref: CharacterBody2D = null

func _ready() -> void:
	_get_managers()
	_init_trails()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		swarm_mgr = cur.get_node_or_null("SwarmManager")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		player_ref = cur.get_node_or_null("Entities/Player")

func _init_trails() -> void:
	blade_trails.clear()
	for i in range(blade_count):
		var t_arr: Array[Vector2] = []
		blade_trails.append(t_arr)

var is_evolved: bool = false

func evolve_vortex() -> void:
	is_evolved = true
	blade_count = 6
	damage = 75.0
	orbit_radius = 125.0
	rotation_speed = 7.0
	_init_trails()

func upgrade_blade() -> void:
	blade_count += 1
	damage += 8.0
	orbit_radius += 10.0
	_init_trails()

func upgrade_damage(multiplier: float) -> void:
	damage *= multiplier

func upgrade_speed(multiplier: float) -> void:
	rotation_speed *= multiplier

func _physics_process(delta: float) -> void:
	if not swarm_mgr or not player_ref:
		_get_managers()

	var cd_mult = player_ref.cooldown_reduction if (player_ref and "cooldown_reduction" in player_ref) else 0.0
	var speed_factor = 1.0 + (cd_mult * 0.5)
	current_angle += rotation_speed * speed_factor * delta
	if current_angle > TAU:
		current_angle -= TAU

	# Ensure trail arrays match count
	while blade_trails.size() < blade_count:
		blade_trails.append([])

	var hit_this_frame = false
	var total_dealt = 0.0

	var crit_info = player_ref.roll_crit(damage) if (player_ref and player_ref.has_method("roll_crit")) else {"damage": damage, "is_crit": false}
	var hit_damage = float(crit_info["damage"]) * delta * 4.0

	# 1. Inner contact sweep: Eliminate 94px deadzone for enemies touching player
	if swarm_mgr and swarm_mgr.active_count > 0:
		var inner_hits = swarm_mgr.damage_in_radius(global_position + Vector2(0, -14), 48.0, hit_damage * 0.65, knockback_force * 0.5)
		if inner_hits > 0:
			hit_this_frame = true
			total_dealt += hit_damage * 0.65 * inner_hits

	# 2. Orbital Scythe blades
	for i in range(blade_count):
		var angle_offset = (TAU / float(blade_count)) * float(i)
		var angle = current_angle + angle_offset
		# 2:1 isometric ellipse compression: Y is 0.5 * X, centered at character waist (-14px)
		var blade_pos = Vector2(
			cos(angle) * orbit_radius,
			sin(angle) * orbit_radius * 0.5 - 14.0
		)

		# Record trail
		var trail = blade_trails[i] as Array
		trail.push_front(blade_pos)
		if trail.size() > TRAIL_LENGTH:
			trail.pop_back()

		# Hit-check against swarm
		if swarm_mgr and swarm_mgr.active_count > 0:
			var world_blade = global_position + blade_pos
			var hits = swarm_mgr.damage_in_radius(world_blade, 28.0, hit_damage, knockback_force)
			if hits > 0:
				hit_this_frame = true
				total_dealt += hit_damage * hits
				if particle_mgr and randf() < 0.35:
					particle_mgr.spawn_sparks(world_blade, Color(0.4, 2.5, 3.5, 1.0), 3)

	if total_dealt > 0.0 and player_ref and player_ref.has_method("record_weapon_damage"):
		player_ref.record_weapon_damage("blade", total_dealt)

	if hit_this_frame and sound_mgr and randf() < 0.2:
		sound_mgr.play_scythe_slice()

	queue_redraw()

func _draw() -> void:
	# 1. Subtle Orbit Ring (Isometric Ellipse)
	draw_set_transform(Vector2(0, -14), 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, orbit_radius, 0.0, TAU, 48, Color(0.2, 0.8, 1.2, 0.18), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Draw Motion Blur Trails
	for i in range(blade_count):
		if i >= blade_trails.size():
			continue
		var trail = blade_trails[i] as Array
		if trail.size() >= 2:
			for t_idx in range(trail.size() - 1):
				var p1 = trail[t_idx] as Vector2
				var p2 = trail[t_idx + 1] as Vector2
				var alpha = 1.0 - (float(t_idx) / float(trail.size()))
				draw_line(p1, p2, Color(0.2, 1.8, 2.8, 0.55 * alpha), 4.0 * alpha)

	# 3. Draw Each Energy Scythe / Glaive
	for i in range(blade_count):
		var angle_offset = (TAU / float(blade_count)) * float(i)
		var angle = current_angle + angle_offset
		var blade_pos = Vector2(
			cos(angle) * orbit_radius,
			sin(angle) * orbit_radius * 0.5 - 14.0
		)

		# Ground shadow under blade
		draw_set_transform(Vector2(blade_pos.x, 0), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 7.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Crescent Scythe Blade
		var spin_rot = angle + PI * 0.5
		draw_set_transform(blade_pos, spin_rot, Vector2.ONE)

		var scythe_poly = PackedVector2Array([
			Vector2(0, -16),
			Vector2(10, -8),
			Vector2(14, 0),
			Vector2(8, 6),
			Vector2(0, 8),
			Vector2(5, 0),
			Vector2(4, -8)
		])
		draw_colored_polygon(scythe_poly, Color(0.2, 2.2, 3.2, 0.95))
		# Specular cutting edge
		draw_line(Vector2(0, -16), Vector2(14, 0), Color(3.5, 3.5, 3.5, 1.0), 2.0)
		draw_circle(Vector2(0, 0), 3.5, Color(2.5, 3.0, 3.5, 1.0))

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
