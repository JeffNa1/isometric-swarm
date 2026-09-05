extends Node2D

const LightHelper = preload("res://scripts/light_helper.gd")

@export var damage: float = 55.0
@export var fire_rate: float = 0.9
@export var chain_count: int = 4
@export var attack_range: float = 500.0
@export var chain_range: float = 160.0

var fire_timer: float = 0.0
var bolt_timer: float = 0.0
var active_arcs: Array = []

var swarm_mgr: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var camera_node: Camera2D = null

@onready var tesla_light: PointLight2D = $TeslaLight

var is_evolved: bool = false

func _ready() -> void:
	_get_managers()
	if tesla_light:
		tesla_light.texture = LightHelper.get_radial_texture(128)
		tesla_light.energy = 0.0
		tesla_light.texture_scale = 3.5

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

	if bolt_timer > 0.0:
		bolt_timer -= delta
		if tesla_light:
			tesla_light.energy = (bolt_timer / 0.14) * (4.5 if is_evolved else 2.8)
		queue_redraw()
	else:
		if tesla_light and tesla_light.energy > 0.0:
			tesla_light.energy = 0.0
		if not active_arcs.is_empty():
			active_arcs.clear()
			queue_redraw()

	fire_timer += delta
	if fire_timer >= fire_rate:
		fire_timer = 0.0
		_attempt_fire()

func _attempt_fire() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	var origin = global_position
	var sample_limit = min(swarm_mgr.active_count, 80)
	var first_idx: int = -1
	var best_dist: float = attack_range

	for i in range(sample_limit):
		var d = origin.distance_to(swarm_mgr.positions[i])
		if d < best_dist:
			best_dist = d
			first_idx = i

	if first_idx == -1:
		return

	active_arcs.clear()
	bolt_timer = 0.14

	_fire_chain(first_idx)

	if is_evolved and swarm_mgr.active_count > 1:
		var second_idx = -1
		var second_dist = attack_range
		for i in range(sample_limit):
			if i != first_idx:
				var d = origin.distance_to(swarm_mgr.positions[i])
				if d < second_dist:
					second_dist = d
					second_idx = i
		if second_idx != -1:
			_fire_chain(second_idx)

	if sound_mgr and sound_mgr.has_method("play_tesla"):
		sound_mgr.play_tesla()

	if is_evolved and camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.18)

	queue_redraw()

func _fire_chain(start_idx: int) -> void:
	var hit_indices: Dictionary = {}
	var chain_points: Array[Vector2] = [Vector2(0, -18)]

	var current_idx = start_idx
	var current_world_pos = swarm_mgr.positions[current_idx]
	hit_indices[current_idx] = true

	swarm_mgr._apply_damage_to_index(current_idx, damage, Vector2.ZERO, is_evolved)
	chain_points.append(to_local(current_world_pos))

	if particle_mgr:
		var spark_col = Color(1.2, 2.5, 4.0, 1.0) if not is_evolved else Color(3.5, 2.8, 0.5, 1.0)
		particle_mgr.spawn_sparks(current_world_pos, spark_col, 5)

	for step in range(chain_count - 1):
		if not is_instance_valid(swarm_mgr) or swarm_mgr.active_count == 0:
			break

		var neighbors = swarm_mgr.spatial_grid.get_nearby(current_world_pos, chain_range)
		var next_idx: int = -1
		var next_dist: float = chain_range

		for n_idx in neighbors:
			if n_idx < swarm_mgr.active_count and not hit_indices.has(n_idx):
				var d = current_world_pos.distance_to(swarm_mgr.positions[n_idx])
				if d < next_dist:
					next_dist = d
					next_idx = n_idx

		if next_idx == -1:
			break

		current_idx = next_idx
		current_world_pos = swarm_mgr.positions[current_idx]
		hit_indices[current_idx] = true

		var chain_falloff = 1.0 - (float(step) * 0.08)
		swarm_mgr._apply_damage_to_index(current_idx, damage * chain_falloff, Vector2.ZERO, false)
		chain_points.append(to_local(current_world_pos))

		if particle_mgr:
			var spark_col = Color(0.4, 2.2, 3.8, 1.0) if not is_evolved else Color(3.0, 2.5, 0.4, 1.0)
			particle_mgr.spawn_sparks(current_world_pos, spark_col, 4)

	var jagged_arc: PackedVector2Array = PackedVector2Array()
	for p_i in range(chain_points.size() - 1):
		var p_start = chain_points[p_i]
		var p_end = chain_points[p_i + 1]
		var seg_len = p_start.distance_to(p_end)
		var seg_count = max(int(seg_len / 22.0), 2)
		var dir = (p_end - p_start).normalized()
		var perp = Vector2(-dir.y, dir.x)

		jagged_arc.append(p_start)
		for s in range(1, seg_count):
			var base_p = p_start.lerp(p_end, float(s) / float(seg_count))
			var offset = perp * randf_range(-14.0, 14.0)
			jagged_arc.append(base_p + offset)
		jagged_arc.append(p_end)

	active_arcs.append(jagged_arc)

func _draw() -> void:
	if active_arcs.is_empty():
		return

	for arc in active_arcs:
		var pts = arc as PackedVector2Array
		if pts.size() < 2:
			continue

		var glow_col = Color(0.2, 0.7, 1.5, 0.35) if not is_evolved else Color(1.5, 1.0, 0.2, 0.4)
		var core_col = Color(1.8, 3.0, 4.0, 1.0) if not is_evolved else Color(3.8, 3.5, 1.8, 1.0)

		draw_polyline(pts, glow_col, 5.0, true)
		draw_polyline(pts, core_col, 1.8, true)

func evolve_mjolnir() -> void:
	is_evolved = true
	damage = 110.0
	fire_rate = 0.38
	chain_count = 8
	chain_range = 220.0
	attack_range = 650.0
	if tesla_light:
		tesla_light.color = Color(2.5, 2.0, 0.4, 1.0)

func upgrade_tesla() -> void:
	chain_count += 1
	damage += 14.0
	fire_rate = max(0.32, fire_rate * 0.88)
	attack_range += 30.0

func upgrade_damage(multiplier: float) -> void:
	damage *= multiplier

func upgrade_speed(multiplier: float) -> void:
	fire_rate = max(0.25, fire_rate * multiplier)
