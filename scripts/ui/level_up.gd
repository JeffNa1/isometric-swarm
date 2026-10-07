extends Control
## Level-up picker. Three cards, row on landscape, stacked on portrait.
## A short input lock stops a frantic thumb from picking by accident.

signal chosen(id: String)

const LOCK_TIME := 0.45

var game: Node
var _cards: Array = []
var _t := 0.0
var _picked := false

class Card extends Control:
	var id := ""
	var info := {}
	var index := 0
	var hover := 0.0
	var appear := 0.0
	var owner_ui: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): set_meta("hot", true))
		mouse_exited.connect(func(): set_meta("hot", false))

	func _process(dt: float) -> void:
		var target := 1.0 if get_meta("hot", false) else 0.0
		hover = lerpf(hover, target, minf(1.0, 14.0 * dt))
		appear = minf(1.0, appear + dt * 5.0)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			owner_ui.pick(index)
			accept_event()

	func _draw() -> void:
		var col: Color = info.color
		var k := ease(clampf(appear - index * 0.12, 0.0, 1.0), 0.3)
		var off := Vector2(0, (1.0 - k) * 40.0 - hover * 6.0)
		var r := Rect2(off, size)
		var bg := Data.C_PANEL.lerp(Data.C_PANEL_HI, hover)
		bg.a = 0.97 * k
		draw_rect(r.grow(6 * hover), Color(col, 0.08 * hover))
		draw_style_box(_box(bg, Color(col, (0.45 + 0.55 * hover) * k)), r)
		draw_rect(Rect2(r.position + Vector2(12, 0), Vector2(r.size.x - 24, 3)), Color(col, k))

		var fb: Font = Data.font_bold
		var fr: Font = Data.font_regular
		var wide := size.x > size.y * 1.4
		var icon_c := r.position + (Vector2(58, size.y * 0.5) if wide else Vector2(size.x * 0.5, 74))
		draw_circle(icon_c, 36, Color(col, 0.12 * k))
		draw_arc(icon_c, 36, 0, TAU, 48, Color(col, 0.5 * k), 2.0, true)
		Icons.draw(self, id, icon_c, 44, Color(col, k))

		var tx := r.position.x + (112.0 if wide else 18.0)
		var tw := size.x - (112.0 + 16.0 if wide else 36.0)
		var ty := r.position.y + (28.0 if wide else 140.0)
		var align := HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER
		draw_string(fr, Vector2(tx, ty), info.tag, align, tw, 14, Color(col.lightened(0.3), k))
		draw_string(fb, Vector2(tx, ty + 30), info.name, align, tw, 25, Color(Data.C_TEXT, k))
		draw_multiline_string(fr, Vector2(tx, ty + 58), info.desc, align, tw, 17, 4, Color(Data.C_TEXT_DIM, k))
		if info.level > 0:
			var pw := 22.0
			var total := pw * Data.MAX_LEVEL
			var px := tx if wide else r.position.x + size.x * 0.5 - total * 0.5
			var py := r.position.y + size.y - 22.0
			for i in Data.MAX_LEVEL:
				var c := col if i < info.level else Color(1, 1, 1, 0.1)
				if i == info.level - 1:
					c = c.lightened(0.4 + 0.3 * sin(Time.get_ticks_msec() / 150.0))
				draw_rect(Rect2(px + i * pw, py, pw - 4, 6), Color(c, c.a * k))

	static func _box(bg: Color, border: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.anti_aliasing = true
		return sb

func setup(g: Node) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	resized.connect(_layout)

func open(offers: Array) -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_t = 0.0
	_picked = false
	for i in offers.size():
		var c := Card.new()
		c.id = offers[i]
		c.info = game.weapons.describe(offers[i])
		c.index = i
		c.owner_ui = self
		add_child(c)
		_cards.append(c)
	visible = true
	_layout()
	Sfx.play("level")

func pick(i: int) -> void:
	if _picked or _t < LOCK_TIME or i >= _cards.size():
		return
	_picked = true
	Sfx.play("click")
	var id: String = _cards[i].id
	visible = false
	chosen.emit(id)

func _process(dt: float) -> void:
	if visible:
		_t += dt
		queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1: pick(0)
			KEY_2: pick(1)
			KEY_3: pick(2)

func _layout() -> void:
	var W := size.x
	var H := size.y
	var n := _cards.size()
	if n == 0:
		return
	if W > H * 1.1:
		var cw := minf(280.0, (W - 80.0) / n - 16.0)
		var ch := 290.0
		var total := cw * n + 24.0 * (n - 1)
		for i in n:
			_cards[i].position = Vector2(W * 0.5 - total * 0.5 + i * (cw + 24.0), H * 0.5 - ch * 0.5 + 40.0)
			_cards[i].size = Vector2(cw, ch)
	else:
		var cw := minf(560.0, W - 48.0)
		var ch := 150.0
		var total := ch * n + 18.0 * (n - 1)
		for i in n:
			_cards[i].position = Vector2(W * 0.5 - cw * 0.5, H * 0.5 - total * 0.5 + i * (ch + 18.0) + 50.0)
			_cards[i].size = Vector2(cw, ch)

func _draw() -> void:
	var a := clampf(_t * 5.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.05, 0.72 * a))
	var fb: Font = Data.font_bold
	var top: float = _cards[0].position.y if not _cards.is_empty() else size.y * 0.3
	var title := "LEVEL UP"
	var w := fb.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	draw_string(fb, Vector2(size.x * 0.5 - w * 0.5, top - 52), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(Data.C_XP, a))
	var sub := "Choose an upgrade" + ("" if game.pending_levels <= 1 else "  •  %d more waiting" % (game.pending_levels - 1))
	var fr: Font = Data.font_regular
	var sw := fr.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_string(fr, Vector2(size.x * 0.5 - sw * 0.5, top - 22), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(Data.C_TEXT_DIM, a))
