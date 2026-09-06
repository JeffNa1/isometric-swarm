extends Node2D

const MainMenu = preload("res://scripts/ui/main_menu.gd")

const MAX_TEXTS: int = 180

var t_pos: PackedVector2Array = PackedVector2Array()
var t_vel: PackedVector2Array = PackedVector2Array()
var t_str: Array[String] = []
var t_life: PackedFloat32Array = PackedFloat32Array()
var t_color: PackedColorArray = PackedColorArray()
var t_is_crit: Array[bool] = []

var active_count: int = 0
var default_font: Font = null
var particle_mgr: Node2D = null

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
	_get_managers()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		particle_mgr = cur.get_node_or_null("ParticleManager")

func spawn_damage(pos: Vector2, amount: float, is_crit: bool = false) -> void:
	if not MainMenu.show_damage_numbers:
		return
	if active_count >= MAX_TEXTS:
		return

	var idx = active_count
	t_pos[idx] = pos + Vector2(randf_range(-12, 12), -14)
	t_life[idx] = 0.72 if is_crit else 0.52
	t_is_crit[idx] = is_crit

	if is_crit:
		t_str[idx] = "⚡%d!" % int(amount)
		t_color[idx] = Color(1.0, 0.88, 0.22, 1.0) # Radiant Gold
		t_vel[idx] = Vector2(randf_range(-40, 40), randf_range(-115, -155))
		if not particle_mgr:
			_get_managers()
		if particle_mgr:
			particle_mgr.spawn_sparks(pos + Vector2(0, -10), Color(3.5, 2.5, 0.4, 1.0), 3)
	else:
		t_str[idx] = "%d" % int(amount)
		t_color[idx] = Color(0.95, 0.98, 1.0, 1.0) # Crisp White
		t_vel[idx] = Vector2(randf_range(-25, 25), randf_range(-75, -115))

	active_count += 1

func spawn_text(pos: Vector2, text: String, col: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	if active_count >= MAX_TEXTS:
		return

	var idx = active_count
	t_pos[idx] = pos + Vector2(0, -18)
	t_vel[idx] = Vector2(0, -60)
	t_life[idx] = 1.15
	t_is_crit[idx] = true
	t_str[idx] = text
	t_color[idx] = col
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
			t_vel[i].y += 190.0 * delta # gravity pull
			i += 1

	queue_redraw()

func _draw() -> void:
	if not default_font:
		return

	for i in range(active_count):
		var max_l = 1.15 if t_str[i].length() > 6 else (0.72 if t_is_crit[i] else 0.52)
		var alpha = clamp(t_life[i] / max_l, 0.0, 1.0)
		var c = t_color[i]
		c.a = alpha
		var base_size = 19 if t_is_crit[i] else 13

		# Elastic overshoot pop
		var elapsed = max_l - t_life[i]
		if elapsed < 0.16:
			var bounce = 1.0 + sin((elapsed / 0.16) * PI) * (0.42 if t_is_crit[i] else 0.22)
			base_size = int(base_size * bounce)

		# 8-way drop shadow and outline for arcade readability
		var shadow_col = Color(0.01, 0.02, 0.04, alpha * 0.95)
		var p = t_pos[i]
		var text = t_str[i]
		
		draw_string(default_font, p + Vector2(-1, -1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, base_size, shadow_col)
		draw_string(default_font, p + Vector2(1, -1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, base_size, shadow_col)
		draw_string(default_font, p + Vector2(-1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, base_size, shadow_col)
		draw_string(default_font, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, base_size, shadow_col)
		draw_string(default_font, p + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_CENTER, -1, base_size, shadow_col)
		draw_string(default_font, p, text, HORIZONTAL_ALIGNMENT_CENTER, -1, base_size, c)
