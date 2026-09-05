extends Node2D

const ARENA_SIZE: float = 10000.0

func _ready() -> void:
	_create_boundaries()

func _create_boundaries() -> void:
	var half_size = ARENA_SIZE * 0.5
	var static_body = StaticBody2D.new()
	static_body.name = "ArenaBoundaries"
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	add_child(static_body)
	
	var points = [
		Vector2(-half_size, -half_size),
		Vector2(half_size, -half_size),
		Vector2(half_size, half_size),
		Vector2(-half_size, half_size)
	]
	
	for i in range(4):
		var col = CollisionShape2D.new()
		var segment = SegmentShape2D.new()
		segment.a = points[i]
		segment.b = points[(i + 1) % 4]
		col.shape = segment
		static_body.add_child(col)
