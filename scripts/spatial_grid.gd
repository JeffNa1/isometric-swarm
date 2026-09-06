class_name SpatialGrid
extends RefCounted

const TABLE_SIZE: int = 65536
const TABLE_MASK: int = 65535

var cell_size: float = 90.0
var inv_cell_size: float = 1.0 / 90.0

# Flat 1D packed arrays for zero-allocation spatial hashing
var cell_head: PackedInt32Array = PackedInt32Array()
var entity_next: PackedInt32Array = PackedInt32Array()
var entity_cell_x: PackedInt32Array = PackedInt32Array()
var entity_cell_y: PackedInt32Array = PackedInt32Array()

# Active hash tracking for O(occupied) clear instead of O(TABLE_SIZE)
var occupied_hashes: PackedInt32Array = PackedInt32Array()
var occupied_count: int = 0

func _init(p_cell_size: float = 90.0, initial_capacity: int = 6000) -> void:
	cell_size = p_cell_size
	inv_cell_size = 1.0 / p_cell_size

	cell_head.resize(TABLE_SIZE)
	cell_head.fill(-1)

	# Pre-allocate large buffer to eliminate re-allocation during physics frames
	occupied_hashes.resize(8192)
	_ensure_capacity(initial_capacity)

func _ensure_capacity(capacity: int) -> void:
	var current = entity_next.size()
	if capacity > current:
		var new_size = max(capacity, current * 2)
		entity_next.resize(new_size)
		entity_cell_x.resize(new_size)
		entity_cell_y.resize(new_size)
		for i in range(current, new_size):
			entity_next[i] = -1

func clear() -> void:
	for i in range(occupied_count):
		cell_head[occupied_hashes[i]] = -1
	occupied_count = 0

func insert(index: int, pos: Vector2) -> void:
	if index >= entity_next.size():
		_ensure_capacity(index + 1024)

	var cx: int = int(floor(pos.x * inv_cell_size))
	var cy: int = int(floor(pos.y * inv_cell_size))
	var h: int = ((cx * 73856093) ^ (cy * 19349663)) & TABLE_MASK

	if cell_head[h] == -1:
		if occupied_count >= occupied_hashes.size():
			occupied_hashes.resize(occupied_hashes.size() * 2)
		occupied_hashes[occupied_count] = h
		occupied_count += 1

	entity_cell_x[index] = cx
	entity_cell_y[index] = cy
	entity_next[index] = cell_head[h]
	cell_head[h] = index

# Returns independent array to prevent buffer corruption on nested calls (e.g. Tesla chain)
func get_nearby(pos: Vector2, search_radius: float) -> Array[int]:
	var result: Array[int] = []
	var min_cx: int = int(floor((pos.x - search_radius) * inv_cell_size))
	var max_cx: int = int(floor((pos.x + search_radius) * inv_cell_size))
	var min_cy: int = int(floor((pos.y - search_radius) * inv_cell_size))
	var max_cy: int = int(floor((pos.y + search_radius) * inv_cell_size))

	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			var h: int = ((cx * 73856093) ^ (cy * 19349663)) & TABLE_MASK
			var curr: int = cell_head[h]
			while curr != -1:
				if entity_cell_x[curr] == cx and entity_cell_y[curr] == cy:
					result.append(curr)
				curr = entity_next[curr]
	return result

const ADJ_DX: PackedInt32Array = [0, -1, 0, 1, -1, 1, -1, 0, 1]
const ADJ_DY: PackedInt32Array = [0, -1, -1, -1, 0, 0, 1, 1, 1]

# Direct zero-allocation separation force calculation
func calculate_separation(pos: Vector2, rad_i: float, my_idx: int, positions: PackedVector2Array, radii: PackedFloat32Array, active_count: int, max_neighbors: int = 5) -> Vector2:
	var cx: int = int(floor(pos.x * inv_cell_size))
	var cy: int = int(floor(pos.y * inv_cell_size))
	var sep = Vector2.ZERO
	var found = 0

	for n in 9:
		var ncx: int = cx + ADJ_DX[n]
		var ncy: int = cy + ADJ_DY[n]
		var h: int = ((ncx * 73856093) ^ (ncy * 19349663)) & TABLE_MASK
		var curr: int = cell_head[h]
		while curr != -1:
			if curr != my_idx and curr < active_count and entity_cell_x[curr] == ncx and entity_cell_y[curr] == ncy:
				var diff = pos - positions[curr]
				var d_sq = diff.length_squared()
				var min_d = rad_i + radii[curr]
				if d_sq < min_d * min_d and d_sq > 0.01:
					var d = sqrt(d_sq)
					sep += (diff / d) * (min_d - d) * 14.0
					found += 1
					if found >= max_neighbors:
						return sep
			curr = entity_next[curr]
	return sep

func get_in_cell_and_adjacent(pos: Vector2) -> Array[int]:
	var result: Array[int] = []
	var cx: int = int(floor(pos.x * inv_cell_size))
	var cy: int = int(floor(pos.y * inv_cell_size))

	for n in 9:
		var ncx: int = cx + ADJ_DX[n]
		var ncy: int = cy + ADJ_DY[n]
		var h: int = ((ncx * 73856093) ^ (ncy * 19349663)) & TABLE_MASK
		var curr: int = cell_head[h]
		while curr != -1:
			if entity_cell_x[curr] == ncx and entity_cell_y[curr] == ncy:
				result.append(curr)
			curr = entity_next[curr]
	return result
