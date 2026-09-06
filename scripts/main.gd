extends Node2D

const PylonScene = preload("res://scenes/pylon.tscn")
const GemScene = preload("res://scenes/gem.tscn")
const CrateScene = preload("res://scenes/crate.tscn")
const BossScene = preload("res://scenes/boss.tscn")
const BossDreadnoughtScene = preload("res://scenes/boss_dreadnought.tscn")
const TreasureChestScene = preload("res://scenes/treasure_chest.tscn")

@onready var arena: Node2D = $Arena
@onready var swarm_mgr: Node2D = $SwarmManager
@onready var player: CharacterBody2D = $Entities/Player
@onready var pylons_container: Node2D = $Entities/Pylons
@onready var entities_container: Node2D = $Entities
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD
@onready var sound_mgr: Node = $SoundManager
@onready var post_process_rect: ColorRect = get_node_or_null("PostProcessLayer/PostProcessRect")
var post_material: ShaderMaterial = null

var shockwave_active: bool = false
var shockwave_progress: float = 0.0
var shockwave_speed: float = 2.4

var chromatic_timer: float = 0.0
var chromatic_duration: float = 0.0
var chromatic_max_intensity: float = 0.0

var vignette_timer: float = 0.0
var vignette_duration: float = 0.0
var vignette_max_intensity: float = 0.0

var total_kills: int = 0
var elapsed_time: float = 0.0
var spawn_timer: float = 0.0
var supply_drop_timer: float = 0.0

# Scripted Wave Director Flags
var surge_triggered: bool = false
var titans_triggered: bool = false
var spitters_triggered: bool = false
var exploders_triggered: bool = false
var boss_spawned: bool = false
var boss2_spawned: bool = false
var victory_triggered: bool = false
var is_endless_overtime: bool = false
var enrage_level: int = 0

# Combo Multikill System
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 2.2
var next_combo_milestone: int = 5

# Internal tracked list of gems (O(1) lookups, zero tree traversal)
var active_gems: Array[Node2D] = []

func _ready() -> void:
	if post_process_rect and post_process_rect.material is ShaderMaterial:
		post_material = post_process_rect.material
	_setup_inputs_if_needed()
	_connect_signals()
	_spawn_pylons()
	_spawn_crates()
	_spawn_initial_horde()

func _spawn_pylons() -> void:
	if not pylons_container:
		return
	var count = 40
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

	# 1. Starting Sector Crates (14 crates immediately visible around player)
	for i in range(14):
		var crate = CrateScene.instantiate()
		var angle = randf() * TAU
		var dist = randf_range(160.0, 600.0)
		crate.position = Vector2(cos(angle) * dist, sin(angle) * dist * 0.65)
		entities_container.add_child(crate)

	# 2. Arena Exploration Crates (85 crates across active radius)
	for i in range(85):
		var crate = CrateScene.instantiate()
		var angle = randf() * TAU
		var dist = randf_range(650.0, 3600.0)
		crate.position = Vector2(cos(angle) * dist, sin(angle) * dist * 0.7)
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
	for i in range(8):
		var angle = (TAU / 8.0) * float(i)
		var offset = Vector2(cos(angle) * 500.0, sin(angle) * 300.0)
		swarm_mgr.spawn_cluster(player.global_position + offset, 8, 0)

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	elapsed_time += delta

	# Post-processing shader animations
	if shockwave_active and post_material:
		shockwave_progress += shockwave_speed * delta
		if shockwave_progress >= 1.0:
			shockwave_active = false
			shockwave_progress = 0.0
		post_material.set_shader_parameter("shockwave_progress", shockwave_progress)

	if chromatic_timer > 0.0 and post_material:
		chromatic_timer -= delta
		var p = clamp(chromatic_timer / max(0.001, chromatic_duration), 0.0, 1.0)
		post_material.set_shader_parameter("chromatic_aberration_intensity", chromatic_max_intensity * p)

	if vignette_timer > 0.0 and post_material:
		vignette_timer -= delta
		var p = clamp(vignette_timer / max(0.001, vignette_duration), 0.0, 1.0)
		post_material.set_shader_parameter("damage_vignette_intensity", vignette_max_intensity * p)

	# Combo decay
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			next_combo_milestone = 5
			if hud and hud.has_method("update_combo"):
				hud.update_combo(0)

	# Periodic supply crate airdrop
	supply_drop_timer += delta
	if supply_drop_timer >= 40.0:
		supply_drop_timer = 0.0
		_drop_supply_crate()

	# Camera follows player smoothly
	if is_instance_valid(player):
		camera.global_position = camera.global_position.lerp(player.global_position, 8.0 * delta)

	# --- 15-MINUTE EXPANDED WAVE DIRECTOR ---
	_process_spawn_director(delta)

func _drop_supply_crate() -> void:
	if not entities_container or not is_instance_valid(player):
		return
	var crate = CrateScene.instantiate()
	var angle = randf() * TAU
	var offset = Vector2(cos(angle) * 350.0, sin(angle) * 220.0)
	crate.position = player.global_position + offset
	entities_container.add_child(crate)
	if hud and hud.has_method("show_surge_warning"):
		hud.show_surge_warning("📦 THÙNG TIẾP TẾ CHIẾN THUẬT ĐÃ ĐÁP XUỐNG! 📦")

func _process_spawn_director(delta: float) -> void:
	spawn_timer += delta

	# Phase 1: 00:00 - 01:30 | Early Swarm (Crawlers)
	if elapsed_time < 90.0:
		if spawn_timer >= 0.90:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 450:
				_spawn_wave_cluster(randi_range(30, 55), 0)

	# Phase 2: 01:30 - 03:00 | Scout Swarm Flankers
	elif elapsed_time < 180.0:
		if not surge_triggered:
			surge_triggered = true
			_trigger_swarm_surge()

		if spawn_timer >= 0.70:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 1500:
				var e_type = 1 if randf() < 0.4 else 0
				_spawn_wave_cluster(randi_range(60, 110), e_type)

	# Phase 3: 03:00 - 05:00 | Toxic Spitters & Brutes
	elif elapsed_time < 300.0:
		if not spitters_triggered:
			spitters_triggered = true
			if hud.has_method("show_surge_warning"):
				hud.show_surge_warning("☣️ CẢNH BÁO: BỌ PHUN ĐỘC TẦM XA TIẾP CẬN! ☣️")

		if spawn_timer >= 0.60:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 2600:
				var roll = randf()
				var e_type = 3 if roll < 0.25 else (2 if roll < 0.35 else (1 if roll < 0.6 else 0))
				_spawn_wave_cluster(randi_range(80, 150), e_type)

	# Phase 4: 05:00 - 07:30 | Boss 1: Apex Leviathan
	elif elapsed_time < 450.0:
		if not boss_spawned:
			boss_spawned = true
			_spawn_boss_leviathan()

		if spawn_timer >= 0.52:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 3200:
				var roll = randf()
				var e_type = 3 if roll < 0.2 else (2 if roll < 0.35 else (1 if roll < 0.6 else 0))
				_spawn_wave_cluster(randi_range(100, 180), e_type)

	# Phase 5: 07:30 - 10:00 | Kamikaze Exploders Surge
	elif elapsed_time < 600.0:
		if not exploders_triggered:
			exploders_triggered = true
			if hud.has_method("show_surge_warning"):
				hud.show_surge_warning("⚠️ NGUY CẤP: BẦY BỌ TỰ NỔ CẢM TỬ LAO TỚI! ⚠️")
			if sound_mgr and sound_mgr.has_method("play_alarm"):
				sound_mgr.play_alarm()

		if spawn_timer >= 0.48:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 3800:
				var roll = randf()
				var e_type = 4 if roll < 0.35 else (3 if roll < 0.55 else (2 if roll < 0.7 else 0))
				_spawn_wave_cluster(randi_range(110, 200), e_type)

	# Phase 6: 10:00 - 12:30 | Boss 2: Cyber Dreadnought
	elif elapsed_time < 750.0:
		if not boss2_spawned:
			boss2_spawned = true
			_spawn_boss_dreadnought()

		if spawn_timer >= 0.45:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 4200:
				var e_type = randi() % 5
				_spawn_wave_cluster(randi_range(130, 220), e_type)

	# Phase 7: 12:30 - 15:00 | Full Apocalypse Swarm (All 5 Enemy Types)
	elif elapsed_time < 900.0:
		if not titans_triggered:
			titans_triggered = true
			_trigger_titan_wave()

		if spawn_timer >= 0.40:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 4800:
				var e_type = randi() % 5
				_spawn_wave_cluster(randi_range(150, 260), e_type)

	# Phase 8: 15:00+ | Victory / Endless Overtime Mode
	else:
		if not victory_triggered:
			victory_triggered = true
			is_endless_overtime = true
			if hud.has_method("show_surge_warning"):
				hud.show_surge_warning("👑 CHIẾN THẮNG 15 PHÚT! KÍCH HOẠT CHẾ ĐỘ VÔ TẬN! 👑")

		# Ramp Enrage level every 90 seconds in overtime
		var current_enrage = int((elapsed_time - 900.0) / 90.0) + 1
		if current_enrage > enrage_level:
			enrage_level = current_enrage
			if hud.has_method("show_surge_warning"):
				hud.show_surge_warning("🔥 CUỒNG NỘ VÔ TẬN CẤP %d: QUÁI TĂNG TỐC & SÁT THƯƠNG! 🔥" % enrage_level)

		if spawn_timer >= 0.38:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 5000:
				var e_type = randi() % 5
				_spawn_wave_cluster(randi_range(160, 280), e_type)

func _spawn_boss_leviathan() -> void:
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

func _spawn_boss_dreadnought() -> void:
	if not entities_container or not is_instance_valid(player):
		return
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud and hud.has_method("show_surge_warning"):
		hud.show_surge_warning("⚡ CHIẾN HẠM TITAN: CYBER DREADNOUGHT TIẾP CẬN! ⚡")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.75)

	var boss = BossDreadnoughtScene.instantiate()
	boss.global_position = player.global_position + Vector2(-650.0, 100.0)
	entities_container.add_child(boss)

func _trigger_swarm_surge() -> void:
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud.has_method("show_surge_warning"):
		hud.show_surge_warning("⚠️ CẢNH BÁO: ĐỢT SÓNG QUÁI VÂY HÃM! ⚠️")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.4)

	var ring_count = 350
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

func register_gem(gem: Node2D) -> void:
	active_gems.append(gem)
	gem.tree_exited.connect(_on_gem_exited.bind(gem))

func _on_gem_exited(gem: Node2D) -> void:
	active_gems.erase(gem)

func spawn_gem(pos: Vector2, xp_val: int, is_boss: bool) -> void:
	# 1. Merge into nearby stationary gem if within 75px
	for g in active_gems:
		if is_instance_valid(g) and g.is_inside_tree() and g.target == null:
			if g.global_position.distance_squared_to(pos) <= 5625.0:
				g.xp_value += xp_val
				g.queue_redraw()
				return

	# 2. Cap 90 gems
	if active_gems.size() >= 90 and not is_boss:
		var best_gem = active_gems[0]
		best_gem.xp_value += xp_val
		best_gem.queue_redraw()
		return

	var gem = GemScene.instantiate()
	gem.xp_value = xp_val
	gem.is_super_gem = is_boss
	gem.position = pos
	entities_container.call_deferred("add_child", gem)
	register_gem(gem)

func _on_enemy_killed(xp_val: int, pos: Vector2, is_boss: bool) -> void:
	total_kills += 1
	hud.set_kills(total_kills)

	combo_count += 1
	combo_timer = COMBO_TIMEOUT
	if hud and hud.has_method("update_combo"):
		hud.update_combo(combo_count)

	if combo_count >= next_combo_milestone:
		_trigger_combo_announcement(combo_count)
		if combo_count >= 500:
			next_combo_milestone += 250
		elif combo_count >= 250:
			next_combo_milestone = 500
		elif combo_count >= 100:
			next_combo_milestone = 250
		elif combo_count >= 75:
			next_combo_milestone = 100
		elif combo_count >= 50:
			next_combo_milestone = 75
		elif combo_count >= 25:
			next_combo_milestone = 50
		elif combo_count >= 10:
			next_combo_milestone = 25
		elif combo_count >= 5:
			next_combo_milestone = 10
		else:
			next_combo_milestone = 5

	# Spawn Gem with cluster consolidation
	if randf() < 0.75 or is_boss:
		spawn_gem(pos, xp_val, is_boss)

	# Mini-Boss Chest Drop (2.5% chance from Brute mini-bosses)
	if is_boss and randf() < 0.025:
		var chest = TreasureChestScene.instantiate()
		chest.global_position = pos
		entities_container.call_deferred("add_child", chest)

func _trigger_combo_announcement(streak: int) -> void:
	var title = "⚡ %d COMBO!" % streak
	var col = Color(1.0, 0.85, 0.2, 1.0)
	if streak >= 500:
		title = "👑 %d DIỆT VỰC THẲM THẦN THÁNH! 👑" % streak
		col = Color(1.0, 0.2, 0.6, 1.0)
	elif streak >= 250:
		title = "💥 %d HỦY DIỆT KHÔNG THỂ CẢN! 💥" % streak
		col = Color(1.0, 0.3, 0.2, 1.0)
	elif streak >= 100:
		title = "☣️ %d EXTINCTION EVENT! ☣️" % streak
		col = Color(1.0, 0.2, 0.3, 1.0)
	elif streak >= 75:
		title = "👑 %d GODLIKE! 👑" % streak
		col = Color(1.0, 0.6, 0.1, 1.0)
	elif streak >= 50:
		title = "💀 %d UNSTOPPABLE! 💀" % streak
		col = Color(0.9, 0.2, 1.0, 1.0)
	elif streak >= 25:
		title = "💥 %d RAMPAGE! 💥" % streak
		col = Color(0.2, 1.0, 0.5, 1.0)
	elif streak >= 10:
		title = "🔥 %d ULTRA KILL! 🔥" % streak
		col = Color(0.3, 0.9, 1.0, 1.0)
	elif streak >= 5:
		title = "⚡ %d MEGA KILL! ⚡" % streak
		col = Color(0.4, 0.8, 1.0, 1.0)

	if hud and hud.has_method("show_combo_milestone"):
		hud.show_combo_milestone(title, col)

	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.35)
	if camera and camera.has_method("trigger_zoom_punch"):
		camera.trigger_zoom_punch(0.04, 0.2)

	trigger_chromatic_aberration_pulse(0.018, 0.16)

func _on_player_died() -> void:
	hud.show_game_over(player.level, elapsed_time, total_kills)

func trigger_shockwave(world_pos: Vector2, force: float = 0.045) -> void:
	if not post_material or not is_instance_valid(camera):
		return
	var viewport = get_viewport()
	if not viewport: return
	var screen_pos = camera.get_screen_center_position()
	var vp_size = viewport.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var diff = (world_pos - screen_pos) * camera.zoom
	var screen_uv = Vector2(0.5, 0.5) + (diff / vp_size)
	screen_uv.x = clamp(screen_uv.x, 0.0, 1.0)
	screen_uv.y = clamp(screen_uv.y, 0.0, 1.0)
	post_material.set_shader_parameter("shockwave_center", screen_uv)
	post_material.set_shader_parameter("shockwave_force", force)
	shockwave_active = true
	shockwave_progress = 0.01

func trigger_chromatic_aberration_pulse(intensity: float = 0.03, duration: float = 0.2) -> void:
	if not post_material: return
	chromatic_max_intensity = intensity
	chromatic_duration = max(0.001, duration)
	chromatic_timer = chromatic_duration

func trigger_damage_vignette(intensity: float = 0.65, duration: float = 0.25) -> void:
	if not post_material: return
	vignette_max_intensity = intensity
	vignette_duration = max(0.001, duration)
	vignette_timer = vignette_duration
