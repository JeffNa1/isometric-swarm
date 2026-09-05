extends Node2D

const LightHelper = preload("res://scripts/light_helper.gd")

@export var damage: float = 80.0
@export var cooldown: float = 2.2
@export var blast_radius: float = 220.0
@export var knockback: float = 400.0

var blast_timer: float = 0.0
var anim_timer: float = 0.0
var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var camera_node: Camera2D = null

@onready var blast_light: PointLight2D = $BlastLight

func _ready() -> void:
	_get_managers()
	if blast_light:
		blast_light.texture = LightHelper.get_radial_texture(128)
		blast_light.energy = 0.0

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		swarm_mgr = cur.get_node_or_null("SwarmManager")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		camera_node = cur.get_node_or_null("Camera2D")

func _process(delta: float) -> void:
	if not swarm_mgr:
		_get_managers()

	if anim_timer > 0.0:
		anim_timer -= delta
		if blast_light:
			blast_light.energy = (anim_timer / 0.28) * 3.5
		queue_redraw()
	else:
		if blast_light and blast_light.energy > 0.0:
			blast_light.energy = 0.0

	blast_timer += delta
	if blast_timer >= cooldown:
		blast_timer = 0.0
		_trigger_blast()

func _trigger_blast() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	anim_timer = 0.28
	var hits = swarm_mgr.damage_in_radius(global_position, blast_radius, damage, knockback)

	if sound_mgr and sound_mgr.has_method("play_shockwave"):
		sound_mgr.play_shockwave()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.42)

	if particle_mgr and hits > 0:
		for s in range(12):
			var a = randf() * TAU
			var p = global_position + Vector2(cos(a) * (blast_radius * 0.75), sin(a) * (blast_radius * 0.38))
			particle_mgr.spawn_sparks(p, Color(1.8, 1.2, 0.2, 1.0), 6)

	queue_redraw()

func upgrade_blast() -> void:
	blast_radius += 45.0
	damage += 25.0
	cooldown = max(1.0, cooldown * 0.85)

func _draw() -> void:
	if anim_timer > 0.0:
		var progress = 1.0 - (anim_timer / 0.28)
		var current_r = blast_radius * progress
		var alpha = (1.0 - progress) * 0.85
		
		# HDR Glowing Isometric shockwave rings
		draw_set_transform(Vector2(0, -10), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, current_r, 0.0, TAU, 48, Color(2.5, 0.8, 0.2, alpha), 8.0)
		draw_arc(Vector2.ZERO, current_r * 0.88, 0.0, TAU, 48, Color(3.0, 2.0, 0.5, alpha * 0.9), 4.5)
		draw_arc(Vector2.ZERO, current_r * 0.65, 0.0, TAU, 36, Color(1.5, 0.3, 0.05, alpha * 0.5), 12.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
