extends CharacterBody2D

const LightHelper = preload("res://scripts/light_helper.gd")

signal health_changed(current: float, maximum: float)
signal xp_changed(current: int, target: int, lvl: int)
signal leveled_up(new_level: int)
signal player_died()

@export var max_health: float = 120.0
@export var base_speed: float = 260.0

var current_health: float = 120.0
var move_speed: float = 260.0

var xp: int = 0
var level: int = 1
var xp_to_next: int = 40

var walk_cycle: float = 0.0
var facing_right: bool = true
var is_invulnerable: bool = false
var invuln_timer: float = 0.0
var hurt_flash_timer: float = 0.0

var sound_mgr: Node = null
var camera_node: Camera2D = null
var particle_mgr: Node2D = null

@onready var aura_light: PointLight2D = $AuraLight
@onready var railgun_weapon: Node2D = $Weapons/Railgun
@onready var flame_weapon: Node2D = $Weapons/Flamethrower
@onready var shockwave_weapon: Node2D = $Weapons/Shockwave

const SpriteFactory = preload("res://scripts/sprite_factory.gd")

var player_frames: Array[ImageTexture] = []
var active_frame: int = 0

func _ready() -> void:
	current_health = max_health
	move_speed = base_speed
	health_changed.emit(current_health, max_health)
	xp_changed.emit(xp, xp_to_next, level)

	player_frames = SpriteFactory.create_player_frames()
	
	if aura_light:
		aura_light.texture = LightHelper.get_radial_texture(128)
		aura_light.energy = 0.85
		
	_get_managers()
	queue_redraw()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		sound_mgr = cur.get_node_or_null("SoundManager")
		camera_node = cur.get_node_or_null("Camera2D")
		particle_mgr = cur.get_node_or_null("ParticleManager")

func _physics_process(delta: float) -> void:
	if is_invulnerable:
		invuln_timer -= delta
		if invuln_timer <= 0.0:
			is_invulnerable = false

	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
		queue_redraw()

	var input_x = Input.get_action_raw_strength("move_right") - Input.get_action_raw_strength("move_left")
	var input_y = Input.get_action_raw_strength("move_down") - Input.get_action_raw_strength("move_up")
	var raw_input = Vector2(input_x, input_y)

	if raw_input.length_squared() > 0.0:
		var input_norm = raw_input.normalized()
		var iso_dir = Vector2(input_norm.x, input_norm.y * 0.75).normalized()
		velocity = velocity.move_toward(iso_dir * move_speed, 1800.0 * delta)
		walk_cycle += delta * 12.0
		active_frame = int(fmod(walk_cycle, 4.0))
		if input_x != 0.0:
			facing_right = input_x > 0.0
			
		# Thruster jet sparks when sprinting
		if particle_mgr and randf() < 0.35:
			var jet_pos = global_position + Vector2(-8 if facing_right else 8, 2)
			particle_mgr.spawn_sparks(jet_pos, Color(0.3, 1.5, 3.0, 1.0), 2)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 2000.0 * delta)
		walk_cycle = 0.0
		active_frame = 0

	move_and_slide()
	queue_redraw()

func take_damage(amount: float) -> void:
	if current_health <= 0.0:
		return

	current_health = max(0.0, current_health - amount)
	hurt_flash_timer = 0.12
	health_changed.emit(current_health, max_health)

	if not sound_mgr:
		_get_managers()

	if sound_mgr and sound_mgr.has_method("play_hit"):
		sound_mgr.play_hit()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.24)

	queue_redraw()

	if current_health <= 0.0:
		player_died.emit()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.3) + 25

		if not sound_mgr:
			_get_managers()
		if sound_mgr and sound_mgr.has_method("play_levelup"):
			sound_mgr.play_levelup()

		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)

func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"railgun":
			if railgun_weapon: railgun_weapon.upgrade_beam()
		"flame":
			if flame_weapon: flame_weapon.upgrade_flame()
		"shockwave":
			if shockwave_weapon: shockwave_weapon.upgrade_blast()
		"damage":
			if railgun_weapon: railgun_weapon.upgrade_damage(1.3)
		"speed":
			move_speed += 40.0
		"health":
			max_health += 40.0
			heal(80.0)

func _draw() -> void:
	if player_frames.is_empty():
		return

	var tex = player_frames[clampi(active_frame, 0, player_frames.size() - 1)]
	var flip = 1.0 if facing_right else -1.0
	var col = Color(5.0, 5.0, 5.0, 1.0) if hurt_flash_timer > 0.0 else Color(1.0, 1.0, 1.0, 1.0)

	# Transform for horizontal flip
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
	draw_texture(tex, Vector2(-24.0, -41.0), col)

	# Dynamic HDR reactor pulse accent
	var pulse = 0.8 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
	draw_circle(Vector2(0, -22), 2.5, Color(0.3 * pulse, 2.5 * pulse, 3.5 * pulse, 0.75))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
