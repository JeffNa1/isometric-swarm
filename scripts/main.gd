extends Node2D

@onready var arena: Node2D = $Arena
@onready var swarm_mgr: Node2D = $SwarmManager
@onready var player: CharacterBody2D = $Entities/Player
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD

var total_kills: int = 0
var elapsed_time: float = 0.0
var cluster_timer: float = 0.0
var cluster_interval: float = 1.6

func _ready() -> void:
	_setup_inputs_if_needed()
	_connect_signals()
	# Spawn initial swarm horde immediately (200 units)
	_spawn_initial_horde()

func _setup_inputs_if_needed() -> void:
	var bindings = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN]
	}
	for action in bindings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in bindings[action]:
				var ev = InputEventKey.new()
				ev.keycode = k
				InputMap.action_add_event(action, ev)

func _connect_signals() -> void:
	player.health_changed.connect(hud.update_health)
	player.xp_changed.connect(hud.update_xp)
	player.leveled_up.connect(hud.show_level_up)
	player.player_died.connect(_on_player_died)
	hud.upgrade_selected.connect(player.apply_upgrade)

	swarm_mgr.enemy_killed.connect(_on_enemy_killed)
	swarm_mgr.swarm_count_changed.connect(hud.set_swarm_count)

func _spawn_initial_horde() -> void:
	for i in range(4):
		var angle = (TAU / 4.0) * float(i)
		var offset = Vector2(cos(angle) * 700.0, sin(angle) * 380.0)
		swarm_mgr.spawn_cluster(player.global_position + offset, 50, 0)

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	elapsed_time += delta
	# Camera follows player smoothly
	if is_instance_valid(player):
		camera.global_position = camera.global_position.lerp(player.global_position, 8.0 * delta)

	# Wave spawner: ramps up cluster size over time
	cluster_timer += delta
	if cluster_timer >= cluster_interval:
		cluster_timer = 0.0
		_spawn_horde_cluster()

func _spawn_horde_cluster() -> void:
	if not is_instance_valid(player) or swarm_mgr.active_count >= 4800:
		return

	# Cluster size scales with time: 40 to 120 units per cluster
	var count = int(40 + min(elapsed_time * 0.75, 90.0))
	var angle = randf() * TAU
	# Spawn in isometric ellipse around player (approx 850x450)
	var spawn_pos = player.global_position + Vector2(
		cos(angle) * 850.0,
		sin(angle) * 450.0
	)
	# Clamp inside arena bounds
	spawn_pos.x = clamp(spawn_pos.x, -4700.0, 4700.0)
	spawn_pos.y = clamp(spawn_pos.y, -4700.0, 4700.0)

	var roll = randf()
	var e_type = 0
	if elapsed_time > 50.0 and roll < 0.2:
		e_type = 2 # Brute
		count = int(count * 0.4) # fewer brutes
	elif elapsed_time > 20.0 and roll < 0.5:
		e_type = 1 # Scout

	swarm_mgr.spawn_cluster(spawn_pos, count, e_type)

func _on_enemy_killed(xp_val: int, _pos: Vector2) -> void:
	total_kills += 1
	hud.set_kills(total_kills)
	if is_instance_valid(player):
		player.add_xp(xp_val)

func _on_player_died() -> void:
	hud.show_game_over(player.level)
