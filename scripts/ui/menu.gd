extends Control
## Title screen: drifting deck, a few critters skittering past, play + settings.

const FloorShader := preload("res://shaders/floor.gdshader")
const SwarmShader := preload("res://shaders/swarm.gdshader")

var _floor: ColorRect
var _critters: Batch
var _crit: Array = []   # [pos, vel, type, phase]
var _t := 0.0
var _title_box: VBoxContainer
var _sound_btn: Button
var _shake_btn: Button

func _ready() -> void:
	theme = Data.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_floor = ColorRect.new()
	_floor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = FloorShader
	_floor.material = fm
	add_child(_floor)

	var holder := Node2D.new()
	add_child(holder)
	_critters = Batch.new().setup(80, SwarmShader)
	holder.add_child(_critters)
	for k in 46:
		_crit.append(_new_critter(true))

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.02, 0.03, 0.07, 0.35)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_title_box = VBoxContainer.new()
	_title_box.add_theme_constant_override("separation", 12)
	_title_box.custom_minimum_size = Vector2(340, 0)
	center.add_child(_title_box)

	var kicker := _label("ISOMETRIC", 20, Data.C_ACCENT, true)
	_title_box.add_child(kicker)
	var title := _label("SWARM", 104, Data.C_TEXT, true)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08))
	_title_box.add_child(title)
	_title_box.add_child(_label("You are one drone. They are thousands.", 18, Data.C_TEXT_DIM, false))
	_title_box.add_child(_spacer(18))

	var play := _button("PLAY", _play)
	play.custom_minimum_size = Vector2(0, 64)
	play.add_theme_font_size_override("font_size", 28)
	var hot := Data._box(Data.C_ACCENT.darkened(0.55), Data.C_ACCENT, 2)
	play.add_theme_stylebox_override("normal", hot)
	play.add_theme_stylebox_override("hover", Data._box(Data.C_ACCENT.darkened(0.4), Color.WHITE, 2))
	_title_box.add_child(play)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_sound_btn = _button("", _toggle_sound)
	_shake_btn = _button("", _toggle_shake)
	_sound_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shake_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sound_btn.add_theme_font_size_override("font_size", 17)
	_shake_btn.add_theme_font_size_override("font_size", 17)
	row.add_child(_sound_btn)
	row.add_child(_shake_btn)
	_title_box.add_child(row)
	_refresh_toggles()

	_title_box.add_child(_spacer(10))
	if Data.best_time > 0.0:
		var best := "Best  %s   •   %d kills" % [Data.format_time(Data.best_time), Data.best_kills]
		if Data.wins > 0:
			best += "   •   %d wins" % Data.wins
		_title_box.add_child(_label(best, 16, Data.C_TEXT_DIM, false))
	var touch := DisplayServer.is_touchscreen_available()
	var hint := "Drag anywhere to move  •  DASH button to dodge" if touch else "WASD / arrows to move  •  Space to dash  •  Esc to pause"
	_title_box.add_child(_label(hint, 15, Color(Data.C_TEXT_DIM, 0.7), false))
	play.grab_focus.call_deferred()

func _new_critter(anywhere: bool) -> Array:
	var vs := get_viewport_rect().size
	var p := Vector2(randf() * vs.x, randf() * vs.y) if anywhere else Vector2(-40.0, randf() * vs.y)
	var v := Vector2(randf_range(40.0, 110.0), randf_range(-20.0, 20.0))
	var r := randf()
	var type := Data.E.MITE if r < 0.7 else (Data.E.DART if r < 0.9 else Data.E.BRUTE)
	if type == Data.E.DART:
		v *= 2.0
	return [p, v, type, randf()]

func _process(dt: float) -> void:
	_t += dt
	(_floor.material as ShaderMaterial).set_shader_parameter("offset", Vector2(_t * 18.0, _t * 9.0))
	var vs := get_viewport_rect().size
	_critters.begin()
	for k in _crit.size():
		var c: Array = _crit[k]
		var wob := sin(_t * 2.0 + c[3] * 20.0) * 30.0
		var v: Vector2 = c[1] + Vector2(0, wob)
		c[0] += v * dt
		if c[0].x > vs.x + 60.0:
			_crit[k] = _new_critter(false)
			continue
		var r: float = Data.ENEMIES[c[2]].radius * 1.3
		var s := r * 2.0 * 1.7
		_critters.add(c[0].x, c[0].y, s, s, 0.0, Data.ENEMIES[c[2]].color, float(c[2]), v.angle(), 0.0, c[3])
	_critters.commit()

func _play() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _toggle_sound() -> void:
	Data.sound_on = not Data.sound_on
	Data.save()
	_refresh_toggles()
	Sfx.play("click")

func _toggle_shake() -> void:
	Data.shake_on = not Data.shake_on
	Data.save()
	_refresh_toggles()
	Sfx.play("click")

func _refresh_toggles() -> void:
	_sound_btn.text = "Sound  " + ("ON" if Data.sound_on else "OFF")
	_shake_btn.text = "Shake  " + ("ON" if Data.shake_on else "OFF")

func _label(text: String, size: int, col: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", Data.font_bold)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b

static func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
