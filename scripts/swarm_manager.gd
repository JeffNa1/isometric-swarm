extends Node2D

const MAX_SWARM: int = 5000
const SPATIAL_CELL_SIZE: float = 90.0

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const SpatialGridClass = preload("res://scripts/spatial_grid.gd")

@onready var crawler_mmi: MultiMeshInstance2D = $CrawlerMM
@onready var scout_mmi: MultiMeshInstance2D = $ScoutMM
@onready var brute_mmi: MultiMeshInstance2D = $BruteMM

var spatial_grid = SpatialGridClass.new(SPATIAL_CELL_SIZE)

var active_count: int = 0

# Swarm data arrays
var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var healths: PackedFloat32Array = PackedFloat32Array()
var max_healths: PackedFloat32Array = PackedFloat32Array()
var types: PackedInt32Array = PackedInt32Array() # 0: Crawler, 1: Scout, 2: Brute
var hit_timers: PackedFloat32Array = PackedFloat32Array()
var radii: PackedFloat32Array = PackedFloat32Array()
var speeds: PackedFloat32Array = PackedFloat32Array()
var damages: PackedFloat32Array = PackedFloat32Array()

var player_ref: Node2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var floating_txt_mgr: Node2D = null
var player_radius: float = 14.0
var elapsed_time: float = 0.0

signal enemy_killed(xp_val: int, pos: Vector2, is_boss: bool)
signal swarm_count_changed(count: int)

func _ready() -> void:
	_init_multimeshes()
	_allocate_arrays()
	_get_managers()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		player_ref = cur.get_node_or_null("Entities/Player")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		floating_txt_mgr = cur.get_node_or_null("FloatingTextManager")

func _allocate_arrays() -> void:
	positions.resize(MAX_SWARM)
	velocities.resize(MAX_SWARM)
	healths.resize(MAX_SWARM)
	max_healths.resize(MAX_SWARM)
	types.resize(MAX_SWARM)
	hit_timers.resize(MAX_SWARM)
	radii.resize(MAX_SWARM)
	speeds.resize(MAX_SWARM)
	damages.resize(MAX_SWARM)

func _init_multimeshes() -> void:
	# 1. Crimson Chitin Crawler MultiMesh (48x48)
	var mm_crawler = MultiMesh.new()
	mm_crawler.transform_format = MultiMesh.TRANSFORM_2D
	mm_crawler.use_colors = true
	mm_crawler.instance_count = MAX_SWARM
	mm_crawler.visible_instance_count = 0
	var quad_crawler = QuadMesh.new()
	quad_crawler.size = Vector2(48.0, 48.0)
	mm_crawler.mesh = quad_crawler
	crawler_mmi.multimesh = mm_crawler
	crawler_mmi.texture = SpriteFactory.create_crawler_texture()
	crawler_mmi.material = CanvasItemMaterial.new()

	# 2. Electric Violet Scout MultiMesh (40x40)
	var mm_scout = MultiMesh.new()
	mm_scout.transform_format = MultiMesh.TRANSFORM_2D
	mm_scout.use_colors = true
	mm_scout.instance_count = MAX_SWARM
	mm_scout.visible_instance_count = 0
	var quad_scout = QuadMesh.new()
	quad_scout.size = Vector2(40.0, 40.0)
	mm_scout.mesh = quad_scout
	scout_mmi.multimesh = mm_scout
	scout_mmi.texture = SpriteFactory.create_scout_texture()
	scout_mmi.material = CanvasItemMaterial.new()

	# 3. Volcanic Magma Behemoth MultiMesh (72x72)
	var mm_brute = MultiMesh.new()
	mm_brute.transform_format = MultiMesh.TRANSFORM_2D
	mm_brute.use_colors = true
	mm_brute.instance_count = MAX_SWARM
	mm_brute.visible_instance_count = 0
	var quad_brute = QuadMesh.new()
	quad_brute.size = Vector2(72.0, 72.0)
	mm_brute.mesh = quad_brute
	brute_mmi.multimesh = mm_brute
	brute_mmi.texture = SpriteFactory.create_brute_texture()
	brute_mmi.material = CanvasItemMaterial.new()

func spawn_enemy(spawn_pos: Vector2, enemy_type: int) -> bool:
	if active_count >= MAX_SWARM:
		return false

	var idx = active_count
	positions[idx] = spawn_pos
	velocities[idx] = Vector2.ZERO
	hit_timers[idx] = 0.0
	types[idx] = enemy_type

	# Exponential Time-based Scaling Curves
	var hp_mult = 1.0 + pow(elapsed_time / 60.0, 1.45) * 0.65
	var spd_mult = min(1.75, 1.0 + (elapsed_time / 360.0) * 0.5)
	var dmg_mult = 1.0 + (elapsed_time / 200.0) * 0.6

	match enemy_type:
		1: # Scout (Fast, Agile, Purple Wasp)
			var base_hp = 25.0 * hp_mult
			max_healths[idx] = base_hp
			healths[idx] = base_hp
			speeds[idx] = 190.0 * spd_mult
			radii[idx] = 12.0
			damages[idx] = 8.0 * dmg_mult
		2: # Brute (Huge, High HP, Volcanic Behemoth)
			var base_hp = 240.0 * hp_mult
			max_healths[idx] = base_hp
			healths[idx] = base_hp
			speeds[idx] = 75.0 * spd_mult
			radii[idx] = 25.0
			damages[idx] = 32.0 * dmg_mult
		_: # 0: Crawler (Swarm backbone, Crimson Beetle)
			var base_hp = 42.0 * hp_mult
			max_healths[idx] = base_hp
			healths[idx] = base_hp
			speeds[idx] = 125.0 * spd_mult
			radii[idx] = 15.0
			damages[idx] = 12.0 * dmg_mult

	active_count += 1
	swarm_count_changed.emit(active_count)
	return true

func spawn_cluster(center: Vector2, count: int, enemy_type: int = 0) -> void:
	for i in range(count):
		var offset = Vector2(
			randf_range(-130.0, 130.0),
			randf_range(-75.0, 75.0)
		)
		spawn_enemy(center + offset, enemy_type)

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	if active_count == 0:
		crawler_mmi.multimesh.visible_instance_count = 0
		scout_mmi.multimesh.visible_instance_count = 0
		brute_mmi.multimesh.visible_instance_count = 0
		return

	if not player_ref:
		_get_managers()

	spatial_grid.clear()
	for i in range(active_count):
		spatial_grid.insert(i, positions[i])

	var player_pos = player_ref.global_position if is_instance_valid(player_ref) else Vector2.ZERO
	var mm_crawler = crawler_mmi.multimesh
	var mm_scout = scout_mmi.multimesh
	var mm_brute = brute_mmi.multimesh

	var c_idx = 0
	var s_idx = 0
	var b_idx = 0
	var ticks = Time.get_ticks_msec() * 0.001

	for i in range(active_count):
		var pos = positions[i]
		var to_player = player_pos - pos
		var dist_to_player = to_player.length()

		var norm_to_player = to_player.normalized()
		var iso_dir = Vector2(norm_to_player.x, norm_to_player.y * 0.75).normalized()

		var sep_force = Vector2.ZERO
		var neighbors = spatial_grid.get_in_cell_and_adjacent(pos)
		var rad_i = radii[i]

		for n_idx in neighbors:
			if n_idx != i and n_idx < active_count:
				var diff = pos - positions[n_idx]
				var d_sq = diff.length_squared()
				var min_d = rad_i + radii[n_idx]
				if d_sq < min_d * min_d and d_sq > 0.01:
					var d = sqrt(d_sq)
					sep_force += (diff / d) * (min_d - d) * 14.0

		var target_vel = (iso_dir * speeds[i]) + sep_force
		velocities[i] = velocities[i].move_toward(target_vel, 750.0 * delta)
		positions[i] += velocities[i] * delta

		if dist_to_player < (rad_i + player_radius):
			if is_instance_valid(player_ref) and player_ref.has_method("take_damage"):
				player_ref.take_damage(damages[i] * delta * 2.0)

		if hit_timers[i] > 0.0:
			hit_timers[i] -= delta

		var is_hit = hit_timers[i] > 0.0
		var col = Color(5.0, 5.0, 5.0, 1.0) if is_hit else Color(1.0, 1.0, 1.0, 1.0)
		var t_type = types[i]

		match t_type:
			1: # Scout
				var hover_wiggle = sin(ticks * 24.0 + float(i) * 2.0) * 0.12
				var rot = velocities[i].angle() + PI * 0.5 + hover_wiggle
				var t = Transform2D(rot, Vector2.ONE, 0.0, positions[i])
				mm_scout.set_instance_transform_2d(s_idx, t)
				mm_scout.set_instance_color(s_idx, col)
				s_idx += 1
			2: # Brute
				var heavy_tread = sin(ticks * 8.0 + float(i)) * 0.07
				var rot = velocities[i].angle() + PI * 0.5 + heavy_tread
				var t = Transform2D(rot, Vector2.ONE, 0.0, positions[i])
				mm_brute.set_instance_transform_2d(b_idx, t)
				mm_brute.set_instance_color(b_idx, col)
				b_idx += 1
			_: # Crawler
				var scuttle = sin(ticks * 16.0 + float(i) * 1.5) * 0.18
				var rot = velocities[i].angle() + PI * 0.5 + scuttle
				var t = Transform2D(rot, Vector2.ONE, 0.0, positions[i])
				mm_crawler.set_instance_transform_2d(c_idx, t)
				mm_crawler.set_instance_color(c_idx, col)
				c_idx += 1

	mm_crawler.visible_instance_count = c_idx
	mm_scout.visible_instance_count = s_idx
	mm_brute.visible_instance_count = b_idx

func damage_in_radius(center: Vector2, radius: float, damage: float, knockback: float) -> int:
	var hit_count = 0
	var targets = spatial_grid.get_nearby(center, radius)
	var radius_sq = radius * radius

	var processed_indices: Dictionary = {}
	for idx in targets:
		if idx < active_count and not processed_indices.has(idx):
			processed_indices[idx] = true
			var diff = positions[idx] - center
			if diff.length_squared() <= radius_sq:
				var knock_dir = diff.normalized()
				_apply_damage_to_index(idx, damage, knock_dir * knockback, true)
				hit_count += 1
	return hit_count

func damage_along_beam(start: Vector2, end: Vector2, width: float, damage: float, knockback: float) -> int:
	var hit_count = 0
	var beam_dir = (end - start).normalized()
	var beam_len = start.distance_to(end)
	var half_width = width * 0.5

	var min_p = Vector2(min(start.x, end.x) - width, min(start.y, end.y) - width)
	var max_p = Vector2(max(start.x, end.x) + width, max(start.y, end.y) + width)
	var center = (min_p + max_p) * 0.5
	var diag_rad = min_p.distance_to(max_p) * 0.5
	
	var candidates = spatial_grid.get_nearby(center, diag_rad)
	var processed: Dictionary = {}

	for idx in candidates:
		if idx < active_count and not processed.has(idx):
			processed[idx] = true
			var pos = positions[idx]
			var to_pos = pos - start
			var proj_dist = to_pos.dot(beam_dir)
			if proj_dist >= 0.0 and proj_dist <= beam_len:
				var perp_dist = abs(to_pos.cross(beam_dir))
				if perp_dist <= (half_width + radii[idx]):
					_apply_damage_to_index(idx, damage, beam_dir * knockback, randf() < 0.25)
					hit_count += 1
	return hit_count

func damage_in_cone(origin: Vector2, direction: Vector2, max_dist: float, angle_deg: float, damage: float) -> int:
	var hit_count = 0
	var norm_dir = direction.normalized()
	var min_dot = cos(deg_to_rad(angle_deg * 0.5))
	var candidates = spatial_grid.get_nearby(origin, max_dist)
	var max_dist_sq = max_dist * max_dist
	var processed: Dictionary = {}

	for idx in candidates:
		if idx < active_count and not processed.has(idx):
			processed[idx] = true
			var diff = positions[idx] - origin
			var d_sq = diff.length_squared()
			if d_sq <= max_dist_sq and d_sq > 0.01:
				var to_norm = diff.normalized()
				if to_norm.dot(norm_dir) >= min_dot:
					_apply_damage_to_index(idx, damage, to_norm * 90.0, false)
					hit_count += 1
	return hit_count

func _apply_damage_to_index(idx: int, dmg: float, knock: Vector2, is_crit: bool = false) -> void:
	if idx >= active_count:
		return
	healths[idx] -= dmg
	hit_timers[idx] = 0.12
	velocities[idx] += knock * (0.35 if types[idx] == 2 else 1.0)

	# Floating damage number
	if floating_txt_mgr and randf() < 0.3:
		floating_txt_mgr.spawn_damage(positions[idx], dmg, is_crit)

	if healths[idx] <= 0.0:
		_kill_enemy(idx)

func _kill_enemy(idx: int) -> void:
	var pos = positions[idx]
	var e_type = types[idx]
	var is_boss = (e_type == 2)
	var xp = 120 if is_boss else (18 if e_type == 1 else 10)
	enemy_killed.emit(xp, pos, is_boss)

	# Audio splat
	if sound_mgr and randf() < 0.4:
		sound_mgr.play_splat()

	# Blood splatter particles matching enemy type
	if particle_mgr:
		var blood_col = Color(1.6, 0.2, 0.2, 1.0)
		if e_type == 1: blood_col = Color(1.4, 0.3, 1.8, 1.0)
		elif e_type == 2: blood_col = Color(1.8, 0.8, 0.1, 1.0)
		particle_mgr.spawn_blood_burst(pos, blood_col, 12)

	# Swap-and-pop O(1)
	var last_idx = active_count - 1
	if idx != last_idx:
		positions[idx] = positions[last_idx]
		velocities[idx] = velocities[last_idx]
		healths[idx] = healths[last_idx]
		max_healths[idx] = max_healths[last_idx]
		types[idx] = types[last_idx]
		hit_timers[idx] = hit_timers[last_idx]
		radii[idx] = radii[last_idx]
		speeds[idx] = speeds[last_idx]
		damages[idx] = damages[last_idx]

	active_count -= 1
	swarm_count_changed.emit(active_count)
