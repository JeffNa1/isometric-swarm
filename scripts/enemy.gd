extends CharacterBody2D

const GEM_SCENE = preload("res://scenes/gem.tscn")

@export var enemy_type: String = "walker" # "walker", "scout", "brute"

var max_health: float = 35.0
var current_health: float = 35.0
var move_speed: float = 120.0
var contact_damage: float = 10.0
var xp_reward: int = 10

var player: Node2D = null
var knockback: Vector2 = Vector2.ZERO
var hit_flash_timer: float = 0.0
var attack_cooldown: float = 0.0
var walk_anim: float = 0.0
var facing_right: bool = true

func _ready() -> void:
	add_to_group("enemies")
	_setup_type_stats()
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")
	walk_anim = randf() * 10.0 # random phase
	queue_redraw()

func _setup_type_stats() -> void:
	match enemy_type:
		"scout":
			max_health = 20.0
			move_speed = 185.0
			contact_damage = 7.0
			xp_reward = 15
			$CollisionShape2D.shape.radius = 9.0
		"brute":
			max_health = 130.0
			move_speed = 75.0
			contact_damage = 25.0
			xp_reward = 40
			$CollisionShape2D.shape.radius = 18.0
		_: # "walker"
			max_health = 40.0
			move_speed = 120.0
			contact_damage = 12.0
			xp_reward = 10
			$CollisionShape2D.shape.radius = 12.0

func _physics_process(delta: float) -> void:
	walk_anim += delta * 10.0
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		queue_redraw()
		
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# Decay knockback
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)

	if player and is_instance_valid(player):
		var to_player = (player.global_position - global_position)
		var dist = to_player.length()
		
		# Isometric movement direction
		var raw_dir = to_player.normalized()
		var iso_dir = Vector2(raw_dir.x, raw_dir.y * 0.75).normalized()
		
		velocity = (iso_dir * move_speed) + knockback
		if raw_dir.x != 0.0:
			facing_right = raw_dir.x > 0.0
			
		# Attack player on contact
		if dist < ($CollisionShape2D.shape.radius + 15.0) and attack_cooldown <= 0.0:
			if player.has_method("take_damage"):
				player.take_damage(contact_damage)
				attack_cooldown = 0.5
	else:
		velocity = knockback

	move_and_slide()
	queue_redraw()

func take_damage(amount: float, knock_vec: Vector2 = Vector2.ZERO) -> void:
	current_health -= amount
	hit_flash_timer = 0.15
	var resistance = 0.4 if enemy_type == "brute" else 1.0
	knockback = knock_vec * resistance
	queue_redraw()
	
	if current_health <= 0.0:
		_die()

func _die() -> void:
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	call_deferred("_spawn_gem_and_free")

func _spawn_gem_and_free() -> void:
	var gem = GEM_SCENE.instantiate()
	var entities = get_tree().current_scene.get_node_or_null("Entities") if get_tree() and get_tree().current_scene else null
	if not entities:
		entities = get_parent()
	if entities:
		entities.add_child(gem)
		gem.global_position = global_position
		gem.xp_value = xp_reward

	if get_tree() and get_tree().current_scene and get_tree().current_scene.has_method("on_enemy_killed"):
		get_tree().current_scene.on_enemy_killed()
		
	queue_free()

func _draw() -> void:
	var flip = 1.0 if facing_right else -1.0
	var bob = sin(walk_anim) * 2.0
	
	match enemy_type:
		"scout":
			_draw_scout(flip, bob)
		"brute":
			_draw_brute(flip, bob)
		_:
			_draw_walker(flip, bob)

func _draw_walker(flip: float, bob: float) -> void:
	# Ground shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	var col = Color(1, 1, 1, 1) if hit_flash_timer > 0.0 else Color(0.9, 0.25, 0.2, 1.0)
	var pos = Vector2(0, -14.0 + bob)
	
	# Spider/Demon torso
	var pts = PackedVector2Array([
		pos + Vector2(0, -10),
		pos + Vector2(10 * flip, -2),
		pos + Vector2(6 * flip, 10),
		pos + Vector2(-6 * flip, 10),
		pos + Vector2(-10 * flip, -2)
	])
	draw_colored_polygon(pts, col)
	
	# Glowing red eye
	draw_circle(pos + Vector2(4 * flip, -2), 3.0, Color(1.0, 0.9, 0.1, 1.0))
	draw_circle(pos + Vector2(4 * flip, -2), 1.2, Color(1.0, 0.0, 0.0, 1.0))

func _draw_scout(flip: float, bob: float) -> void:
	# Ground shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var col = Color(1, 1, 1, 1) if hit_flash_timer > 0.0 else Color(0.7, 0.2, 0.9, 1.0)
	var pos = Vector2(0, -18.0 + bob * 1.5)
	
	# Bat/Imp Wings
	var wing_spread = sin(walk_anim * 1.8) * 8.0
	var wing_left = PackedVector2Array([
		pos, pos + Vector2(-14 * flip, -8 + wing_spread), pos + Vector2(-6 * flip, 4)
	])
	var wing_right = PackedVector2Array([
		pos, pos + Vector2(14 * flip, -8 + wing_spread), pos + Vector2(6 * flip, 4)
	])
	draw_colored_polygon(wing_left, Color(0.4, 0.1, 0.6, 0.85))
	draw_colored_polygon(wing_right, Color(0.4, 0.1, 0.6, 0.85))
	
	# Body
	draw_circle(pos, 7.0, col)
	draw_circle(pos + Vector2(2 * flip, -1), 2.0, Color(0.2, 1.0, 0.4, 1.0))

func _draw_brute(flip: float, bob: float) -> void:
	# Ground shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var col = Color(1, 1, 1, 1) if hit_flash_timer > 0.0 else Color(0.85, 0.45, 0.1, 1.0)
	var pos = Vector2(0, -22.0 + bob * 0.6)
	
	# Huge Golem Body
	var pts = PackedVector2Array([
		pos + Vector2(-16, -18),
		pos + Vector2(16, -18),
		pos + Vector2(18 * flip, 4),
		pos + Vector2(10 * flip, 18),
		pos + Vector2(-10 * flip, 18),
		pos + Vector2(-18 * flip, 4)
	])
	draw_colored_polygon(pts, col)
	draw_circle(pos + Vector2(0, -14), 6.0, Color(0.3, 0.15, 0.05, 1.0))
	draw_circle(pos + Vector2(3 * flip, -14), 2.5, Color(1.0, 0.2, 0.0, 1.0))
