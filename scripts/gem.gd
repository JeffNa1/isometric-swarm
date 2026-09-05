extends Area2D

@export var xp_value: int = 10
@export var is_super_gem: bool = false

var target: Node2D = null
var speed: float = 0.0
var max_speed: float = 750.0
var acceleration: float = 1600.0
var bob_offset: float = 0.0
var time_alive: float = 0.0
var swirl_offset: Vector2 = Vector2.ZERO

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
static var gem_tex: ImageTexture = null

static var player_ref: Node2D = null
static var sound_mgr: Node = null
static var particle_mgr: Node2D = null

func _ready() -> void:
	z_as_relative = false
	z_index = 4 # Render strictly above swarm (z=3)
	if not gem_tex:
		gem_tex = SpriteFactory.create_gem_texture()
	collision_layer = 8
	collision_mask = 0
	add_to_group("gems")
	_ensure_managers()
	queue_redraw()

static func _ensure_managers() -> void:
	if not is_instance_valid(player_ref) or not is_instance_valid(sound_mgr) or not is_instance_valid(particle_mgr):
		var tree = Engine.get_main_loop() as SceneTree
		if tree and tree.current_scene:
			var cur = tree.current_scene
			player_ref = cur.get_node_or_null("Entities/Player")
			sound_mgr = cur.get_node_or_null("SoundManager")
			particle_mgr = cur.get_node_or_null("ParticleManager")

func get_tier_info() -> Dictionary:
	if is_super_gem or xp_value >= 80:
		return {
			"scale": 2.0,
			"color": Color(3.8, 2.8, 0.5, 1.0), # Tier 4: Radiant Supernova Gold
			"shadow_size": 11.0,
			"halo_size": 6.0,
			"sound_chest": true
		}
	elif xp_value >= 25:
		return {
			"scale": 1.6,
			"color": Color(2.6, 0.5, 3.8, 1.0), # Tier 3: Radiant Amethyst Violet
			"shadow_size": 9.0,
			"halo_size": 4.6,
			"sound_chest": false
		}
	elif xp_value >= 8:
		return {
			"scale": 1.3,
			"color": Color(0.3, 2.6, 4.0, 1.0), # Tier 2: Electric Sapphire Cyan
			"shadow_size": 7.5,
			"halo_size": 3.4,
			"sound_chest": false
		}
	else:
		return {
			"scale": 1.0,
			"color": Color(0.4, 3.2, 1.2, 1.0), # Tier 1: Radiant Emerald Green
			"shadow_size": 6.0,
			"halo_size": 2.2,
			"sound_chest": false
		}

func _process(delta: float) -> void:
	# If untargeted, check distance to player
	if not target:
		if not is_instance_valid(player_ref):
			_ensure_managers()
			if not is_instance_valid(player_ref):
				return

		var dist_sq = global_position.distance_squared_to(player_ref.global_position)
		var rad = player_ref.get("pickup_radius")
		if rad == null: rad = 48.0
		var rad_sq = rad * rad

		# Off-screen culling for gems: If gem is > 950px away, skip bobbing redraw!
		if dist_sq > 902500.0:
			return

		time_alive += delta
		bob_offset = sin(time_alive * 6.0) * 3.5

		if dist_sq < rad_sq:
			target = player_ref
			speed = 120.0
			var perp = (player_ref.global_position - global_position).orthogonal().normalized()
			swirl_offset = perp * randf_range(-30.0, 30.0)

		queue_redraw()
		return

	# Fly toward target with accelerating curve
	if is_instance_valid(target):
		time_alive += delta
		bob_offset = sin(time_alive * 6.0) * 3.5
		speed = move_toward(speed, max_speed, acceleration * delta)
		swirl_offset = swirl_offset.move_toward(Vector2.ZERO, 160.0 * delta)
		var dir = (target.global_position - global_position).normalized()
		global_position += (dir * speed + swirl_offset) * delta

		if global_position.distance_to(target.global_position) < 28.0:
			if target.has_method("add_xp"):
				target.add_xp(xp_value)
			var tier = get_tier_info()
			if sound_mgr:
				if tier.sound_chest and sound_mgr.has_method("play_chest"):
					sound_mgr.play_chest()
				elif sound_mgr.has_method("play_gem_pickup"):
					sound_mgr.play_gem_pickup()
			if particle_mgr:
				particle_mgr.spawn_sparks(target.global_position + Vector2(0, -18), tier.color, 4 + int(tier.scale * 3))
			queue_free()
			return

		queue_redraw()

func attract_to(new_target: Node2D) -> void:
	if not target:
		target = new_target
		speed = 120.0

func _draw() -> void:
	var tier = get_tier_info()
	var t_scale: float = tier.scale
	var t_col: Color = tier.color

	# Ground shadow (isometric ellipse on floor)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	var shadow_scale = (1.0 - (bob_offset * 0.05)) * t_scale
	draw_circle(Vector2.ZERO, tier.shadow_size * shadow_scale, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Hovering Faceted 3D Diamond Crystal
	if gem_tex:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(t_scale, t_scale))
		draw_texture(gem_tex, Vector2(-12.0, -18.0 + bob_offset), t_col)

		var pulse = 0.8 + 0.3 * sin(time_alive * 7.0)
		var center_glow = Vector2(0, -8.0 + bob_offset)
		draw_circle(center_glow, tier.halo_size, t_col * pulse)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
