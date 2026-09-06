extends CanvasLayer

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const SaveManagerClass = preload("res://scripts/save_manager.gd")

signal upgrade_selected(upgrade_id: String)

var rerolls_left: int = 1
var banishes_left: int = 1
var banished_upgrades: Array[String] = []
var current_level_picks: Array[Dictionary] = []
var tactical_row: HBoxContainer = null
var debrief_damage_box: VBoxContainer = null

@onready var xp_bar: ProgressBar = $TopBar/XPBar
@onready var level_label: Label = $TopBar/LevelLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var kill_label: Label = $TopBar/KillLabel
@onready var fps_label: Label = $TopBar/FPSLabel
@onready var swarm_label: Label = $TopBar/SwarmLabel

@onready var health_chassis: PanelContainer = $BottomBar/HealthChassis
@onready var reactor_pod: PanelContainer = $BottomBar/HealthChassis/ChassisLayout/ReactorPod
@onready var heart_icon: Label = $BottomBar/HealthChassis/ChassisLayout/ReactorPod/CenterContainer/HeartIcon
@onready var hp_bar: ProgressBar = $BottomBar/HealthChassis/ChassisLayout/GaugeColumn/BarStack/HPBar
@onready var ghost_hp_bar: ProgressBar = $BottomBar/HealthChassis/ChassisLayout/GaugeColumn/BarStack/GhostHPBar
@onready var hp_label: Label = $BottomBar/HealthChassis/ChassisLayout/GaugeColumn/HPHeader/HPLabel
@onready var hp_percent_label: Label = $BottomBar/HealthChassis/ChassisLayout/GaugeColumn/HPHeader/HPPercent
@onready var battery_cells_box: HBoxContainer = $BottomBar/HealthChassis/ChassisLayout/GaugeColumn/BatteryRow/BatteryCells
@onready var inventory_tray: PanelContainer = $BottomBar/InventoryTray
@onready var inventory_box: HBoxContainer = $BottomBar/InventoryTray/InventoryBox
@onready var low_hp_overlay: ColorRect = $LowHPOverlay

const VignetteShader = preload("res://shaders/vignette.gdshader")
var vignette_mat: ShaderMaterial = null

@onready var radar_rect: Control = $RadarContainer/RadarView
@onready var level_up_dimming: ColorRect = $LevelUpDimming
@onready var level_up_panel: PanelContainer = $LevelUpModal
@onready var card_container: HBoxContainer = $LevelUpModal/VBox/CardContainer
@onready var game_over_panel: PanelContainer = $GameOverModal
@onready var game_over_stats: Label = $GameOverModal/VBox/StatsLabel

@onready var boss_container: Control = $BossContainer
@onready var boss_hp_bar: ProgressBar = $BossContainer/BossHPBar
@onready var boss_label: Label = $BossContainer/BossLabel

@onready var chest_modal: PanelContainer = $ChestModal
@onready var chest_rewards_container: HBoxContainer = $ChestModal/VBox/RewardsContainer
@onready var chest_claim_btn: Button = $ChestModal/VBox/ClaimButton

@onready var restart_button: Button = $GameOverModal/VBox/ButtonsRow/RestartButton
@onready var menu_button: Button = $GameOverModal/VBox/ButtonsRow/MenuButton
@onready var pause_modal: PanelContainer = $PauseModal
@onready var pause_resume_btn: Button = $PauseModal/VBox/ResumeButton
@onready var pause_restart_btn: Button = $PauseModal/VBox/PauseRestartButton
@onready var pause_menu_btn: Button = $PauseModal/VBox/PauseMenuButton

var survival_seconds: float = 0.0
var kills: int = 0
var swarm_count: int = 0
var player_node: Node2D = null
var sound_mgr: Node = null

var target_hp: float = 100.0
var max_hp: float = 100.0
var ghost_hp: float = 100.0
var ghost_delay: float = 0.0

var target_boss_hp: float = 4500.0
var max_boss_hp: float = 4500.0
var pending_chest_rewards: Array[String] = []

var surge_banner: Label = null
var surge_banner_timer: float = 0.0

var combo_badge: PanelContainer = null
var combo_label: Label = null
var combo_scale: float = 1.0

var milestone_banner: Label = null
var milestone_timer: float = 0.0

var active_card_scales: Dictionary = {}
var active_card_targets: Dictionary = {}

var health_chassis_base_pos: Vector2 = Vector2.ZERO
var health_chassis_shake_frames: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManagerClass.init_and_load()
	rerolls_left = 1 + int(SaveManagerClass.get_bonus("rerolls"))
	banishes_left = 1 + int(SaveManagerClass.get_bonus("banishes"))
	banished_upgrades.clear()

	level_up_panel.hide()
	if level_up_dimming: level_up_dimming.hide()
	game_over_panel.hide()
	if boss_container: boss_container.hide()
	if chest_modal: chest_modal.hide()
	if pause_modal: pause_modal.hide()
	if low_hp_overlay:
		vignette_mat = ShaderMaterial.new()
		vignette_mat.shader = VignetteShader
		vignette_mat.set_shader_parameter("intensity", 0.0)
		low_hp_overlay.material = vignette_mat
		low_hp_overlay.color = Color.WHITE
		low_hp_overlay.show()

	if health_chassis:
		health_chassis_base_pos = health_chassis.position

	sound_mgr = get_node_or_null("/root/Main/SoundManager")
	if not sound_mgr:
		sound_mgr = get_tree().get_first_node_in_group("sound_manager")

	_setup_hud_styling()

	if restart_button: restart_button.pressed.connect(_on_restart_pressed)
	if menu_button: menu_button.pressed.connect(_on_menu_pressed)
	if pause_resume_btn: pause_resume_btn.pressed.connect(_on_resume_pressed)
	if pause_restart_btn: pause_restart_btn.pressed.connect(_on_restart_pressed)
	if pause_menu_btn: pause_menu_btn.pressed.connect(_on_menu_pressed)

	if chest_claim_btn:
		chest_claim_btn.pressed.connect(_on_chest_claim_pressed)
	player_node = get_tree().get_first_node_in_group("player")
	radar_rect.draw.connect(_on_radar_draw)

	_create_surge_banner()
	_create_combo_elements()
	call_deferred("update_inventory")

func _setup_hud_styling() -> void:
	# 1. XP Bar Style (Pixel Grooved Track + Segmented Neon Bar)
	var xp_bg_tex = SpriteFactory.create_pixel_bar_bg_texture(Color(0.02, 0.04, 0.08, 0.95), Color(0.15, 0.35, 0.55, 0.8))
	xp_bar.add_theme_stylebox_override("background", SpriteFactory.create_pixel_stylebox(xp_bg_tex, 3))

	var xp_fill_tex = SpriteFactory.create_glossy_plasma_fluid_texture(Color(0.2, 0.9, 1.0, 1.0))
	xp_bar.add_theme_stylebox_override("fill", SpriteFactory.create_pixel_bar_stylebox(xp_fill_tex))

	# 2. Health Chassis Panel (Industrial Mech Frame with Left Reactor Core Pod - Ref Image 1)
	if health_chassis:
		var ch_tex = SpriteFactory.create_pixel_panel_texture(Color(0.25, 0.6, 0.9, 0.95), Color(0.03, 0.06, 0.12, 0.96), Color(0.4, 0.9, 1.0, 1.0), true)
		health_chassis.add_theme_stylebox_override("panel", SpriteFactory.create_pixel_stylebox(ch_tex, 6))

	if reactor_pod:
		var pod_tex = SpriteFactory.create_mech_reactor_pod_texture(Color(1.0, 0.25, 0.4), Color(0.08, 0.03, 0.05))
		reactor_pod.add_theme_stylebox_override("panel", SpriteFactory.create_pixel_stylebox(pod_tex, 4))

	# Populate Golden Energy Battery Cells (Ref Image 1)
	if battery_cells_box:
		for child in battery_cells_box.get_children():
			child.queue_free()
		for i in range(8):
			var cell = TextureRect.new()
			cell.texture = SpriteFactory.create_energy_cell_texture(true)
			cell.custom_minimum_size = Vector2(8, 12)
			battery_cells_box.add_child(cell)

	# 3. Inventory Tray Panel (Recessed Cyber Module Plate)
	if inventory_tray:
		var tray_tex = SpriteFactory.create_pixel_panel_texture(Color(0.18, 0.38, 0.65, 0.85), Color(0.02, 0.05, 0.10, 0.92), Color(0.25, 0.7, 1.0, 0.8), false)
		inventory_tray.add_theme_stylebox_override("panel", SpriteFactory.create_pixel_stylebox(tray_tex, 6))

	# 4. HP Bar Style (Glossy Plasma Fluid inside Glass Cylinder - Ref Image 1)
	var hp_bg_tex = SpriteFactory.create_pixel_bar_bg_texture(Color(0.01, 0.02, 0.05, 0.98), Color(0.15, 0.3, 0.48, 0.95))
	hp_bar.add_theme_stylebox_override("background", SpriteFactory.create_pixel_stylebox(hp_bg_tex, 3))

	var hp_fill_tex = SpriteFactory.create_glossy_plasma_fluid_texture(Color(0.18, 0.95, 0.45, 1.0))
	hp_bar.add_theme_stylebox_override("fill", SpriteFactory.create_pixel_bar_stylebox(hp_fill_tex))

	# 5. Ghost HP Bar Style (Lagging Amber Plasma Trail)
	if ghost_hp_bar:
		var g_bg = StyleBoxEmpty.new()
		ghost_hp_bar.add_theme_stylebox_override("background", g_bg)
		var g_fill_tex = SpriteFactory.create_glossy_plasma_fluid_texture(Color(1.0, 0.72, 0.15, 0.9), true)
		ghost_hp_bar.add_theme_stylebox_override("fill", SpriteFactory.create_pixel_bar_stylebox(g_fill_tex))

	# 6. Boss Bar Style
	if boss_hp_bar:
		var b_bg_tex = SpriteFactory.create_pixel_bar_bg_texture(Color(0.1, 0.02, 0.03, 0.98), Color(0.8, 0.15, 0.25, 0.9))
		boss_hp_bar.add_theme_stylebox_override("background", SpriteFactory.create_pixel_stylebox(b_bg_tex, 3))

		var b_fill_tex = SpriteFactory.create_glossy_plasma_fluid_texture(Color(1.0, 0.18, 0.28, 1.0))
		boss_hp_bar.add_theme_stylebox_override("fill", SpriteFactory.create_pixel_bar_stylebox(b_fill_tex))

	# 7. Dialog Modals (Industrial CRT Bezel with Exposed Cables & Header Plate - Ref Image 2)
	var modal_tex = SpriteFactory.create_industrial_crt_frame(Color(0.25, 0.8, 1.0, 0.95), Color(0.05, 0.08, 0.14, 0.98))
	var modal_style = SpriteFactory.create_pixel_stylebox(modal_tex, 8)
	level_up_panel.add_theme_stylebox_override("panel", modal_style)
	if pause_modal:
		pause_modal.add_theme_stylebox_override("panel", modal_style)
		_style_industrial_btn(pause_modal.get_node_or_null("VBox/ResumeButton"), Color(0.2, 0.9, 0.5), Color(0.05, 0.14, 0.08, 0.95))
		_style_industrial_btn(pause_modal.get_node_or_null("VBox/PauseRestartButton"), Color(1.0, 0.75, 0.2), Color(0.14, 0.10, 0.03, 0.95))
		_style_industrial_btn(pause_modal.get_node_or_null("VBox/PauseMenuButton"), Color(0.4, 0.7, 1.0), Color(0.06, 0.10, 0.18, 0.95))
	if game_over_panel:
		var go_tex = SpriteFactory.create_industrial_crt_frame(Color(1.0, 0.2, 0.3, 0.95), Color(0.12, 0.04, 0.06, 0.98))
		game_over_panel.add_theme_stylebox_override("panel", SpriteFactory.create_pixel_stylebox(go_tex, 8))
		_style_industrial_btn(game_over_panel.get_node_or_null("VBox/ButtonsRow/RestartButton"), Color(1.0, 0.3, 0.3), Color(0.16, 0.04, 0.06, 0.95))
		_style_industrial_btn(game_over_panel.get_node_or_null("VBox/ButtonsRow/MenuButton"), Color(0.4, 0.7, 1.0), Color(0.06, 0.10, 0.18, 0.95))
	if chest_modal:
		var ch_modal_tex = SpriteFactory.create_industrial_crt_frame(Color(1.0, 0.85, 0.25, 0.95), Color(0.14, 0.08, 0.02, 0.98))
		chest_modal.add_theme_stylebox_override("panel", SpriteFactory.create_pixel_stylebox(ch_modal_tex, 8))
		_style_industrial_btn(chest_modal.get_node_or_null("VBox/ClaimButton"), Color(1.0, 0.85, 0.25), Color(0.18, 0.12, 0.03, 0.95))

func _style_industrial_btn(btn: Button, border_col: Color, bg_col: Color) -> void:
	if not btn: return
	var norm_tex = SpriteFactory.create_industrial_button_texture(border_col, bg_col, false, false)
	var hov_tex = SpriteFactory.create_industrial_button_texture(Color.WHITE, bg_col.lightened(0.15), false, true)
	var press_tex = SpriteFactory.create_industrial_button_texture(border_col, bg_col.darkened(0.2), true, false)
	btn.add_theme_stylebox_override("normal", SpriteFactory.create_pixel_stylebox(norm_tex, 4))
	btn.add_theme_stylebox_override("hover", SpriteFactory.create_pixel_stylebox(hov_tex, 4))
	btn.add_theme_stylebox_override("pressed", SpriteFactory.create_pixel_stylebox(press_tex, 4))
	btn.add_theme_stylebox_override("focus", SpriteFactory.create_pixel_stylebox(hov_tex, 4))

func _create_surge_banner() -> void:
	surge_banner = Label.new()
	surge_banner.name = "SurgeBanner"
	surge_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surge_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	surge_banner.anchor_left = 0.0
	surge_banner.anchor_right = 1.0
	surge_banner.offset_top = 80.0
	surge_banner.offset_bottom = 120.0
	surge_banner.add_theme_font_size_override("font_size", 24)
	surge_banner.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	surge_banner.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	surge_banner.add_theme_constant_override("shadow_offset_x", 2)
	surge_banner.add_theme_constant_override("shadow_offset_y", 2)
	surge_banner.hide()
	add_child(surge_banner)

func _create_combo_elements() -> void:
	# 1. Floating Combo Meter Badge (Top Right below TopBar)
	combo_badge = PanelContainer.new()
	combo_badge.name = "ComboBadge"
	combo_badge.custom_minimum_size = Vector2(160, 36)
	combo_badge.position = Vector2(1090, 75)
	combo_badge.pivot_offset = Vector2(80, 18)
	var c_tex = SpriteFactory.create_pixel_panel_texture(Color(1.0, 0.7, 0.2, 0.95), Color(0.08, 0.04, 0.02, 0.95), Color(1.0, 0.85, 0.3, 1.0), true)
	combo_badge.add_theme_stylebox_override("panel", SpriteFactory.create_pixel_stylebox(c_tex, 4))

	combo_label = Label.new()
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 14)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	combo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	combo_label.add_theme_constant_override("shadow_offset_x", 1)
	combo_label.add_theme_constant_override("shadow_offset_y", 1)
	combo_label.text = "🔥 x0 COMBO"
	combo_badge.add_child(combo_label)
	combo_badge.hide()
	add_child(combo_badge)

	# 2. Huge Multikill Announcement Banner
	milestone_banner = Label.new()
	milestone_banner.name = "MilestoneBanner"
	milestone_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	milestone_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	milestone_banner.anchor_left = 0.0
	milestone_banner.anchor_right = 1.0
	milestone_banner.offset_top = 135.0
	milestone_banner.offset_bottom = 185.0
	milestone_banner.add_theme_font_size_override("font_size", 30)
	milestone_banner.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	milestone_banner.add_theme_constant_override("shadow_offset_x", 3)
	milestone_banner.add_theme_constant_override("shadow_offset_y", 3)
	milestone_banner.hide()
	add_child(milestone_banner)

func update_combo(count: int) -> void:
	if not combo_badge:
		_create_combo_elements()

	if count < 2:
		combo_badge.hide()
		return

	combo_badge.show()
	combo_scale = 1.38

	var col = Color(0.4, 0.8, 1.0, 1.0)
	var prefix = "⚡"
	if count >= 250:
		col = Color(1.0, 0.2, 0.6, 1.0)
		prefix = "👑"
	elif count >= 100:
		col = Color(1.0, 0.25, 0.2, 1.0)
		prefix = "☣️"
	elif count >= 75:
		col = Color(1.0, 0.5, 0.1, 1.0)
		prefix = "👑"
	elif count >= 50:
		col = Color(1.0, 0.85, 0.2, 1.0)
		prefix = "💀"
	elif count >= 25:
		col = Color(0.2, 1.0, 0.5, 1.0)
		prefix = "💥"
	elif count >= 10:
		col = Color(0.3, 0.9, 1.0, 1.0)
		prefix = "🔥"
	elif count >= 5:
		col = Color(0.4, 0.8, 1.0, 1.0)
		prefix = "⚡"

	combo_label.text = "%s x%d COMBO!" % [prefix, count]
	combo_label.add_theme_color_override("font_color", col)

func show_combo_milestone(text: String, col: Color) -> void:
	if not milestone_banner:
		_create_combo_elements()

	milestone_banner.text = text
	milestone_banner.add_theme_color_override("font_color", col)
	milestone_banner.show()
	milestone_timer = 2.4
	if sound_mgr and sound_mgr.has_method("play_chest"):
		sound_mgr.play_chest()

func show_surge_warning(text: String) -> void:
	if not surge_banner:
		_create_surge_banner()
	surge_banner.text = text
	surge_banner.show()
	surge_banner_timer = 3.8

func _process(delta: float) -> void:
	if combo_scale > 1.0:
		combo_scale = move_toward(combo_scale, 1.0, 3.5 * delta)
		if combo_badge:
			combo_badge.scale = Vector2(combo_scale, combo_scale)

	if milestone_timer > 0.0:
		milestone_timer -= delta
		var pulse = (int(float(Time.get_ticks_msec()) / 90.0) % 2) * 0.3 + 0.7
		milestone_banner.modulate = Color(1.0, 1.0, 1.0, pulse)
		if milestone_timer <= 0.0:
			milestone_banner.hide()

	# Update card scale springs (quantized 10-fps retro tick for crisp pixel feel)
	for c in active_card_scales.keys():
		if is_instance_valid(c):
			var cur = active_card_scales[c] as Vector2
			var target = active_card_targets[c] as Vector2
			var n_scale = cur.lerp(target, 24.0 * delta)
			n_scale.x = snappedf(n_scale.x, 0.01)
			n_scale.y = snappedf(n_scale.y, 0.01)
			active_card_scales[c] = n_scale
			c.scale = n_scale

	if surge_banner_timer > 0.0:
		surge_banner_timer -= delta
		var pulse = (int(float(Time.get_ticks_msec()) / 150.0) % 2) * 0.35 + 0.65
		surge_banner.modulate = Color(1.0, 1.0, 1.0, pulse)
		if surge_banner_timer <= 0.0:
			surge_banner.hide()

	if not get_tree().paused:
		survival_seconds += delta
		var mins = int(survival_seconds / 60.0)
		var secs = int(survival_seconds) % 60
		timer_label.text = "%02d:%02d" % [mins, secs]
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()

		# Health chassis pixel jitter on hit
		if health_chassis:
			if health_chassis_shake_frames > 0:
				health_chassis_shake_frames -= 1
				var rx = randi_range(-2, 2)
				var ry = randi_range(-2, 2)
				health_chassis.position = health_chassis_base_pos + Vector2(rx, ry)
			else:
				health_chassis.position = health_chassis_base_pos

		# Reactor pod heart pulsation
		if heart_icon:
			var beat = (int(float(Time.get_ticks_msec()) / 250.0) % 2)
			heart_icon.modulate = Color(1.4, 0.5, 0.6, 1.0) if beat == 1 else Color(1.0, 0.25, 0.4, 1.0)

		# Pixel segmented health bar & ghost trail
		hp_bar.value = round(lerp(float(hp_bar.value), target_hp, 16.0 * delta))
		if ghost_delay > 0.0:
			ghost_delay -= delta
		else:
			ghost_hp = round(lerp(ghost_hp, target_hp, 6.0 * delta))
		if ghost_hp_bar:
			ghost_hp_bar.value = ghost_hp

		# Low HP warning vignette (soft, non-intrusive edge breathing pulse)
		if max_hp > 0.0 and (target_hp / max_hp) < 0.3:
			var hp_ratio = target_hp / max_hp
			var pulse = (sin(Time.get_ticks_msec() * 0.005) * 0.5 + 0.5)
			var target_intensity = lerp(0.5, 0.18, hp_ratio / 0.3) * (0.7 + 0.3 * pulse)
			if vignette_mat:
				vignette_mat.set_shader_parameter("intensity", target_intensity)
		else:
			if vignette_mat:
				vignette_mat.set_shader_parameter("intensity", 0.0)

		if boss_container and boss_container.visible:
			boss_hp_bar.value = round(lerp(float(boss_hp_bar.value), target_boss_hp, 10.0 * delta))
		radar_rect.queue_redraw()

var current_boss_name: String = "APEX LEVIATHAN"

func show_boss_bar(b_name: String, cur_hp: float, maximum: float) -> void:
	current_boss_name = b_name
	max_boss_hp = maximum
	target_boss_hp = cur_hp
	boss_hp_bar.max_value = maximum
	boss_hp_bar.value = cur_hp
	boss_label.text = "%s - %d / %d HP" % [current_boss_name, int(cur_hp), int(maximum)]
	boss_container.show()

func update_boss_health(cur_hp: float, maximum: float) -> void:
	target_boss_hp = cur_hp
	boss_label.text = "%s - %d / %d HP" % [current_boss_name, int(cur_hp), int(maximum)]

func hide_boss_bar() -> void:
	if boss_container:
		boss_container.hide()

func show_chest_jackpot() -> void:
	get_tree().paused = true
	for child in chest_rewards_container.get_children():
		child.queue_free()
	pending_chest_rewards.clear()

	if sound_mgr and sound_mgr.has_method("play_chest"):
		sound_mgr.play_chest()

	if not player_node:
		player_node = get_tree().get_first_node_in_group("player")

	var available = _build_available_upgrades()
	available.shuffle()

	var reward_count = randi_range(3, min(5, available.size()))
	reward_count = max(reward_count, 1)

	var picks: Array[Dictionary] = []
	for i in range(min(reward_count, available.size())):
		picks.append(available[i])

	for item in picks:
		pending_chest_rewards.append(item.id)
		var card = _create_reward_card(item)
		chest_rewards_container.add_child(card)

	chest_modal.show()

func _create_reward_card(item: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(160, 180)
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.bg_color = Color(0.14, 0.08, 0.02, 0.95)
	style.border_color = Color(1.0, 0.85, 0.25, 1.0)
	style.shadow_color = Color(0.8, 0.6, 0.1, 0.5)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	var icon_rect = TextureRect.new()
	icon_rect.texture = SpriteFactory.create_item_icon(item.id)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.custom_minimum_size = Vector2(44, 44)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_rect)

	var stars = Label.new()
	stars.text = item.stars
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	stars.add_theme_font_size_override("font_size", 12)

	var title = Label.new()
	title.text = item.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	title.add_theme_font_size_override("font_size", 13)

	vbox.add_child(stars)
	vbox.add_child(title)
	panel.add_child(vbox)
	return panel

func _on_chest_claim_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	chest_modal.hide()
	get_tree().paused = false
	for up_id in pending_chest_rewards:
		upgrade_selected.emit(up_id)
	call_deferred("update_inventory")

func update_health(current: float, maximum: float) -> void:
	if current < target_hp:
		ghost_delay = 0.35
		health_chassis_shake_frames = 5
	max_hp = maximum
	target_hp = current
	hp_bar.max_value = maximum
	if ghost_hp_bar:
		ghost_hp_bar.max_value = maximum
	hp_label.text = "%d / %d HP" % [int(current), int(maximum)]

	var pct = clamp(current / max(1.0, maximum), 0.0, 1.0)
	var col = Color(0.18, 0.95, 0.45, 1.0)
	if pct <= 0.25:
		col = Color(1.0, 0.22, 0.25, 1.0)
	elif pct <= 0.5:
		col = Color(1.0, 0.75, 0.2, 1.0)

	if hp_percent_label:
		hp_percent_label.text = "%d%%" % int(pct * 100)
		hp_percent_label.add_theme_color_override("font_color", col)

	var fill_style = hp_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxTexture:
		fill_style.texture = SpriteFactory.create_glossy_plasma_fluid_texture(col)
	elif fill_style is StyleBoxFlat:
		fill_style.bg_color = col

	if battery_cells_box:
		var cells = battery_cells_box.get_children()
		var active_count = int(ceil(pct * cells.size()))
		for i in range(cells.size()):
			var c = cells[i] as TextureRect
			if c:
				c.texture = SpriteFactory.create_energy_cell_texture(i < active_count)

func update_xp(current: int, target: int, lvl: int) -> void:
	xp_bar.max_value = target
	xp_bar.value = current
	level_label.text = "LVL %d" % lvl

func set_kills(count: int) -> void:
	kills = count
	kill_label.text = "💀 %d" % kills

func set_swarm_count(count: int) -> void:
	swarm_count = count
	if count < 200:
		swarm_label.text = "BẦY QUÁI: %d [ỔN ĐỊNH]" % count
		swarm_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
	elif count < 600:
		swarm_label.text = "BẦY QUÁI: %d [CẢNH BÁO]" % count
		swarm_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
	else:
		swarm_label.text = "BẦY QUÁI: %d [NGUY CẤP!]" % count
		swarm_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))

func update_inventory() -> void:
	if not inventory_box: return
	if not player_node:
		player_node = get_tree().get_first_node_in_group("player")
	if not player_node: return

	for child in inventory_box.get_children():
		child.queue_free()

	var w_lv = player_node.get("weapon_levels")
	var p_lv = player_node.get("passive_levels")
	var evo = player_node.get("evolved_weapons")
	if not w_lv or not p_lv: return

	# Weapon slots
	for w_id in w_lv.keys():
		if w_lv[w_id] > 0:
			var is_evolved = evo.get(w_id, false) if evo else false
			var icon_id = (w_id + "_evo") if is_evolved else w_id
			var slot = _create_inventory_slot(icon_id, w_lv[w_id], is_evolved, true)
			inventory_box.add_child(slot)

	# Passive slots
	for p_id in p_lv.keys():
		if p_lv[p_id] > 0:
			var slot = _create_inventory_slot(p_id, p_lv[p_id], false, false)
			inventory_box.add_child(slot)

func _create_inventory_slot(item_id: String, lvl: int, is_evolved: bool, is_weapon: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(36, 36)
	var border_col = Color(1.0, 0.3, 0.6, 1.0) if is_evolved else (Color(0.25, 0.85, 1.0, 0.9) if is_weapon else Color(0.25, 0.95, 0.5, 0.9))
	var slot_tex = SpriteFactory.create_pixel_panel_texture(border_col, Color(0.03, 0.05, 0.09, 0.95), border_col, false)
	panel.add_theme_stylebox_override("panel", SpriteFactory.create_pixel_stylebox(slot_tex, 4))

	var icon_rect = TextureRect.new()
	icon_rect.texture = SpriteFactory.create_item_icon(item_id)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.custom_minimum_size = Vector2(26, 26)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_child(icon_rect)

	var lvl_lbl = Label.new()
	lvl_lbl.text = "👑" if is_evolved else str(lvl)
	lvl_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lvl_lbl.add_theme_font_size_override("font_size", 9)
	lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	panel.add_child(lvl_lbl)

	return panel

func show_level_up(lvl: int) -> void:
	get_tree().paused = true
	active_card_scales.clear()
	active_card_targets.clear()

	if sound_mgr and sound_mgr.has_method("play_levelup"):
		sound_mgr.play_levelup()

	if not player_node:
		player_node = get_tree().get_first_node_in_group("player")

	_populate_level_cards(lvl, false)

	if level_up_dimming:
		level_up_dimming.show()
	level_up_panel.show()

func _populate_level_cards(lvl: int, is_banish_mode: bool = false) -> void:
	for child in card_container.get_children():
		child.queue_free()

	var available = _build_available_upgrades()
	available.shuffle()

	# Guarantee evolution card if one is ready
	var picks: Array[Dictionary] = []
	for item in available:
		if item.rarity == "evo":
			picks.append(item)
			break

	for item in available:
		if picks.size() >= 3:
			break
		if not picks.has(item):
			picks.append(item)

	current_level_picks = picks

	for item in picks:
		var card = _create_hologram_card(item, is_banish_mode, lvl)
		card_container.add_child(card)

	_setup_tactical_row(lvl, is_banish_mode)

func _setup_tactical_row(lvl: int, is_banish_mode: bool) -> void:
	if not tactical_row:
		tactical_row = HBoxContainer.new()
		tactical_row.name = "TacticalRow"
		tactical_row.alignment = BoxContainer.ALIGNMENT_CENTER
		tactical_row.add_theme_constant_override("separation", 24)
		$LevelUpModal/VBox.add_child(tactical_row)

	for c in tactical_row.get_children():
		c.queue_free()

	# 1. Reroll Button
	var btn_reroll = Button.new()
	btn_reroll.custom_minimum_size = Vector2(210, 42)
	btn_reroll.text = "🎲 ĐỔI THẺ (Còn %d)" % rerolls_left
	btn_reroll.disabled = (rerolls_left <= 0 or is_banish_mode)
	_style_industrial_btn(btn_reroll, Color(0.2, 0.85, 1.0), Color(0.04, 0.08, 0.16))
	btn_reroll.pressed.connect(func():
		if rerolls_left > 0:
			rerolls_left -= 1
			if sound_mgr and sound_mgr.has_method("play_ui_click"):
				sound_mgr.play_ui_click()
			_populate_level_cards(lvl, false)
	)
	tactical_row.add_child(btn_reroll)

	# 2. Banish Button
	var btn_banish = Button.new()
	btn_banish.custom_minimum_size = Vector2(210, 42)
	btn_banish.text = "◀ QUAY LẠI CHỌN" if is_banish_mode else ("🚫 TẨY TRỪ (Còn %d)" % banishes_left)
	btn_banish.disabled = (banishes_left <= 0 and not is_banish_mode)
	var banish_col = Color(1.0, 0.6, 0.2) if is_banish_mode else Color(1.0, 0.3, 0.35)
	_style_industrial_btn(btn_banish, banish_col, Color(0.14, 0.04, 0.06))
	btn_banish.pressed.connect(func():
		if sound_mgr and sound_mgr.has_method("play_ui_click"):
			sound_mgr.play_ui_click()
		_populate_level_cards(lvl, not is_banish_mode)
	)
	tactical_row.add_child(btn_banish)

	# 3. Skip Button
	var btn_skip = Button.new()
	btn_skip.custom_minimum_size = Vector2(210, 42)
	btn_skip.text = "⏩ BỎ QUA (+50 NANITES)"
	_style_industrial_btn(btn_skip, Color(1.0, 0.85, 0.25), Color(0.14, 0.10, 0.03))
	btn_skip.pressed.connect(func():
		if sound_mgr and sound_mgr.has_method("play_ui_click"):
			sound_mgr.play_ui_click()
		SaveManagerClass.add_nanites(50)
		level_up_panel.hide()
		if level_up_dimming:
			level_up_dimming.hide()
		get_tree().paused = false
	)
	tactical_row.add_child(btn_skip)

func _create_hologram_card(item: Dictionary, is_banish_mode: bool = false, current_lvl: int = 1) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(290, 380)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.pivot_offset = Vector2(145, 190)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	active_card_scales[card] = Vector2.ONE
	active_card_targets[card] = Vector2.ONE

	var glow_col = Color(0.25, 0.85, 1.0, 1.0)
	var cat_name = "[ VŨ KHÍ MỚI ]"
	var bg_col = Color(0.04, 0.08, 0.16, 0.96)

	if is_banish_mode:
		bg_col = Color(0.18, 0.03, 0.05, 0.97)
		glow_col = Color(1.0, 0.25, 0.3, 1.0)
		cat_name = "🚫 CHỌN ĐỂ LOẠI BỎ KHỎI RUN"
	else:
		match item.rarity:
			"evo":
				bg_col = Color(0.16, 0.05, 0.14, 0.97)
				glow_col = Color(1.0, 0.28, 0.65, 1.0)
				cat_name = "👑 TIẾN HÓA TỐI THƯỢNG"
			"passive":
				bg_col = Color(0.03, 0.12, 0.07, 0.96)
				glow_col = Color(0.25, 1.0, 0.55, 1.0)
				cat_name = "💠 NỘI TẠI CÔNG NGHỆ"
			_:
				bg_col = Color(0.04, 0.09, 0.18, 0.96)
				glow_col = Color(0.25, 0.85, 1.0, 1.0)
				if item.get("is_new", false):
					cat_name = "✨ VŨ KHÍ MỚI"
				else:
					cat_name = "⚡ CƯỜNG HÓA VŨ KHÍ"

	var card_tex_normal = SpriteFactory.create_industrial_crt_frame(glow_col, bg_col)
	var card_tex_hover = SpriteFactory.create_industrial_crt_frame(Color(1.0, 1.0, 1.0, 1.0), bg_col.lightened(0.06))
	var card_style_normal = SpriteFactory.create_pixel_stylebox(card_tex_normal, 8)
	var card_style_hover = SpriteFactory.create_pixel_stylebox(card_tex_hover, 8)

	card.add_theme_stylebox_override("panel", card_style_normal)

	var margin_c = MarginContainer.new()
	margin_c.add_theme_constant_override("margin_left", 16)
	margin_c.add_theme_constant_override("margin_right", 16)
	margin_c.add_theme_constant_override("margin_top", 16)
	margin_c.add_theme_constant_override("margin_bottom", 16)
	margin_c.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(margin_c)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin_c.add_child(vbox)

	# 1. Rarity Header Badge
	var tag = Label.new()
	tag.text = cat_name
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", glow_col)
	tag.add_theme_font_size_override("font_size", 12)
	vbox.add_child(tag)

	# 2. Icon 3D Pixel Pedestal
	var icon_pedestal = PanelContainer.new()
	icon_pedestal.custom_minimum_size = Vector2(72, 72)
	icon_pedestal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_pedestal.mouse_filter = Control.MOUSE_FILTER_PASS
	var ip_tex = SpriteFactory.create_pixel_panel_texture(glow_col * 0.85, Color(0.02, 0.04, 0.08, 0.95), glow_col, true)
	icon_pedestal.add_theme_stylebox_override("panel", SpriteFactory.create_pixel_stylebox(ip_tex, 6))

	var icon_rect = TextureRect.new()
	icon_rect.texture = SpriteFactory.create_item_icon(item.id)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_pedestal.add_child(icon_rect)
	vbox.add_child(icon_pedestal)

	# 3. Title
	var title = Label.new()
	title.text = item.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
	vbox.add_child(title)

	# 4. 5-Segment LED Level Meter
	var meter_hbox = HBoxContainer.new()
	meter_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	meter_hbox.add_theme_constant_override("separation", 6)
	meter_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if item.rarity == "evo":
		var evo_meter = Label.new()
		evo_meter.text = "👑 TIẾN HÓA TỐI THƯỢNG - MAX LEVEL"
		evo_meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		evo_meter.add_theme_font_size_override("font_size", 11)
		evo_meter.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
		meter_hbox.add_child(evo_meter)
	else:
		var cur_lvl = item.get("lvl", 0)
		for seg_i in range(5):
			var seg = Panel.new()
			seg.custom_minimum_size = Vector2(28, 8)
			var is_lit = (seg_i < cur_lvl)
			var is_next = (seg_i == cur_lvl)
			var seg_col = glow_col if is_lit else (Color(1.0, 1.0, 1.0, 0.95) if is_next else Color(0.12, 0.18, 0.28, 0.8))
			var seg_border = glow_col if (is_lit or is_next) else Color(0.08, 0.12, 0.18, 0.9)
			var seg_tex = SpriteFactory.create_pixel_button_texture(seg_border, seg_col, false, is_next)
			seg.add_theme_stylebox_override("panel", SpriteFactory.create_pixel_stylebox(seg_tex, 2))
			meter_hbox.add_child(seg)
	vbox.add_child(meter_hbox)

	# 5. Stat Boost Badge (Pixel Pill)
	if item.has("stat_bonus") and str(item.stat_bonus) != "":
		var pill_panel = PanelContainer.new()
		pill_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pill_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		var pill_bg = Color(glow_col.r * 0.15, glow_col.g * 0.15, glow_col.b * 0.15, 0.85)
		var pill_tex = SpriteFactory.create_pixel_panel_texture(glow_col * 0.85, pill_bg, Color.TRANSPARENT, false)
		pill_panel.add_theme_stylebox_override("panel", SpriteFactory.create_pixel_stylebox(pill_tex, 4))

		var pill_lbl = Label.new()
		pill_lbl.text = "  [ %s ]  " % item.stat_bonus
		pill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill_lbl.add_theme_font_size_override("font_size", 11)
		pill_lbl.add_theme_color_override("font_color", glow_col)
		pill_panel.add_child(pill_lbl)
		vbox.add_child(pill_panel)

	# 6. Description
	var desc = Label.new()
	desc.text = item.desc
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98, 0.88))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	# 7. Dedicated Action Button (3D Pixel Bevel)
	var btn_action = Button.new()
	btn_action.custom_minimum_size = Vector2(250, 42)
	btn_action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if is_banish_mode:
		btn_action.text = "🚫 XÓA VĨNH VIỄN KHỎI RUN"
		_style_industrial_btn(btn_action, Color(1.0, 0.3, 0.3), Color(0.18, 0.04, 0.04, 0.98))
	else:
		btn_action.text = "👑 TIẾN HÓA NGAY ▶" if item.rarity == "evo" else "⚡ BÚ NÂNG CẤP NÀY ▶"
		_style_industrial_btn(btn_action, glow_col, Color(0.06, 0.12, 0.22, 0.95))
	btn_action.add_theme_font_size_override("font_size", 13)
	btn_action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	vbox.add_child(btn_action)

	# Event Wiring
	var up_id = item.id
	var on_select = func():
		if is_banish_mode:
			if banishes_left > 0:
				banished_upgrades.append(up_id)
				banishes_left -= 1
				if sound_mgr and sound_mgr.has_method("play_ui_click"):
					sound_mgr.play_ui_click()
				_populate_level_cards(current_lvl, false)
		else:
			if sound_mgr and sound_mgr.has_method("play_ui_click"):
				sound_mgr.play_ui_click()
			_choose_upgrade(up_id)

	btn_action.pressed.connect(on_select)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_select.call()
	)

	card.mouse_entered.connect(func():
		active_card_targets[card] = Vector2(1.05, 1.05)
		card.z_index = 10
		card.add_theme_stylebox_override("panel", card_style_hover)
		if sound_mgr and sound_mgr.has_method("play_ui_hover"):
			sound_mgr.play_ui_hover()
	)
	card.mouse_exited.connect(func():
		active_card_targets[card] = Vector2(1.0, 1.0)
		card.z_index = 0
		card.add_theme_stylebox_override("panel", card_style_normal)
	)

	btn_action.mouse_entered.connect(func():
		active_card_targets[card] = Vector2(1.05, 1.05)
		card.z_index = 10
	)

	return card

func _build_available_upgrades() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if not player_node:
		return list

	var w_lv = player_node.get("weapon_levels")
	var p_lv = player_node.get("passive_levels")
	var evo = player_node.get("evolved_weapons")

	if not w_lv or not p_lv or not evo:
		return list

	# 1. Super Evolutions Check
	if w_lv["railgun"] >= 5 and p_lv["energy_core"] >= 1 and not evo["railgun"]:
		list.append({
			"id": "railgun_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "⚡ HYPERION TACHYON",
			"desc": "Bắn chùm laser kép hủy diệt liên tục xé toạc toàn bộ chiến trường!",
			"lvl": 5, "stat_bonus": "MAX TIẾN HÓA • LASER KÉP", "is_new": false
		})
	if w_lv["flame"] >= 5 and p_lv["thrusters"] >= 1 and not evo["flame"]:
		list.append({
			"id": "flame_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "🔥 INFERNAL SUNSTORM",
			"desc": "Phun bão lửa plasma xoay tròn 360° thiêu rụi mọi quái vật áp sát!",
			"lvl": 5, "stat_bonus": "MAX TIẾN HÓA • BÃO LỬA 360°", "is_new": false
		})
	if w_lv["shockwave"] >= 5 and p_lv["amp"] >= 1 and not evo["shockwave"]:
		list.append({
			"id": "shockwave_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "💥 SUPERNOVA ZERO",
			"desc": "Sóng nổ kép hố đen nén quái lại rồi kích nổ kinh thiên động địa!",
			"lvl": 5, "stat_bonus": "MAX TIẾN HÓA • HỐ ĐEN KÉP", "is_new": false
		})
	if w_lv["missile"] >= 5 and p_lv["magnet"] >= 1 and not evo["missile"]:
		list.append({
			"id": "missile_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "🚀 APOCALYPSE BARRAGE",
			"desc": "Phóng loạt 6 tên lửa đạn chùm tầm nhiệt nổ liên hoàn khắp màn hình!",
			"lvl": 5, "stat_bonus": "MAX TIẾN HÓA • 6 TÊN LỬA TẦM NHIỆT", "is_new": false
		})
	if w_lv["blade"] >= 5 and p_lv["nano_armor"] >= 1 and not evo["blade"]:
		list.append({
			"id": "blade_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "🌀 OMNI-SCYTHE VORTEX",
			"desc": "6 lưỡi hái năng lượng khổng lồ bọc kín không gian xung quanh!",
			"lvl": 5, "stat_bonus": "MAX TIẾN HÓA • 6 LƯỠI HÁI OMNI", "is_new": false
		})
	if w_lv.has("tesla") and w_lv["tesla"] >= 5 and p_lv["energy_core"] >= 1 and not evo["tesla"]:
		list.append({
			"id": "tesla_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "⚡ MJOLNIR STORMCORE",
			"desc": "Bão sấm sét cuồng nộ giáng liên hoàn khắp bản đồ xé nát quân thù!",
			"lvl": 5, "stat_bonus": "MAX TIẾN HÓA • SẤM SÉT TOÀN BẢN ĐỒ", "is_new": false
		})
	if w_lv.has("mortar") and w_lv["mortar"] >= 5 and p_lv["amp"] >= 1 and not evo["mortar"]:
		list.append({
			"id": "mortar_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "☣️ CORROSIVE CHERNOBYL",
			"desc": "Bắn 3 pháo cối phóng xạ tạo biển axít hủy diệt làm tan chảy mọi quái vật!",
			"lvl": 5, "stat_bonus": "MAX TIẾN HÓA • 3 PHÁO CỐI BIỂN AXÍT", "is_new": false
		})

	# 2. Weapons Unlocks & Upgrades
	if w_lv["railgun"] == 0:
		list.append({
			"id": "railgun", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
			"title": "⚡ SÚNG LASER RAILGUN", "desc": "Mở khóa chùm laser cao tần xuyên thủng hàng loạt quái vật theo đường thẳng.",
			"lvl": 0, "stat_bonus": "MỞ KHÓA VŨ KHÍ MỚI", "is_new": true
		})
	elif w_lv["railgun"] < 5 and not evo["railgun"]:
		var r_lvl = w_lv["railgun"]
		list.append({
			"id": "railgun", "rarity": "weapon", "stars": _get_stars(r_lvl),
			"title": "⚡ CƯỜNG HÓA RAILGUN", "desc": "Tăng độ rộng chùm laser, độ dài và sát thương xuyên thấu.",
			"lvl": r_lvl, "stat_bonus": "+30% SÁT THƯƠNG & TIA RỘNG", "is_new": false
		})

	if w_lv["flame"] == 0:
		list.append({
			"id": "flame", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
			"title": "🔥 SÚNG PHUN LỬA", "desc": "Mở khóa luồng lửa plasma thiêu đốt quái vật phía trước mặt.",
			"lvl": 0, "stat_bonus": "MỞ KHÓA VŨ KHÍ MỚI", "is_new": true
		})
	elif w_lv["flame"] < 5 and not evo["flame"]:
		var f_lvl = w_lv["flame"]
		list.append({
			"id": "flame", "rarity": "weapon", "stars": _get_stars(f_lvl),
			"title": "🔥 NÂNG CẤP LỬA PLASMA", "desc": "Mở rộng góc phun, tăng tầm xa và sát thương thiêu đốt.",
			"lvl": f_lvl, "stat_bonus": "+25% GÓC & TẦM PHUN", "is_new": false
		})

	if w_lv["shockwave"] == 0:
		list.append({
			"id": "shockwave", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
			"title": "💥 SÓNG CHẤN ĐỘNG NOVA", "desc": "Mở khóa vòng sóng xung kích hất tung toàn bộ quái vật áp sát.",
			"lvl": 0, "stat_bonus": "MỞ KHÓA VŨ KHÍ MỚI", "is_new": true
		})
	elif w_lv["shockwave"] < 5 and not evo["shockwave"]:
		var s_lvl = w_lv["shockwave"]
		list.append({
			"id": "shockwave", "rarity": "weapon", "stars": _get_stars(s_lvl),
			"title": "💥 NÂNG CẤP SHOCKWAVE", "desc": "Tăng bán kính nổ, lực đẩy lùi và giảm thời gian nạp chiêu.",
			"lvl": s_lvl, "stat_bonus": "+35% BÁN KÍNH SÓNG NỔ", "is_new": false
		})

	if w_lv["missile"] == 0:
		list.append({
			"id": "missile", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
			"title": "🚀 TÊN LỬA TỰ DẪN", "desc": "Mở khóa bệ phóng tên lửa tầm nhiệt bắn đạn chùm nổ diện rộng.",
			"lvl": 0, "stat_bonus": "MỞ KHÓA VŨ KHÍ MỚI", "is_new": true
		})
	elif w_lv["missile"] < 5 and not evo["missile"]:
		var m_lvl = w_lv["missile"]
		list.append({
			"id": "missile", "rarity": "weapon", "stars": _get_stars(m_lvl),
			"title": "🚀 NÂNG CẤP TÊN LỬA", "desc": "Bắn thêm tên lửa mỗi loạt, tăng bán kính nổ và giảm hồi chiêu.",
			"lvl": m_lvl, "stat_bonus": "+2 TÊN LỬA TẦM NHIỆT / LOẠT", "is_new": false
		})

	if w_lv["blade"] == 0:
		list.append({
			"id": "blade", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
			"title": "🌀 LƯỠI HÁI QUỸ ĐẠO", "desc": "Mở khóa lưỡi dao năng lượng xoay quanh người bảo vệ cận chiến.",
			"lvl": 0, "stat_bonus": "MỞ KHÓA VŨ KHÍ MỚI", "is_new": true
		})
	elif w_lv["blade"] < 5 and not evo["blade"]:
		var b_lvl = w_lv["blade"]
		list.append({
			"id": "blade", "rarity": "weapon", "stars": _get_stars(b_lvl),
			"title": "🌀 NÂNG CẤP LƯỠI HÁI", "desc": "Tăng số lượng lưỡi dao, tốc độ xoay và bán kính quỹ đạo.",
			"lvl": b_lvl, "stat_bonus": "+1 LƯỠI HÁI QUỸ ĐẠO", "is_new": false
		})

	if w_lv.has("tesla"):
		if w_lv["tesla"] == 0:
			list.append({
				"id": "tesla", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
				"title": "⚡ CUỘN DÂY TESLA", "desc": "Mở khóa phóng tia điện giật lan truyền qua nhiều kẻ địch liên tiếp.",
				"lvl": 0, "stat_bonus": "MỞ KHÓA VŨ KHÍ MỚI", "is_new": true
			})
		elif w_lv["tesla"] < 5 and not evo["tesla"]:
			var t_lvl = w_lv["tesla"]
			list.append({
				"id": "tesla", "rarity": "weapon", "stars": _get_stars(t_lvl),
				"title": "⚡ NÂNG CẤP TESLA", "desc": "Tăng số lần giật lan, sát thương điện và giảm thời gian nạp.",
				"lvl": t_lvl, "stat_bonus": "+2 TIA SÉT LAN TRUYỀN", "is_new": false
			})

	if w_lv.has("mortar"):
		if w_lv["mortar"] == 0:
			list.append({
				"id": "mortar", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
				"title": "☣️ PHÁO CỐI AXÍT", "desc": "Mở khóa bắn đạn axít vòng cung tạo vũng độc ăn mòn diện rộng.",
				"lvl": 0, "stat_bonus": "MỞ KHÓA VŨ KHÍ MỚI", "is_new": true
			})
		elif w_lv["mortar"] < 5 and not evo["mortar"]:
			var mo_lvl = w_lv["mortar"]
			list.append({
				"id": "mortar", "rarity": "weapon", "stars": _get_stars(mo_lvl),
				"title": "☣️ NÂNG CẤP PHÁO CỐI", "desc": "Bắn thêm đạn cối, tăng bán kính và sát thương vũng axít.",
				"lvl": mo_lvl, "stat_bonus": "+1 ĐẠN PHÁO CỐI AXÍT", "is_new": false
			})

	# 3. Passive Items
	if p_lv["energy_core"] < 5:
		var ec_lvl = p_lv["energy_core"]
		list.append({
			"id": "energy_core", "rarity": "passive", "stars": _get_stars(ec_lvl),
			"title": "⚡ PIN NĂNG LƯỢNG", "desc": "Giảm 12% thời gian hồi chiêu mọi vũ khí (Tiến hóa Railgun & Tesla).",
			"lvl": ec_lvl, "stat_bonus": "-12% HỒI CHIÊU TOÀN DIỆN", "is_new": ec_lvl == 0
		})
	if p_lv["nano_armor"] < 5:
		var na_lvl = p_lv["nano_armor"]
		list.append({
			"id": "nano_armor", "rarity": "passive", "stars": _get_stars(na_lvl),
			"title": "🩸 GIÁP HỢP KIM", "desc": "+30 Máu tối đa và hồi phục 1.5 HP/giây (Tiến hóa Lưỡi Hái).",
			"lvl": na_lvl, "stat_bonus": "+30 HP & +1.5 HP/GIÂY", "is_new": na_lvl == 0
		})
	if p_lv["thrusters"] < 5:
		var th_lvl = p_lv["thrusters"]
		list.append({
			"id": "thrusters", "rarity": "passive", "stars": _get_stars(th_lvl),
			"title": "👟 BỘ ĐẨY PHẢN LỰC", "desc": "+35 Tốc độ di chuyển để luồn lách né quái (Tiến hóa Phun Lửa).",
			"lvl": th_lvl, "stat_bonus": "+35 TỐC ĐỘ DI CHUYỂN", "is_new": th_lvl == 0
		})
	if p_lv["magnet"] < 5:
		var mg_lvl = p_lv["magnet"]
		list.append({
			"id": "magnet", "rarity": "passive", "stars": _get_stars(mg_lvl),
			"title": "🧲 BỘ HÚT TINH THỂ", "desc": "+65 Bán kính hút ngọc kinh nghiệm từ xa (Tiến hóa Tên Lửa).",
			"lvl": mg_lvl, "stat_bonus": "+65 BÁN KÍNH HÚT TINH THỂ", "is_new": mg_lvl == 0
		})
	if p_lv["amp"] < 5:
		var ap_lvl = p_lv["amp"]
		list.append({
			"id": "amp", "rarity": "passive", "stars": _get_stars(ap_lvl),
			"title": "💥 CHÍP KHUẾCH ĐẠI", "desc": "+20% Sát thương toàn bộ kho vũ khí (Tiến hóa Shockwave & Pháo Cối).",
			"lvl": ap_lvl, "stat_bonus": "+20% TỔNG SÁT THƯƠNG", "is_new": ap_lvl == 0
		})

	var filtered: Array[Dictionary] = []
	for it in list:
		if not banished_upgrades.has(it.id):
			filtered.append(it)
	return filtered

func _get_stars(lvl: int) -> String:
	var s = ""
	for i in range(5):
		s += "★" if i < lvl else "☆"
	return "CẤP %d/5  [%s]" % [lvl + 1, s]

func _choose_upgrade(upgrade_id: String) -> void:
	level_up_panel.hide()
	if level_up_dimming:
		level_up_dimming.hide()
	get_tree().paused = false
	upgrade_selected.emit(upgrade_id)
	call_deferred("update_inventory")

func show_game_over(level: int, time_survived: float = 0.0, total_kills_count: int = 0) -> void:
	get_tree().paused = true
	if time_survived > 0.0:
		survival_seconds = time_survived
	if total_kills_count > 0:
		kills = total_kills_count

	if sound_mgr and sound_mgr.has_method("play_ui_back"):
		sound_mgr.play_ui_back()

	SaveManagerClass.init_and_load()
	var base_nanites = int(survival_seconds * 0.75 + float(kills) * 0.25)
	var prev_best = SaveManagerClass.best_time
	SaveManagerClass.add_nanites(base_nanites)
	var run_nanites = int(float(base_nanites) * (1.0 + SaveManagerClass.get_bonus("nanite_gain")))
	SaveManagerClass.record_run_stats(survival_seconds, kills)
	var is_new_record = survival_seconds > prev_best and prev_best > 0.0

	var is_win = survival_seconds >= 900.0
	var title_lbl = game_over_panel.get_node_or_null("VBox/Title") as Label
	if title_lbl:
		if is_win:
			title_lbl.text = "🏆 CHIẾN THẮNG HUY HOÀNG - TÁC CHIẾN HOÀN TẤT! 🏆"
			title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		else:
			title_lbl.text = "☠️ TỬ TRẬN TRONG DANH DỰ • KẾT THÚC CHIẾN DỊCH ☠️"
			title_lbl.add_theme_color_override("font_color", Color(1.0, 0.28, 0.35, 1.0))

	var mins = int(survival_seconds / 60.0)
	var secs = int(survival_seconds) % 60
	var op_info = SaveManagerClass.operative_defs.get(SaveManagerClass.selected_operative, {})
	var op_name = op_info.get("name", "VEX")

	var record_str = " 🔥 [KỶ LỤC MỚI!]" if is_new_record else ""
	game_over_stats.text = "CHIẾN BINH: %s\n⏱️ THỜI GIAN SINH TỒN: %02d:%02d%s    |    ⭐ CẤP ĐỘ ĐẠT ĐƯỢC: LVL %d\n💀 TIÊU DIỆT BẦY QUÁI: %d CON    |    💎 NANITES THU ĐƯỢC: +%d (TỔNG: %d)" % [
		op_name, mins, secs, record_str, level, kills, run_nanites, SaveManagerClass.nanites
	]

	# Build weapon damage breakdown
	if not debrief_damage_box:
		debrief_damage_box = VBoxContainer.new()
		debrief_damage_box.name = "DebriefDamageBox"
		debrief_damage_box.add_theme_constant_override("separation", 6)
		var vbox = $GameOverModal/VBox
		var btn_row = $GameOverModal/VBox/ButtonsRow
		vbox.add_child(debrief_damage_box)
		vbox.move_child(debrief_damage_box, btn_row.get_index())

	for c in debrief_damage_box.get_children():
		c.queue_free()

	var dmg_header = Label.new()
	dmg_header.text = "--- HIỆU SUẤT SÁT THƯƠNG KHO VŨ KHÍ ---"
	dmg_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_header.add_theme_font_size_override("font_size", 13)
	dmg_header.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 1.0))
	debrief_damage_box.add_child(dmg_header)

	var w_dmg = player_node.get("weapon_damage_dealt") if player_node else {}
	var total_dmg = 0.0
	if w_dmg:
		for d in w_dmg.values():
			total_dmg += float(d)

	var weapon_names = {
		"railgun": "⚡ Railgun Laser",
		"flame": "🔥 Súng Phun Lửa",
		"shockwave": "💥 Sóng Chấn Động",
		"missile": "🚀 Tên Lửa Tự Dẫn",
		"blade": "🌀 Lưỡi Hái Quỹ Đạo",
		"tesla": "⚡ Cuộn Dây Tesla",
		"mortar": "☣️ Pháo Cối Axít"
	}

	if total_dmg > 0:
		for w_id in w_dmg.keys():
			var d_val = float(w_dmg[w_id])
			if d_val <= 0: continue
			var pct = (d_val / total_dmg) * 100.0
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			var name_lbl = Label.new()
			name_lbl.custom_minimum_size = Vector2(170, 0)
			name_lbl.text = weapon_names.get(w_id, w_id.capitalize())
			name_lbl.add_theme_font_size_override("font_size", 12)
			row.add_child(name_lbl)

			var bar = ProgressBar.new()
			bar.custom_minimum_size = Vector2(240, 14)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.max_value = 100.0
			bar.value = pct
			bar.show_percentage = false
			var bar_style = StyleBoxFlat.new()
			bar_style.bg_color = Color(0.2, 0.75, 1.0, 0.85)
			bar_style.set_corner_radius_all(3)
			bar.add_theme_stylebox_override("fill", bar_style)
			row.add_child(bar)

			var val_lbl = Label.new()
			val_lbl.custom_minimum_size = Vector2(160, 0)
			val_lbl.text = "%d DMG (%.1f%%)" % [int(d_val), pct]
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_lbl.add_theme_font_size_override("font_size", 12)
			val_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
			row.add_child(val_lbl)

			debrief_damage_box.add_child(row)
	else:
		var no_dmg = Label.new()
		no_dmg.text = "Chưa ghi nhận sát thương vũ khí."
		no_dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_dmg.add_theme_font_size_override("font_size", 11)
		debrief_damage_box.add_child(no_dmg)

	game_over_panel.custom_minimum_size = Vector2(680, 480)
	game_over_panel.pivot_offset = Vector2(340, 240)
	game_over_panel.show()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not level_up_panel.visible and not chest_modal.visible and not game_over_panel.visible:
			if pause_modal.visible:
				_on_resume_pressed()
			else:
				if sound_mgr and sound_mgr.has_method("play_ui_hover"):
					sound_mgr.play_ui_hover()
				get_tree().paused = true
				pause_modal.show()

func _on_resume_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	if pause_modal:
		pause_modal.hide()
	get_tree().paused = false

func _on_menu_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_back"):
		sound_mgr.play_ui_back()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_restart_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_radar_draw() -> void:
	var r_size = radar_rect.size
	var r_center = r_size * 0.5
	var r_radius = min(r_size.x, r_size.y) * 0.5 - 4.0

	# Radar background & rings
	radar_rect.draw_circle(r_center, r_radius, Color(0.03, 0.06, 0.10, 0.9))
	radar_rect.draw_arc(r_center, r_radius, 0.0, TAU, 32, Color(0.3, 0.8, 1.5, 0.85), 2.0)
	radar_rect.draw_arc(r_center, r_radius * 0.5, 0.0, TAU, 24, Color(0.3, 0.8, 1.5, 0.35), 1.0)
	
	# Crosshairs
	radar_rect.draw_line(Vector2(r_center.x, 4), Vector2(r_center.x, r_size.y - 4), Color(0.3, 0.8, 1.5, 0.3), 1.0)
	radar_rect.draw_line(Vector2(4, r_center.y), Vector2(r_size.x - 4, r_center.y), Color(0.3, 0.8, 1.5, 0.3), 1.0)

	# Radar sweep line rotating
	var sweep_angle = Time.get_ticks_msec() * 0.003
	var sweep_end = r_center + Vector2.from_angle(sweep_angle) * (r_radius * 0.95)
	radar_rect.draw_line(r_center, sweep_end, Color(0.4, 0.9, 1.8, 0.4), 1.5)

	# Player dot on map
	if is_instance_valid(player_node):
		var p_pos = player_node.global_position
		var norm_x = clamp(p_pos.x / 5000.0, -1.0, 1.0)
		var norm_y = clamp(p_pos.y / 5000.0, -1.0, 1.0)
		var p_radar_pos = r_center + Vector2(norm_x, norm_y) * (r_radius * 0.9)
		radar_rect.draw_circle(p_radar_pos, 4.0, Color(0.2, 1.8, 0.5, 1.0))
