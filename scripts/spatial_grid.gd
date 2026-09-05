class_name SpatialGrid
extends RefCounted

var cell_size: float = 90.0
var inv_cell_size: float = 1.0 / 90.0
# Dictionary mapping Vector2i -> Array[int]
var grid: Dictionary = {}

func _init(p_cell_size: float = 90.0) -> void:
	cell_size = p_cell_size
	inv_cell_size = 1.0 / p_cell_size

func clear() -> void:
	grid.clear()

func insert(index: int, pos: Vector2) -> void:
	var cx: int = int(floor(pos.x * inv_cell_size))
	var cy: int = int(floor(pos.y * inv_cell_size))
	var key = Vector2i(cx, cy)
	if not grid.has(key):
		grid[key] = [index]
	else:
		grid[key].append(index)

func get_nearby(pos: Vector2, search_radius: float) -> Array[int]:
	var result: Array[int] = []
	var min_cx: int = int(floor((pos.x - search_radius) * inv_cell_size))
	var max_cx: int = int(floor((pos.x + search_radius) * inv_cell_size))
	var min_cy: int = int(floor((pos.y - search_radius) * inv_cell_size))
	var max_cy: int = int(floor((pos.y + search_radius) * inv_cell_size))

	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			var key = Vector2i(cx, cy)
			if grid.has(key):
				result.append_array(grid[key])
	return result

func get_in_cell_and_adjacent(pos: Vector2) -> Array[int]:
	var cx: int = int(floor(pos.x * inv_cell_size))
	var cy: int = int(floor(pos.y * inv_cell_size))
	var result: Array[int] = []
	
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var key = Vector2i(cx + ox, cy + oy)
			if grid.has(key):
				result.append_array(grid[key])
	return result
