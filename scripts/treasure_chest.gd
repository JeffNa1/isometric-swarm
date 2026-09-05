extends Node2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")

var time_alive: float = 0.0
var bob_offset: float = 0.0

static var chest_tex: ImageTexture = null

var player_ref: Node2D = null
var sound_mgr: Node = null
var hud: CanvasLayer = null

func _ready() -> void:
	z_as_relative = false
	z_index = 4 # Render strictly above swarm (z=3)
	if not chest_tex:
		chest_tex = SpriteFactory.create_chest_texture()
	_get_managers()
	queue_redraw()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		player_ref = cur.get_node_or_null("Entities/Player")
		sound_mgr = cur.get_node_or_null("SoundManager")
		hud = cur.get_node_or_null("HUD")

func _process(delta: float) -> void:
	time_alive += delta
	bob_offset = sin(time_alive * 4.0) * 4.0

	if not player_ref:
		_get_managers()

	if player_ref and is_instance_valid(player_ref):
		if global_position.distance_to(player_ref.global_position) < 38.0:
			_open_chest()
			return

	queue_redraw()

func _open_chest() -> void:
	if not hud:
		_get_managers()

	if sound_mgr and sound_mgr.has_method("play_chest"):
		sound_mgr.play_chest()

	if hud and hud.has_method("show_chest_jackpot"):
		hud.show_chest_jackpot()

	queue_free()

func _draw() -> void:
	# Ground shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 18.0 * (1.0 - bob_offset * 0.04), Color(0.0, 0.0, 0.0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if chest_tex:
		var draw_pos = Vector2(-20.0, -26.0 + bob_offset)
		draw_texture(chest_tex, draw_pos)

		var pulse = sin(time_alive * 5.0) * 0.3 + 0.7
		# Radiant golden aura
		draw_circle(Vector2(0, -10.0 + bob_offset), 8.0, Color(3.5 * pulse, 2.5 * pulse, 0.4 * pulse, 0.35))
