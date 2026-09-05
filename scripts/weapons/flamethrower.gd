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

# Dynamic flame puff data for rendering rolling turbulent fireballs
class FlamePuff:
	var offset: Vector2
	var dist_ratio: float
	var size: float
	var color: Color
	var life: float

var active_puffs: Array[FlamePuff] = []

@onready var flame_light: PointLight2D = $FlameLight

func _ready() -> void:
	_get_managers()
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

	# Update existing puffs
	var i = 0
	while i < active_puffs.size():
		active_puffs[i].life -= delta * 3.5
		if active_puffs[i].life <= 0.0:
			active_puffs.remove_at(i)
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

	for p in range(6):
		var puff = FlamePuff.new()
		puff.dist_ratio = randf_range(0.15, 1.0)
		var spread_angle = dir_angle + randf_range(-half_angle_rad, half_angle_rad) * puff.dist_ratio
		var dist = flame_range * puff.dist_ratio
		
		# 2:1 isometric compression
		var stream_vec = Vector2(cos(spread_angle) * dist, sin(spread_angle) * dist * 0.75)
		puff.offset = Vector2(0, -14) + stream_vec
		puff.size = lerp(8.0, 32.0, puff.dist_ratio) * randf_range(0.85, 1.15)
		puff.life = randf_range(0.8, 1.0)

		# Color temperature curve: White-Yellow core -> Orange flame -> Dark smoke
		if puff.dist_ratio < 0.35:
			puff.color = Color(3.5, 2.5, 0.8, 0.85) # Incandescent White-Gold
		elif puff.dist_ratio < 0.7:
			puff.color = Color(2.8, 1.1, 0.1, 0.75) # Fiery Orange
		else:
			puff.color = Color(1.4, 0.25, 0.05, 0.5) # Outer Crimson Embers

		active_puffs.append(puff)

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
	for puff in active_puffs:
		var alpha = clamp(puff.life, 0.0, 1.0)
		var c = puff.color
		c.a *= alpha
		# Outer soft flame halo
		draw_circle(puff.offset, puff.size, Color(c.r * 0.6, c.g * 0.4, c.b * 0.4, c.a * 0.4))
		# Hot flame core
		draw_circle(puff.offset, puff.size * 0.65, c)
		# Ultra-hot center if near base
		if puff.dist_ratio < 0.35:
			draw_circle(puff.offset, puff.size * 0.35, Color(3.5, 3.5, 2.0, c.a))
