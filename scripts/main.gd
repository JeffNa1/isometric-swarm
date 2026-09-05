extends Node2D

const PylonScene = preload("res://scenes/pylon.tscn")
const GemScene = preload("res://scenes/gem.tscn")
const CrateScene = preload("res://scenes/crate.tscn")
const BossScene = preload("res://scenes/boss.tscn")

@onready var arena: Node2D = $Arena
@onready var swarm_mgr: Node2D = $SwarmManager
@onready var player: CharacterBody2D = $Entities/Player
@onready var pylons_container: Node2D = $Entities/Pylons
@onready var entities_container: Node2D = $Entities
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD
@onready var sound_mgr: Node = $SoundManager

var total_kills: int = 0
var elapsed_time: float = 0.0
var spawn_timer: float = 0.0

# Scripted Wave Director Flags
var surge_triggered: bool = false
var titans_triggered: bool = false
var apocalypse_triggered: bool = false
var boss_spawned: bool = false

func _ready() -> void:
	_setup_inputs_if_needed()
	_connect_signals()
	_spawn_pylons()
	_spawn_crates()
	# Scrappy Start: Trickle in only 10 initial crawlers
	_spawn_initial_horde()

func _spawn_pylons() -> void:
	if not pylons_container:
		return
	var count = 50
	for i in range(count):
		var pylon = PylonScene.instantiate()
		var p_pos = Vector2.ZERO
		while true:
			p_pos = Vector2(
				randf_range(-4400.0, 4400.0),
				randf_range(-4400.0, 4400.0)
			)
			if p_pos.length() > 380.0:
				break
		pylon.position = p_pos
		pylons_container.add_child(pylon)

func _spawn_crates() -> void:
	if not entities_container:
		return
	var count = 65
	for i in range(count):
		var crate = CrateScene.instantiate()
		var c_pos = Vector2.ZERO
		while true:
			c_pos = Vector2(
				randf_range(-4400.0, 4400.0),
				randf_range(-4400.0, 4400.0)
			)
			if c_pos.length() > 250.0:
				break
		crate.position = c_pos
		entities_container.add_child(crate)

func vacuum_all_gems() -> void:
	if not is_instance_valid(player):
		return
	var gems = get_tree().get_nodes_in_group("gems")
	for g in gems:
		if is_instance_valid(g) and g.has_method("attract_to"):
			g.attract_to(player)

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
	# Only 12 initial Crawlers to test basic kiting with Railgun Lv1
	for i in range(3):
		var angle = (TAU / 3.0) * float(i)
		var offset = Vector2(cos(angle) * 450.0, sin(angle) * 250.0)
		swarm_mgr.spawn_cluster(player.global_position + offset, 4, 0)

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	elapsed_time += delta

	# Camera follows player smoothly
	if is_instance_valid(player):
		camera.global_position = camera.global_position.lerp(player.global_position, 8.0 * delta)

	# --- SCRIPTED SPAWN DIRECTOR (Vampire Survivors Pacing Curve) ---
	_process_spawn_director(delta)

func _process_spawn_director(delta: float) -> void:
	spawn_timer += delta

	# Phase 1: 00:00 - 00:45 | The Trickle (Early scrappy kiting)
	if elapsed_time < 45.0:
		if spawn_timer >= 2.2:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 60:
				_spawn_wave_cluster(randi_range(6, 12), 0)

	# Phase 2: 00:45 - 02:00 | Scout Flankers (Pincer mobility test)
	elif elapsed_time < 120.0:
		if spawn_timer >= 1.6:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 260:
				var e_type = 1 if randf() < 0.35 else 0
				_spawn_wave_cluster(randi_range(16, 28), e_type)

	# Phase 3: 02:00 - 03:30 | Crimson Swarm Surge (Surround & AoE test)
	elif elapsed_time < 210.0:
		if not surge_triggered:
			surge_triggered = true
			_trigger_swarm_surge()

		if spawn_timer >= 1.2:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 1100:
				var e_type = 1 if randf() < 0.3 else 0
				_spawn_wave_cluster(randi_range(35, 60), e_type)

	# Phase 4: 03:30 - 05:00 | Titan Behemoths (Mini-Bosses & Super Drops)
	elif elapsed_time < 300.0:
		if not titans_triggered:
			titans_triggered = true
			_trigger_titan_wave()

		if spawn_timer >= 1.0:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 2200:
				var roll = randf()
				var e_type = 2 if roll < 0.12 else (1 if roll < 0.4 else 0)
				_spawn_wave_cluster(randi_range(40, 75), e_type)

	# Phase 5: 05:00+ | Apocalyptic Swarm & Apex Leviathan Boss
	else:
		if not boss_spawned:
			boss_spawned = true
			_spawn_boss()

		if not apocalypse_triggered:
			apocalypse_triggered = true
			if hud.has_method("show_surge_warning"):
				hud.show_surge_warning("💀 NGUY HIỂM TỘT CÙNG: KHẢI HUYỀN TẬN DIỆT! 💀")
			if sound_mgr and sound_mgr.has_method("play_alarm"):
				sound_mgr.play_alarm()

		if spawn_timer >= 0.85:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 4200:
				var roll = randf()
				var e_type = 2 if roll < 0.18 else (1 if roll < 0.45 else 0)
				_spawn_wave_cluster(randi_range(60, 110), e_type)

func _spawn_boss() -> void:
	if not entities_container or not is_instance_valid(player):
		return
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud and hud.has_method("show_surge_warning"):
		hud.show_surge_warning("💀 BÁ CHỦ VỰC THẲM: APEX LEVIATHAN ĐÃ XUẤT HIỆN! 💀")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.65)

	var boss = BossScene.instantiate()
	boss.global_position = player.global_position + Vector2(650.0, -100.0)
	entities_container.add_child(boss)

func _trigger_swarm_surge() -> void:
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud.has_method("show_surge_warning"):
		hud.show_surge_warning("⚠️ CẢNH BÁO: ĐỢT SÓNG QUÁI VÂY HÃM! ⚠️")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.35)

	# Ring of 280 Crawlers closing in from all directions
	var ring_count = 280
	var player_pos = player.global_position if is_instance_valid(player) else Vector2.ZERO
	for i in range(ring_count):
		var angle = (TAU / float(ring_count)) * float(i)
		var spawn_pos = player_pos + Vector2(cos(angle) * 900.0, sin(angle) * 500.0)
		spawn_pos.x = clamp(spawn_pos.x, -4700.0, 4700.0)
		spawn_pos.y = clamp(spawn_pos.y, -4700.0, 4700.0)
		swarm_mgr.spawn_enemy(spawn_pos, 0)

func _trigger_titan_wave() -> void:
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud.has_method("show_surge_warning"):
		hud.show_surge_warning("⚠️ CỰ THÚ VOLCANIC BEHEMOTH TIẾP CẬN! ⚠️")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.4)

	# Spawn 4 Volcanic Behemoths in cardinal directions
	var player_pos = player.global_position if is_instance_valid(player) else Vector2.ZERO
	var dirs = [Vector2(750, 0), Vector2(-750, 0), Vector2(0, 450), Vector2(0, -450)]
	for d in dirs:
		swarm_mgr.spawn_enemy(player_pos + d, 2)

func _spawn_wave_cluster(count: int, enemy_type: int) -> void:
	if not is_instance_valid(player):
		return

	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2(
		cos(angle) * randf_range(750.0, 950.0),
		sin(angle) * randf_range(420.0, 520.0)
	)
	spawn_pos.x = clamp(spawn_pos.x, -4700.0, 4700.0)
	spawn_pos.y = clamp(spawn_pos.y, -4700.0, 4700.0)

	swarm_mgr.spawn_cluster(spawn_pos, count, enemy_type)

func _on_enemy_killed(xp_val: int, pos: Vector2, is_boss: bool) -> void:
	total_kills += 1
	hud.set_kills(total_kills)

	# Spawn physical XP Gem (Drop chance 65% for fodder, 100% for bosses)
	if randf() < 0.65 or is_boss:
		var gem = GemScene.instantiate()
		gem.xp_value = xp_val
		gem.is_super_gem = is_boss
		gem.global_position = pos
		entities_container.call_deferred("add_child", gem)

func _on_player_died() -> void:
	hud.show_game_over(player.level)
