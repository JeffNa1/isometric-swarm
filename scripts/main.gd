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

# Combo Multikill System
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 2.0
var next_combo_milestone: int = 25

# Internal tracked list of gems (O(1) lookups, zero tree traversal)
var active_gems: Array[Node2D] = []

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
	for g in active_gems:
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
	# Massive initial swarm: 8 clusters of 8 Crawlers = 64 Crawlers scurrying right away!
	for i in range(8):
		var angle = (TAU / 8.0) * float(i)
		var offset = Vector2(cos(angle) * 500.0, sin(angle) * 300.0)
		swarm_mgr.spawn_cluster(player.global_position + offset, 8, 0)

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	elapsed_time += delta

	# Combo decay
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			next_combo_milestone = 25
			if hud and hud.has_method("update_combo"):
				hud.update_combo(0)

	# Camera follows player smoothly
	if is_instance_valid(player):
		camera.global_position = camera.global_position.lerp(player.global_position, 8.0 * delta)

	# --- SCRIPTED SPAWN DIRECTOR (High Density Swarm Survivor Pacing) ---
	_process_spawn_director(delta)

func _process_spawn_director(delta: float) -> void:
	spawn_timer += delta

	# Phase 1: 00:00 - 00:45 | Immediate Swarm Influx (Culling Fodder)
	if elapsed_time < 45.0:
		if spawn_timer >= 0.95:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 380:
				_spawn_wave_cluster(randi_range(28, 48), 0)

	# Phase 2: 00:45 - 02:00 | Scout Flankers & Dense Packs
	elif elapsed_time < 120.0:
		if spawn_timer >= 0.75:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 1400:
				var e_type = 1 if randf() < 0.35 else 0
				_spawn_wave_cluster(randi_range(50, 95), e_type)

	# Phase 3: 02:00 - 03:30 | Crimson Swarm Surge (Surround & AoE Slaughter)
	elif elapsed_time < 210.0:
		if not surge_triggered:
			surge_triggered = true
			_trigger_swarm_surge()

		if spawn_timer >= 0.62:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 2800:
				var e_type = 1 if randf() < 0.3 else 0
				_spawn_wave_cluster(randi_range(80, 150), e_type)

	# Phase 4: 03:30 - 05:00 | Titan Behemoths & Giant Hordes
	elif elapsed_time < 300.0:
		if not titans_triggered:
			titans_triggered = true
			_trigger_titan_wave()

		if spawn_timer >= 0.52:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 3800:
				var roll = randf()
				var e_type = 2 if roll < 0.12 else (1 if roll < 0.4 else 0)
				_spawn_wave_cluster(randi_range(120, 220), e_type)

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

		if spawn_timer >= 0.45:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 4800:
				var roll = randf()
				var e_type = 2 if roll < 0.16 else (1 if roll < 0.45 else 0)
				_spawn_wave_cluster(randi_range(160, 280), e_type)

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
		camera.add_trauma(0.4)

	# Ring of 450 Crawlers closing in from all directions
	var ring_count = 450
	var player_pos = player.global_position if is_instance_valid(player) else Vector2.ZERO
	for i in range(ring_count):
		var angle = (TAU / float(ring_count)) * float(i)
		var spawn_pos = player_pos + Vector2(cos(angle) * 950.0, sin(angle) * 550.0)
		spawn_pos.x = clamp(spawn_pos.x, -4700.0, 4700.0)
		spawn_pos.y = clamp(spawn_pos.y, -4700.0, 4700.0)
		swarm_mgr.spawn_enemy(spawn_pos, 0)

func _trigger_titan_wave() -> void:
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud.has_method("show_surge_warning"):
		hud.show_surge_warning("⚠️ CỰ THÚ VOLCANIC BEHEMOTH TIẾP CẬN! ⚠️")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.45)

	# Spawn 8 Volcanic Behemoths in a ring
	var player_pos = player.global_position if is_instance_valid(player) else Vector2.ZERO
	for i in range(8):
		var angle = (TAU / 8.0) * float(i)
		var d = Vector2(cos(angle) * 750.0, sin(angle) * 450.0)
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

	# Combo Multikill System
	combo_count += 1
	combo_timer = COMBO_TIMEOUT
	if hud and hud.has_method("update_combo"):
		hud.update_combo(combo_count)

	if combo_count >= next_combo_milestone:
		_trigger_combo_announcement(combo_count)
		if combo_count >= 500:
			next_combo_milestone += 250
		elif combo_count >= 100:
			next_combo_milestone += 100
		elif combo_count >= 50:
			next_combo_milestone = 100
		else:
			next_combo_milestone = 50

	# Spawn physical XP Gem (Drop chance 30% for fodder, 100% for bosses)
	if randf() < 0.30 or is_boss:
		if active_gems.size() >= 300 and not is_boss:
			# Vampire Survivors gem consolidation: upgrade an existing gem instead of creating new node
			var target_gem = active_gems[randi() % active_gems.size()]
			if is_instance_valid(target_gem):
				target_gem.xp_value += xp_val
				target_gem.is_super_gem = true
				target_gem.queue_redraw()
		else:
			var gem = GemScene.instantiate()
			gem.xp_value = xp_val
			gem.is_super_gem = is_boss
			gem.global_position = pos
			active_gems.append(gem)
			gem.tree_exited.connect(func(): active_gems.erase(gem))
			entities_container.call_deferred("add_child", gem)

func _trigger_combo_announcement(streak: int) -> void:
	var title = "🔥 %d COMBO!" % streak
	var col = Color(1.0, 0.85, 0.2, 1.0)
	if streak >= 500:
		title = "👑 %d DIỆT VỰC THẲM THẦN THÁNH! 👑" % streak
		col = Color(1.0, 0.2, 0.6, 1.0)
	elif streak >= 250:
		title = "💥 %d HỦY DIỆT KHÔNG THỂ CẢN! 💥" % streak
		col = Color(1.0, 0.3, 0.2, 1.0)
	elif streak >= 100:
		title = "💀 %d CUỒNG NỘ ĐẪM MÁU! 💀" % streak
		col = Color(0.9, 0.2, 1.0, 1.0)
	elif streak >= 50:
		title = "⚡ %d ĐẠI ĐỒ SÁT! ⚡" % streak
		col = Color(0.2, 0.9, 1.0, 1.0)

	if hud and hud.has_method("show_combo_milestone"):
		hud.show_combo_milestone(title, col)

	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.3)

func _on_player_died() -> void:
	hud.show_game_over(player.level)
