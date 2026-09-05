extends Node2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")

@export var pickup_type: String = "nuke" # "nuke", "vacuum", "medkit", "overclock", "gold"

var time_alive: float = 0.0
var bob_offset: float = 0.0
var pickup_tex: ImageTexture = null

var player_ref: CharacterBody2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var floating_txt_mgr: Node2D = null
var camera_node: Camera2D = null
var swarm_mgr: Node2D = null

func _ready() -> void:
	pickup_tex = SpriteFactory.create_pickup_texture(pickup_type)
	_get_managers()
	queue_redraw()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		player_ref = cur.get_node_or_null("Entities/Player")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		floating_txt_mgr = cur.get_node_or_null("FloatingTextManager")
		camera_node = cur.get_node_or_null("Camera2D")
		swarm_mgr = cur.get_node_or_null("SwarmManager")

func setup(type: String) -> void:
	pickup_type = type
	pickup_tex = SpriteFactory.create_pickup_texture(pickup_type)
	queue_redraw()

func _process(delta: float) -> void:
	time_alive += delta
	bob_offset = sin(time_alive * 5.0) * 3.5

	if not player_ref or not is_instance_valid(player_ref):
		_get_managers()

	if player_ref and is_instance_valid(player_ref):
		var dist = global_position.distance_to(player_ref.global_position)
		if dist <= 38.0:
			_consume_pickup()
			return

	if particle_mgr and randf() < 0.2:
		var spark_col = Color(0.3, 2.5, 3.5, 1.0)
		if pickup_type == "nuke": spark_col = Color(3.5, 1.2, 0.2, 1.0)
		elif pickup_type == "medkit": spark_col = Color(0.2, 3.5, 0.8, 1.0)
		elif pickup_type == "overclock": spark_col = Color(3.5, 3.0, 0.4, 1.0)
		elif pickup_type == "gold": spark_col = Color(3.5, 2.5, 0.3, 1.0)
		particle_mgr.spawn_sparks(global_position + Vector2(0, bob_offset - 10), spark_col, 2)

	queue_redraw()

func _consume_pickup() -> void:
	var cur = get_tree().current_scene
	var main_node = cur if (cur and cur.has_method("vacuum_all_gems")) else null

	match pickup_type:
		"nuke":
			if swarm_mgr and swarm_mgr.has_method("nuke_screen"):
				swarm_mgr.nuke_screen(player_ref.global_position, 1600.0)
			if sound_mgr and sound_mgr.has_method("play_nuke"):
				sound_mgr.play_nuke()
			if camera_node and camera_node.has_method("add_trauma"):
				camera_node.add_trauma(0.65)
			if floating_txt_mgr and floating_txt_mgr.has_method("spawn_text"):
				floating_txt_mgr.spawn_text(global_position, "💥 EMP TẬN DIỆT TOÀN BẢN ĐỒ!", Color(3.5, 1.5, 0.2, 1.0))

		"vacuum":
			if main_node:
				main_node.vacuum_all_gems()
			if sound_mgr and sound_mgr.has_method("play_chest"):
				sound_mgr.play_chest()
			if floating_txt_mgr and floating_txt_mgr.has_method("spawn_text"):
				floating_txt_mgr.spawn_text(global_position, "🧲 LỰC HÚT TOÀN BỘ NGỌC!", Color(0.4, 2.5, 3.8, 1.0))

		"medkit":
			if player_ref:
				player_ref.current_health = player_ref.max_health
				player_ref.health_changed.emit(player_ref.current_health, player_ref.max_health)
				player_ref.is_invulnerable = true
				player_ref.invuln_timer = 3.5
			if sound_mgr and sound_mgr.has_method("play_levelup"):
				sound_mgr.play_levelup()
			if floating_txt_mgr and floating_txt_mgr.has_method("spawn_text"):
				floating_txt_mgr.spawn_text(global_position, "🩸 HỒI PHỤC SIÊU CẤP 100%!", Color(0.3, 3.5, 0.8, 1.0))

		"overclock":
			if player_ref and player_ref.has_method("trigger_overclock"):
				player_ref.trigger_overclock(10.0)
			if sound_mgr and sound_mgr.has_method("play_levelup"):
				sound_mgr.play_levelup()
			if floating_txt_mgr and floating_txt_mgr.has_method("spawn_text"):
				floating_txt_mgr.spawn_text(global_position, "⚡ QUÁ TẢI TỐC ĐỘ 200%!", Color(3.5, 3.0, 0.3, 1.0))

		"gold":
			if player_ref and player_ref.has_method("add_xp"):
				player_ref.add_xp(300)
			if sound_mgr and sound_mgr.has_method("play_gem_pickup"):
				sound_mgr.play_gem_pickup()
			if floating_txt_mgr and floating_txt_mgr.has_method("spawn_text"):
				floating_txt_mgr.spawn_text(global_position, "💰 +300 EXP THƯỞNG!", Color(3.5, 2.5, 0.4, 1.0))

	if particle_mgr:
		particle_mgr.spawn_sparks(global_position, Color(3.0, 3.0, 3.0, 1.0), 12)

	queue_free()

func _draw() -> void:
	# Ground shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 9.0 * (1.0 - bob_offset * 0.05), Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if pickup_tex:
		var draw_pos = Vector2(-12.0, -16.0 + bob_offset)
		draw_texture(pickup_tex, draw_pos)
		var halo_pulse = sin(time_alive * 6.0) * 0.2 + 0.8
		draw_circle(Vector2(0, -6.0 + bob_offset), 2.5, Color(1.5 * halo_pulse, 2.5 * halo_pulse, 3.5 * halo_pulse, 0.7))
