extends Node2D

const MAX_SWARM: int = 5000
const SPATIAL_CELL_SIZE: float = 90.0

@onready var multi_mesh_inst: MultiMeshInstance2D = $MultiMeshInstance2D

const SpatialGridClass = preload("res://scripts/spatial_grid.gd")
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

signal enemy_killed(xp_val: int, pos: Vector2)
signal swarm_count_changed(count: int)

func _ready() -> void:
	_init_multimesh()
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

func _init_multimesh() -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = MAX_SWARM
	mm.visible_instance_count = 0

	var quad = QuadMesh.new()
	quad.size = Vector2(34.0, 34.0)
	mm.mesh = quad

	# High-fidelity procedural beetle sprite texture with ground shadow & specular chitin
	var img = Image.create(34, 34, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Ground shadow (isometric ellipse)
	for y in range(24, 32):
		for x in range(6, 28):
			var dx = (x - 17.0) / 10.0
			var dy = (y - 28.0) / 3.5
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.5))
				
	# Bug carapace (chitin segments)
	for y in range(4, 25):
		for x in range(7, 27):
			var dx = (x - 17.0) / 8.0
			var dy = (y - 15.0) / 9.0
			var r_sq = dx * dx + dy * dy
			if r_sq <= 1.0:
				# Specular ridge highlight down center
				var is_ridge = abs(x - 17) <= 1
				var col_val = 1.0 if is_ridge else (0.85 if r_sq < 0.65 else 0.5)
				img.set_pixel(x, y, Color(col_val, col_val, col_val, 1.0))

	# Front mandibles / pincers
	img.set_pixel(12, 3, Color(0.9, 0.9, 0.9, 1.0))
	img.set_pixel(13, 2, Color(0.9, 0.9, 0.9, 1.0))
	img.set_pixel(21, 2, Color(0.9, 0.9, 0.9, 1.0))
	img.set_pixel(22, 3, Color(0.9, 0.9, 0.9, 1.0))
				
	# Glowing menacing eyes
	img.set_pixel(13, 6, Color(1.5, 0.1, 0.1, 1.0)) # HDR Red eye
	img.set_pixel(14, 6, Color(2.0, 1.5, 0.2, 1.0))
	img.set_pixel(19, 6, Color(2.0, 1.5, 0.2, 1.0))
	img.set_pixel(20, 6, Color(1.5, 0.1, 0.1, 1.0))

	var tex = ImageTexture.create_from_image(img)
	var mat = CanvasItemMaterial.new()
	multi_mesh_inst.texture = tex
	multi_mesh_inst.material = mat
	multi_mesh_inst.multimesh = mm

func spawn_enemy(spawn_pos: Vector2, enemy_type: int) -> bool:
	if active_count >= MAX_SWARM:
		return false

	var idx = active_count
	positions[idx] = spawn_pos
	velocities[idx] = Vector2.ZERO
	hit_timers[idx] = 0.0
	types[idx] = enemy_type

	match enemy_type:
		1: # Scout (Fast, Agile, Purple)
			max_healths[idx] = 25.0
			healths[idx] = 25.0
			speeds[idx] = 195.0
			radii[idx] = 10.0
			damages[idx] = 8.0
		2: # Brute (Huge, High HP, Heavy)
			max_healths[idx] = 160.0
			healths[idx] = 160.0
			speeds[idx] = 80.0
			radii[idx] = 19.0
			damages[idx] = 28.0
		_: # 0: Crawler (Swarm backbone, Red)
			max_healths[idx] = 40.0
			healths[idx] = 40.0
			speeds[idx] = 130.0
			radii[idx] = 12.0
			damages[idx] = 12.0

	active_count += 1
	multi_mesh_inst.multimesh.visible_instance_count = active_count
	swarm_count_changed.emit(active_count)
	return true

func spawn_cluster(center: Vector2, count: int, enemy_type: int = 0) -> void:
	for i in range(count):
		var offset = Vector2(
			randf_range(-120.0, 120.0),
			randf_range(-70.0, 70.0)
		)
		spawn_enemy(center + offset, enemy_type)

func _physics_process(delta: float) -> void:
	if active_count == 0:
		return

	if not player_ref:
		_get_managers()

	spatial_grid.clear()
	for i in range(active_count):
		spatial_grid.insert(i, positions[i])

	var player_pos = player_ref.global_position if is_instance_valid(player_ref) else Vector2.ZERO
	var mm = multi_mesh_inst.multimesh

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

		var col = _get_enemy_color(types[i], hit_timers[i] > 0.0)
		var scale_factor = 1.6 if types[i] == 2 else (0.85 if types[i] == 1 else 1.0)
		
		# Wiggle scuttle animation while walking
		var scuttle_wiggle = sin(Time.get_ticks_msec() * 0.02 + float(i)) * 0.15
		var rot = velocities[i].angle() + PI * 0.5 + scuttle_wiggle
		var t = Transform2D(rot, Vector2(scale_factor, scale_factor), 0.0, positions[i])
		
		mm.set_instance_transform_2d(i, t)
		mm.set_instance_color(i, col)

func _get_enemy_color(enemy_type: int, is_hit: bool) -> Color:
	if is_hit:
		return Color(4.5, 4.5, 4.5, 1.0) # Intense HDR White flash
	match enemy_type:
		1: # Scout: Electric Violet
			return Color(1.1, 0.35, 1.8, 1.0)
		2: # Brute: Magma Amber
			return Color(1.8, 0.8, 0.1, 1.0)
		_: # Crawler: Blood Crimson
			return Color(1.2, 0.25, 0.2, 1.0)

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
	var xp = 35 if e_type == 2 else (15 if e_type == 1 else 10)
	enemy_killed.emit(xp, pos)

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
	multi_mesh_inst.multimesh.visible_instance_count = active_count
	swarm_count_changed.emit(active_count)
