extends StaticBody2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const LightHelper = preload("res://scripts/light_helper.gd")

static var generator_tex: ImageTexture = null

var point_light: PointLight2D = null
var spark_timer: float = 0.0

func _ready() -> void:
	if not generator_tex:
		generator_tex = SpriteFactory.create_generator_texture()
	
	collision_layer = 1
	collision_mask = 0
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 18.0
	col.shape = shape
	col.position = Vector2(0, -6)
	add_child(col)

	point_light = PointLight2D.new()
	point_light.texture = LightHelper.get_radial_texture(128)
	point_light.energy = 1.1
	point_light.color = Color(0.2, 1.2, 1.8, 1.0)
	point_light.texture_scale = 2.2
	point_light.position = Vector2(0, -56)
	add_child(point_light)

	spark_timer = randf_range(1.0, 3.0)
	queue_redraw()

func _process(delta: float) -> void:
	if point_light:
		var pulse = 0.9 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
		point_light.energy = 1.1 * pulse

	spark_timer -= delta
	if spark_timer <= 0.0:
		spark_timer = randf_range(1.8, 4.0)
		_emit_apex_spark()

func _emit_apex_spark() -> void:
	var cur = get_tree().current_scene
	if cur:
		var pm = cur.get_node_or_null("ParticleManager")
		if pm and pm.has_method("spawn_sparks"):
			var apex_pos = global_position + Vector2(0, -108)
			pm.spawn_sparks(apex_pos, Color(2.5, 3.8, 5.5, 1.0), 4)

func _draw() -> void:
	if generator_tex:
		# Draw texture anchored so contact base is around (0, 0)
		draw_texture(generator_tex, Vector2(-32.0, -100.0))
