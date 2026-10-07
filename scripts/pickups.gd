extends Node2D
## XP crystals and field items. Crystals merge when the floor gets crowded so
## the count stays bounded no matter how many enemies die.

const GemShader := preload("res://shaders/gem.gdshader")
const SOFT_CAP := 320
const HARD_CAP := 480

enum Item { GEM, HEART, MAGNET, BOMB, CHEST }
const ITEM_COLORS := {
	Item.HEART: Color("ff4d6d"),
	Item.MAGNET: Color("4fb6ff"),
	Item.BOMB: Color("ff9b3d"),
	Item.CHEST: Color("ffc94d"),
}

var game: Node

var g_pos := PackedVector2Array()
var g_vel := PackedVector2Array()
var g_val := PackedInt32Array()
var g_fly := PackedByteArray()
var g_phase := PackedFloat32Array()
var g_age := PackedFloat32Array()

# items: [pos, kind, phase, flying, vel]
var items: Array = []

var batch: Batch

func setup(g: Node) -> void:
	game = g
	batch = Batch.new().setup(HARD_CAP + 40, GemShader)
	add_child(batch)

func clear() -> void:
	for a in [g_pos, g_vel, g_val, g_fly, g_phase, g_age]:
		a.clear()
	items.clear()

static func gem_color(v: int) -> Color:
	if v < 3:
		return Color("3dffb0")
	if v < 10:
		return Color("4fb6ff")
	if v < 40:
		return Color("c47dff")
	return Color("ffc94d")

func drop_gem(p: Vector2, value: int) -> void:
	var n := g_pos.size()
	if n >= SOFT_CAP:
		# fold into a nearby idle crystal
		var best := -1
		var best_d := 240.0 * 240.0 if n < HARD_CAP else INF
		for k in range(n - 1, maxi(-1, n - 120), -1):
			if g_fly[k] == 1:
				continue
			var d := g_pos[k].distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = k
		if best >= 0:
			g_val[best] += value
			return
		if n >= HARD_CAP:
			g_val[randi() % n] += value
			return
	g_pos.append(p + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
	g_vel.append(Vector2.ZERO)
	g_val.append(value)
	g_fly.append(0)
	g_phase.append(randf())
	g_age.append(0.0)

func drop_item(p: Vector2, kind: int) -> void:
	items.append([p, kind, randf(), false, Vector2.ZERO])

## Pull every crystal on the map toward the player.
func vacuum() -> void:
	for i in g_pos.size():
		g_fly[i] = 1

func update(dt: float) -> void:
	var player = game.player
	var pp: Vector2 = player.position
	var mag: float = player.magnet
	var mag_sq := mag * mag
	var grab: float = player.radius + 10.0
	var grab_sq: float = grab * grab
	var i := 0
	var collected := 0
	while i < g_pos.size():
		var p := g_pos[i]
		var d_sq := p.distance_squared_to(pp)
		g_age[i] += dt
		# crystals left lying around slowly drift to the player so a crowded
		# floor never starves the build
		if g_fly[i] == 0 and g_age[i] > 8.0:
			p += (pp - p).normalized() * minf(60.0 + (g_age[i] - 8.0) * 25.0, 260.0) * dt
			g_pos[i] = p
		if g_fly[i] == 0 and d_sq < mag_sq:
			g_fly[i] = 1
			g_vel[i] = (p - pp).normalized() * 160.0  # little hop away first
		if g_fly[i] == 1:
			var to := (pp - p)
			var v := g_vel[i].lerp(to.normalized() * (520.0 + player.vel.length()), minf(1.0, 7.0 * dt))
			g_vel[i] = v
			g_pos[i] = p + v * dt
		if d_sq < grab_sq:
			collected += 1
			game.gain_xp(g_val[i])
			var last := g_pos.size() - 1
			g_pos[i] = g_pos[last]; g_vel[i] = g_vel[last]; g_val[i] = g_val[last]
			g_fly[i] = g_fly[last]; g_phase[i] = g_phase[last]; g_age[i] = g_age[last]
			g_pos.resize(last); g_vel.resize(last); g_val.resize(last)
			g_fly.resize(last); g_phase.resize(last); g_age.resize(last)
			continue
		i += 1
	if collected > 0:
		game.on_gems_collected(collected)

	var keep: Array = []
	for it in items:
		var p: Vector2 = it[0]
		var d := p.distance_to(pp)
		if d < 60.0:
			it[3] = true
		if it[3]:
			it[4] = (it[4] as Vector2).lerp((pp - p).normalized() * 420.0, minf(1.0, 8.0 * dt))
			it[0] = p + it[4] * dt
		if d < player.radius + 14.0:
			game.on_item(it[1], p)
		else:
			keep.append(it)
	items = keep

func render(view: Rect2) -> void:
	batch.begin()
	var grow := view.grow(40.0)
	for i in g_pos.size():
		var p := g_pos[i]
		if not grow.has_point(p):
			continue
		var v := g_val[i]
		var s := 22.0 + minf(16.0, log(float(v)) * 4.5)
		batch.add(p.x, p.y, s, s, 0.0, gem_color(v), 0.0, g_phase[i])
	for it in items:
		var p: Vector2 = it[0]
		var s := 50.0 if it[1] == Item.CHEST else 38.0
		batch.add(p.x, p.y, s, s, 0.0, ITEM_COLORS[it[1]], float(it[1]), it[2])
	batch.commit()

## Off-screen items worth pointing at (chests, hearts) for the HUD arrows.
func notable_items() -> Array:
	var out: Array = []
	for it in items:
		if it[1] == Item.CHEST:
			out.append(it[0])
	return out
