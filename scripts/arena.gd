extends Node2D

const ARENA_SIZE: float = 10000.0

const PowerGeneratorScript = preload("res://scripts/power_generator.gd")
const SteamVentScript = preload("res://scripts/steam_vent.gd")

func _ready() -> void:
	_create_boundaries()
	_spawn_environmental_props()

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

func _spawn_environmental_props() -> void:
	var props_container = Node2D.new()
	props_container.name = "EnvironmentalProps"
	props_container.y_sort_enabled = true
	add_child(props_container)

	# 1. Monumental Tesla Power Generators at Industrial Quad-Hubs
	var generator_positions = [
		Vector2(1100.0, 550.0),
		Vector2(-1100.0, -550.0),
		Vector2(-1100.0, 550.0),
		Vector2(1100.0, -550.0),
		Vector2(2400.0, 1200.0),
		Vector2(-2400.0, -1200.0),
		Vector2(-2400.0, 1200.0),
		Vector2(2400.0, -1200.0)
	]
	for pos in generator_positions:
		var gen = StaticBody2D.new()
		gen.set_script(PowerGeneratorScript)
		gen.position = pos
		props_container.add_child(gen)

	# 2. Ground Steam Vents along industrial transit lanes
	var vent_positions = [
		Vector2(512.0, 256.0), Vector2(576.0, 288.0),
		Vector2(-512.0, -256.0), Vector2(-576.0, -288.0),
		Vector2(-512.0, 256.0), Vector2(-576.0, 288.0),
		Vector2(512.0, -256.0), Vector2(576.0, -288.0),
		Vector2(1536.0, 768.0), Vector2(1600.0, 800.0),
		Vector2(-1536.0, -768.0), Vector2(-1600.0, -800.0),
		Vector2(-1536.0, 768.0), Vector2(-1600.0, 800.0),
		Vector2(1536.0, -768.0), Vector2(1600.0, -800.0),
		Vector2(0.0, 896.0), Vector2(0.0, -896.0),
		Vector2(1792.0, 0.0), Vector2(-1792.0, 0.0),
		Vector2(896.0, 1280.0), Vector2(-896.0, 1280.0),
		Vector2(896.0, -1280.0), Vector2(-896.0, -1280.0)
	]
	for pos in vent_positions:
		var vent = Node2D.new()
		vent.set_script(SteamVentScript)
		vent.position = pos
		props_container.add_child(vent)
