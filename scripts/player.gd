extends CharacterBody2D

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

@onready var railgun_weapon: Node2D = $Weapons/Railgun
@onready var flame_weapon: Node2D = $Weapons/Flamethrower
@onready var shockwave_weapon: Node2D = $Weapons/Shockwave

func _ready() -> void:
	current_health = max_health
	move_speed = base_speed
	health_changed.emit(current_health, max_health)
	xp_changed.emit(xp, xp_to_next, level)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_invulnerable:
		invuln_timer -= delta
		if invuln_timer <= 0.0:
			is_invulnerable = false

	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
		queue_redraw()

	# 8-direction isometric movement
	var input_x = Input.get_action_raw_strength("move_right") - Input.get_action_raw_strength("move_left")
	var input_y = Input.get_action_raw_strength("move_down") - Input.get_action_raw_strength("move_up")
	var raw_input = Vector2(input_x, input_y)

	if raw_input.length_squared() > 0.0:
		var input_norm = raw_input.normalized()
		# 2:1 isometric movement ratio
		var iso_dir = Vector2(input_norm.x, input_norm.y * 0.75).normalized()
		velocity = velocity.move_toward(iso_dir * move_speed, 1800.0 * delta)
		walk_cycle += delta * 14.0
		if input_x != 0.0:
			facing_right = input_x > 0.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 2000.0 * delta)
		walk_cycle = move_toward(walk_cycle, 0.0, delta * 8.0)

	move_and_slide()
	queue_redraw()

func take_damage(amount: float) -> void:
	if current_health <= 0.0:
		return

	current_health = max(0.0, current_health - amount)
	hurt_flash_timer = 0.12
	health_changed.emit(current_health, max_health)
	queue_redraw()

	if current_health <= 0.0:
		player_died.emit()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.3) + 25
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)

func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"railgun":
			if railgun_weapon:
				railgun_weapon.upgrade_beam()
		"flame":
			if flame_weapon:
				flame_weapon.upgrade_flame()
		"shockwave":
			if shockwave_weapon:
				shockwave_weapon.upgrade_blast()
		"damage":
			if railgun_weapon: railgun_weapon.upgrade_damage(1.3)
		"speed":
			move_speed += 40.0
		"health":
			max_health += 40.0
			heal(80.0)

func _draw() -> void:
	# Isometric Ground Shadow (ellipse 2:1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 18.0, Color(0.0, 0.0, 0.0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var bob = sin(walk_cycle) * 2.5
	var color_body = Color(1.0, 1.0, 1.0, 1.0) if hurt_flash_timer > 0.0 else Color(0.15, 0.55, 1.0, 1.0)
	var flip = 1.0 if facing_right else -1.0

	# Heavy Armor Torso
	var body_pos = Vector2(0.0, -18.0 + bob)
	var torso_pts = PackedVector2Array([
		body_pos + Vector2(0, -14),
		body_pos + Vector2(12 * flip, -5),
		body_pos + Vector2(8 * flip, 12),
		body_pos + Vector2(-8 * flip, 12),
		body_pos + Vector2(-12 * flip, -5)
	])
	draw_colored_polygon(torso_pts, color_body)

	# Shoulder pads / pauldron
	draw_circle(body_pos + Vector2(-10 * flip, -8), 6.0, Color(0.1, 0.35, 0.8, 1.0))
	draw_circle(body_pos + Vector2(10 * flip, -8), 6.0, Color(0.1, 0.35, 0.8, 1.0))

	# Cyber Core
	draw_circle(body_pos + Vector2(2 * flip, 0), 4.0, Color(0.2, 1.0, 0.9, 1.0))

	# Helmet
	var head_pos = body_pos + Vector2(0, -18)
	draw_circle(head_pos, 8.0, Color(0.9, 0.95, 1.0, 1.0))
	draw_rect(Rect2(head_pos + Vector2(1 * flip, -1), Vector2(7 * flip, 3.5)), Color(0.1, 0.9, 1.0, 1.0))
