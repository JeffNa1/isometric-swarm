extends Node2D
## Run controller. Builds the world, runs the spawn director, routes events
## between systems, and owns the camera, pacing and end-of-run flow.

const FloorShader := preload("res://shaders/floor.gdshader")
const ScreenShader := preload("res://shaders/screen.gdshader")
const SwarmScript := preload("res://scripts/swarm.gd")
const ProjectilesScript := preload("res://scripts/projectiles.gd")
const PickupsScript := preload("res://scripts/pickups.gd")
const FxScript := preload("res://scripts/fx.gd")
const WeaponsScript := preload("res://scripts/weapons.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BossScript := preload("res://scripts/boss.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const LevelUpScript := preload("res://scripts/ui/level_up.gd")
const OverlayScript := preload("res://scripts/ui/overlay.gd")

var swarm: Node2D
var projectiles: Node2D
var pickups: Node2D
var fx: Node2D
var weapons: Node2D
var player: Node2D
var bosses: Array = []
var camera: Camera2D
var hud: Control
var level_up_ui: Control
var overlay: Control
var floor_rect: ColorRect
var screen_mat: ShaderMaterial

var elapsed := 0.0
var kills := 0
var level := 1
var xp := 0
var level_xp_need := 0
var pending_levels := 0
var damage_dealt := 0.0
var paused_for_ui := false
var run_over := false

var _spawn_budget := 0.0
var _next_surge: float = Data.FIRST_SURGE
var _elites_done := 0
var _mid_boss_done := false
var _final_boss_done := false
var _trauma := 0.0
var _hurt_fx := 0.0
var _flash_fx := 0.0
var _gem_chain := 0
var _gem_chain_t := 0.0
var _perf_t := 0.0
var _slow_frames := 0
var _fast_frames := 0

func _ready() -> void:
	_build_world()
	_build_ui()
	start_run()

# ------------------------------------------------------------------ building
func _build_world() -> void:
	# The floor lives on its own layer behind the world (following the camera)
	# so it never interleaves with the MultiMesh batches.
	var floor_layer := CanvasLayer.new()
	floor_layer.layer = -1
	floor_layer.follow_viewport_enabled = true
	add_child(floor_layer)
	floor_rect = ColorRect.new()
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = FloorShader
	floor_rect.material = fm
	floor_layer.add_child(floor_rect)

	pickups = PickupsScript.new()
	pickups.z_index = 0
	add_child(pickups)
	pickups.setup(self)

	fx = FxScript.new()
	add_child(fx)
	fx.setup(self)

	swarm = SwarmScript.new()
	swarm.z_index = 1
	add_child(swarm)
	swarm.setup(self, 1500)

	weapons = WeaponsScript.new()
	add_child(weapons)
	weapons.setup(self)

	player = PlayerScript.new()
	add_child(player)
	player.setup(self)
	player.died.connect(_on_player_died)

	projectiles = ProjectilesScript.new()
	projectiles.z_index = 5
	add_child(projectiles)
	projectiles.setup(self)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

func _build_ui() -> void:
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 5
	add_child(fx_layer)
	var scr := ColorRect.new()
	scr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_mat = ShaderMaterial.new()
	screen_mat.shader = ScreenShader
	scr.material = screen_mat
	fx_layer.add_child(scr)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = HudScript.new()
	ui.add_child(hud)
	hud.setup(self)
	level_up_ui = LevelUpScript.new()
	ui.add_child(level_up_ui)
	level_up_ui.setup(self)
	level_up_ui.chosen.connect(_on_upgrade_chosen)
	overlay = OverlayScript.new()
	ui.add_child(overlay)
	overlay.setup()

func start_run() -> void:
	elapsed = 0.0
	kills = 0
	level = 1
	xp = 0
	level_xp_need = Data.xp_to_next(1)
	pending_levels = 0
	damage_dealt = 0.0
	run_over = false
	paused_for_ui = false
	_spawn_budget = 0.0
	_next_surge = Data.FIRST_SURGE
	_elites_done = 0
	_mid_boss_done = false
	_final_boss_done = false
	for b in bosses:
		b.queue_free()
	bosses.clear()
	swarm.clear()
	projectiles.clear()
	pickups.clear()
	fx.clear()
	weapons.reset()
	player.reset()
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	overlay.hide_screen()
	level_up_ui.visible = false
	# an opening ring so the first seconds already feel like a swarm
	for k in 36:
		var a := TAU * k / 36.0
		swarm.spawn(Vector2.from_angle(a) * randf_range(380.0, 520.0), Data.E.MITE, 0.0)
	hud.banner("SURVIVE", "Hold out for 10 minutes. Kill the Queen.", Data.C_ACCENT)
	Sfx.music(true)

# ------------------------------------------------------------------ main loop
func _process(dt: float) -> void:
	dt = minf(dt, 1.0 / 30.0)
	_update_camera(dt)
	_update_screen_fx(dt)
	if paused_for_ui:
		_render()
		return
	if not run_over:
		elapsed += dt
		_director(dt)
	player.update(dt)
	swarm.update(dt, player.position, player.radius)
	weapons.update(dt)
	projectiles.update(dt)
	for b in bosses.duplicate():
		if is_instance_valid(b) and not b.dead:
			b.update(dt)
	swarm.reap()
	pickups.update(dt)
	fx.update(dt)
	_gem_chain_t -= dt
	if _gem_chain_t <= 0.0:
		_gem_chain = 0
	_adapt_performance(dt)
	Sfx.set_music_intensity(float(swarm.count) / 1200.0 + (0.4 if not bosses.is_empty() else 0.0))
	_render()

func _render() -> void:
	var view := view_rect()
	floor_rect.position = view.position - Vector2(64, 64)
	floor_rect.size = view.size + Vector2(128, 128)
	(floor_rect.material as ShaderMaterial).set_shader_parameter("player_pos", player.position)
	swarm.render(view)
	projectiles.render()
	pickups.render(view)
	fx.render(view)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("dash"):
		player.try_dash()
	elif e.is_action_pressed("pause"):
		toggle_pause()
	elif e is InputEventKey and e.pressed and e.keycode == KEY_F3:
		hud.show_fps = not hud.show_fps

func _notification(what: int) -> void:
	# auto-pause when the app loses focus (phone notifications, tab switches)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if not paused_for_ui and not run_over:
			toggle_pause()

# ------------------------------------------------------------------ camera
func view_rect() -> Rect2:
	var vs := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - vs * 0.5, vs)

func view_radius() -> float:
	return (get_viewport_rect().size / camera.zoom).length() * 0.5

func _update_camera(dt: float) -> void:
	var target: Vector2 = player.position + player.vel * 0.12
	camera.position = camera.position.lerp(target, minf(1.0, 7.0 * dt))
	_trauma = maxf(0.0, _trauma - dt * 1.8)
	if Data.shake_on and _trauma > 0.0:
		var s := _trauma * _trauma * 16.0
		camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	else:
		camera.offset = Vector2.ZERO

func shake(amount: float) -> void:
	_trauma = minf(0.8, _trauma + amount)

func _update_screen_fx(dt: float) -> void:
	_hurt_fx = maxf(0.0, _hurt_fx - dt * 2.5)
	_flash_fx = maxf(0.0, _flash_fx - dt * 2.0)
	screen_mat.set_shader_parameter("hurt", _hurt_fx)
	screen_mat.set_shader_parameter("low_hp", 1.0 if player.alive and player.hp / player.max_hp < 0.3 else 0.0)
	screen_mat.set_shader_parameter("flash", _flash_fx * 0.6)

## Keep the frame rate up on weak devices by trimming the enemy cap.
func _adapt_performance(dt: float) -> void:
	_perf_t += dt
	if _perf_t < 0.5:
		return
	_perf_t = 0.0
	var fps := Engine.get_frames_per_second()
	if fps < 48:
		_slow_frames += 1
		_fast_frames = 0
	elif fps >= 58:
		_fast_frames += 1
		_slow_frames = 0
	if _slow_frames >= 3:
		swarm.max_count = maxi(450, int(swarm.max_count * 0.88))
		_slow_frames = 0
	elif _fast_frames >= 6:
		swarm.max_count = mini(1500, swarm.max_count + 60)
		_fast_frames = 0

# ------------------------------------------------------------------ director
func _director(dt: float) -> void:
	var target := minf(Data.target_population(elapsed), float(swarm.max_count))
	if not bosses.is_empty():
		target *= 0.6
	var deficit := target - float(swarm.count)
	if deficit > 0.0:
		_spawn_budget += maxf(10.0, deficit * 1.4) * dt
	while _spawn_budget >= 1.0:
		var n := mini(int(_spawn_budget), randi_range(4, 12))
		_spawn_cluster(n, _pick_type())
		_spawn_budget -= n

	if elapsed >= _next_surge and elapsed < Data.RUN_LENGTH - 5.0:
		_next_surge += Data.SURGE_INTERVAL
		_surge()

	if _elites_done < Data.ELITE_TIMES.size() and elapsed >= Data.ELITE_TIMES[_elites_done]:
		_elites_done += 1
		_spawn_elite()

	if not _mid_boss_done and elapsed >= Data.MID_BOSS_TIME:
		_mid_boss_done = true
		_spawn_boss(1)
	if not _final_boss_done and elapsed >= Data.RUN_LENGTH:
		_final_boss_done = true
		_spawn_boss(2)

func next_event_hint() -> String:
	if not _final_boss_done and Data.RUN_LENGTH - elapsed < 30.0:
		return "QUEEN IN %d" % ceili(Data.RUN_LENGTH - elapsed)
	if not _mid_boss_done and Data.MID_BOSS_TIME - elapsed < 20.0:
		return "BOSS IN %d" % ceili(Data.MID_BOSS_TIME - elapsed)
	if _next_surge - elapsed < 5.0 and _next_surge < Data.RUN_LENGTH - 5.0:
		return "SURGE IN %d" % ceili(_next_surge - elapsed)
	return ""

func _pick_type() -> int:
	var total := 0.0
	for e in Data.SPAWN_TABLE:
		if elapsed >= e.from:
			total += e.weight
	var r := randf() * total
	for e in Data.SPAWN_TABLE:
		if elapsed >= e.from:
			r -= e.weight
			if r <= 0.0:
				return e.type
	return Data.E.MITE

func _edge_point(spread: float = 1.0) -> Vector2:
	var ahead: Vector2 = player.vel.normalized() if player.vel.length_squared() > 400.0 else Vector2.ZERO
	var dir := Vector2.from_angle(randf() * TAU)
	# bias spawns toward where the player is heading
	dir = (dir + ahead * 0.6).normalized() if ahead != Vector2.ZERO else dir
	return player.position + dir * view_radius() * randf_range(1.02, 1.15) * spread

func _spawn_cluster(n: int, type: int) -> void:
	var c := _edge_point()
	for k in n:
		swarm.spawn(c + Vector2(randf_range(-40, 40), randf_range(-40, 40)), type, elapsed)

func _surge() -> void:
	var n := clampi(int(70 + elapsed * 0.5), 70, 380)
	var type := Data.E.MITE if elapsed < 150.0 else (Data.E.DART if randf() < 0.4 else Data.E.MITE)
	var r := view_radius() * 0.98
	# two or three escape lanes so a sharp player (or a dash) can break out
	var gaps: Array[float] = []
	for g in randi_range(2, 3):
		gaps.append(randf() * TAU)
	for k in n:
		var a := TAU * k / float(n)
		var blocked := false
		for g in gaps:
			if absf(angle_difference(a, g)) < 0.16:
				blocked = true
		if blocked:
			continue
		swarm.spawn(player.position + Vector2.from_angle(a) * (r + randf_range(-10.0, 30.0)), type, elapsed, 0.8)
	hud.banner("SWARM SURGE", "They're closing in from every side", Data.C_HP)
	Sfx.play("alarm")

func _spawn_elite() -> void:
	var p := _edge_point(0.8)
	var i: int = swarm.spawn(p, Data.E.ELITE, elapsed)
	if i >= 0:
		hud.banner("CHAMPION", "Kill it for a supply cache", Data.C_GOLD)
		Sfx.play("alarm", 1.2)

func _spawn_boss(tier: int) -> void:
	var b := BossScript.new()
	add_child(b)
	b.setup(self, tier)
	b.position = _edge_point(0.75)
	bosses.append(b)
	hud.banner(b.title, "Watch for the glowing tells" if tier == 1 else "End this", b.color)
	Sfx.play("boss")
	shake(0.4)

func boss_at(p: Vector2, r: float):
	for b in bosses:
		if not b.dead and b.position.distance_squared_to(p) < pow(b.radius + r, 2.0):
			return b
	return null

func nearest_boss(p: Vector2, max_d: float):
	var best = null
	var bd := max_d
	for b in bosses:
		if b.dead:
			continue
		var d: float = b.position.distance_to(p) - b.radius
		if d < bd:
			bd = d
			best = b
	return best

# ------------------------------------------------------------------ events
func on_damage_dealt(amount: float) -> void:
	damage_dealt += amount

func on_enemy_killed(type: int, p: Vector2, rewarded: bool) -> void:
	var d: Dictionary = Data.ENEMIES[type]
	fx.death(p, d.color, d.radius)
	if not rewarded:
		return
	kills += 1
	Sfx.play("pop", randf_range(0.85, 1.25))
	pickups.drop_gem(p, d.xp)
	if type == Data.E.ELITE:
		pickups.drop_item(p, pickups.Item.CHEST)
		fx.explosion(p, 90.0, d.color)
		shake(0.3)
		return
	var roll := randf()
	var low_hp: bool = player.hp / player.max_hp < 0.5
	if roll < (0.006 if low_hp else 0.0025):
		pickups.drop_item(p, pickups.Item.HEART)
	elif roll < 0.0042 and roll >= 0.003:
		pickups.drop_item(p, pickups.Item.MAGNET)
	elif roll > 0.9985:
		pickups.drop_item(p, pickups.Item.BOMB)

func on_boss_killed(b: Node2D) -> void:
	fx.explosion(b.position, 220.0, b.color)
	fx.burst(b.position, Color.WHITE, 40, 500.0, 22.0, 0.9)
	shake(0.8)
	_flash_fx = 0.6
	Sfx.play("bomb")
	for k in 14:
		pickups.drop_gem(b.position + Vector2.from_angle(randf() * TAU) * randf_range(10, 90), 25)
	bosses.erase(b)
	var tier: int = b.tier
	b.queue_free()
	if tier == 2:
		_victory()
	else:
		pickups.drop_item(b.position, pickups.Item.CHEST)
		hud.banner("BROODMOTHER DOWN", "The hive is furious", Data.C_GOLD)

func gain_xp(v: int) -> void:
	xp += int(ceil(v * weapons.xp_mult()))
	while xp >= level_xp_need:
		xp -= level_xp_need
		level += 1
		level_xp_need = Data.xp_to_next(level)
		pending_levels += 1
	if pending_levels > 0 and not paused_for_ui and not run_over:
		_open_level_up()

func on_gems_collected(n: int) -> void:
	_gem_chain += n
	_gem_chain_t = 0.6
	Sfx.play("gem", 1.0 + minf(_gem_chain, 24) * 0.04)

func on_item(kind: int, p: Vector2) -> void:
	Sfx.play("pick")
	match kind:
		pickups.Item.HEART:
			player.heal(30.0)
			fx.burst(p, Data.C_HP, 14, 180.0)
		pickups.Item.MAGNET:
			pickups.vacuum()
			fx.ring(player.position, view_radius(), Color("4fb6ff"), 0.6, 6.0)
		pickups.Item.BOMB:
			_flash_fx = 0.8
			shake(0.6)
			Sfx.play("bomb")
			fx.ring(player.position, view_radius(), Data.C_WARN, 0.5, 14.0)
			swarm.nuke(player.position, view_radius())
			projectiles.clear_enemy_shots()
		pickups.Item.CHEST:
			var offer: Array = weapons.roll_offers(1)
			var id: String = offer[0]
			var info: Dictionary = weapons.describe(id)
			weapons.add_upgrade(id)
			player.heal(player.max_hp * 0.25)
			fx.explosion(p, 80.0, Data.C_GOLD)
			hud.banner("SUPPLY CACHE", "%s  •  %s" % [info.name, info.tag], Data.C_GOLD)
			Sfx.play("level")

func on_player_hurt(amount: float) -> void:
	_hurt_fx = clampf(0.25 + amount / 60.0, 0.0, 0.8)
	shake(0.18)
	Sfx.play("hurt")

func _open_level_up() -> void:
	paused_for_ui = true
	fx.ring(player.position, 150.0, Data.C_XP, 0.5, 8.0, 20.0)
	player.stick = Vector2.ZERO
	level_up_ui.open(weapons.roll_offers(3))

func _on_upgrade_chosen(id: String) -> void:
	weapons.add_upgrade(id)
	player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.08)
	pending_levels -= 1
	if pending_levels > 0:
		level_up_ui.open(weapons.roll_offers(3))
	else:
		paused_for_ui = false
		player.invuln = maxf(player.invuln, 0.6)

# ------------------------------------------------------------------ flow
func toggle_pause() -> void:
	if run_over:
		return
	if overlay.visible:
		overlay.hide_screen()
		paused_for_ui = level_up_ui.visible
		return
	paused_for_ui = true
	overlay.show_screen("PAUSED", Data.C_TEXT, Data.format_time(elapsed) + "  •  Level %d  •  %d kills" % [level, kills], [], [
		["Resume", toggle_pause],
		["Sound: " + ("On" if Data.sound_on else "Off"), func():
			Data.sound_on = not Data.sound_on
			Data.save()
			Sfx.music(Data.sound_on)
			overlay.hide_screen()
			toggle_pause()],
		["Screen shake: " + ("On" if Data.shake_on else "Off"), func():
			Data.shake_on = not Data.shake_on
			Data.save()
			overlay.hide_screen()
			toggle_pause()],
		["Quit to menu", _to_menu],
	])

func _on_player_died() -> void:
	if run_over:
		return
	run_over = true
	shake(0.7)
	Sfx.play("lose")
	Sfx.music(false)
	Data.record_run(elapsed, kills, false)
	await get_tree().create_timer(1.4).timeout
	paused_for_ui = true
	overlay.show_screen("OVERRUN", Data.C_HP, "The swarm got you.", _stats(), [
		["Try again", start_run],
		["Menu", _to_menu],
	])

func _victory() -> void:
	run_over = true
	player.invuln = 999.0
	Sfx.play("win")
	Sfx.music(false)
	Data.record_run(elapsed, kills, true)
	hud.banner("HIVE QUEEN DESTROYED", "", Data.C_GOLD)
	await get_tree().create_timer(2.5).timeout
	paused_for_ui = true
	overlay.show_screen("VICTORY", Data.C_GOLD, "The hive is broken.", _stats(), [
		["Play again", start_run],
		["Menu", _to_menu],
	])

func _stats() -> Array:
	return [
		["Time", Data.format_time(elapsed)],
		["Level", str(level)],
		["Kills", str(kills)],
		["Damage", _short(damage_dealt)],
		["Best time", Data.format_time(Data.best_time)],
	]

static func _short(v: float) -> String:
	if v >= 1_000_000.0:
		return "%.1fM" % (v / 1_000_000.0)
	if v >= 1000.0:
		return "%.1fK" % (v / 1000.0)
	return str(int(v))

func _to_menu() -> void:
	Sfx.music(false)
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
