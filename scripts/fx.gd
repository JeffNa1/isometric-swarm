extends Node2D
## Particles, shock rings, glowing ground residue and the odd damage number.
## Everything is budgeted so a screen-wide massacre never tanks the frame.

const GlowShader := preload("res://shaders/glow.gdshader")
const MAX_PARTICLES := 1400
const MAX_SPLATS := 260

var game: Node

var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_life := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_size := PackedFloat32Array()
var p_col: Array[Color] = []

var s_pos := PackedVector2Array()
var s_life := PackedFloat32Array()
var s_size := PackedFloat32Array()
var s_col: Array[Color] = []

# rings: [pos, radius, max_radius, life, max_life, color, width]
var rings: Array = []
# texts: [pos, text, life, color, size]
var texts: Array = []

var part_batch: Batch
var splat_batch: Batch
var ring_layer: Node2D

func setup(g: Node) -> void:
	game = g
	splat_batch = Batch.new().setup(MAX_SPLATS, GlowShader)
	splat_batch.z_index = -5
	add_child(splat_batch)
	part_batch = Batch.new().setup(MAX_PARTICLES, GlowShader)
	part_batch.z_index = 6
	add_child(part_batch)
	ring_layer = Node2D.new()
	ring_layer.z_index = 6
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring_layer.material = add
	ring_layer.draw.connect(_draw_rings)
	add_child(ring_layer)
	z_index = 7
	draw.connect(_draw_texts)

func clear() -> void:
	for a in [p_pos, p_vel, p_life, p_max, p_size, s_pos, s_life, s_size]:
		a.clear()
	p_col.clear()
	s_col.clear()
	rings.clear()
	texts.clear()

# ------------------------------------------------------------------ emitters
func particle(p: Vector2, v: Vector2, life: float, size: float, col: Color) -> void:
	if p_pos.size() >= MAX_PARTICLES:
		return
	p_pos.append(p); p_vel.append(v); p_life.append(life); p_max.append(life)
	p_size.append(size); p_col.append(col)

func burst(p: Vector2, col: Color, n: int, spd: float = 160.0, size: float = 14.0, life: float = 0.45) -> void:
	var budget := MAX_PARTICLES - p_pos.size()
	n = mini(n, budget / 4) if budget < 400 else n
	for k in n:
		var a := randf() * TAU
		var s := spd * randf_range(0.3, 1.0)
		particle(p, Vector2(cos(a), sin(a) * 0.7) * s, life * randf_range(0.6, 1.0), size * randf_range(0.6, 1.1), col)

func sparks(p: Vector2, col: Color, n: int) -> void:
	burst(p, col, n, 220.0, 9.0, 0.22)

func death(p: Vector2, col: Color, r: float) -> void:
	burst(p, col, 4 + int(r / 4.0), 120.0 + r * 4.0, 10.0 + r * 0.4, 0.4)
	splat(p, col, r * 2.6)

func splat(p: Vector2, col: Color, size: float) -> void:
	if s_pos.size() >= MAX_SPLATS:
		# overwrite the oldest
		s_pos.remove_at(0); s_life.remove_at(0); s_size.remove_at(0); s_col.remove_at(0)
	s_pos.append(p); s_life.append(5.0); s_size.append(size); s_col.append(col)

func ring(p: Vector2, max_r: float, col: Color, life: float = 0.35, width: float = 6.0, start_r: float = 0.0) -> void:
	rings.append([p, start_r, max_r, life, life, col, width])

func explosion(p: Vector2, r: float, col: Color) -> void:
	ring(p, r, col, 0.3, 10.0, r * 0.2)
	ring(p, r * 0.7, Color(1, 1, 1), 0.18, 5.0)
	burst(p, col, 18, r * 3.0, 18.0, 0.5)
	burst(p, Color(1.0, 0.9, 0.7), 6, r * 1.5, 26.0, 0.25)
	splat(p, col, r * 1.6)

func text(p: Vector2, s: String, col: Color, size: int = 22) -> void:
	if texts.size() > 30:
		texts.pop_front()
	texts.append([p, s, 0.8, col, size])

# ------------------------------------------------------------------ update/draw
func update(dt: float) -> void:
	var drag := exp(-3.5 * dt)
	var i := 0
	while i < p_pos.size():
		p_life[i] -= dt
		if p_life[i] <= 0.0:
			var last := p_pos.size() - 1
			p_pos[i] = p_pos[last]; p_vel[i] = p_vel[last]; p_life[i] = p_life[last]
			p_max[i] = p_max[last]; p_size[i] = p_size[last]; p_col[i] = p_col[last]
			p_pos.resize(last); p_vel.resize(last); p_life.resize(last)
			p_max.resize(last); p_size.resize(last); p_col.resize(last)
			continue
		p_pos[i] += p_vel[i] * dt
		p_vel[i] *= drag
		i += 1

	i = 0
	while i < s_pos.size():
		s_life[i] -= dt
		if s_life[i] <= 0.0:
			s_pos.remove_at(i); s_life.remove_at(i); s_size.remove_at(i); s_col.remove_at(i)
			continue
		i += 1

	for r in rings:
		r[3] -= dt
		var k: float = 1.0 - r[3] / r[4]
		r[1] = lerpf(r[1], r[2], 1.0 - pow(1.0 - k, 3.0))
	rings = rings.filter(func(r): return r[3] > 0.0)

	for tx in texts:
		tx[2] -= dt
		tx[0].y -= 40.0 * dt
	texts = texts.filter(func(tx): return tx[2] > 0.0)

func render(view: Rect2) -> void:
	part_batch.begin()
	for i in p_pos.size():
		var k := p_life[i] / p_max[i]
		var s := p_size[i] * (0.35 + 0.65 * k)
		var v := p_vel[i]
		var stretch := 1.0 + minf(v.length() / 260.0, 1.6)
		var c: Color = p_col[i]
		c.a = clampf(k * 1.4, 0.0, 1.0)
		part_batch.add(p_pos[i].x, p_pos[i].y, s * stretch, s, v.angle(), c, 0.3, 0.8)
	part_batch.commit()

	splat_batch.begin()
	var grow := view.grow(60.0)
	for i in s_pos.size():
		if not grow.has_point(s_pos[i]):
			continue
		var c: Color = s_col[i]
		c.a = 0.16 * clampf(s_life[i] / 2.0, 0.0, 1.0)
		var s := s_size[i]
		splat_batch.add(s_pos[i].x, s_pos[i].y, s, s * 0.55, 0.0, c, 0.01, 0.9)
	splat_batch.commit()
	ring_layer.queue_redraw()
	queue_redraw()

func _draw_rings() -> void:
	for r in rings:
		var k: float = r[3] / r[4]
		var c: Color = r[5]
		c.a = k
		var w: float = r[6] * (0.4 + 0.6 * k)
		_ellipse(ring_layer, r[0], r[1], c, w)
		c.a = k * 0.25
		_ellipse(ring_layer, r[0], r[1], c, w * 3.0)

func _draw_texts() -> void:
	for tx in texts:
		var c: Color = tx[3]
		c.a = clampf(tx[2] * 2.5, 0.0, 1.0)
		var f: Font = Data.font_bold
		var sz: int = tx[4]
		var w := f.get_string_size(tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string_outline(f, tx[0] - Vector2(w * 0.5, 0), tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 5, Color(0, 0, 0, c.a * 0.8))
		draw_string(f, tx[0] - Vector2(w * 0.5, 0), tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

## Circle outline. Hit areas are true circles, so the visuals match gameplay.
static func _ellipse(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	var n := clampi(int(r / 4.0), 24, 72)
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r))
	ci.draw_polyline(pts, col, w, true)
