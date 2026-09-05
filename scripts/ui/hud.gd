extends CanvasLayer

signal upgrade_selected(upgrade_id: String)

@onready var xp_bar: ProgressBar = $TopBar/XPBar
@onready var level_label: Label = $TopBar/LevelLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var kill_label: Label = $TopBar/KillLabel
@onready var fps_label: Label = $TopBar/FPSLabel
@onready var swarm_label: Label = $TopBar/SwarmLabel
@onready var hp_bar: ProgressBar = $BottomBar/HPBar
@onready var hp_label: Label = $BottomBar/HPBar/HPLabel
@onready var radar_rect: Control = $RadarContainer/RadarView

@onready var level_up_panel: PanelContainer = $LevelUpModal
@onready var card_container: HBoxContainer = $LevelUpModal/VBox/CardContainer
@onready var game_over_panel: PanelContainer = $GameOverModal
@onready var game_over_stats: Label = $GameOverModal/VBox/StatsLabel

var survival_seconds: float = 0.0
var kills: int = 0
var swarm_count: int = 0
var player_node: Node2D = null

var target_hp: float = 100.0
var max_hp: float = 100.0

var surge_banner: Label = null
var surge_banner_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_up_panel.hide()
	game_over_panel.hide()
	$GameOverModal/VBox/RestartButton.pressed.connect(_on_restart_pressed)
	player_node = get_tree().get_first_node_in_group("player")
	radar_rect.draw.connect(_on_radar_draw)

	_create_surge_banner()

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
		
		# Smooth health bar
		hp_bar.value = lerp(float(hp_bar.value), target_hp, 14.0 * delta)
		radar_rect.queue_redraw()

func update_health(current: float, maximum: float) -> void:
	max_hp = maximum
	target_hp = current
	hp_bar.max_value = maximum
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
	swarm_label.text = "BẦY QUÁI: %d CON" % count

func show_level_up(lvl: int) -> void:
	get_tree().paused = true
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
		btn.custom_minimum_size = Vector2(250, 180)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Rarity Border Styling
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)

		match item.rarity:
			"evo":
				style.bg_color = Color(0.18, 0.05, 0.12, 0.95)
				style.border_color = Color(1.0, 0.25, 0.6, 1.0) # Neon Pink / Red
			"passive":
				style.bg_color = Color(0.05, 0.14, 0.1, 0.95)
				style.border_color = Color(0.2, 0.9, 0.5, 1.0) # Emerald
			_:
				style.bg_color = Color(0.06, 0.1, 0.18, 0.95)
				style.border_color = Color(0.2, 0.7, 1.0, 1.0) # Cyan

		btn.add_theme_stylebox_override("normal", style)
		var hover_style = style.duplicate()
		hover_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
		btn.add_theme_stylebox_override("hover", hover_style)

		var vbox = VBoxContainer.new()
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Header Stars / Category Tag
		var tag = Label.new()
		tag.text = item.stars
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tag_col = Color(1.0, 0.3, 0.5) if item.rarity == "evo" else (Color(0.3, 1.0, 0.6) if item.rarity == "passive" else Color(0.4, 0.85, 1.0))
		tag.add_theme_color_override("font_color", tag_col)
		tag.add_theme_font_size_override("font_size", 13)

		var title = Label.new()
		title.text = item.title
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD
		title.add_theme_font_size_override("font_size", 15)
		var title_col = Color(1.0, 0.9, 0.3, 1.0) if item.rarity == "evo" else Color(1.0, 1.0, 1.0, 1.0)
		title.add_theme_color_override("font_color", title_col)

		var desc = Label.new()
		desc.text = item.desc
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95, 0.9))

		vbox.add_child(tag)
		vbox.add_child(title)
		vbox.add_child(desc)
		btn.add_child(vbox)

		var up_id = item.id
		btn.pressed.connect(func(): _choose_upgrade(up_id))
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

	# 3. Passive Items
	if p_lv["energy_core"] < 5:
		list.append({
			"id": "energy_core", "rarity": "passive", "stars": _get_stars(p_lv["energy_core"]),
			"title": "⚡ PIN NĂNG LƯỢNG", "desc": "Giảm 12% thời gian hồi chiêu mọi vũ khí (Tổ hợp tiến hóa Railgun)."
		})
	if p_lv["nano_armor"] < 5:
		list.append({
			"id": "nano_armor", "rarity": "passive", "stars": _get_stars(p_lv["nano_armor"]),
			"title": "🩸 GIÁP HỢP KIM", "desc": "+30 Máu tối đa và hồi phục 1.5 HP/giây (Tổ hợp tiến hóa Lưỡi Hái)."
		})
	if p_lv["thrusters"] < 5:
		list.append({
			"id": "thrusters", "rarity": "passive", "stars": _get_stars(p_lv["thrusters"]),
			"title": "👟 BỘ ĐẨY PHẢN LỰC", "desc": "+35 Tốc độ di chuyển để luồn lách né quái (Tổ hợp tiến hóa Phun Lửa)."
		})
	if p_lv["magnet"] < 5:
		list.append({
			"id": "magnet", "rarity": "passive", "stars": _get_stars(p_lv["magnet"]),
			"title": "🧲 BỘ HÚT TINH THỂ", "desc": "+65 Bán kính hút ngọc kinh nghiệm từ xa (Tổ hợp tiến hóa Tên Lửa)."
		})
	if p_lv["amp"] < 5:
		list.append({
			"id": "amp", "rarity": "passive", "stars": _get_stars(p_lv["amp"]),
			"title": "💥 CHÍP KHUẾCH ĐẠI", "desc": "+20% Sát thương toàn bộ kho vũ khí (Tổ hợp tiến hóa Shockwave)."
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

func show_game_over(level: int) -> void:
	get_tree().paused = true
	var mins = int(survival_seconds) / 60
	var secs = int(survival_seconds) % 60
	game_over_stats.text = "Thời gian sinh tồn: %02d:%02d\nCấp độ đạt được: LVL %d\nSố quái đã tiêu diệt: %d" % [mins, secs, level, kills]
	game_over_panel.show()

func _on_restart_pressed() -> void:
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
