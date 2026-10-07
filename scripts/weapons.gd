extends Node2D
## Owns the player's loadout: weapon + passive levels, derived stats, firing
## logic, and the additive visuals for melee/area weapons.

var game: Node
var levels := {}     # id -> level, for weapons and passives alike
var weapon_order: Array[String] = []
var passive_order: Array[String] = []
var bonus_damage := 0.0   # from overflow "Power Surge" picks

var _cd := {}        # weapon id -> seconds until next fire
var _orbit_angle := 0.0
var _arcs: Array = []      # [points, life, color]
var _beams: Array = []     # [from, to, width, life, color]
var _novas: Array = []     # [radius, max_radius, life, dmg, hit_set]
var _shells: Array = []    # [from, to, t, dur, dmg, radius]
var _boss_orbit_cd := 0.0

func setup(g: Node) -> void:
	game = g
	z_index = 4
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add

func reset() -> void:
	levels.clear()
	weapon_order.clear()
	passive_order.clear()
	_cd.clear()
	_arcs.clear(); _beams.clear(); _novas.clear(); _shells.clear()
	bonus_damage = 0.0
	add_upgrade("pulse")

func lv(id: String) -> int:
	return levels.get(id, 0)

# ------------------------------------------------------------------ stats
func might() -> float:
	return (1.0 + 0.12 * lv("power")) * (1.0 + bonus_damage)

func haste() -> float:
	return pow(0.92, lv("rapid"))

func area() -> float:
	return 1.0 + 0.12 * lv("reach")

func move_mult() -> float:
	return 1.0 + 0.08 * lv("swift")

func dash_cd_mult() -> float:
	return pow(0.9, lv("swift"))

func max_hp_bonus() -> float:
	return 20.0 * lv("vital")

func regen() -> float:
	return 0.5 * lv("vital")

func magnet_mult() -> float:
	return 1.0 + 0.35 * lv("magnet")

func xp_mult() -> float:
	return 1.0 + 0.08 * lv("magnet")

# ------------------------------------------------------------------ upgrades
func add_upgrade(id: String) -> void:
	if id == "heal":
		game.player.heal(game.player.max_hp * 0.4)
		return
	if id == "surge":
		bonus_damage += 0.05
		return
	levels[id] = lv(id) + 1
	if Data.WEAPONS.has(id):
		if not weapon_order.has(id):
			weapon_order.append(id)
			_cd[id] = 0.3
	elif not passive_order.has(id):
		passive_order.append(id)
	game.player.refresh_stats()

## Up to n distinct upgrade offers, weighted toward things you already own.
func roll_offers(n: int) -> Array:
	var pool: Array = []
	for id in Data.WEAPONS:
		var l := lv(id)
		if l >= Data.MAX_LEVEL:
			continue
		if l == 0 and weapon_order.size() >= Data.MAX_WEAPONS:
			continue
		pool.append([id, 1.4 if l > 0 else 1.0])
	for id in Data.PASSIVES:
		var l := lv(id)
		if l >= Data.MAX_LEVEL:
			continue
		if l == 0 and passive_order.size() >= Data.MAX_PASSIVES:
			continue
		pool.append([id, 1.0 if l > 0 else 0.8])
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for e in pool:
			total += e[1]
		var r := randf() * total
		for k in pool.size():
			r -= pool[k][1]
			if r <= 0.0:
				out.append(pool[k][0])
				pool.remove_at(k)
				break
	# early on, always offer at least one new weapon so builds come online fast
	if weapon_order.size() < 3 and n > 1:
		var has_new_weapon := false
		for id in out:
			if Data.WEAPONS.has(id) and lv(id) == 0:
				has_new_weapon = true
		if not has_new_weapon:
			var fresh: Array = []
			for id in Data.WEAPONS:
				if lv(id) == 0:
					fresh.append(id)
			if not fresh.is_empty():
				out[out.size() - 1] = fresh.pick_random()
	if out.size() < n:
		out.append("heal")
	if out.size() < n:
		out.append("surge")
	return out

func describe(id: String) -> Dictionary:
	if id == "heal":
		return {"name": "Field Repair", "desc": "Restore 40% of max HP.", "color": Data.C_HP, "tag": "REPAIR", "level": 0}
	if id == "surge":
		return {"name": "Power Surge", "desc": "+5% damage, permanently.", "color": Data.C_GOLD, "tag": "BONUS", "level": 0}
	var next := lv(id) + 1
	if Data.WEAPONS.has(id):
		var w: Dictionary = Data.WEAPONS[id]
		return {"name": w.name, "desc": w.desc[next - 1], "color": w.color, "tag": "NEW WEAPON" if next == 1 else "LEVEL %d" % next, "level": next}
	var p: Dictionary = Data.PASSIVES[id]
	return {"name": p.name, "desc": p.desc, "color": p.color, "tag": "NEW SYSTEM" if next == 1 else "LEVEL %d" % next, "level": next}

# ------------------------------------------------------------------ firing
func update(dt: float) -> void:
	var pp: Vector2 = game.player.position
	for id in weapon_order:
		_cd[id] -= dt
		if _cd[id] <= 0.0:
			var fired: bool = call("_fire_" + id, pp)
			if fired:
				_cd[id] = _cooldown(id)
			else:
				_cd[id] = 0.1
	if lv("orbit") > 0:
		_update_orbit(dt, pp)
	_update_novas(dt, pp)
	_update_shells(dt)
	for a in _arcs:
		a[1] -= dt
	_arcs = _arcs.filter(func(a): return a[1] > 0.0)
	for b in _beams:
		b[3] -= dt
	_beams = _beams.filter(func(b): return b[3] > 0.0)
	queue_redraw()

func _cooldown(id: String) -> float:
	var l := lv(id)
	var cd := 1.0
	match id:
		"pulse": cd = 0.42 * (0.85 if l >= 4 else 1.0)
		"orbit": cd = 999.0
		"arc": cd = 1.25 * (0.7 if l >= 5 else 1.0)
		"nova": cd = 2.8 * (0.75 if l >= 4 else 1.0)
		"lance": cd = 1.8 * (0.7 if l >= 5 else 1.0)
		"mortar": cd = 2.2
	return cd * haste()

func _fire_orbit(_pp: Vector2) -> bool:
	return true

func _fire_pulse(pp: Vector2) -> bool:
	var l := lv("pulse")
	var j: int = game.swarm.nearest(pp, 560.0)
	var target := Vector2.INF
	if j >= 0:
		target = game.swarm.pos[j]
	# bosses in range take priority; piercing bolts chew through the escort
	var boss = game.nearest_boss(pp, 460.0)
	if boss:
		target = boss.position
	if target == Vector2.INF:
		return false
	var bolts := 1 + int(l >= 2) + int(l >= 4) + 2 * int(l >= 5)
	var dmg := 12.0 * (1.4 if l >= 3 else 1.0) * might()
	var pierce := int(l >= 3) + int(l >= 5)
	var base := (target - pp).angle()
	var col: Color = Data.WEAPONS.pulse.color
	for b in bolts:
		var off := (float(b) - float(bolts - 1) * 0.5) * 0.13
		var dir := Vector2.from_angle(base + off)
		game.projectiles.shoot(pp + dir * 18.0, dir * 760.0, dmg, pierce, col)
	game.player.recoil(Vector2.from_angle(base))
	Sfx.play("shoot", randf_range(0.95, 1.08))
	return true

func _update_orbit(dt: float, pp: Vector2) -> void:
	var l := lv("orbit")
	var spin := 3.4 * (1.35 if l >= 4 else 1.0)
	_orbit_angle = fmod(_orbit_angle + spin * dt, TAU)
	_boss_orbit_cd -= dt
	var blades := _orbit_blades()
	var r := _orbit_radius()
	var dmg := 9.0 * (1.3 if l >= 3 else 1.0) * (1.3 if l >= 5 else 1.0) * might()
	var hit_r := 16.0 * area()
	var swarm = game.swarm
	for b in blades:
		var a := _orbit_angle + TAU * float(b) / float(blades)
		var bp := pp + Vector2.from_angle(a) * r
		var hits: PackedInt32Array = swarm.query(bp, hit_r)
		for j in hits:
			if swarm.orbit_cd[j] > 0.0:
				continue
			swarm.orbit_cd[j] = 0.3
			swarm.damage(j, dmg, (swarm.pos[j] - pp).normalized() * 140.0)
			game.fx.sparks(swarm.pos[j], Data.WEAPONS.orbit.color, 2)
		if _boss_orbit_cd <= 0.0:
			var boss = game.boss_at(bp, hit_r)
			if boss:
				boss.take_damage(dmg)
				_boss_orbit_cd = 0.3

func _orbit_blades() -> int:
	var l := lv("orbit")
	return 2 + int(l >= 2) + int(l >= 4) + 2 * int(l >= 5)

func _orbit_radius() -> float:
	return 80.0 * (1.2 if lv("orbit") >= 3 else 1.0) * area()

func _fire_arc(pp: Vector2) -> bool:
	var l := lv("arc")
	var casts := 1 + int(l >= 4)
	var jumps := 4 + 2 * int(l >= 2) + 3 * int(l >= 5)
	var dmg := 15.0 * (1.4 if l >= 3 else 1.0) * might()
	var jump_r := 150.0 * area()
	var swarm = game.swarm
	var any := false
	var boss = game.nearest_boss(pp, 440.0)
	if boss:
		boss.take_damage(dmg * 2.0 * casts)
		_arcs.append([_jagged(pp, boss.position), 0.2, Data.WEAPONS.arc.color])
		any = true
	for c in casts:
		var j: int = swarm.nearest(pp, 440.0) if c == 0 else swarm.nearest(pp + Vector2.from_angle(randf() * TAU) * 200.0, 300.0)
		if j < 0:
			continue
		any = true
		var pts := PackedVector2Array([pp])
		var prev := pp
		var last_uid := -1
		for k in jumps:
			if j < 0:
				break
			var tp: Vector2 = swarm.pos[j]
			pts.append_array(_jagged(prev, tp))
			last_uid = swarm.uid[j]
			swarm.damage(j, dmg, Vector2.ZERO)
			game.fx.sparks(tp, Data.WEAPONS.arc.color, 3)
			prev = tp
			j = swarm.nearest(tp, jump_r, last_uid)
		_arcs.append([pts, 0.2, Data.WEAPONS.arc.color])
	if any:
		Sfx.play("zap", randf_range(0.9, 1.15))
	return any

func _jagged(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segs := maxi(2, int(a.distance_to(b) / 22.0))
	var n := (b - a).orthogonal().normalized()
	for s in range(1, segs + 1):
		var t := float(s) / float(segs)
		var off := 0.0 if s == segs else randf_range(-12.0, 12.0)
		pts.append(a.lerp(b, t) + n * off)
	return pts

func _fire_nova(pp: Vector2) -> bool:
	var l := lv("nova")
	if game.swarm.nearest(pp, 260.0) < 0 and game.nearest_boss(pp, 260.0) == null:
		return false
	var r := 140.0 * (1.2 if l >= 2 else 1.0) * (1.25 if l >= 5 else 1.0) * area()
	var dmg := 20.0 * (1.45 if l >= 3 else 1.0) * (1.3 if l >= 5 else 1.0) * might()
	_novas.append([0.0, r, 0.32, dmg, {}, false])
	Sfx.play("nova", randf_range(0.95, 1.05))
	return true

func _update_novas(dt: float, pp: Vector2) -> void:
	var swarm = game.swarm
	for nv in _novas:
		nv[2] -= dt
		var k: float = 1.0 - nv[2] / 0.32
		nv[0] = nv[1] * (1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 2.5))
		var hits: PackedInt32Array = swarm.query(pp, nv[0])
		var hit_set: Dictionary = nv[4]
		for j in hits:
			var u: int = swarm.uid[j]
			if hit_set.has(u):
				continue
			hit_set[u] = true
			swarm.damage(j, nv[3], (swarm.pos[j] - pp).normalized() * 420.0)
		if not nv[5]:
			var boss = game.boss_at(pp, nv[0])
			if boss:
				boss.take_damage(nv[3])
				nv[5] = true
	_novas = _novas.filter(func(nv): return nv[2] > 0.0)

func _fire_lance(pp: Vector2) -> bool:
	var l := lv("lance")
	var target: Vector2 = game.swarm.densest(pp, 420.0)
	var boss = game.nearest_boss(pp, 600.0)
	if boss:
		target = boss.position
	if target == Vector2.INF:
		return false
	var beams := 1 + int(l >= 4) + int(l >= 5)
	var width := 20.0 * (1.4 if l >= 2 else 1.0) * area()
	var dmg := 32.0 * (1.5 if l >= 3 else 1.0) * might()
	var length := 680.0 * sqrt(area())
	var base := (target - pp).angle()
	var swarm = game.swarm
	for b in beams:
		var a := base + TAU * float(b) / float(beams)
		var dir := Vector2.from_angle(a)
		var from := pp + dir * 20.0
		var to := from + dir * length
		var hit_set := {}
		var steps := int(length / 30.0)
		for s in steps + 1:
			var cp := from + dir * (float(s) * 30.0)
			var hits: PackedInt32Array = swarm.query(cp, width * 0.5 + 6.0)
			for j in hits:
				var u: int = swarm.uid[j]
				if hit_set.has(u):
					continue
				hit_set[u] = true
				swarm.damage(j, dmg, dir * 90.0)
		for bs in game.bosses:
			if Geometry2D.get_closest_point_to_segment(bs.position, from, to).distance_to(bs.position) < bs.radius + width * 0.5:
				bs.take_damage(dmg)
		_beams.append([from, to, width, 0.22, Data.WEAPONS.lance.color])
	game.shake(0.08)
	Sfx.play("lance", randf_range(0.95, 1.05))
	return true

func _fire_mortar(pp: Vector2) -> bool:
	var l := lv("mortar")
	var center: Vector2 = game.swarm.densest(pp, 520.0)
	var boss = game.nearest_boss(pp, 600.0)
	if boss and randf() < 0.7:
		center = boss.position
	if center == Vector2.INF:
		return false
	var shells := 1 + int(l >= 2) + 2 * int(l >= 5)
	var radius := 74.0 * (1.25 if l >= 3 else 1.0) * area()
	var dmg := 34.0 * (1.45 if l >= 4 else 1.0) * might()
	for s in shells:
		var tgt := center if s == 0 else center + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 150.0)
		_shells.append([pp, tgt, 0.0, 0.62 + 0.08 * s, dmg, radius])
	return true

func _update_shells(dt: float) -> void:
	var keep: Array = []
	for sh in _shells:
		sh[2] += dt
		if sh[2] >= sh[3]:
			var p: Vector2 = sh[1]
			var hits: PackedInt32Array = game.swarm.query(p, sh[5])
			var swarm = game.swarm
			for j in hits.duplicate():
				swarm.damage(j, sh[4], (swarm.pos[j] - p).normalized() * 300.0)
			var boss = game.boss_at(p, sh[5])
			if boss:
				boss.take_damage(sh[4])
			game.fx.explosion(p, sh[5], Data.WEAPONS.mortar.color)
			Sfx.play("boom", randf_range(0.95, 1.15), -3.0)
			game.shake(0.06)
		else:
			keep.append(sh)
	_shells = keep

# ------------------------------------------------------------------ visuals
func _draw() -> void:
	var pp: Vector2 = game.player.position
	var t := Time.get_ticks_msec() / 1000.0

	if lv("orbit") > 0:
		var r := _orbit_radius()
		var col: Color = Data.WEAPONS.orbit.color
		draw_arc(pp, r, 0.0, TAU, 64, Color(col, 0.08), 2.0, true)
		var blades := _orbit_blades()
		for b in blades:
			var a := _orbit_angle + TAU * float(b) / float(blades)
			var bp := pp + Vector2.from_angle(a) * r
			# motion trail
			for k in 5:
				var ta := a - float(k + 1) * 0.07
				draw_circle(pp + Vector2.from_angle(ta) * r, 9.0 - k, Color(col, 0.16 - k * 0.03))
			var fwd := Vector2.from_angle(a + PI * 0.5)
			var side := Vector2.from_angle(a)
			var s := 15.0 * area()
			var pts := PackedVector2Array([bp + fwd * s * 1.3, bp + side * s * 0.45, bp - fwd * s * 0.7, bp - side * s * 0.45])
			draw_colored_polygon(pts, Color(col, 0.9))
			draw_circle(bp, s * 1.1, Color(col, 0.18))
			draw_circle(bp, s * 0.32, Color(1, 1, 1, 0.9))

	for nv in _novas:
		var k: float = nv[2] / 0.32
		var col: Color = Data.WEAPONS.nova.color
		draw_arc(pp, nv[0], 0.0, TAU, 72, Color(col, 0.9 * k), 8.0 * k + 2.0, true)
		draw_arc(pp, nv[0] * 0.92, 0.0, TAU, 72, Color(col, 0.25 * k), 22.0 * k, true)
		draw_circle(pp, nv[0], Color(col, 0.06 * k))

	for a in _arcs:
		var k: float = a[1] / 0.2
		var col: Color = a[2]
		draw_polyline(a[0], Color(col, 0.35 * k), 9.0, true)
		draw_polyline(a[0], Color(col.lerp(Color.WHITE, 0.6), k), 2.5, true)

	for b in _beams:
		var k: float = b[3] / 0.22
		var col: Color = b[4]
		var w: float = b[2]
		draw_line(b[0], b[1], Color(col, 0.25 * k), w * (1.6 - 0.4 * k), true)
		draw_line(b[0], b[1], Color(col, 0.8 * k), w * 0.6 * k + 2.0, true)
		draw_line(b[0], b[1], Color(1, 1, 1, k), w * 0.2 * k + 1.0, true)
		draw_circle(b[0], w * 0.8 * k, Color(col, 0.6 * k))

	for sh in _shells:
		var k: float = sh[2] / sh[3]
		var from: Vector2 = sh[0]
		var to: Vector2 = sh[1]
		var col: Color = Data.WEAPONS.mortar.color
		# target reticle tightens as the shell lands
		var rr: float = sh[5] * (1.4 - 0.4 * k)
		draw_arc(to, rr, t * 2.0, t * 2.0 + TAU, 48, Color(col, 0.18 + 0.35 * k), 2.0, true)
		draw_circle(to, sh[5] * k, Color(col, 0.05 + 0.08 * k))
		var p := from.lerp(to, k) + Vector2(0, -sin(k * PI) * 160.0)
		draw_circle(p, 10.0, Color(col, 0.35))
		draw_circle(p, 5.0, Color(1, 1, 1, 0.95))
