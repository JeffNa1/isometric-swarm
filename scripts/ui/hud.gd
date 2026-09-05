extends CanvasLayer

const SpriteFactory = preload("res://scripts/sprite_factory.gd")

signal upgrade_selected(upgrade_id: String)

@onready var xp_bar: ProgressBar = $TopBar/XPBar
@onready var level_label: Label = $TopBar/LevelLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var kill_label: Label = $TopBar/KillLabel
@onready var fps_label: Label = $TopBar/FPSLabel
@onready var swarm_label: Label = $TopBar/SwarmLabel

@onready var hp_bar: ProgressBar = $BottomBar/HPBar
@onready var hp_label: Label = $BottomBar/HPBar/HPLabel
@onready var ghost_hp_bar: ProgressBar = $BottomBar/GhostHPBar
@onready var inventory_box: HBoxContainer = $BottomBar/InventoryBox
@onready var low_hp_overlay: ColorRect = $LowHPOverlay

@onready var radar_rect: Control = $RadarContainer/RadarView
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

var active_card_scales: Dictionary = {}
var active_card_targets: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_up_panel.hide()
	game_over_panel.hide()
	if boss_container: boss_container.hide()
	if chest_modal: chest_modal.hide()
	if pause_modal: pause_modal.hide()
	if low_hp_overlay: low_hp_overlay.hide()

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
	call_deferred("update_inventory")

func _setup_hud_styling() -> void:
	# XP Bar Style
	var xp_bg = StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.03, 0.06, 0.12, 0.92)
	xp_bg.border_color = Color(0.15, 0.35, 0.55, 0.8)
	xp_bg.set_border_width_all(1)
	xp_bg.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("background", xp_bg)

	var xp_fill = StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.2, 0.9, 1.0, 1.0)
	xp_fill.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)

	# HP Bar Style
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.04, 0.07, 0.11, 0.92)
	hp_bg.border_color = Color(0.18, 0.35, 0.55, 0.85)
	hp_bg.set_border_width_all(2)
	hp_bg.set_corner_radius_all(6)
	hp_bar.add_theme_stylebox_override("background", hp_bg)

	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.18, 0.95, 0.45, 1.0)
	hp_fill.set_corner_radius_all(6)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)

	# Ghost HP Bar Style
	if ghost_hp_bar:
		var g_bg = StyleBoxEmpty.new()
		ghost_hp_bar.add_theme_stylebox_override("background", g_bg)
		var g_fill = StyleBoxFlat.new()
		g_fill.bg_color = Color(1.0, 0.72, 0.15, 0.85)
		g_fill.set_corner_radius_all(6)
		ghost_hp_bar.add_theme_stylebox_override("fill", g_fill)

	# Boss Bar Style
	if boss_hp_bar:
		var b_bg = StyleBoxFlat.new()
		b_bg.bg_color = Color(0.12, 0.02, 0.04, 0.95)
		b_bg.border_color = Color(0.9, 0.15, 0.25, 0.9)
		b_bg.set_border_width_all(2)
		b_bg.set_corner_radius_all(6)
		boss_hp_bar.add_theme_stylebox_override("background", b_bg)

		var b_fill = StyleBoxFlat.new()
		b_fill.bg_color = Color(1.0, 0.18, 0.28, 1.0)
		b_fill.set_corner_radius_all(6)
		boss_hp_bar.add_theme_stylebox_override("fill", b_fill)

	# Dialog modals
	var modal_style = StyleBoxFlat.new()
	modal_style.bg_color = Color(0.04, 0.07, 0.14, 0.96)
	modal_style.border_color = Color(0.25, 0.8, 1.0, 0.9)
	modal_style.set_border_width_all(2)
	modal_style.set_corner_radius_all(10)
	modal_style.shadow_color = Color(0, 0, 0, 0.8)
	modal_style.shadow_size = 20

	level_up_panel.add_theme_stylebox_override("panel", modal_style)
	if pause_modal:
		pause_modal.add_theme_stylebox_override("panel", modal_style)
	if game_over_panel:
		var go_style = modal_style.duplicate()
		go_style.border_color = Color(1.0, 0.2, 0.3, 0.9)
		game_over_panel.add_theme_stylebox_override("panel", go_style)

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

func show_surge_warning(text: String) -> void:
	if not surge_banner:
		_create_surge_banner()
	surge_banner.text = text
	surge_banner.show()
	surge_banner_timer = 3.8

func _process(delta: float) -> void:
	# Update card scale springs (runs even when paused!)
	for c in active_card_scales.keys():
		if is_instance_valid(c):
			var cur = active_card_scales[c] as Vector2
			var target = active_card_targets[c] as Vector2
			var n_scale = cur.lerp(target, 20.0 * delta)
			active_card_scales[c] = n_scale
			c.scale = n_scale

	if surge_banner_timer > 0.0:
		surge_banner_timer -= delta
		var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.7
		surge_banner.modulate = Color(1.0, 1.0, 1.0, pulse)
		if surge_banner_timer <= 0.0:
			surge_banner.hide()

	if not get_tree().paused:
		survival_seconds += delta
		var mins = int(survival_seconds) / 60
		var secs = int(survival_seconds) % 60
		timer_label.text = "%02d:%02d" % [mins, secs]
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
		
		# Smooth health bar & ghost trail
		hp_bar.value = lerp(float(hp_bar.value), target_hp, 18.0 * delta)
		if ghost_delay > 0.0:
			ghost_delay -= delta
		else:
			ghost_hp = lerp(ghost_hp, target_hp, 6.0 * delta)
		if ghost_hp_bar:
			ghost_hp_bar.value = ghost_hp

		# Low HP warning vignette pulse
		if max_hp > 0.0 and (target_hp / max_hp) < 0.3:
			if low_hp_overlay:
				low_hp_overlay.show()
				var pulse = (sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5) * 0.28
				low_hp_overlay.color = Color(0.9, 0.05, 0.05, pulse)
		else:
			if low_hp_overlay:
				low_hp_overlay.hide()

		if boss_container and boss_container.visible:
			boss_hp_bar.value = lerp(float(boss_hp_bar.value), target_boss_hp, 10.0 * delta)
		radar_rect.queue_redraw()

func show_boss_bar(b_name: String, cur_hp: float, maximum: float) -> void:
	max_boss_hp = maximum
	target_boss_hp = cur_hp
	boss_hp_bar.max_value = maximum
	boss_hp_bar.value = cur_hp
	boss_label.text = "%s - %d / %d HP" % [b_name, int(cur_hp), int(maximum)]
	boss_container.show()

func update_boss_health(cur_hp: float, maximum: float) -> void:
	target_boss_hp = cur_hp
	boss_label.text = "APEX LEVIATHAN - %d / %d HP" % [int(cur_hp), int(maximum)]

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
	max_hp = maximum
	target_hp = current
	hp_bar.max_value = maximum
	if ghost_hp_bar:
		ghost_hp_bar.max_value = maximum
	hp_label.text = "%d / %d HP" % [int(current), int(maximum)]

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
	panel.custom_minimum_size = Vector2(34, 34)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.12, 0.9)
	var border_col = Color(1.0, 0.3, 0.6, 1.0) if is_evolved else (Color(0.25, 0.85, 1.0, 0.9) if is_weapon else Color(0.25, 0.95, 0.5, 0.9))
	style.border_color = border_col
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

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

	for child in card_container.get_children():
		child.queue_free()

	if not player_node:
		player_node = get_tree().get_first_node_in_group("player")

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

	for item in picks:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(260, 330)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = ""
		btn.pivot_offset = Vector2(130, 165)
		active_card_scales[btn] = Vector2.ONE
		active_card_targets[btn] = Vector2.ONE

		# Rarity Styling
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)

		var glow_col = Color(0.25, 0.85, 1.0, 1.0)
		var cat_name = "[VŨ KHÍ MỚI]"
		match item.rarity:
			"evo":
				style.bg_color = Color(0.16, 0.05, 0.12, 0.96)
				glow_col = Color(1.0, 0.28, 0.65, 1.0) # Mythic Pink
				cat_name = "[TIẾN HÓA TỐI THƯỢNG]"
			"passive":
				style.bg_color = Color(0.04, 0.13, 0.08, 0.96)
				glow_col = Color(0.25, 1.0, 0.55, 1.0) # Emerald
				cat_name = "[NỘI TẠI CÔNG NGHỆ]"
			_:
				style.bg_color = Color(0.05, 0.09, 0.18, 0.96)
				glow_col = Color(0.25, 0.85, 1.0, 1.0) # Cyan
				if not item.stars.begins_with("✨"):
					cat_name = "[CƯỜNG HÓA VŨ KHÍ]"

		style.border_color = glow_col
		style.shadow_color = Color(glow_col.r * 0.15, glow_col.g * 0.15, glow_col.b * 0.15, 0.45)
		style.shadow_size = 14
		btn.add_theme_stylebox_override("normal", style)

		var hover_style = style.duplicate()
		hover_style.bg_color = style.bg_color.lightened(0.12)
		hover_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
		hover_style.set_border_width_all(3)
		hover_style.shadow_size = 22
		btn.add_theme_stylebox_override("hover", hover_style)

		# Build Card Internal Layout
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 16.0
		vbox.offset_right = -16.0
		vbox.offset_top = 16.0
		vbox.offset_bottom = -16.0
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 10)

		# Category ribbon
		var tag = Label.new()
		tag.text = cat_name
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_color_override("font_color", glow_col)
		tag.add_theme_font_size_override("font_size", 12)
		vbox.add_child(tag)

		# Icon Box
		var icon_panel = PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(64, 64)
		icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ip_style = StyleBoxFlat.new()
		ip_style.bg_color = Color(0.02, 0.04, 0.08, 0.9)
		ip_style.border_color = glow_col * 0.8
		ip_style.set_border_width_all(2)
		ip_style.set_corner_radius_all(8)
		icon_panel.add_theme_stylebox_override("panel", ip_style)

		var icon_rect = TextureRect.new()
		icon_rect.texture = SpriteFactory.create_item_icon(item.id)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(icon_rect)
		vbox.add_child(icon_panel)

		# Title
		var title = Label.new()
		title.text = item.title
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0, 1.0))
		vbox.add_child(title)

		# Stars progression
		var stars_lbl = Label.new()
		stars_lbl.text = item.stars
		stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stars_lbl.add_theme_font_size_override("font_size", 13)
		stars_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3, 1.0) if item.rarity != "evo" else Color(1.0, 0.5, 0.8, 1.0))
		vbox.add_child(stars_lbl)

		# Description
		var desc = Label.new()
		desc.text = item.desc
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95, 0.88))
		vbox.add_child(desc)

		btn.add_child(vbox)

		# Connect Hover & Click
		var cur_btn = btn
		var up_id = item.id
		btn.mouse_entered.connect(func():
			active_card_targets[cur_btn] = Vector2(1.06, 1.06)
			if sound_mgr and sound_mgr.has_method("play_ui_hover"):
				sound_mgr.play_ui_hover()
		)
		btn.mouse_exited.connect(func():
			active_card_targets[cur_btn] = Vector2(1.0, 1.0)
		)
		btn.pressed.connect(func():
			if sound_mgr and sound_mgr.has_method("play_ui_click"):
				sound_mgr.play_ui_click()
			_choose_upgrade(up_id)
		)
		card_container.add_child(btn)

	level_up_panel.show()

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
			"desc": "Bắn chùm laser kép hủy diệt liên tục xé toạc toàn bộ chiến trường!"
		})
	if w_lv["flame"] >= 5 and p_lv["thrusters"] >= 1 and not evo["flame"]:
		list.append({
			"id": "flame_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "🔥 INFERNAL SUNSTORM",
			"desc": "Phun bão lửa plasma xoay tròn 360° thiêu rụi mọi quái vật áp sát!"
		})
	if w_lv["shockwave"] >= 5 and p_lv["amp"] >= 1 and not evo["shockwave"]:
		list.append({
			"id": "shockwave_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "💥 SUPERNOVA ZERO",
			"desc": "Sóng nổ kép hố đen nén quái lại rồi kích nổ kinh thiên động địa!"
		})
	if w_lv["missile"] >= 5 and p_lv["magnet"] >= 1 and not evo["missile"]:
		list.append({
			"id": "missile_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "🚀 APOCALYPSE BARRAGE",
			"desc": "Phóng loạt 6 tên lửa đạn chùm tầm nhiệt nổ liên hoàn khắp màn hình!"
		})
	if w_lv["blade"] >= 5 and p_lv["nano_armor"] >= 1 and not evo["blade"]:
		list.append({
			"id": "blade_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "🌀 OMNI-SCYTHE VORTEX",
			"desc": "4 lưỡi hái năng lượng khổng lồ bọc kín không gian xung quanh!"
		})
	if w_lv.has("tesla") and w_lv["tesla"] >= 5 and p_lv["energy_core"] >= 1 and not evo["tesla"]:
		list.append({
			"id": "tesla_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "⚡ MJOLNIR STORMCORE",
			"desc": "Bão sấm sét cuồng nộ giáng liên hoàn khắp bản đồ xé nát quân thù!"
		})
	if w_lv.has("mortar") and w_lv["mortar"] >= 5 and p_lv["amp"] >= 1 and not evo["mortar"]:
		list.append({
			"id": "mortar_evo", "rarity": "evo", "stars": "👑 TIẾN HÓA TỐI THƯỢNG",
			"title": "☣️ CORROSIVE CHERNOBYL",
			"desc": "Bắn 4 pháo cối phóng xạ tạo biển axít hủy diệt làm tan chảy mọi quái vật!"
		})

	# 2. Weapons Unlocks & Upgrades
	if w_lv["railgun"] < 5 and not evo["railgun"]:
		list.append({
			"id": "railgun", "rarity": "weapon", "stars": _get_stars(w_lv["railgun"]),
			"title": "⚡ CƯỜNG HÓA RAILGUN", "desc": "Tăng độ rộng chùm laser, độ dài và sát thương xuyên thấu."
		})
	if w_lv["flame"] == 0:
		list.append({
			"id": "flame", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
			"title": "🔥 SÚNG PHUN LỬA", "desc": "Mở khóa luồng lửa plasma thiêu đốt quái vật phía trước mặt."
		})
	elif w_lv["flame"] < 5 and not evo["flame"]:
		list.append({
			"id": "flame", "rarity": "weapon", "stars": _get_stars(w_lv["flame"]),
			"title": "🔥 NÂNG CẤP LỬA PLASMA", "desc": "Mở rộng góc phun, tăng tầm xa và sát thương thiêu đốt."
		})

	if w_lv["shockwave"] == 0:
		list.append({
			"id": "shockwave", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
			"title": "💥 SÓNG CHẤN ĐỘNG NOVA", "desc": "Mở khóa vòng sóng xung kích hất tung toàn bộ quái vật áp sát."
		})
	elif w_lv["shockwave"] < 5 and not evo["shockwave"]:
		list.append({
			"id": "shockwave", "rarity": "weapon", "stars": _get_stars(w_lv["shockwave"]),
			"title": "💥 NÂNG CẤP SHOCKWAVE", "desc": "Tăng bán kính nổ, lực đẩy lùi và giảm thời gian nạp chiêu."
		})

	if w_lv["missile"] == 0:
		list.append({
			"id": "missile", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
			"title": "🚀 TÊN LỬA TỰ DẪN", "desc": "Mở khóa bệ phóng tên lửa tầm nhiệt bắn đạn chùm nổ diện rộng."
		})
	elif w_lv["missile"] < 5 and not evo["missile"]:
		list.append({
			"id": "missile", "rarity": "weapon", "stars": _get_stars(w_lv["missile"]),
			"title": "🚀 NÂNG CẤP TÊN LỬA", "desc": "Bắn thêm tên lửa mỗi loạt, tăng bán kính nổ và giảm hồi chiêu."
		})

	if w_lv["blade"] == 0:
		list.append({
			"id": "blade", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
			"title": "🌀 LƯỠI HÁI QUỸ ĐẠO", "desc": "Mở khóa lưỡi dao năng lượng xoay quanh người bảo vệ cận chiến."
		})
	elif w_lv["blade"] < 5 and not evo["blade"]:
		list.append({
			"id": "blade", "rarity": "weapon", "stars": _get_stars(w_lv["blade"]),
			"title": "🌀 NÂNG CẤP LƯỠI HÁI", "desc": "Tăng số lượng lưỡi dao, tốc độ xoay và bán kính quỹ đạo."
		})

	if w_lv.has("tesla"):
		if w_lv["tesla"] == 0:
			list.append({
				"id": "tesla", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
				"title": "⚡ CUỘN DÂY TESLA", "desc": "Mở khóa phóng tia điện giật lan truyền qua nhiều kẻ địch liên tiếp."
			})
		elif w_lv["tesla"] < 5 and not evo["tesla"]:
			list.append({
				"id": "tesla", "rarity": "weapon", "stars": _get_stars(w_lv["tesla"]),
				"title": "⚡ NÂNG CẤP TESLA", "desc": "Tăng số lần giật lan, sát thương điện và giảm thời gian nạp."
			})

	if w_lv.has("mortar"):
		if w_lv["mortar"] == 0:
			list.append({
				"id": "mortar", "rarity": "weapon", "stars": "✨ VŨ KHÍ MỚI",
				"title": "☣️ PHÁO CỐI AXÍT", "desc": "Mở khóa bắn đạn axít vòng cung tạo vũng độc ăn mòn diện rộng."
			})
		elif w_lv["mortar"] < 5 and not evo["mortar"]:
			list.append({
				"id": "mortar", "rarity": "weapon", "stars": _get_stars(w_lv["mortar"]),
				"title": "☣️ NÂNG CẤP PHÁO CỐI", "desc": "Bắn thêm đạn cối, tăng bán kính và sát thương vũng axít."
			})

	# 3. Passive Items
	if p_lv["energy_core"] < 5:
		list.append({
			"id": "energy_core", "rarity": "passive", "stars": _get_stars(p_lv["energy_core"]),
			"title": "⚡ PIN NĂNG LƯỢNG", "desc": "Giảm 12% thời gian hồi chiêu mọi vũ khí (Tiến hóa Railgun & Tesla)."
		})
	if p_lv["nano_armor"] < 5:
		list.append({
			"id": "nano_armor", "rarity": "passive", "stars": _get_stars(p_lv["nano_armor"]),
			"title": "🩸 GIÁP HỢP KIM", "desc": "+30 Máu tối đa và hồi phục 1.5 HP/giây (Tiến hóa Lưỡi Hái)."
		})
	if p_lv["thrusters"] < 5:
		list.append({
			"id": "thrusters", "rarity": "passive", "stars": _get_stars(p_lv["thrusters"]),
			"title": "👟 BỘ ĐẨY PHẢN LỰC", "desc": "+35 Tốc độ di chuyển để luồn lách né quái (Tiến hóa Phun Lửa)."
		})
	if p_lv["magnet"] < 5:
		list.append({
			"id": "magnet", "rarity": "passive", "stars": _get_stars(p_lv["magnet"]),
			"title": "🧲 BỘ HÚT TINH THỂ", "desc": "+65 Bán kính hút ngọc kinh nghiệm từ xa (Tiến hóa Tên Lửa)."
		})
	if p_lv["amp"] < 5:
		list.append({
			"id": "amp", "rarity": "passive", "stars": _get_stars(p_lv["amp"]),
			"title": "💥 CHÍP KHUẾCH ĐẠI", "desc": "+20% Sát thương toàn bộ kho vũ khí (Tiến hóa Shockwave & Pháo Cối)."
		})

	return list

func _get_stars(lvl: int) -> String:
	var s = ""
	for i in range(5):
		s += "★" if i < lvl else "☆"
	return "CẤP %d/5  [%s]" % [lvl + 1, s]

func _choose_upgrade(upgrade_id: String) -> void:
	level_up_panel.hide()
	get_tree().paused = false
	upgrade_selected.emit(upgrade_id)
	call_deferred("update_inventory")

func show_game_over(level: int) -> void:
	get_tree().paused = true
	if sound_mgr and sound_mgr.has_method("play_ui_back"):
		sound_mgr.play_ui_back()
	var mins = int(survival_seconds) / 60
	var secs = int(survival_seconds) % 60
	game_over_stats.text = "⏱️ THỜI GIAN SINH TỒN: %02d:%02d\n⭐ CẤP ĐỘ ĐẠT ĐƯỢC: LVL %d\n💀 QUÁI VẬT TIÊU DIỆT: %d CON" % [mins, secs, level, kills]
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
