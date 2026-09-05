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

func _init(p_cell_size: float = 90.0, initial_capacity: int = 6000) -> void:
	cell_size = p_cell_size
	inv_cell_size = 1.0 / p_cell_size

	cell_head.resize(TABLE_SIZE)
	cell_head.fill(-1)

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
	cell_head.fill(-1)

func insert(index: int, pos: Vector2) -> void:
	if index >= entity_next.size():
		_ensure_capacity(index + 1024)

	var cx: int = int(floor(pos.x * inv_cell_size))
	var cy: int = int(floor(pos.y * inv_cell_size))
	var h: int = ((cx * 73856093) ^ (cy * 19349663)) & TABLE_MASK

	entity_cell_x[index] = cx
	entity_cell_y[index] = cy
	entity_next[index] = cell_head[h]
	cell_head[h] = index

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

func get_in_cell_and_adjacent(pos: Vector2) -> Array[int]:
	var cx: int = int(floor(pos.x * inv_cell_size))
	var cy: int = int(floor(pos.y * inv_cell_size))
	var result: Array[int] = []

	for ox in range(-1, 2):
		var ncx: int = cx + ox
		for oy in range(-1, 2):
			var ncy: int = cy + oy
			var h: int = ((ncx * 73856093) ^ (ncy * 19349663)) & TABLE_MASK
			var curr: int = cell_head[h]
			while curr != -1:
				if entity_cell_x[curr] == ncx and entity_cell_y[curr] == ncy:
					result.append(curr)
				curr = entity_next[curr]
	return result

func get_neighbors_capped(pos: Vector2, max_count: int = 6) -> Array[int]:
	var cx: int = int(floor(pos.x * inv_cell_size))
	var cy: int = int(floor(pos.y * inv_cell_size))
	var result: Array[int] = []

	for ox in range(-1, 2):
		var ncx: int = cx + ox
		for oy in range(-1, 2):
			var ncy: int = cy + oy
			var h: int = ((ncx * 73856093) ^ (ncy * 19349663)) & TABLE_MASK
			var curr: int = cell_head[h]
			while curr != -1:
				if entity_cell_x[curr] == ncx and entity_cell_y[curr] == ncy:
					result.append(curr)
					if result.size() >= max_count:
						return result
				curr = entity_next[curr]
	return result
