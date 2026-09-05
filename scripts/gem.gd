extends Area2D

@export var xp_value: int = 10
@export var is_super_gem: bool = false

var target: Node2D = null
var speed: float = 0.0
var max_speed: float = 1350.0
var acceleration: float = 2400.0
var bob_offset: float = 0.0
var time_alive: float = 0.0
var swirl_offset: Vector2 = Vector2.ZERO

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
static var gem_tex: ImageTexture = null

func _ready() -> void:
	if not gem_tex:
		gem_tex = SpriteFactory.create_gem_texture()
	collision_layer = 8
	collision_mask = 0
	add_to_group("gems")
	queue_redraw()

func _process(delta: float) -> void:
	time_alive += delta
	bob_offset = sin(time_alive * 6.0) * 3.5

	# Magnetic check if untargeted
	if not target:
		var cur = get_tree().current_scene
		if cur:
			var player = cur.get_node_or_null("Entities/Player")
			if player and is_instance_valid(player):
				var rad = player.get("pickup_radius")
				if rad == null: rad = 140.0
				if global_position.distance_to(player.global_position) < rad:
					target = player
					speed = 180.0
					var perp = (player.global_position - global_position).orthogonal().normalized()
					swirl_offset = perp * randf_range(-40.0, 40.0)

	# Fly toward target with accelerating curve
	if target and is_instance_valid(target):
		speed = move_toward(speed, max_speed, acceleration * delta)
		swirl_offset = swirl_offset.move_toward(Vector2.ZERO, 160.0 * delta)
		var dir = (target.global_position - global_position).normalized()
		global_position += (dir * speed + swirl_offset) * delta

		if global_position.distance_to(target.global_position) < 28.0:
			if target.has_method("add_xp"):
				target.add_xp(xp_value)
			var cur = get_tree().current_scene
			if cur:
				var snd = cur.get_node_or_null("SoundManager")
				if snd:
					if is_super_gem and snd.has_method("play_chest"):
						snd.play_chest()
					elif snd.has_method("play_gem_pickup"):
						snd.play_gem_pickup()
				var pm = cur.get_node_or_null("ParticleManager")
				if pm:
					var p_col = Color(3.5, 2.5, 0.5, 1.0) if is_super_gem else Color(0.4, 3.2, 1.2, 1.0)
					pm.spawn_sparks(target.global_position + Vector2(0, -18), p_col, 4)
			queue_free()

	queue_redraw()

func attract_to(new_target: Node2D) -> void:
	if not target:
		target = new_target
		speed = 140.0

func _draw() -> void:
	# Ground shadow (isometric ellipse on floor)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	var shadow_scale = 1.0 - (bob_offset * 0.05)
	var shadow_size = 8.5 if is_super_gem else 6.0
	draw_circle(Vector2.ZERO, shadow_size * shadow_scale, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Hovering Faceted 3D Diamond Crystal
	if gem_tex:
		var draw_pos = Vector2(-12.0, -18.0 + bob_offset)
		if is_super_gem:
			# Super Gem: Golden halo & larger scale
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.4, 1.4))
			draw_texture(gem_tex, draw_pos, Color(2.0, 1.5, 0.3, 1.0))
			draw_circle(Vector2(0, -8.0 + bob_offset), 4.5, Color(3.5, 2.5, 0.5, 0.85))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture(gem_tex, draw_pos)
			var pulse = 0.8 + 0.3 * sin(time_alive * 7.0)
			draw_circle(Vector2(0, -8.0 + bob_offset), 2.2, Color(0.4 * pulse, 3.2 * pulse, 1.2 * pulse, 0.95))
