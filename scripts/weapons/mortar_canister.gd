extends Node2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const ACID_POOL_SCENE = preload("res://scenes/weapons/acid_pool.tscn")

var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var flight_duration: float = 0.65
var arc_height: float = 140.0
var elapsed_flight: float = 0.0

var impact_damage: float = 65.0
var pool_duration: float = 5.0
var pool_tick_damage: float = 24.0
var pool_radius: float = 55.0
var is_evolved: bool = false

var rotation_speed: float = 12.0
var current_rotation: float = 0.0

var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var camera_node: Camera2D = null

static var canister_tex: ImageTexture = null

func _ready() -> void:
	if not canister_tex:
		canister_tex = SpriteFactory.create_mortar_canister_texture()
	_get_managers()
	queue_redraw()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		swarm_mgr = cur.get_node_or_null("SwarmManager")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		camera_node = cur.get_node_or_null("Camera2D")

func setup(p_start: Vector2, p_target: Vector2, p_dmg: float, p_pool_dmg: float, p_radius: float, p_evolved: bool = false) -> void:
	start_pos = p_start
	target_pos = p_target
	impact_damage = p_dmg
	pool_tick_damage = p_pool_dmg
	pool_radius = p_radius
	is_evolved = p_evolved
	if is_evolved:
		arc_height = 180.0
		flight_duration = 0.75
		pool_duration = 8.0
	global_position = start_pos

func _process(delta: float) -> void:
	elapsed_flight += delta
	var t = clamp(elapsed_flight / flight_duration, 0.0, 1.0)

	# Parabolic trajectory
	var ground_pos = start_pos.lerp(target_pos, t)
	var height_offset = sin(t * PI) * arc_height
	global_position = Vector2(ground_pos.x, ground_pos.y - height_offset)

	current_rotation += rotation_speed * delta

	# Trail particles
	if particle_mgr and randf() < 0.5:
		var trail_col = Color(0.2, 3.2, 0.6, 1.0) if not is_evolved else Color(3.5, 3.2, 0.2, 1.0)
		particle_mgr.spawn_sparks(global_position, trail_col, 2)

	if t >= 1.0:
		_on_impact()

	queue_redraw()

func _on_impact() -> void:
	if not swarm_mgr:
		_get_managers()

	# Impact damage
	if swarm_mgr and swarm_mgr.active_count > 0:
		swarm_mgr.damage_in_radius(target_pos, 70.0, impact_damage, 220.0)

	# Sound & Screen Shake
	if sound_mgr and sound_mgr.has_method("play_mortar"):
		sound_mgr.play_mortar()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.25 if not is_evolved else 0.4)

	# Toxic explosion debris
	if particle_mgr:
		var burst_col = Color(0.3, 3.5, 0.8, 1.0) if not is_evolved else Color(3.5, 3.0, 0.2, 1.0)
		particle_mgr.spawn_sparks(target_pos, burst_col, 16)

	# Spawn persistent Acid Pool
	var pool = ACID_POOL_SCENE.instantiate()
	var entities = get_tree().current_scene.get_node_or_null("Entities")
	if not entities:
		entities = get_parent()
	entities.add_child(pool)
	pool.global_position = target_pos
	pool.setup(pool_duration, pool_tick_damage, pool_radius, is_evolved)

	queue_free()

func _draw() -> void:
	# Ground shadow underneath canister
	var t = clamp(elapsed_flight / flight_duration, 0.0, 1.0)
	var ground_pos = start_pos.lerp(target_pos, t)
	var shadow_local = to_local(ground_pos)
	draw_set_transform(shadow_local, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 6.0 * (1.0 - sin(t * PI) * 0.4), Color(0.0, 0.0, 0.0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Canister texture
	if canister_tex:
		var draw_scale = Vector2.ONE * (1.3 if is_evolved else 1.0)
		draw_set_transform(Vector2.ZERO, current_rotation, draw_scale)
		draw_texture(canister_tex, Vector2(-8.0, -8.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
