extends CharacterBody2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const TREASURE_CHEST_SCENE = preload("res://scenes/treasure_chest.tscn")
const GEM_SCENE = preload("res://scenes/gem.tscn")

signal boss_health_changed(current: float, maximum: float)
signal boss_defeated()

@export var max_health: float = 4500.0
var current_health: float = 4500.0

enum State { CHASE, WINDUP, CHARGE, QUAKE }
var current_state: State = State.CHASE

var state_timer: float = 0.0
var attack_cooldown: float = 4.0
var hurt_flash_timer: float = 0.0
var charge_dir: Vector2 = Vector2.ZERO

var player_ref: CharacterBody2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var camera_node: Camera2D = null
var hud: CanvasLayer = null

static var boss_tex: ImageTexture = null

func _ready() -> void:
	if not boss_tex:
		boss_tex = SpriteFactory.create_boss_texture()
	current_health = max_health
	add_to_group("boss")
	_get_managers()
	queue_redraw()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		player_ref = cur.get_node_or_null("Entities/Player")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		camera_node = cur.get_node_or_null("Camera2D")
		hud = cur.get_node_or_null("HUD")
		if hud and hud.has_method("show_boss_bar"):
			hud.show_boss_bar("APEX LEVIATHAN", current_health, max_health)

func _physics_process(delta: float) -> void:
	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
		queue_redraw()

	if not player_ref:
		_get_managers()

	if not player_ref or not is_instance_valid(player_ref):
		return

	var p_pos = player_ref.global_position
	var to_player = p_pos - global_position
	var dist = to_player.length()

	state_timer += delta

	match current_state:
		State.CHASE:
			var move_dir = Vector2(to_player.x, to_player.y * 0.75).normalized()
			velocity = velocity.move_toward(move_dir * 135.0, 600.0 * delta)
			move_and_slide()

			if state_timer >= attack_cooldown:
				state_timer = 0.0
				if randf() < 0.6:
					_start_charge(p_pos)
				else:
					_start_quake()

		State.WINDUP:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			move_and_slide()
			# Telegraph red sparks
			if particle_mgr and randf() < 0.4:
				particle_mgr.spawn_sparks(global_position, Color(3.8, 0.4, 0.2, 1.0), 3)

			if state_timer >= 0.75:
				state_timer = 0.0
				current_state = State.CHARGE
				if sound_mgr and sound_mgr.has_method("play_alarm"):
					sound_mgr.play_alarm()

		State.CHARGE:
			velocity = velocity.move_toward(charge_dir * 490.0, 1800.0 * delta)
			move_and_slide()

			if particle_mgr and randf() < 0.6:
				particle_mgr.spawn_blood_burst(global_position, Color(3.5, 0.8, 0.1, 1.0), 3)

			if state_timer >= 1.25:
				state_timer = 0.0
				current_state = State.CHASE
				attack_cooldown = randf_range(3.5, 5.5)

		State.QUAKE:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			move_and_slide()
			if state_timer >= 0.5:
				_execute_quake()
				state_timer = 0.0
				current_state = State.CHASE
				attack_cooldown = randf_range(4.0, 6.0)

	# Contact damage to player
	if dist < 48.0 and player_ref.has_method("take_damage"):
		player_ref.take_damage(35.0 * delta * 2.0)

	queue_redraw()

func _start_charge(target: Vector2) -> void:
	current_state = State.WINDUP
	charge_dir = (target - global_position).normalized()
	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.2)

func _start_quake() -> void:
	current_state = State.QUAKE
	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.3)

func _execute_quake() -> void:
	if sound_mgr and sound_mgr.has_method("play_shockwave"):
		sound_mgr.play_shockwave()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.55)

	if particle_mgr:
		particle_mgr.spawn_shockwave_debris(global_position, 120.0, 32)
		particle_mgr.spawn_blood_burst(global_position, Color(3.8, 1.0, 0.2, 1.0), 24)

	# Shockwave knockback / damage to player if nearby
	if player_ref and global_position.distance_to(player_ref.global_position) < 220.0:
		player_ref.take_damage(30.0)

func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	hurt_flash_timer = 0.12
	boss_health_changed.emit(current_health, max_health)

	if hud and hud.has_method("update_boss_health"):
		hud.update_boss_health(current_health, max_health)

	var cur = get_tree().current_scene
	var txt_mgr = cur.get_node_or_null("FloatingTextManager") if cur else null
	if txt_mgr and randf() < 0.4:
		txt_mgr.spawn_damage(global_position + Vector2(randf_range(-20, 20), randf_range(-30, 0)), amount, true)

	if current_health <= 0.0:
		_die()

func _die() -> void:
	boss_defeated.emit()

	if hud and hud.has_method("hide_boss_bar"):
		hud.hide_boss_bar()

	if sound_mgr and sound_mgr.has_method("play_nuke"):
		sound_mgr.play_nuke()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.8)

	if particle_mgr:
		for k in range(5):
			var off = Vector2(randf_range(-40, 40), randf_range(-40, 40))
			particle_mgr.spawn_blood_burst(global_position + off, Color(3.8, 1.2, 0.2, 1.0), 20)
			particle_mgr.spawn_shockwave_debris(global_position + off, 60.0, 18)

	var entities = get_tree().current_scene.get_node_or_null("Entities")
	if not entities:
		entities = get_parent()

	# Drop Golden Treasure Chest
	var chest = TREASURE_CHEST_SCENE.instantiate()
	chest.global_position = global_position
	entities.call_deferred("add_child", chest)

	# Drop cluster of 8 Super Gems
	for g in range(8):
		var gem = GEM_SCENE.instantiate()
		gem.xp_value = 60
		gem.is_super_gem = true
		var angle = (TAU / 8.0) * float(g)
		gem.global_position = global_position + Vector2(cos(angle) * 45.0, sin(angle) * 30.0)
		entities.call_deferred("add_child", gem)

	queue_free()

func _draw() -> void:
	# Warning telegraph in windup
	if current_state == State.WINDUP:
		var line_end = charge_dir * 350.0
		draw_line(Vector2.ZERO, line_end, Color(3.5, 0.2, 0.2, 0.65), 3.0)
		draw_circle(line_end, 16.0, Color(3.5, 0.2, 0.2, 0.45))

	if boss_tex:
		var col = Color(5.0, 5.0, 5.0, 1.0) if hurt_flash_timer > 0.0 else Color(1.0, 1.0, 1.0, 1.0)
		var flip = 1.0 if (player_ref and player_ref.global_position.x > global_position.x) else -1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
		draw_texture(boss_tex, Vector2(-48.0, -68.0), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
