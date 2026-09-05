extends StaticBody2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const FIELD_PICKUP_SCENE = preload("res://scenes/field_pickup.tscn")
const GEM_SCENE = preload("res://scenes/gem.tscn")
const TREASURE_CHEST_SCENE = preload("res://scenes/treasure_chest.tscn")

@export var max_health: float = 35.0
var current_health: float = 35.0
var hurt_flash_timer: float = 0.0

static var crate_tex: ImageTexture = null

var sound_mgr: Node = null
var particle_mgr: Node2D = null
var player_ref: Node2D = null

func _ready() -> void:
	z_as_relative = false
	z_index = 4 # Render strictly above swarm (z=3)
	if not crate_tex:
		crate_tex = SpriteFactory.create_crate_texture()
	current_health = max_health
	add_to_group("crates")
	_get_managers()
	queue_redraw()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		player_ref = cur.get_node_or_null("Entities/Player")

func _process(delta: float) -> void:
	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
		queue_redraw()

	if not player_ref:
		_get_managers()

	# Player ramming / proximity damage
	if player_ref and is_instance_valid(player_ref):
		if global_position.distance_to(player_ref.global_position) < 36.0:
			take_damage(20.0 * delta)

func take_damage(amount: float) -> void:
	current_health -= amount
	hurt_flash_timer = 0.12
	queue_redraw()

	if current_health <= 0.0:
		_break_crate()

func _break_crate() -> void:
	if not sound_mgr:
		_get_managers()

	if sound_mgr and sound_mgr.has_method("play_crate_break"):
		sound_mgr.play_crate_break()

	if particle_mgr:
		particle_mgr.spawn_shockwave_debris(global_position, 20.0, 16)
		particle_mgr.spawn_sparks(global_position, Color(2.5, 1.8, 0.4, 1.0), 8)

	var entities = get_tree().current_scene.get_node_or_null("Entities")
	if not entities:
		entities = get_parent()

	var roll = randf()
	# 8% jackpot chance to drop a golden treasure chest!
	if roll < 0.08:
		var chest = TREASURE_CHEST_SCENE.instantiate()
		chest.global_position = global_position
		entities.call_deferred("add_child", chest)
	# 65% chance to drop field powerup
	elif roll < 0.73:
		var pickup = FIELD_PICKUP_SCENE.instantiate()
		var p_roll = randf()
		var p_type = "gold"
		if p_roll < 0.15: p_type = "nuke"
		elif p_roll < 0.38: p_type = "vacuum"
		elif p_roll < 0.58: p_type = "medkit"
		elif p_roll < 0.78: p_type = "overclock"
		else: p_type = "gold"

		pickup.setup(p_type)
		pickup.global_position = global_position
		entities.call_deferred("add_child", pickup)
	# 27% chance for gem cluster
	else:
		for g in range(3):
			var gem = GEM_SCENE.instantiate()
			gem.xp_value = 35
			gem.is_super_gem = true
			var off = Vector2(randf_range(-20, 20), randf_range(-14, 14))
			gem.global_position = global_position + off
			entities.call_deferred("add_child", gem)

	queue_free()

func _draw() -> void:
	if crate_tex:
		var col = Color(4.0, 4.0, 4.0, 1.0) if hurt_flash_timer > 0.0 else Color(1.0, 1.0, 1.0, 1.0)
		draw_texture(crate_tex, Vector2(-16.0, -22.0), col)
