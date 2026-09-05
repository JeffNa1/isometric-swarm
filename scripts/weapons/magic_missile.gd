extends Node2D

const MISSILE_SCENE = preload("res://scenes/weapons/missile_projectile.tscn")

@export var damage: float = 45.0
@export var fire_rate: float = 1.1
@export var missiles_per_volley: int = 2
@export var attack_range: float = 650.0

var fire_timer: float = 0.0
var swarm_mgr: Node2D = null
var sound_mgr: Node = null

func _ready() -> void:
	_get_managers()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		swarm_mgr = cur.get_node_or_null("SwarmManager")
		sound_mgr = cur.get_node_or_null("SoundManager")

func _process(delta: float) -> void:
	if not swarm_mgr:
		_get_managers()

	fire_timer += delta
	if fire_timer >= fire_rate:
		fire_timer = 0.0
		_attempt_fire()

func _attempt_fire() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	var origin_pos = global_position
	# Find candidate targets in swarm
	var targets: Array[Vector2] = []
	var sample_count = min(swarm_mgr.active_count, 60)

	for i in range(sample_count):
		var p = swarm_mgr.positions[i]
		var dist = origin_pos.distance_to(p)
		if dist <= attack_range and dist > 40.0:
			targets.append(p)

	if targets.is_empty():
		return

	# Fire volley
	var shots = min(missiles_per_volley, targets.size())
	for i in range(shots):
		var target_pos = targets[i]
		_spawn_missile(target_pos, i)

	if sound_mgr and sound_mgr.has_method("play_missile_launch"):
		sound_mgr.play_missile_launch()

func _spawn_missile(target_pos: Vector2, volley_idx: int) -> void:
	var projectile = MISSILE_SCENE.instantiate()
	var entities = get_tree().current_scene.get_node_or_null("Entities")
	if not entities:
		entities = get_parent()

	entities.add_child(projectile)
	# Stagger launch positions on shoulders
	var launch_offset = Vector2(-12.0 if volley_idx % 2 == 0 else 12.0, -26.0)
	projectile.global_position = global_position + launch_offset

	var base_dir = (target_pos - projectile.global_position).normalized()
	# Add slight initial spread angle
	var spread_angle = base_dir.angle() + randf_range(-0.35, 0.35)
	var fire_dir = Vector2.from_angle(spread_angle)

	projectile.setup(fire_dir, target_pos, damage)

var is_evolved: bool = false

func evolve_barrage() -> void:
	is_evolved = true
	missiles_per_volley = 6
	damage = 85.0
	fire_rate = 0.55

func upgrade_missile() -> void:
	missiles_per_volley += 1
	damage += 12.0
	fire_rate = max(0.4, fire_rate * 0.85)

func upgrade_damage(multiplier: float) -> void:
	damage *= multiplier

func upgrade_speed(multiplier: float) -> void:
	fire_rate = max(0.3, fire_rate * multiplier)
