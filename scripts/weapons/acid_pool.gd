extends Node2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const LightHelper = preload("res://scripts/light_helper.gd")

@export var duration: float = 5.0
@export var damage_per_tick: float = 24.0
@export var radius: float = 55.0
@export var is_evolved: bool = false

var time_alive: float = 0.0
var tick_timer: float = 0.0
var sound_timer: float = 0.0

var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null

static var pool_tex: ImageTexture = null

func _ready() -> void:
	z_as_relative = false
	z_index = 1 # Ground layer: strictly beneath SwarmManager (z_index = 3)
	if not pool_tex:
		pool_tex = SpriteFactory.create_acid_pool_texture()
	_get_managers()
	queue_redraw()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		swarm_mgr = cur.get_node_or_null("SwarmManager")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")

func setup(p_duration: float, p_damage: float, p_radius: float, p_evolved: bool = false) -> void:
	duration = p_duration
	damage_per_tick = p_damage
	radius = p_radius
	is_evolved = p_evolved

func _process(delta: float) -> void:
	if not swarm_mgr:
		_get_managers()

	time_alive += delta
	if time_alive >= duration:
		queue_free()
		return

	# Damage tick every 0.25s
	tick_timer += delta
	if tick_timer >= 0.25:
		tick_timer = 0.0
		if swarm_mgr and swarm_mgr.active_count > 0:
			swarm_mgr.damage_in_radius(global_position, radius, damage_per_tick, 8.0)

	# Sound tick
	sound_timer += delta
	if sound_timer >= 1.1:
		sound_timer = 0.0
		if sound_mgr and sound_mgr.has_method("play_acid"):
			sound_mgr.play_acid()

	# Toxic bubbling vapor particles
	if particle_mgr and randf() < 0.35:
		var off = Vector2(randf_range(-radius * 0.7, radius * 0.7), randf_range(-radius * 0.35, radius * 0.35))
		var spark_col = Color(0.2, 3.2, 0.6, 1.0) if not is_evolved else Color(2.5, 3.5, 0.3, 1.0)
		particle_mgr.spawn_sparks(global_position + off, spark_col, 2)

	queue_redraw()

func _draw() -> void:
	var progress = time_alive / duration
	var alpha = clamp(1.0 - (progress * progress), 0.1, 1.0)
	var pulse = 1.0 + sin(time_alive * 8.0) * 0.06

	# Floor shadow/glow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	var pool_col = Color(0.1, 1.8, 0.4, 0.45 * alpha) if not is_evolved else Color(1.8, 3.2, 0.2, 0.6 * alpha)
	draw_circle(Vector2.ZERO, radius * pulse, pool_col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Draw textured puddle
	if pool_tex:
		var tex_scale = (radius / 24.0) * pulse
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(tex_scale, tex_scale))
		var tex_col = Color(1.0, 1.0, 1.0, alpha)
		draw_texture(pool_tex, Vector2(-24.0, -24.0), tex_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
