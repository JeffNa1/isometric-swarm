extends Control
## In-run HUD, drawn directly for crispness: XP bar, timer, HP, loadout,
## boss bar, event banners, plus the touch controls (floating stick, dash, pause).

var game: Node
var touch_mode := false
var show_fps := false

var _banners: Array = []   # [title, sub, color, life]
var _banner_t := 0.0
var _xp_shown := 0.0
var _hp_shown := 1.0
var _kills_pop := 0.0
var _last_kills := 0

# touch state
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
const STICK_R := 70.0

func setup(g: Node) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_mode = DisplayServer.is_touchscreen_available()

func banner(title: String, sub: String = "", col: Color = Data.C_ACCENT) -> void:
	_banners.append([title, sub, col, 2.8])

func _process(dt: float) -> void:
	if not _banners.is_empty():
		_banners[0][3] -= dt
		if _banners[0][3] <= 0.0:
			_banners.pop_front()
	if game.level_xp_need > 0:
		_xp_shown = lerpf(_xp_shown, float(game.xp) / float(game.level_xp_need), minf(1.0, 10.0 * dt))
	_hp_shown = lerpf(_hp_shown, game.player.hp / game.player.max_hp, minf(1.0, 8.0 * dt))
	if game.kills != _last_kills:
		_last_kills = game.kills
		_kills_pop = 1.0
	_kills_pop = maxf(0.0, _kills_pop - dt * 6.0)
	queue_redraw()

# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_mode = true
	if game.paused_for_ui:
		_release_stick()
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var p := _to_local(e.position)
		if e.pressed:
			if _pause_rect().grow(10).has_point(p):
				game.toggle_pause()
				get_viewport().set_input_as_handled()
			elif p.distance_to(_dash_center()) < _dash_radius() + 18.0:
				game.player.try_dash()
				get_viewport().set_input_as_handled()
			elif _stick_id < 0:
				_stick_id = e.index
				_stick_origin = p
				_stick_pos = p
		elif e.index == _stick_id:
			_release_stick()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _stick_id:
			_stick_pos = _to_local(e.position)
			var d := _stick_pos - _stick_origin
			# let the base trail behind the thumb so the stick never "runs out"
			if d.length() > STICK_R:
				_stick_origin = _stick_pos - d.normalized() * STICK_R
			_update_stick()

func _to_local(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos

func _update_stick() -> void:
	var d := (_stick_pos - _stick_origin) / STICK_R
	if d.length() < 0.12:
		d = Vector2.ZERO
	game.player.stick = d.limit_length(1.0)

func _release_stick() -> void:
	_stick_id = -1
	game.player.stick = Vector2.ZERO

func _pause_rect() -> Rect2:
	return Rect2(size.x - 58, 16, 42, 42)

func _dash_center() -> Vector2:
	return Vector2(size.x - 92, size.y - 104)

func _dash_radius() -> float:
	return 46.0

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var W := size.x
	var H := size.y
	var fb: Font = Data.font_bold
	var fr: Font = Data.font_regular

	# XP bar across the very top
	draw_rect(Rect2(0, 0, W, 8), Color(0.02, 0.04, 0.08, 0.85))
	draw_rect(Rect2(0, 0, W * clampf(_xp_shown, 0, 1), 8), Data.C_XP)
	draw_rect(Rect2(0, 6, W * clampf(_xp_shown, 0, 1), 2), Data.C_XP.lightened(0.5))

	# level + HP (top-left)
	var x := 18.0
	var y := 22.0
	_panel(Rect2(x - 6, y - 4, 210, 62))
	_text(fb, Vector2(x + 4, y + 22), "LV %d" % game.level, 24, Data.C_TEXT)
	var hpw := 120.0
	var hpr := Rect2(x + 76, y + 8, hpw, 10)
	draw_rect(hpr, Color(0, 0, 0, 0.55))
	var hpk := clampf(_hp_shown, 0, 1)
	var hp_col := Data.C_HP if hpk < 0.35 else Color("ff7d8f")
	draw_rect(Rect2(hpr.position, Vector2(hpw * hpk, 10)), hp_col)
	_text(fr, Vector2(x + 76, y + 40), "%d / %d" % [ceili(game.player.hp), int(game.player.max_hp)], 15, Data.C_TEXT_DIM)

	# loadout icons
	var iy := y + 70.0
	var ix := x - 6.0
	for id in game.weapons.weapon_order:
		_slot(Vector2(ix, iy), 40.0, id, Data.WEAPONS[id].color, game.weapons.lv(id))
		ix += 46.0
	ix = x - 6.0
	for id in game.weapons.passive_order:
		_slot(Vector2(ix, iy + 48.0), 32.0, id, Data.PASSIVES[id].color, game.weapons.lv(id))
		ix += 38.0

	# timer (center)
	var ts := Data.format_time(game.elapsed)
	_text_c(fb, Vector2(W * 0.5, 50), ts, 36, Data.C_TEXT)
	var sub: String = game.next_event_hint()
	if sub != "":
		_text_c(fr, Vector2(W * 0.5, 72), sub, 15, Data.C_TEXT_DIM)

	# kills (top-right)
	var kx := W - (76.0 if touch_mode else 20.0)
	var ks := "%d" % game.kills
	var ksz := int(24 + 4 * _kills_pop)
	var kw := fb.get_string_size(ks, HORIZONTAL_ALIGNMENT_LEFT, -1, ksz).x
	_text(fb, Vector2(kx - kw, 46), ks, ksz, Data.C_TEXT)
	_skull(Vector2(kx - kw - 18, 38), 10.0)
	_text(fr, Vector2(kx - fr.get_string_size("ENEMIES %d" % game.swarm.count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, 66), "ENEMIES %d" % game.swarm.count, 14, Data.C_TEXT_DIM)

	if show_fps:
		_text(fr, Vector2(W - 120, H - 16), "%d FPS  cap %d" % [Engine.get_frames_per_second(), game.swarm.max_count], 14, Data.C_TEXT_DIM)

	# boss bar
	var by := 96.0
	for b in game.bosses:
		var bw := minf(560.0, W - 80.0)
		var r := Rect2(W * 0.5 - bw * 0.5, by + 14, bw, 12)
		_text_c(fb, Vector2(W * 0.5, by + 6), b.title, 18, b.color.lightened(0.3))
		draw_rect(r.grow(2), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(r.position, Vector2(bw * clampf(b.hp / b.max_hp, 0, 1), 12)), b.color)
		draw_rect(Rect2(r.position, Vector2(bw * clampf(b.hp / b.max_hp, 0, 1), 3)), b.color.lightened(0.5))
		by += 44.0

	# banner
	if not _banners.is_empty():
		var bn: Array = _banners[0]
		var life: float = bn[3]
		var a := clampf(minf((2.8 - life) * 5.0, life * 2.0), 0.0, 1.0)
		var scale_in := 1.0 + 0.15 * clampf(1.0 - (2.8 - life) * 5.0, 0.0, 1.0)
		var col: Color = bn[2]
		var cy := H * 0.3
		draw_rect(Rect2(0, cy - 44, W, 76), Color(0.02, 0.03, 0.07, 0.55 * a))
		draw_rect(Rect2(0, cy - 44, W, 2), Color(col, 0.7 * a))
		draw_rect(Rect2(0, cy + 30, W, 2), Color(col, 0.7 * a))
		_text_c(fb, Vector2(W * 0.5, cy + 2), bn[0], int(38 * scale_in), Color(col.lightened(0.2), a))
		if bn[1] != "":
			_text_c(fr, Vector2(W * 0.5, cy + 24), bn[1], 17, Color(Data.C_TEXT, a * 0.9))

	# touch controls
	if touch_mode:
		var pr := _pause_rect()
		draw_rect(pr, Color(0.05, 0.08, 0.15, 0.7))
		draw_rect(Rect2(pr.position + Vector2(13, 11), Vector2(5, 20)), Data.C_TEXT)
		draw_rect(Rect2(pr.position + Vector2(24, 11), Vector2(5, 20)), Data.C_TEXT)

		var dc := _dash_center()
		var dr := _dash_radius()
		var ready: bool = game.player.dash_cd <= 0.0
		draw_circle(dc, dr, Color(0.05, 0.1, 0.2, 0.55))
		draw_arc(dc, dr, 0, TAU, 48, Color(Data.C_ACCENT, 0.9 if ready else 0.25), 3.0, true)
		if not ready:
			var k: float = 1.0 - game.player.dash_cd / game.player.dash_cooldown()
			draw_arc(dc, dr, -PI * 0.5, -PI * 0.5 + TAU * k, 48, Data.C_ACCENT, 3.0, true)
		_text_c(fb, dc + Vector2(0, 7), "DASH", 18, Color(Data.C_TEXT, 1.0 if ready else 0.4))

		if _stick_id >= 0:
			draw_circle(_stick_origin, STICK_R, Color(0.05, 0.1, 0.2, 0.35))
			draw_arc(_stick_origin, STICK_R, 0, TAU, 48, Color(Data.C_ACCENT, 0.35), 2.0, true)
			var kp := _stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_R)
			draw_circle(kp, 28.0, Color(Data.C_ACCENT, 0.35))
			draw_circle(kp, 18.0, Color(Data.C_ACCENT, 0.6))

	# off-screen pointers for supply caches
	var view: Rect2 = game.view_rect()
	for ip in game.pickups.notable_items():
		if view.grow(-20).has_point(ip):
			continue
		var center := view.get_center()
		var dir: Vector2 = (ip - center).normalized()
		var sp := Vector2(W, H) * 0.5 + dir * minf(W, H) * 0.42
		draw_colored_polygon(PackedVector2Array([sp + dir * 14, sp + dir.orthogonal() * 8, sp - dir.orthogonal() * 8]), Data.C_GOLD)

func _panel(r: Rect2) -> void:
	draw_rect(r, Color(0.03, 0.05, 0.1, 0.55))

func _slot(p: Vector2, s: float, id: String, col: Color, level: int) -> void:
	var r := Rect2(p, Vector2(s, s))
	draw_rect(r, Color(0.04, 0.06, 0.12, 0.8))
	draw_rect(r, Color(col, 0.6), false, 1.5)
	Icons.draw(self, id, r.get_center() - Vector2(0, 3), s * 0.75, col)
	var pip := (s - 8.0) / Data.MAX_LEVEL
	for k in Data.MAX_LEVEL:
		draw_rect(Rect2(p.x + 4 + k * pip, p.y + s - 6, pip - 2, 3), col if k < level else Color(1, 1, 1, 0.12))

func _skull(c: Vector2, r: float) -> void:
	draw_circle(c, r, Data.C_TEXT_DIM)
	draw_rect(Rect2(c.x - r * 0.6, c.y + r * 0.5, r * 1.2, r * 0.6), Data.C_TEXT_DIM)
	draw_circle(c + Vector2(-r * 0.38, 0), r * 0.28, Data.C_BG)
	draw_circle(c + Vector2(r * 0.38, 0), r * 0.28, Data.C_BG)

func _text(f: Font, p: Vector2, s: String, sz: int, col: Color) -> void:
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, col.a * 0.6))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _text_c(f: Font, p: Vector2, s: String, sz: int, col: Color) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	_text(f, p - Vector2(w * 0.5, 0), s, sz, col)
