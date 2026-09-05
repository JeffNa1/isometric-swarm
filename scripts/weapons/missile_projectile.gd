extends Area2D

@export var speed: float = 450.0
@export var damage: float = 35.0
@export var knockback_force: float = 180.0

var direction: Vector2 = Vector2.RIGHT
var target_enemy: Node2D = null
var lifetime: float = 3.0
var time_alive: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Enemy layer
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	queue_redraw()

func setup(dir: Vector2, target: Node2D, dmg: float) -> void:
	direction = dir.normalized()
	target_enemy = target
	damage = dmg

func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
		return
		
	# Subtle homing towards target if alive
	if target_enemy and is_instance_valid(target_enemy):
		var to_target = (target_enemy.global_position - global_position).normalized()
		direction = direction.lerp(to_target, 6.0 * delta).normalized()
		
	global_position += direction * speed * delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, direction * knockback_force)
		set_deferred("monitoring", false)
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		parent.take_damage(damage, direction * knockback_force)
		set_deferred("monitoring", false)
		queue_free()

func _draw() -> void:
	# Ground shadow
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 4.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Missile energy orb
	draw_circle(Vector2.ZERO, 7.0, Color(0.9, 0.3, 1.0, 0.4))
	draw_circle(Vector2.ZERO, 4.5, Color(1.0, 0.5, 0.9, 0.9))
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 1.0, 1.0, 1.0))
	
	# Trail line behind
	draw_line(Vector2.ZERO, -direction * 14.0, Color(0.8, 0.2, 1.0, 0.5), 2.5)
