extends Node2D

const MAX_TEXTS: int = 60

var t_pos: PackedVector2Array = PackedVector2Array()
var t_vel: PackedVector2Array = PackedVector2Array()
var t_str: Array[String] = []
var t_life: PackedFloat32Array = PackedFloat32Array()
var t_color: PackedColorArray = PackedColorArray()
var t_is_crit: Array[bool] = []

var active_count: int = 0
var default_font: Font = null

func _ready() -> void:
	z_index = 20 # render above everything in world
	default_font = ThemeDB.fallback_font
	t_pos.resize(MAX_TEXTS)
	t_vel.resize(MAX_TEXTS)
	t_life.resize(MAX_TEXTS)
	t_color.resize(MAX_TEXTS)
	for i in range(MAX_TEXTS):
		t_str.append("")
		t_is_crit.append(false)

func spawn_damage(pos: Vector2, amount: float, is_crit: bool = false) -> void:
	if active_count >= MAX_TEXTS:
		return

	var idx = active_count
	t_pos[idx] = pos + Vector2(randf_range(-10, 10), -12)
	t_vel[idx] = Vector2(randf_range(-30, 30), randf_range(-85, -130))
	t_life[idx] = 0.55
	t_is_crit[idx] = is_crit

	if is_crit:
		t_str[idx] = "⚡%d!" % int(amount)
		t_color[idx] = Color(1.0, 0.9, 0.2, 1.0) # Gold
	else:
		t_str[idx] = "%d" % int(amount)
		t_color[idx] = Color(1.0, 1.0, 1.0, 1.0) # White

	active_count += 1

func _process(delta: float) -> void:
	if active_count == 0:
		return

	var i = 0
	while i < active_count:
		t_life[i] -= delta
		if t_life[i] <= 0.0:
			var last = active_count - 1
			if i != last:
				t_pos[i] = t_pos[last]
				t_vel[i] = t_vel[last]
				t_str[i] = t_str[last]
				t_life[i] = t_life[last]
				t_color[i] = t_color[last]
				t_is_crit[i] = t_is_crit[last]
			active_count -= 1
		else:
			t_pos[i] += t_vel[i] * delta
			t_vel[i].y += 180.0 * delta # gravity pull
			i += 1

	queue_redraw()

func _draw() -> void:
	if not default_font:
		return

	for i in range(active_count):
		var alpha = clamp(t_life[i] / 0.55, 0.0, 1.0)
		var c = t_color[i]
		c.a = alpha
		var font_size = 18 if t_is_crit[i] else 13
		
		# Draw subtle black outline shadow
		var shadow_col = Color(0, 0, 0, alpha * 0.8)
		draw_string(default_font, t_pos[i] + Vector2(1, 1), t_str[i], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_col)
		draw_string(default_font, t_pos[i], t_str[i], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, c)
