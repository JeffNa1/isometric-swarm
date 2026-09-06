extends Node2D

const MORTAR_CANISTER_SCENE = preload("res://scenes/weapons/mortar_canister.tscn")

@export var damage: float = 65.0
@export var pool_damage: float = 24.0
@export var fire_rate: float = 1.8
@export var canister_count: int = 1
@export var attack_range: float = 600.0
@export var pool_radius: float = 55.0

var fire_timer: float = 0.0
var swarm_mgr: Node2D = null
var player_ref: CharacterBody2D = null
var is_evolved: bool = false

func _ready() -> void:
	_get_managers()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		swarm_mgr = cur.get_node_or_null("SwarmManager")
		player_ref = cur.get_node_or_null("Entities/Player")

func _process(delta: float) -> void:
	if not swarm_mgr or not player_ref:
		_get_managers()

	var cd_mult = player_ref.cooldown_reduction if (player_ref and "cooldown_reduction" in player_ref) else 0.0
	var actual_rate = max(0.4, fire_rate * (1.0 - cd_mult))

	fire_timer += delta
	if fire_timer >= actual_rate:
		fire_timer = 0.0
		_attempt_fire()

func _attempt_fire() -> void:
	if not swarm_mgr or swarm_mgr.active_count == 0:
		return

	var origin = global_position
	var candidates: Array[Vector2] = []
	var nearby = swarm_mgr.spatial_grid.get_nearby(origin, attack_range)

	for idx in nearby:
		if idx < swarm_mgr.active_count:
			var pos = swarm_mgr.positions[idx]
			var d = origin.distance_to(pos)
			if d <= attack_range and d > 60.0:
				candidates.append(pos)

	if candidates.is_empty():
		return

	candidates.shuffle()

	var dmg_mult = player_ref.damage_multiplier if (player_ref and "damage_multiplier" in player_ref) else 1.0
	var final_damage = damage * dmg_mult
	var final_pool_dmg = pool_damage * dmg_mult

	var shots = min(canister_count, candidates.size())
	for i in range(shots):
		var target_pos = candidates[i]
		if i > 0:
			target_pos += Vector2(randf_range(-60.0, 60.0), randf_range(-40.0, 40.0))
		_spawn_canister(target_pos, final_damage, final_pool_dmg)

func _spawn_canister(target: Vector2, d: float, pd: float) -> void:
	var canister = MORTAR_CANISTER_SCENE.instantiate()
	var entities = get_tree().current_scene.get_node_or_null("Entities")
	if not entities:
		entities = get_parent()

	entities.add_child(canister)
	canister.setup(global_position, target, d, pd, pool_radius, is_evolved)

func evolve_chernobyl() -> void:
	is_evolved = true
	canister_count = 3
	damage = 140.0
	pool_damage = 42.0
	fire_rate = 0.95
	pool_radius = 85.0
	attack_range = 700.0

func upgrade_mortar() -> void:
	canister_count = min(3, canister_count + 1)
	damage += 15.0
	pool_damage += 7.0
	pool_radius += 8.0
	fire_rate = max(0.9, fire_rate * 0.85)

func upgrade_damage(multiplier: float) -> void:
	damage *= multiplier
	pool_damage *= multiplier

func upgrade_speed(multiplier: float) -> void:
	fire_rate = max(0.5, fire_rate * multiplier)
