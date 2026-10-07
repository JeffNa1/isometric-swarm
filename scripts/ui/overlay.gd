extends Control
## Modal panel used for pause, defeat and victory screens.

var _panel: PanelContainer
var _box: VBoxContainer
var _t := 0.0

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Data.theme
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Data.C_PANEL, 0.96)
	sb.border_color = Data.C_LINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 32
	sb.content_margin_bottom = 32
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_panel.add_child(_box)

## lines: Array of [label, value] pairs. buttons: Array of [text, Callable].
func show_screen(title: String, title_col: Color, subtitle: String, lines: Array, buttons: Array) -> void:
	for c in _box.get_children():
		c.queue_free()
	var tl := Label.new()
	tl.text = title
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_override("font", Data.font_bold)
	tl.add_theme_font_size_override("font_size", 48)
	tl.add_theme_color_override("font_color", title_col)
	_box.add_child(tl)
	if subtitle != "":
		var st := Label.new()
		st.text = subtitle
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.add_theme_color_override("font_color", Data.C_TEXT_DIM)
		st.add_theme_font_size_override("font_size", 18)
		_box.add_child(st)
	if not lines.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 40)
		grid.add_theme_constant_override("v_separation", 6)
		var gc := CenterContainer.new()
		gc.add_child(grid)
		_box.add_child(_spacer(6))
		_box.add_child(gc)
		for ln in lines:
			var a := Label.new()
			a.text = ln[0]
			a.add_theme_color_override("font_color", Data.C_TEXT_DIM)
			var b := Label.new()
			b.text = ln[1]
			b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			b.add_theme_font_override("font", Data.font_bold)
			grid.add_child(a)
			grid.add_child(b)
	_box.add_child(_spacer(10))
	var first: Button = null
	for bt in buttons:
		var btn := Button.new()
		btn.text = bt[0]
		btn.custom_minimum_size = Vector2(0, 56)
		var cb: Callable = bt[1]
		btn.pressed.connect(func():
			Sfx.play("click")
			cb.call())
		_box.add_child(btn)
		if first == null:
			first = btn
	visible = true
	_t = 0.0
	modulate.a = 0.0
	if first:
		first.grab_focus.call_deferred()

func hide_screen() -> void:
	visible = false

func _process(dt: float) -> void:
	if visible:
		_t += dt
		modulate.a = clampf(_t * 5.0, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.05, 0.7))

static func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
