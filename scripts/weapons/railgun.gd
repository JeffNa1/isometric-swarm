extends Node2D

@export var damage: float = 65.0
@export var fire_rate: float = 0.85
@export var beam_length: float = 750.0
@export var beam_width: float = 28.0

var fire_timer: float = 0.0
var swarm_mgr: Node2D = null
var beam_draw_timer: float = 0.0
var beam_start: Vector2 = Vector2.ZERO
var beam_end: Vector2 = Vector2.ZERO

func _ready() -> void:
	swarm_mgr = get_tree().current_scene.get_node_or_null("SwarmManager")

func _process(delta: float) -> void:
	if not swarm_mgr:
		swarm_mgr = get_tree().current_scene.get_node_or_null("SwarmManager")
		
	if beam_draw_timer > 0.0:
		beam_draw_timer -= delta
		queue_redraw()

	fire_timer += delta
	if fire_timer >= fire_rate:
		fire_timer = 0.0
		_fire_piercing_beam()

func _fire_piercing_beam() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	# Target direction: towards closest enemy or densest cluster
	var player_pos = global_position
	var best_target: Vector2 = Vector2.ZERO
	var min_dist: float = beam_length

	# Sample first 60 enemies to find a good line of fire
	var sample_count = min(swarm_mgr.active_count, 60)
	for i in range(sample_count):
		var ep = swarm_mgr.positions[i]
		var d = player_pos.distance_to(ep)
		if d < min_dist:
			min_dist = d
			best_target = ep

	var fire_dir = Vector2.RIGHT
	if best_target != Vector2.ZERO:
		fire_dir = (best_target - player_pos).normalized()
	else:
		fire_dir = Vector2(1, 0.5).normalized() # isometric default

	beam_start = Vector2(0, -14)
	beam_end = beam_start + fire_dir * beam_length
	beam_draw_timer = 0.15

	# Execute spatial piercing damage through the horde
	var world_start = global_position + beam_start
	var world_end = global_position + beam_end
	swarm_mgr.damage_along_beam(world_start, world_end, beam_width, damage, 260.0)
	queue_redraw()

func upgrade_damage(multiplier: float) -> void:
	damage *= multiplier

func upgrade_speed(multiplier: float) -> void:
	fire_rate = max(0.2, fire_rate * multiplier)

func upgrade_beam() -> void:
	beam_width += 10.0
	beam_length += 100.0
	damage += 20.0

func _draw() -> void:
	if beam_draw_timer > 0.0:
		var alpha = clamp(beam_draw_timer / 0.15, 0.0, 1.0)
		# Outer beam glow
		draw_line(beam_start, beam_end, Color(0.2, 0.8, 1.0, 0.4 * alpha), beam_width)
		# Inner core beam
		draw_line(beam_start, beam_end, Color(0.7, 0.95, 1.0, 0.85 * alpha), beam_width * 0.45)
		# White hot center
		draw_line(beam_start, beam_end, Color(1.0, 1.0, 1.0, 1.0 * alpha), 3.0)
