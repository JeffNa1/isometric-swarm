extends Node2D

const MAX_SWARM: int = 5000
const SPATIAL_CELL_SIZE: float = 90.0

@onready var multi_mesh_inst: MultiMeshInstance2D = $MultiMeshInstance2D

const SpatialGridClass = preload("res://scripts/spatial_grid.gd")
var spatial_grid = SpatialGridClass.new(SPATIAL_CELL_SIZE)

# Active count
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
var player_radius: float = 14.0

signal enemy_killed(xp_val: int, pos: Vector2)
signal swarm_count_changed(count: int)

func _ready() -> void:
	_init_multimesh()
	_allocate_arrays()
	player_ref = get_tree().get_first_node_in_group("player")

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

	# Create procedural QuadMesh with custom texture
	var quad = QuadMesh.new()
	quad.size = Vector2(32.0, 32.0)
	mm.mesh = quad

	# Procedural beetle / bug sprite texture with ground shadow
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Draw ground shadow (bottom ellipse)
	for y in range(22, 30):
		for x in range(6, 26):
			var dx = (x - 16.0) / 9.0
			var dy = (y - 26.0) / 3.5
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.45))
				
	# Draw bug body (chitin shell + glowing eyes)
	for y in range(4, 23):
		for x in range(8, 24):
			var dx = (x - 16.0) / 7.0
			var dy = (y - 14.0) / 8.0
			if dx * dx + dy * dy <= 1.0:
				var rim = 1.0 if (dx * dx + dy * dy > 0.7) else 0.0
				var col = Color(0.9, 0.9, 0.9, 1.0) if rim == 0.0 else Color(0.6, 0.6, 0.6, 1.0)
				img.set_pixel(x, y, col)
				
	# Eyes
	img.set_pixel(13, 7, Color(1.0, 0.1, 0.1, 1.0))
	img.set_pixel(14, 7, Color(1.0, 0.9, 0.2, 1.0))
	img.set_pixel(18, 7, Color(1.0, 0.1, 0.1, 1.0))
	img.set_pixel(19, 7, Color(1.0, 0.9, 0.2, 1.0))

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
			randf_range(-70.0, 70.0) # 2:1 isometric dispersion
		)
		spawn_enemy(center + offset, enemy_type)

func _physics_process(delta: float) -> void:
	if active_count == 0:
		return

	# Re-register spatial hash grid
	spatial_grid.clear()
	for i in range(active_count):
		spatial_grid.insert(i, positions[i])

	var player_pos = player_ref.global_position if is_instance_valid(player_ref) else Vector2.ZERO
	var mm = multi_mesh_inst.multimesh

	# Process swarm motion & interactions
	for i in range(active_count):
		var pos = positions[i]
		var to_player = player_pos - pos
		var dist_to_player = to_player.length()

		# Isometric direction toward player
		var norm_to_player = to_player.normalized()
		var iso_dir = Vector2(norm_to_player.x, norm_to_player.y * 0.75).normalized()

		# Boids Separation force from nearby neighbors
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

		# Damage player on contact
		if dist_to_player < (rad_i + player_radius):
			if is_instance_valid(player_ref) and player_ref.has_method("take_damage"):
				player_ref.take_damage(damages[i] * delta * 2.0)

		# Hit flash update & MultiMesh transform
		if hit_timers[i] > 0.0:
			hit_timers[i] -= delta

		var col = _get_enemy_color(types[i], hit_timers[i] > 0.0)
		var scale_factor = 1.6 if types[i] == 2 else (0.85 if types[i] == 1 else 1.0)
		
		# Facing rotation angle towards velocity
		var rot = velocities[i].angle() + PI * 0.5
		var t = Transform2D(rot, Vector2(scale_factor, scale_factor), 0.0, positions[i])
		
		mm.set_instance_transform_2d(i, t)
		mm.set_instance_color(i, col)

func _get_enemy_color(enemy_type: int, is_hit: bool) -> Color:
	if is_hit:
		return Color(3.5, 3.5, 3.5, 1.0) # HDR White flash
	match enemy_type:
		1: # Scout: Electric Violet
			return Color(0.75, 0.25, 1.0, 1.0)
		2: # Brute: Magma Amber
			return Color(1.0, 0.55, 0.1, 1.0)
		_: # Crawler: Blood Crimson
			return Color(0.95, 0.25, 0.2, 1.0)

# AoE / Radius Damage (for Explosions, Orbit Blades, Nova)
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
				_apply_damage_to_index(idx, damage, knock_dir * knockback)
				hit_count += 1
	return hit_count

# Piercing Line / Beam Damage (for Railgun, Piercing Shotgun)
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
					_apply_damage_to_index(idx, damage, beam_dir * knockback)
					hit_count += 1
	return hit_count

# Conical Damage (for Flamethrower / Plasma cone)
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
					_apply_damage_to_index(idx, damage, to_norm * 90.0)
					hit_count += 1
	return hit_count

func _apply_damage_to_index(idx: int, dmg: float, knock: Vector2) -> void:
	if idx >= active_count:
		return
	healths[idx] -= dmg
	hit_timers[idx] = 0.12
	velocities[idx] += knock * (0.35 if types[idx] == 2 else 1.0)

	if healths[idx] <= 0.0:
		_kill_enemy(idx)

func _kill_enemy(idx: int) -> void:
	var pos = positions[idx]
	var xp = 35 if types[idx] == 2 else (15 if types[idx] == 1 else 10)
	enemy_killed.emit(xp, pos)

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
