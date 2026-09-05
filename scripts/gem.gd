extends Area2D

@export var xp_value: int = 10
var target: Node2D = null
var speed: float = 0.0
var max_speed: float = 550.0
var acceleration: float = 800.0
var bob_offset: float = 0.0
var time_alive: float = 0.0

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
static var gem_tex: ImageTexture = null

func _ready() -> void:
	if not gem_tex:
		gem_tex = SpriteFactory.create_gem_texture()
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
	# Ground shadow (isometric ellipse on floor)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	var shadow_scale = 1.0 - (bob_offset * 0.05)
	draw_circle(Vector2.ZERO, 6.0 * shadow_scale, Color(0.0, 0.0, 0.0, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Hovering Faceted 3D Diamond Crystal
	if gem_tex:
		var draw_pos = Vector2(-12.0, -18.0 + bob_offset)
		draw_texture(gem_tex, draw_pos)
		# Specular refractive core pulse
		var pulse = 0.8 + 0.3 * sin(time_alive * 7.0)
		draw_circle(Vector2(0, -8.0 + bob_offset), 2.0, Color(0.4 * pulse, 2.8 * pulse, 3.8 * pulse, 0.9))
