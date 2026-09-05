extends Node2D

const LightHelper = preload("res://scripts/light_helper.gd")

@export var damage_per_tick: float = 8.0
@export var tick_interval: float = 0.08
@export var flame_range: float = 240.0
@export var flame_angle: float = 55.0

var tick_timer: float = 0.0
var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var current_aim_dir: Vector2 = Vector2.RIGHT

@onready var flame_light: PointLight2D = $FlameLight

func _ready() -> void:
	_get_managers()
	if flame_light:
		flame_light.texture = LightHelper.get_radial_texture(128)
		flame_light.energy = 0.9

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

	if flame_light:
		flame_light.position = Vector2(0, -12) + current_aim_dir * (flame_range * 0.45)
		flame_light.energy = randf_range(0.8, 1.3) # flickering flame light

	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		_burn_enemies()
		queue_redraw()

func _burn_enemies() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	var hits = swarm_mgr.damage_in_cone(global_position, current_aim_dir, flame_range, flame_angle, damage_per_tick)

	if sound_mgr and randf() < 0.35: # throttle audio trigger for natural roaring sound
		sound_mgr.play_flame()

	if particle_mgr and hits > 0:
		var ember_p = global_position + current_aim_dir * randf_range(40.0, flame_range * 0.8)
		particle_mgr.spawn_sparks(ember_p, Color(1.5, 0.7, 0.1, 1.0), 3)

func upgrade_flame() -> void:
	flame_range += 40.0
	flame_angle += 10.0
	damage_per_tick += 3.0

func _draw() -> void:
	var half_angle_rad = deg_to_rad(flame_angle * 0.5)
	var dir_angle = current_aim_dir.angle()
	
	var left_vec = Vector2.from_angle(dir_angle - half_angle_rad) * (flame_range * (0.8 + randf() * 0.2))
	var right_vec = Vector2.from_angle(dir_angle + half_angle_rad) * (flame_range * (0.8 + randf() * 0.2))
	var mid_vec = current_aim_dir * (flame_range * (0.9 + randf() * 0.2))

	var origin = Vector2(0, -12)
	var flame_poly = PackedVector2Array([
		origin, origin + left_vec, origin + mid_vec, origin + right_vec
	])

	# HDR Outer Flame (Glows!)
	draw_colored_polygon(flame_poly, Color(1.5, 0.4, 0.05, 0.3))
	
	# HDR Inner Core
	var inner_poly = PackedVector2Array([
		origin, origin + left_vec * 0.5, origin + mid_vec * 0.6, origin + right_vec * 0.5
	])
	draw_colored_polygon(inner_poly, Color(2.0, 1.6, 0.2, 0.55))
