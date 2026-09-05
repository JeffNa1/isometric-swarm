extends Node2D

@export var blade_count: int = 1
@export var damage: float = 25.0
@export var rotation_speed: float = 3.5
@export var orbit_radius: float = 75.0
@export var knockback_force: float = 220.0

var current_angle: float = 0.0
var active_blades: Array[Area2D] = []

func _ready() -> void:
	rebuild_blades()

func upgrade_blade() -> void:
	blade_count += 1
	damage += 5.0
	orbit_radius += 8.0
	rebuild_blades()

func upgrade_damage(multiplier: float) -> void:
	damage *= multiplier

func upgrade_speed(multiplier: float) -> void:
	rotation_speed *= multiplier

func rebuild_blades() -> void:
	for b in active_blades:
		if is_instance_valid(b):
			b.queue_free()
	active_blades.clear()

	for i in range(blade_count):
		var blade = Area2D.new()
		blade.name = "Blade_%d" % i
		blade.collision_layer = 0
		blade.collision_mask = 2 # Enemies are layer 2
		blade.monitoring = true
		blade.monitorable = false
		
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 16.0
		col.shape = shape
		blade.add_child(col)
		
		blade.area_entered.connect(_on_blade_hit.bind(blade))
		blade.body_entered.connect(_on_blade_body_hit.bind(blade))
		add_child(blade)
		active_blades.append(blade)

func _physics_process(delta: float) -> void:
	current_angle += rotation_speed * delta
	if current_angle > TAU:
		current_angle -= TAU
		
	for i in range(active_blades.size()):
		var angle_offset = (TAU / float(active_blades.size())) * float(i)
		var angle = current_angle + angle_offset
		# 2:1 isometric ellipse compression: Y is 0.5 * X
		var blade_pos = Vector2(
			cos(angle) * orbit_radius,
			sin(angle) * orbit_radius * 0.5 - 12.0 # -12 to align with character waist
		)
		active_blades[i].position = blade_pos
		
	queue_redraw()

func _on_blade_body_hit(body: Node2D, blade: Area2D) -> void:
	if body.has_method("take_damage"):
		var knock_dir = (body.global_position - global_position).normalized()
		body.take_damage(damage, knock_dir * knockback_force)

func _on_blade_hit(area: Area2D, blade: Area2D) -> void:
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		var knock_dir = (parent.global_position - global_position).normalized()
		parent.take_damage(damage, knock_dir * knockback_force)

func _draw() -> void:
	# Draw orbit indicator trail (subtle isometric ellipse)
	draw_set_transform(Vector2(0, -12), 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, orbit_radius, 0.0, TAU, 36, Color(0.3, 0.7, 1.0, 0.15), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Draw each blade (energy scythe / sword)
	for blade in active_blades:
		if not is_instance_valid(blade):
			continue
		var pos = blade.position
		# Shadow under blade
		draw_set_transform(Vector2(pos.x, 0), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 6.0, Color(0.0, 0.0, 0.0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		
		# Blade glow & polygon
		var blade_pts = PackedVector2Array([
			pos + Vector2(0, -14),
			pos + Vector2(8, 0),
			pos + Vector2(0, 8),
			pos + Vector2(-8, 0)
		])
		draw_circle(pos, 9.0, Color(0.2, 0.8, 1.0, 0.3))
		draw_colored_polygon(blade_pts, Color(0.3, 0.9, 1.0, 0.95))
		draw_circle(pos, 3.5, Color(1.0, 1.0, 1.0, 1.0))
