extends Area2D

@export var xp_value: int = 10
var target: Node2D = null
var speed: float = 0.0
var max_speed: float = 550.0
var acceleration: float = 800.0
var bob_offset: float = 0.0
var time_alive: float = 0.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	queue_redraw()

func _process(delta: float) -> void:
	time_alive += delta
	bob_offset = sin(time_alive * 6.0) * 3.0
	
	if target and is_instance_valid(target):
		speed = move_toward(speed, max_speed, acceleration * delta)
		var dir = (target.global_position - global_position).normalized()
		global_position += dir * speed * delta
		
		if global_position.distance_to(target.global_position) < 18.0:
			if target.has_method("add_xp"):
				target.add_xp(xp_value)
			queue_free()
	
	queue_redraw()

func attract_to(new_target: Node2D) -> void:
	if not target:
		target = new_target
		speed = 100.0

func _draw() -> void:
	# Ground shadow (isometric ellipse)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 5.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Floating gem (cyan diamond)
	var gem_pos = Vector2(0.0, -10.0 + bob_offset)
	var points = PackedVector2Array([
		gem_pos + Vector2(0, -6),
		gem_pos + Vector2(5, 0),
		gem_pos + Vector2(0, 6),
		gem_pos + Vector2(-5, 0)
	])
	
	var gem_color = Color(0.1, 0.9, 1.0, 0.9)
	var inner_color = Color(0.8, 1.0, 1.0, 1.0)
	draw_colored_polygon(points, gem_color)
	draw_circle(gem_pos, 2.0, inner_color)
