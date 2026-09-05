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

const UPGRADES = [
	{"id": "railgun", "title": "⚡ Cường Hóa Railgun", "desc": "Tăng mạnh độ rộng chùm laser và sát thương xuyên thấu."},
	{"id": "flame", "title": "🔥 Bão Lửa Plasma", "desc": "Mở rộng góc thiêu đốt và tầm phun lửa phía trước."},
	{"id": "shockwave", "title": "💥 Sóng Chấn Động Nova", "desc": "Tăng bán kính vụ nổ đẩy lùi quái và giảm thời gian nạp."},
	{"id": "damage", "title": "⚔️ Tăng Sát Thương 30%", "desc": "Gia tăng uy lực tiêu diệt hàng loạt trên mọi vũ khí."},
	{"id": "speed", "title": "👟 Động Cơ Phản Lực", "desc": "Tăng 40 tốc độ di chuyển để thoát khỏi vòng vây quái."},
	{"id": "health", "title": "❤️ Tăng Cường Sinh Lực", "desc": "Tăng 40 máu tối đa và hồi phục khẩn cấp 80 HP."}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_up_panel.hide()
	game_over_panel.hide()
	$GameOverModal/VBox/RestartButton.pressed.connect(_on_restart_pressed)
	player_node = get_tree().get_first_node_in_group("player")
	radar_rect.draw.connect(_on_radar_draw)

func _process(delta: float) -> void:
	if not get_tree().paused:
		survival_seconds += delta
		var mins = int(survival_seconds) / 60
		var secs = int(survival_seconds) % 60
		timer_label.text = "%02d:%02d" % [mins, secs]
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
		radar_rect.queue_redraw()

func update_health(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
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

	var pool = UPGRADES.duplicate()
	pool.shuffle()
	var picks = pool.slice(0, 3)

	for item in picks:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(230, 160)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var vbox = VBoxContainer.new()
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var title = Label.new()
		title.text = item.title
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD

		var desc = Label.new()
		desc.text = item.desc
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.modulate = Color(0.8, 0.85, 0.95, 0.85)

		vbox.add_child(title)
		vbox.add_child(desc)
		btn.add_child(vbox)

		var up_id = item.id
		btn.pressed.connect(func(): _choose_upgrade(up_id))
		card_container.add_child(btn)

	level_up_panel.show()

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
	radar_rect.draw_circle(r_center, r_radius, Color(0.04, 0.08, 0.12, 0.85))
	radar_rect.draw_arc(r_center, r_radius, 0.0, TAU, 32, Color(0.2, 0.6, 1.0, 0.8), 2.0)
	radar_rect.draw_arc(r_center, r_radius * 0.5, 0.0, TAU, 24, Color(0.2, 0.6, 1.0, 0.3), 1.0)
	
	# Radar crosshair
	radar_rect.draw_line(Vector2(r_center.x, 4), Vector2(r_center.x, r_size.y - 4), Color(0.2, 0.6, 1.0, 0.25), 1.0)
	radar_rect.draw_line(Vector2(4, r_center.y), Vector2(r_size.x - 4, r_center.y), Color(0.2, 0.6, 1.0, 0.25), 1.0)

	# Player dot on map (Scale 10,000 px arena to radar radius)
	if is_instance_valid(player_node):
		var p_pos = player_node.global_position
		var norm_x = clamp(p_pos.x / 5000.0, -1.0, 1.0)
		var norm_y = clamp(p_pos.y / 5000.0, -1.0, 1.0)
		var p_radar_pos = r_center + Vector2(norm_x, norm_y) * (r_radius * 0.9)
		radar_rect.draw_circle(p_radar_pos, 3.5, Color(0.2, 1.0, 0.4, 1.0))
