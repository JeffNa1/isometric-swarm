extends Node2D

@export var damage_per_tick: float = 8.0
@export var tick_interval: float = 0.08
@export var flame_range: float = 240.0
@export var flame_angle: float = 55.0

var tick_timer: float = 0.0
var swarm_mgr: Node2D = null
var current_aim_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	swarm_mgr = get_tree().current_scene.get_node_or_null("SwarmManager")

func _process(delta: float) -> void:
	if not swarm_mgr:
		swarm_mgr = get_tree().current_scene.get_node_or_null("SwarmManager")

	# Aim in direction of player movement or closest enemy
	var parent_body = get_parent().get_parent()
	if parent_body and "velocity" in parent_body and parent_body.velocity.length_squared() > 10.0:
		current_aim_dir = parent_body.velocity.normalized()

	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		_burn_enemies()
		queue_redraw()

func _burn_enemies() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return
	swarm_mgr.damage_in_cone(global_position, current_aim_dir, flame_range, flame_angle, damage_per_tick)

func upgrade_flame() -> void:
	flame_range += 40.0
	flame_angle += 10.0
	damage_per_tick += 3.0

func _draw() -> void:
	# Draw pulsing flame cone particles / polygon
	var half_angle_rad = deg_to_rad(flame_angle * 0.5)
	var dir_angle = current_aim_dir.angle()
	
	var left_vec = Vector2.from_angle(dir_angle - half_angle_rad) * (flame_range * (0.8 + randf() * 0.2))
	var right_vec = Vector2.from_angle(dir_angle + half_angle_rad) * (flame_range * (0.8 + randf() * 0.2))
	var mid_vec = current_aim_dir * (flame_range * (0.9 + randf() * 0.2))

	var origin = Vector2(0, -12)
	var flame_poly = PackedVector2Array([
		origin,
		origin + left_vec,
		origin + mid_vec,
		origin + right_vec
	])

	# Draw outer flame orange & inner core yellow
	draw_colored_polygon(flame_poly, Color(1.0, 0.35, 0.05, 0.25))
	
	var inner_poly = PackedVector2Array([
		origin,
		origin + left_vec * 0.5,
		origin + mid_vec * 0.6,
		origin + right_vec * 0.5
	])
	draw_colored_polygon(inner_poly, Color(1.0, 0.85, 0.1, 0.4))
