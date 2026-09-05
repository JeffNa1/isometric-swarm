extends Node2D

const MISSILE_SCENE = preload("res://scenes/weapons/missile_projectile.tscn")

@export var damage: float = 40.0
@export var fire_rate: float = 1.2 # seconds between shots
@export var missiles_per_volley: int = 1
@export var attack_range: float = 500.0

var fire_timer: float = 0.0

func _process(delta: float) -> void:
	fire_timer += delta
	if fire_timer >= fire_rate:
		fire_timer = 0.0
		_attempt_fire()

func _attempt_fire() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
		
	# Sort enemies by distance
	var player_pos = global_position
	var sorted_enemies = []
	for e in enemies:
		if is_instance_valid(e):
			var dist = player_pos.distance_to(e.global_position)
			if dist <= attack_range:
				sorted_enemies.append({"enemy": e, "dist": dist})
				
	if sorted_enemies.is_empty():
		return
		
	sorted_enemies.sort_custom(func(a, b): return a.dist < b.dist)
	
	# Fire volley
	var shots = min(missiles_per_volley, sorted_enemies.size())
	for i in range(shots):
		var target = sorted_enemies[i].enemy
		_spawn_missile(target)

func _spawn_missile(target: Node2D) -> void:
	var projectile = MISSILE_SCENE.instantiate()
	var dir = (target.global_position - global_position).normalized()
	# Spawn at entities container or root
	var entities = get_tree().current_scene.get_node_or_null("Entities")
	if not entities:
		entities = get_parent()
		
	entities.add_child(projectile)
	projectile.global_position = global_position + Vector2(0, -16)
	projectile.setup(dir, target, damage)

func upgrade_missile() -> void:
	missiles_per_volley += 1
	damage += 10.0
	fire_rate = max(0.4, fire_rate * 0.85)

func upgrade_damage(multiplier: float) -> void:
	damage *= multiplier

func upgrade_speed(multiplier: float) -> void:
	fire_rate = max(0.3, fire_rate * multiplier)
