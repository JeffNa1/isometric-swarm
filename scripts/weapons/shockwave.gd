extends Node2D

@export var damage: float = 80.0
@export var cooldown: float = 2.2
@export var blast_radius: float = 220.0
@export var knockback: float = 400.0

var blast_timer: float = 0.0
var anim_timer: float = 0.0
var swarm_mgr: Node2D = null

func _ready() -> void:
	swarm_mgr = get_tree().current_scene.get_node_or_null("SwarmManager")

func _process(delta: float) -> void:
	if not swarm_mgr:
		swarm_mgr = get_tree().current_scene.get_node_or_null("SwarmManager")

	if anim_timer > 0.0:
		anim_timer -= delta
		queue_redraw()

	blast_timer += delta
	if blast_timer >= cooldown:
		blast_timer = 0.0
		_trigger_blast()

func _trigger_blast() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	anim_timer = 0.28
	# Clear out swarm around player
	swarm_mgr.damage_in_radius(global_position, blast_radius, damage, knockback)
	queue_redraw()

func upgrade_blast() -> void:
	blast_radius += 45.0
	damage += 25.0
	cooldown = max(1.0, cooldown * 0.85)

func _draw() -> void:
	if anim_timer > 0.0:
		var progress = 1.0 - (anim_timer / 0.28) # 0 to 1
		var current_r = blast_radius * progress
		var alpha = (1.0 - progress) * 0.7
		
		# 2:1 isometric ring compression
		draw_set_transform(Vector2(0, -10), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, current_r, 0.0, TAU, 48, Color(1.0, 0.4, 0.1, alpha), 8.0)
		draw_arc(Vector2.ZERO, current_r * 0.85, 0.0, TAU, 48, Color(1.0, 0.85, 0.2, alpha * 0.8), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
