extends Node2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")

static var vent_tex: ImageTexture = null

var puff_timer: float = 0.0

func _ready() -> void:
	z_index = 0 # Strictly below entities and decals
	if not vent_tex:
		vent_tex = SpriteFactory.create_steam_vent_texture()
	puff_timer = randf_range(1.0, 4.0)
	queue_redraw()

func _process(delta: float) -> void:
	puff_timer -= delta
	if puff_timer <= 0.0:
		puff_timer = randf_range(3.0, 6.0)
		_puff_steam()

func _puff_steam() -> void:
	var cur = get_tree().current_scene
	if cur:
		var pm = cur.get_node_or_null("ParticleManager")
		if pm and pm.has_method("spawn_sparks"):
			# Plume of high-pressure cooling steam
			pm.spawn_sparks(global_position, Color(1.8, 2.2, 2.8, 0.7), 6)

func _draw() -> void:
	if vent_tex:
		draw_texture(vent_tex, Vector2(-24.0, -14.0))
