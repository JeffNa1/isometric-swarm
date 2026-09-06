class_name MainMenu
extends Control

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const SaveManagerClass = preload("res://scripts/save_manager.gd")

# Sound manager instance
var sound_mgr: Node = null

# Background FX elements
var embers: Array[Dictionary] = []
const MAX_EMBERS = 45

var bug_silhouettes: Array[Dictionary] = []
const MAX_BUGS = 6

var time_alive: float = 0.0
var is_transitioning: bool = false

# Global settings stored statically
static var master_volume: float = 1.0
static var screen_shake_intensity: float = 1.0
static var show_damage_numbers: bool = true

# UI Node References
@onready var bg_overlay: Control = $BackgroundOverlay
@onready var title_box: VBoxContainer = $Margin/Content/LeftCol/TitleBox
@onready var title_label: Label = $Margin/Content/LeftCol/TitleBox/TitleLabel
@onready var subtitle_label: Label = $Margin/Content/LeftCol/TitleBox/SubtitleBadge/SubtitleLabel
@onready var buttons_vbox: VBoxContainer = $Margin/Content/LeftCol/ButtonsVBox

@onready var btn_play: Button = $Margin/Content/LeftCol/ButtonsVBox/BtnPlay
@onready var btn_operatives: Button = $Margin/Content/LeftCol/ButtonsVBox/BtnOperatives
@onready var btn_armory: Button = $Margin/Content/LeftCol/ButtonsVBox/BtnArmory
@onready var btn_how_to_play: Button = $Margin/Content/LeftCol/ButtonsVBox/BtnHowToPlay
@onready var btn_settings: Button = $Margin/Content/LeftCol/ButtonsVBox/BtnSettings
@onready var btn_credits: Button = $Margin/Content/LeftCol/ButtonsVBox/BtnCredits
@onready var btn_quit: Button = $Margin/Content/LeftCol/ButtonsVBox/BtnQuit

# Modals
@onready var settings_modal: PanelContainer = $SettingsModal
@onready var how_to_play_modal: PanelContainer = $HowToPlayModal
@onready var credits_modal: PanelContainer = $CreditsModal
@onready var operatives_modal: PanelContainer = $OperativesModal
@onready var armory_modal: PanelContainer = $ArmoryModal

# Stats Panel References
@onready var nanite_label: Label = $Margin/Content/RightCol/StatsPanel/Margin/StatsVBox/NaniteLabel
@onready var record_label: Label = $Margin/Content/RightCol/StatsPanel/Margin/StatsVBox/RecordLabel
@onready var kills_label: Label = $Margin/Content/RightCol/StatsPanel/Margin/StatsVBox/KillsLabel
@onready var op_label: Label = $Margin/Content/RightCol/StatsPanel/Margin/StatsVBox/OperativeLabel

# Settings elements
@onready var volume_slider: HSlider = $SettingsModal/VBox/VolumeRow/VolumeSlider
@onready var volume_label: Label = $SettingsModal/VBox/VolumeRow/VolumeValue
@onready var sound_icon_rect: TextureRect = $SettingsModal/VBox/VolumeRow/SoundIcon
@onready var shake_slider: HSlider = $SettingsModal/VBox/ShakeRow/ShakeSlider
@onready var shake_label: Label = $SettingsModal/VBox/ShakeRow/ShakeValue
@onready var dmg_num_btn: Button = $SettingsModal/VBox/DmgNumRow/DmgNumToggle
@onready var btn_settings_back: Button = $SettingsModal/VBox/BtnSettingsBack

# Transition Overlay
@onready var transition_rect: ColorRect = $TransitionRect

# Track button animated scales
var btn_scales: Dictionary = {}
var btn_target_scales: Dictionary = {}
var btn_chevrons: Dictionary = {}

func _ready() -> void:
	# Force window to center and bring to foreground on the active screen
	var screen_size = DisplayServer.screen_get_size()
	var win_size = DisplayServer.window_get_size()
	DisplayServer.window_set_position(Vector2i(Vector2(screen_size - win_size) * 0.5))
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	get_tree().create_timer(1.2).timeout.connect(func():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	)

	SaveManagerClass.init_and_load()
	# Instantiate or find sound manager
	sound_mgr = get_node_or_null("SoundManager")
	if not sound_mgr:
		var snd_scene = preload("res://scenes/sound_manager.tscn")
		sound_mgr = snd_scene.instantiate()
		add_child(sound_mgr)

	_init_background_elements()
	_setup_button_visuals_and_signals()
	_setup_modals()
	_update_stats_display()

	if transition_rect:
		transition_rect.visible = true
		transition_rect.modulate = Color(1, 1, 1, 1)
		var tween = create_tween()
		tween.tween_property(transition_rect, "modulate:a", 0.0, 0.45)
		tween.tween_callback(func(): transition_rect.visible = false)

func _init_background_elements() -> void:
	# Initialize embers
	for i in range(MAX_EMBERS):
		embers.append({
			"pos": Vector2(randf_range(0, 1280), randf_range(0, 720)),
			"vel": Vector2(randf_range(-15, 15), randf_range(-35, -85)),
			"size": randf_range(2.0, 4.2),
			"alpha": randf_range(0.2, 0.8),
			"color": Color(0.2, 2.5, 3.8, 1.0) if randf() < 0.7 else Color(3.5, 2.0, 0.4, 1.0)
		})

	# Initialize subtle scuttling crawler bug silhouettes in distant fog
	var crawler_tex = SpriteFactory.create_crawler_texture()
	for i in range(MAX_BUGS):
		bug_silhouettes.append({
			"pos": Vector2(randf_range(-100, 1380), randf_range(480, 720)),
			"vel": Vector2(randf_range(40, 90), randf_range(20, 45)),
			"scale": randf_range(0.6, 1.1),
			"alpha": randf_range(0.08, 0.18),
			"tex": crawler_tex
		})

	if bg_overlay:
		bg_overlay.draw.connect(_on_bg_draw)

func _setup_button_visuals_and_signals() -> void:
	var buttons = [
		{"btn": btn_play, "code": "01", "title": "CHIẾN DỊCH MỚI", "desc": "Bắt đầu cuộc chiến sinh tồn vô tận", "icon": "play", "color": Color(0.2, 2.8, 3.8, 1.0)},
		{"btn": btn_operatives, "code": "02", "title": "CHỌN CHIẾN BINH", "desc": "4 Đặc nhiệm: Vex, Pyro, Volt, Colossus", "icon": "evolution", "color": Color(0.4, 2.6, 3.8, 1.0)},
		{"btn": btn_armory, "code": "03", "title": "KHO CÔNG NGHỆ CYBER", "desc": "Nâng cấp vĩnh viễn 11 chỉ số tác chiến", "icon": "chest", "color": Color(3.8, 2.2, 0.4, 1.0)},
		{"btn": btn_how_to_play, "code": "04", "title": "CẨM NANG SINH TỒN", "desc": "Hệ thống vũ khí, tiến hóa & di chuyển", "icon": "how_to_play", "color": Color(0.2, 3.5, 1.8, 1.0)},
		{"btn": btn_settings, "code": "05", "title": "THIẾT LẬP HỆ THỐNG", "desc": "Âm lượng, rung chấn & số sát thương", "icon": "settings", "color": Color(3.5, 2.4, 0.4, 1.0)},
		{"btn": btn_credits, "code": "06", "title": "DANH THẦN & ĐỘI NGŨ", "desc": "Bản quyền & đội ngũ phát triển game", "icon": "credits", "color": Color(3.5, 3.0, 0.6, 1.0)},
		{"btn": btn_quit, "code": "07", "title": "THOÁT TRÒ CHƠI", "desc": "Lưu trạng thái & trở về desktop", "icon": "quit", "color": Color(3.8, 0.35, 0.45, 1.0)}
	]

	for b_data in buttons:
		var b = b_data.btn as Button
		if not b: continue

		b.text = ""
		b.custom_minimum_size = Vector2(400, 56)
		b.pivot_offset = Vector2(200, 28)
		btn_scales[b] = Vector2.ONE
		btn_target_scales[b] = Vector2.ONE

		# Custom cyber button styling
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.04, 0.07, 0.13, 0.92)
		style_normal.border_color = Color(0.16, 0.28, 0.44, 0.85)
		style_normal.border_width_left = 4
		style_normal.border_width_top = 1
		style_normal.border_width_right = 1
		style_normal.border_width_bottom = 2
		style_normal.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", style_normal)

		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.08, 0.14, 0.26, 0.96)
		style_hover.border_color = b_data.color
		style_hover.border_width_left = 6
		style_hover.shadow_color = Color(b_data.color.r * 0.15, b_data.color.g * 0.15, b_data.color.b * 0.15, 0.5)
		style_hover.shadow_size = 12
		b.add_theme_stylebox_override("hover", style_hover)

		var style_pressed = style_normal.duplicate()
		style_pressed.bg_color = Color(0.02, 0.04, 0.08, 1.0)
		style_pressed.border_color = Color(1.0, 1.0, 1.0, 1.0)
		b.add_theme_stylebox_override("pressed", style_pressed)

		# Build internal cyber layout
		var hbox = HBoxContainer.new()
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 12.0
		hbox.offset_right = -14.0
		hbox.offset_top = 0.0
		hbox.offset_bottom = 0.0
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 12)
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN

		# Left icon container
		var icon_panel = PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(36, 36)
		icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_style = StyleBoxFlat.new()
		icon_style.bg_color = Color(0.08, 0.13, 0.22, 0.9)
		icon_style.border_color = b_data.color * 0.7
		icon_style.set_border_width_all(1)
		icon_style.set_corner_radius_all(4)
		icon_panel.add_theme_stylebox_override("panel", icon_style)

		var icon_rect = TextureRect.new()
		icon_rect.texture = SpriteFactory.create_menu_icon(b_data.icon)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.custom_minimum_size = Vector2(26, 26)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(icon_rect)
		hbox.add_child(icon_panel)

		# Text VBox
		var tvbox = VBoxContainer.new()
		tvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tvbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tvbox.add_theme_constant_override("separation", 2)

		var top_row = HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_theme_constant_override("separation", 8)

		var code_lbl = Label.new()
		code_lbl.text = "[%s]" % b_data.code
		code_lbl.add_theme_font_size_override("font_size", 13)
		code_lbl.add_theme_color_override("font_color", b_data.color)
		top_row.add_child(code_lbl)

		var title_lbl = Label.new()
		title_lbl.text = b_data.title
		title_lbl.add_theme_font_size_override("font_size", 15)
		title_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		top_row.add_child(title_lbl)
		tvbox.add_child(top_row)

		var desc_lbl = Label.new()
		desc_lbl.text = b_data.desc
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 0.92, 0.75))
		tvbox.add_child(desc_lbl)
		hbox.add_child(tvbox)

		# Right sliding indicator chevron
		var chevron = Label.new()
		chevron.text = "▶"
		chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chevron.add_theme_font_size_override("font_size", 14)
		chevron.add_theme_color_override("font_color", b_data.color)
		chevron.modulate.a = 0.2
		chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(chevron)
		btn_chevrons[b] = chevron

		b.add_child(hbox)

		# Connect Hover & Click
		b.mouse_entered.connect(func(): _on_button_hover(b))
		b.mouse_exited.connect(func(): _on_button_unhover(b))

	btn_play.pressed.connect(_on_play_pressed)
	btn_operatives.pressed.connect(_on_operatives_pressed)
	btn_armory.pressed.connect(_on_armory_pressed)
	btn_how_to_play.pressed.connect(_on_how_to_play_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_credits.pressed.connect(_on_credits_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

func _setup_modals() -> void:
	settings_modal.hide()
	how_to_play_modal.hide()
	credits_modal.hide()
	operatives_modal.hide()
	armory_modal.hide()

	# Volume setup
	volume_slider.value = master_volume * 100.0
	volume_label.text = "%d%%" % int(volume_slider.value)
	volume_slider.value_changed.connect(_on_volume_changed)
	sound_icon_rect.texture = SpriteFactory.create_menu_icon("sound_on")

	# Shake setup
	shake_slider.value = screen_shake_intensity * 100.0
	shake_label.text = "%d%%" % int(shake_slider.value)
	shake_slider.value_changed.connect(_on_shake_changed)

	# Damage numbers toggle setup
	_update_dmg_num_btn_visual()
	dmg_num_btn.pressed.connect(_on_dmg_num_toggled)

	btn_settings_back.pressed.connect(func(): _close_modal(settings_modal))
	$HowToPlayModal/VBox/BtnHowToPlayBack.pressed.connect(func(): _close_modal(how_to_play_modal))
	$CreditsModal/VBox/BtnCreditsBack.pressed.connect(func(): _close_modal(credits_modal))
	$OperativesModal/Margin/VBox/BtnOperativesBack.pressed.connect(func(): _close_modal(operatives_modal))
	$ArmoryModal/Margin/VBox/BottomRow/BtnArmoryBack.pressed.connect(func(): _close_modal(armory_modal))
	$ArmoryModal/Margin/VBox/BottomRow/BtnRefund.pressed.connect(_on_refund_pressed)

	# Populate How To Play Cards with procedural icons
	_setup_how_to_play_cards()

func _setup_how_to_play_cards() -> void:
	var cards_data = [
		{"icon": "wasd", "title": "ĐIỀU KHIỂN", "desc": "Cụm phím W-A-S-D hoặc Mũi Tên di chuyển luồn lách né quái 360°."},
		{"icon": "auto_aim", "title": "TÁC CHIẾN", "desc": "7 Vũ khí tự động khóa mục tiêu và xả hỏa lực liên hoàn."},
		{"icon": "chest", "title": "BẢO BỐI", "desc": "65 Hòm tiếp tế: Bom EMP xóa sạch sàn, Hút Ngọc, Siêu Máu, Quá Tải x2."},
		{"icon": "evolution", "title": "TIẾN HÓA", "desc": "Vũ Khí Cấp 5 + Bị Động = Siêu Vũ Khí! Diệt Trùm 05:00 bú Rương Jackpot."}
	]

	var container = $HowToPlayModal/VBox/CardsContainer
	for child in container.get_children():
		child.queue_free()

	for cd in cards_data:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(210, 220)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.12, 0.20, 0.95)
		style.border_color = Color(0.2, 0.8, 1.4, 0.8)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)

		var vb = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 10)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER

		var icon = TextureRect.new()
		icon.texture = SpriteFactory.create_menu_icon(cd.icon)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

		var t_lbl = Label.new()
		t_lbl.text = cd.title
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3, 1.0))
		t_lbl.add_theme_font_size_override("font_size", 15)

		var d_lbl = Label.new()
		d_lbl.text = cd.desc
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		d_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98, 0.9))
		d_lbl.add_theme_font_size_override("font_size", 12)

		vb.add_child(icon)
		vb.add_child(t_lbl)
		vb.add_child(d_lbl)
		panel.add_child(vb)
		container.add_child(panel)

func _process(delta: float) -> void:
	time_alive += delta

	# Title breathing hover without moving container layout
	if title_label:
		title_label.pivot_offset = title_label.size * 0.5
		title_label.scale = Vector2.ONE * (1.0 + 0.015 * sin(time_alive * 2.0))
		title_label.rotation = sin(time_alive * 1.5) * 0.008

	# Update button scale springs
	for b in btn_scales.keys():
		var cur = btn_scales[b] as Vector2
		var target = btn_target_scales[b] as Vector2
		var new_scale = cur.lerp(target, 20.0 * delta)
		btn_scales[b] = new_scale
		b.scale = new_scale

		# Update chevron slide & glow
		var ch = btn_chevrons[b] as Label
		if target.x > 1.0:
			ch.modulate.a = lerp(ch.modulate.a, 1.0, 16.0 * delta)
		else:
			ch.modulate.a = lerp(ch.modulate.a, 0.2, 16.0 * delta)

	# Update floating embers
	for em in embers:
		em.pos += em.vel * delta
		if em.pos.y < -20:
			em.pos = Vector2(randf_range(0, 1280), 740)
			em.vel = Vector2(randf_range(-15, 15), randf_range(-35, -85))

	# Update scuttling crawler bug silhouettes in background
	for bug in bug_silhouettes:
		bug.pos += bug.vel * delta
		if bug.pos.x > 1380 or bug.pos.y > 780:
			bug.pos = Vector2(randf_range(-120, -20), randf_range(460, 680))

	if bg_overlay:
		bg_overlay.queue_redraw()

func _on_bg_draw() -> void:
	# Draw distant shadowy crawler silhouettes in the fog
	for bug in bug_silhouettes:
		var tex = bug.tex as ImageTexture
		if tex:
			var s = bug.scale
			bg_overlay.draw_set_transform(bug.pos, 0.5, Vector2(s, s))
			bg_overlay.draw_texture(tex, Vector2(-24, -24), Color(0.0, 0.0, 0.0, bug.alpha))
			bg_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Draw floating embers
	for em in embers:
		var c = em.color as Color
		c.a = em.alpha * (0.6 + 0.4 * sin(time_alive * 4.0 + em.pos.x))
		bg_overlay.draw_circle(em.pos, em.size, c)

func _on_button_hover(b: Button) -> void:
	if is_transitioning: return
	btn_target_scales[b] = Vector2(1.06, 1.06)
	if sound_mgr and sound_mgr.has_method("play_ui_hover"):
		sound_mgr.play_ui_hover()

func _on_button_unhover(b: Button) -> void:
	btn_target_scales[b] = Vector2(1.0, 1.0)

func _on_play_pressed() -> void:
	if is_transitioning: return
	is_transitioning = true

	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()

	btn_target_scales[btn_play] = Vector2(0.94, 0.94)

	if transition_rect:
		transition_rect.visible = true
		transition_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var tw = create_tween()
		tw.tween_property(transition_rect, "modulate:a", 1.0, 0.45)
		tw.tween_callback(func():
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		)

func _on_how_to_play_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	_open_modal(how_to_play_modal)

func _on_settings_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	_open_modal(settings_modal)

func _on_credits_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	_open_modal(credits_modal)

func _on_quit_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	get_tree().quit()

func _open_modal(modal: PanelContainer) -> void:
	modal.scale = Vector2(0.85, 0.85)
	modal.pivot_offset = modal.size * 0.5
	modal.modulate.a = 0.0
	modal.show()
	var tw = create_tween()
	tw.tween_property(modal, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(modal, "modulate:a", 1.0, 0.18)

func _close_modal(modal: PanelContainer) -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_back"):
		sound_mgr.play_ui_back()
	var tw = create_tween()
	tw.tween_property(modal, "scale", Vector2(0.88, 0.88), 0.15)
	tw.parallel().tween_property(modal, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): modal.hide())

func _on_volume_changed(val: float) -> void:
	master_volume = val / 100.0
	volume_label.text = "%d%%" % int(val)
	if sound_icon_rect:
		sound_icon_rect.texture = SpriteFactory.create_menu_icon("sound_off" if val <= 0.0 else "sound_on")
	if sound_mgr and sound_mgr.has_method("set_master_volume"):
		sound_mgr.set_master_volume(master_volume)
	if sound_mgr and sound_mgr.has_method("play_ui_hover") and fmod(val, 10.0) == 0:
		sound_mgr.play_ui_hover()

func _on_shake_changed(val: float) -> void:
	screen_shake_intensity = val / 100.0
	shake_label.text = "%d%%" % int(val)

func _on_dmg_num_toggled() -> void:
	show_damage_numbers = not show_damage_numbers
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	_update_dmg_num_btn_visual()

func _update_dmg_num_btn_visual() -> void:
	if dmg_num_btn:
		dmg_num_btn.text = " [ BẬT ] " if show_damage_numbers else " [ TẮT ] "
		var col = Color(0.2, 3.5, 1.8, 1.0) if show_damage_numbers else Color(3.8, 0.3, 0.4, 1.0)
		dmg_num_btn.add_theme_color_override("font_color", col)

func _on_operatives_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	_setup_operatives_modal()
	_open_modal(operatives_modal)

func _on_armory_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	_setup_armory_modal()
	_open_modal(armory_modal)

func _on_refund_pressed() -> void:
	if sound_mgr and sound_mgr.has_method("play_ui_click"):
		sound_mgr.play_ui_click()
	SaveManagerClass.refund_all_upgrades()
	_update_stats_display()
	_setup_armory_modal()

func _update_stats_display() -> void:
	SaveManagerClass.init_and_load()
	if nanite_label:
		nanite_label.text = "NANITE CORES: %d 💎" % SaveManagerClass.nanites
	if record_label:
		var mins = int(SaveManagerClass.best_time / 60.0)
		var secs = int(SaveManagerClass.best_time) % 60
		record_label.text = "KỶ LỤC SINH TỒN: %02d:%02d" % [mins, secs]
	if kills_label:
		kills_label.text = "TỔNG TIÊU DIỆT: %d QUÁI" % SaveManagerClass.total_kills
	if op_label:
		var op_info = SaveManagerClass.operative_defs.get(SaveManagerClass.selected_operative, {})
		var op_name = op_info.get("name", "VEX")
		op_label.text = "CHIẾN BINH: %s" % op_name

func _setup_operatives_modal() -> void:
	var container = $OperativesModal/Margin/VBox/OperativesContainer
	for c in container.get_children():
		c.queue_free()

	for op_id in SaveManagerClass.operative_defs.keys():
		var op = SaveManagerClass.operative_defs[op_id]
		var is_selected = (SaveManagerClass.selected_operative == op_id)

		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(220, 315)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var border_col = op.color if is_selected else Color(0.2, 0.4, 0.6, 0.8)
		var bg_col = Color(0.06, 0.10, 0.18, 0.96) if not is_selected else Color(0.08, 0.15, 0.25, 0.98)
		var style = StyleBoxFlat.new()
		style.bg_color = bg_col
		style.border_color = border_col
		style.set_border_width_all(3 if is_selected else 1)
		style.set_corner_radius_all(8)
		if is_selected:
			style.shadow_color = Color(op.color.r * 0.3, op.color.g * 0.3, op.color.b * 0.3, 0.6)
			style.shadow_size = 10
		card.add_theme_stylebox_override("panel", style)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		card.add_child(margin)

		var vb = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		margin.add_child(vb)

		var name_lbl = Label.new()
		name_lbl.text = op.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", op.color)
		vb.add_child(name_lbl)

		var title_lbl = Label.new()
		title_lbl.text = "[ %s ]" % op.title
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 11)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.9))
		vb.add_child(title_lbl)

		var avatar_rect = TextureRect.new()
		avatar_rect.texture = SpriteFactory.create_operative_avatar(op_id)
		avatar_rect.custom_minimum_size = Vector2(52, 52)
		avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(avatar_rect)

		var w_lbl = Label.new()
		w_lbl.text = "⚔️ Khởi đầu: %s" % op.weapon
		w_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w_lbl.add_theme_font_size_override("font_size", 11)
		w_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 0.95))
		vb.add_child(w_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = op.desc
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98, 0.85))
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(desc_lbl)

		var select_btn = Button.new()
		select_btn.custom_minimum_size = Vector2(180, 36)
		select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if is_selected:
			select_btn.text = "✔ ĐANG CHỌN"
			select_btn.disabled = true
		else:
			select_btn.text = "CHỌN CHIẾN BINH"
			select_btn.pressed.connect(func():
				if sound_mgr and sound_mgr.has_method("play_ui_click"):
					sound_mgr.play_ui_click()
				SaveManagerClass.selected_operative = op_id
				SaveManagerClass.save_game()
				_update_stats_display()
				_setup_operatives_modal()
			)
		vb.add_child(select_btn)

		container.add_child(card)

func _setup_armory_modal() -> void:
	var balance_lbl = $ArmoryModal/Margin/VBox/NaniteBalanceLabel as Label
	if balance_lbl:
		balance_lbl.text = "💎 NANITE CORES KHẢ DỤNG: %d" % SaveManagerClass.nanites

	var grid = $ArmoryModal/Margin/VBox/Scroll/Grid
	for c in grid.get_children():
		c.queue_free()

	for up_id in SaveManagerClass.upgrade_defs.keys():
		var def = SaveManagerClass.upgrade_defs[up_id]
		var cur_lvl = SaveManagerClass.meta_upgrades.get(up_id, 0)
		var max_lvl = SaveManagerClass.max_upgrade_levels.get(up_id, 5)
		var cost = SaveManagerClass.get_upgrade_cost(up_id)
		var is_max = (cur_lvl >= max_lvl)

		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(440, 78)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.10, 0.18, 0.9)
		style.border_color = Color(0.2, 0.5, 0.8, 0.7)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", style)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		card.add_child(margin)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		margin.add_child(hbox)

		# Text Column
		var vb = VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vb.add_theme_constant_override("separation", 3)

		var top_row = HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)

		var name_lbl = Label.new()
		name_lbl.text = def.name
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
		top_row.add_child(name_lbl)

		var lvl_lbl = Label.new()
		var stars = ""
		for i in range(max_lvl):
			stars += "★" if i < cur_lvl else "☆"
		lvl_lbl.text = "[%s]" % stars
		lvl_lbl.add_theme_font_size_override("font_size", 11)
		lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		top_row.add_child(lvl_lbl)
		vb.add_child(top_row)

		var desc_lbl = Label.new()
		desc_lbl.text = "%s (%s)" % [def.desc, def.unit]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.88, 0.96, 0.8))
		vb.add_child(desc_lbl)
		hbox.add_child(vb)

		# Buy button
		var buy_btn = Button.new()
		buy_btn.custom_minimum_size = Vector2(130, 38)
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if is_max:
			buy_btn.text = "MAX CẤP 👑"
			buy_btn.disabled = true
		else:
			buy_btn.text = "%d 💎" % cost
			buy_btn.disabled = (SaveManagerClass.nanites < cost)
			buy_btn.pressed.connect(func():
				if SaveManagerClass.buy_upgrade(up_id):
					if sound_mgr and sound_mgr.has_method("play_ui_click"):
						sound_mgr.play_ui_click()
					_update_stats_display()
					_setup_armory_modal()
			)
		hbox.add_child(buy_btn)

		grid.add_child(card)
