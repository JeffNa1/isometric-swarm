extends CharacterBody2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const SaveManagerClass = preload("res://scripts/save_manager.gd")
const TREASURE_CHEST_SCENE = preload("res://scenes/treasure_chest.tscn")
const GEM_SCENE = preload("res://scenes/gem.tscn")

signal boss_health_changed(current: float, maximum: float)
signal boss_defeated()

@export var max_health: float = 8500.0
var current_health: float = 8500.0

enum State { CHASE, BARRAGE, SHIELD, EMP }
var current_state: State = State.CHASE

var state_timer: float = 0.0
var attack_cooldown: float = 4.5
var hurt_flash_timer: float = 0.0
var is_shielded: bool = false

var player_ref: CharacterBody2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var camera_node: Camera2D = null
var hud: CanvasLayer = null

static var dreadnought_tex: ImageTexture = null

# Active boss plasma rockets
var boss_rockets: Array[Dictionary] = []
var turret_angle: float = 0.0

func _ready() -> void:
	if not dreadnought_tex:
		dreadnought_tex = SpriteFactory.create_dreadnought_texture()
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
			hud.show_boss_bar("CYBER DREADNOUGHT", current_health, max_health)

func _physics_process(delta: float) -> void:
	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta

	if not player_ref or not is_instance_valid(player_ref):
		_get_managers()
		if not player_ref: return

	var p_pos = player_ref.global_position
	var to_player = p_pos - global_position
	var dist = to_player.length()

	turret_angle = rotate_toward(turret_angle, to_player.angle(), 4.5 * delta)
	state_timer += delta
	_update_rockets(delta)
	queue_redraw()

	match current_state:
		State.CHASE:
			is_shielded = false
			var move_dir = Vector2(to_player.x, to_player.y * 0.75).normalized()
			velocity = velocity.move_toward(move_dir * 110.0, 500.0 * delta)
			move_and_slide()

			if state_timer >= attack_cooldown:
				state_timer = 0.0
				if randf() < 0.55:
					_start_barrage()
				else:
					_start_shield()

		State.BARRAGE:
			velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
			move_and_slide()
			if state_timer >= 0.4 and state_timer <= 1.2 and fmod(state_timer, 0.2) < delta:
				_fire_salvo_rocket(p_pos)

			if state_timer >= 1.5:
				state_timer = 0.0
				current_state = State.CHASE
				attack_cooldown = randf_range(4.0, 6.0)

		State.SHIELD:
			is_shielded = true
			velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
			move_and_slide()
			if state_timer >= 2.0:
				state_timer = 0.0
				_execute_emp()
				current_state = State.CHASE
				attack_cooldown = randf_range(4.0, 6.0)

	if dist < 52.0 and player_ref.has_method("take_damage"):
		player_ref.take_damage(40.0 * delta * 2.0)

	queue_redraw()

func _start_barrage() -> void:
	current_state = State.BARRAGE
	state_timer = 0.0
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()

func _fire_salvo_rocket(target: Vector2) -> void:
	var angle = randf() * TAU
	var start_p = global_position + Vector2(cos(angle) * 35.0, sin(angle) * 20.0)
	var dir = (target - start_p).normalized()
	boss_rockets.append({
		"pos": start_p,
		"dir": dir,
		"speed": 340.0,
		"life": 3.0
	})
	if sound_mgr and sound_mgr.has_method("play_missile_launch"):
		sound_mgr.play_missile_launch()

func _update_rockets(delta: float) -> void:
	var p_pos = player_ref.global_position if is_instance_valid(player_ref) else Vector2.ZERO
	var i = 0
	while i < boss_rockets.size():
		var r = boss_rockets[i]
		r.life -= delta

		if r.life <= 0.0:
			boss_rockets.remove_at(i)
			continue

		var to_p = (p_pos - r.pos).normalized()
		r.dir = r.dir.lerp(to_p, 4.5 * delta).normalized()
		r.pos += r.dir * r.speed * delta

		if particle_mgr and randf() < 0.4:
			particle_mgr.spawn_sparks(r.pos, Color(0.3, 2.5, 4.0, 1.0), 2)

		if is_instance_valid(player_ref) and r.pos.distance_to(p_pos) <= 22.0:
			player_ref.take_damage(25.0)
			if particle_mgr:
				particle_mgr.spawn_blood_burst(r.pos, Color(0.3, 2.8, 4.5, 1.0), 12)
			boss_rockets.remove_at(i)
			continue

		i += 1

func _start_shield() -> void:
	current_state = State.SHIELD
	state_timer = 0.0

func _execute_emp() -> void:
	is_shielded = false
	if sound_mgr and sound_mgr.has_method("play_nuke"):
		sound_mgr.play_nuke()
	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.65)
	if particle_mgr:
		particle_mgr.spawn_shockwave_ring(global_position, Color(0.4, 3.0, 4.5, 1.0), 220.0)
		particle_mgr.spawn_shockwave_debris(global_position, 160.0, 32)
	if player_ref and global_position.distance_to(player_ref.global_position) < 250.0:
		player_ref.take_damage(35.0)

func take_damage(amount: float) -> void:
	var effective_dmg = amount * 0.15 if is_shielded else amount
	current_health = max(0.0, current_health - effective_dmg)
	hurt_flash_timer = 0.12
	boss_health_changed.emit(current_health, max_health)

	if hud and hud.has_method("update_boss_health"):
		hud.update_boss_health(current_health, max_health)

	var cur = get_tree().current_scene
	var txt_mgr = cur.get_node_or_null("FloatingTextManager") if cur else null
	if txt_mgr and randf() < 0.4:
		txt_mgr.spawn_damage(global_position + Vector2(randf_range(-20, 20), randf_range(-30, 0)), effective_dmg, not is_shielded)

	if current_health <= 0.0:
		_die()

var is_dead: bool = false

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	boss_defeated.emit()

	if hud and hud.has_method("hide_boss_bar"):
		hud.hide_boss_bar()

	if sound_mgr and sound_mgr.has_method("play_nuke"):
		sound_mgr.play_nuke()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.95)

	# Award bonus nanites
	SaveManagerClass.add_nanites(500)

	var entities = get_tree().current_scene.get_node_or_null("Entities")
	if not entities: entities = get_parent()

	var chest = TREASURE_CHEST_SCENE.instantiate()
	chest.global_position = global_position
	entities.call_deferred("add_child", chest)

	for g in range(12):
		var gem = GEM_SCENE.instantiate()
		gem.xp_value = 120
		gem.is_super_gem = true
		var a = (TAU / 12.0) * float(g)
		gem.global_position = global_position + Vector2(cos(a) * 55.0, sin(a) * 35.0)
		entities.call_deferred("add_child", gem)

	queue_free()

func _draw() -> void:
	# 1. Massive Ground Shadow (Detached 2:1 Isometric Oval)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 52.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(Vector2.ZERO, 38.0, Color(0.0, 0.0, 0.0, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Main Dreadnought Hull
	if dreadnought_tex:
		var col = Color(5.0, 5.0, 5.0, 1.0) if hurt_flash_timer > 0.0 else Color.WHITE
		var flip = 1.0 if (player_ref and player_ref.global_position.x > global_position.x) else -1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
		draw_texture(dreadnought_tex, Vector2(-52.0, -72.0), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 3. Independent Dual Plasma Turret Mounts (Aiming at Player)
	var mounts = [Vector2(-20, -32), Vector2(20, -32)]
	for m in mounts:
		draw_set_transform(m, turret_angle, Vector2.ONE)
		# Rotating Turret Base
		draw_circle(Vector2.ZERO, 7.0, Color(0.15, 0.20, 0.28))
		draw_circle(Vector2.ZERO, 4.0, Color(0.1, 2.5, 3.5)) # Neon cyan core
		# Twin Parallel Heavy Barrels
		draw_line(Vector2(2, -3), Vector2(18, -3), Color(0.35, 0.42, 0.55), 3.0)
		draw_line(Vector2(2, 3), Vector2(18, 3), Color(0.35, 0.42, 0.55), 3.0)
		# Barrage glowing muzzle charge
		if current_state == State.BARRAGE:
			draw_circle(Vector2(18, -3), 2.5, Color(3.5, 1.8, 0.2))
			draw_circle(Vector2(18, 3), 2.5, Color(3.5, 1.8, 0.2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 4. Shield Bubble
	if is_shielded:
		var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.15 + 0.85
		draw_set_transform(Vector2(0, -20), 0.0, Vector2(1.0, 0.6))
		draw_arc(Vector2.ZERO, 68.0 * pulse, 0.0, TAU, 36, Color(0.4, 3.2, 4.8, 0.85), 4.0)
		draw_circle(Vector2.ZERO, 65.0 * pulse, Color(0.2, 1.8, 3.5, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 5. Draw Rockets
	for r in boss_rockets:
		var local_p = to_local(r.pos)
		draw_circle(local_p, 4.0, Color(0.3, 3.5, 4.8, 1.0))
		draw_circle(local_p, 2.0, Color(3.5, 3.5, 3.5, 1.0))

