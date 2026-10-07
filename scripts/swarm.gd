extends Node2D
## The horde. Struct-of-arrays simulation for thousands of enemies, a coarse
## spatial grid rebuilt every frame around the player, crowd pressure instead
## of pairwise separation, and a single MultiMesh draw call.

const SwarmShader := preload("res://shaders/swarm.gdshader")
const PAD := 1.7  # must match swarm.gdshader

const CELL := 44.0
const GW := 96   # grid covers GW*CELL pixels around the player
const GH := 96

var game: Node
var max_count := 1600
var count := 0

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var knock := PackedVector2Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var kind := PackedInt32Array()
var radius := PackedFloat32Array()
var speed := PackedFloat32Array()
var dmg := PackedFloat32Array()
var flash := PackedFloat32Array()
var timer := PackedFloat32Array()    # spitter cooldown / bomber fuse
var age := PackedFloat32Array()
var orbit_cd := PackedFloat32Array()
var uid := PackedInt32Array()
var phase := PackedFloat32Array()
var _next_uid := 1

# spatial grid (linked lists through `cell_next`)
var cell_head := PackedInt32Array()
var cell_next := PackedInt32Array()
var cell_count := PackedInt32Array()
var cell_sum := PackedVector2Array()
var grid_origin := Vector2.ZERO

var _dead := PackedInt32Array()
var _is_dead := PackedByteArray()
var _query := PackedInt32Array()

var batch: Batch

func setup(g: Node, capacity: int) -> void:
	game = g
	max_count = capacity
	var cap := 2400
	for arr in [pos, vel, knock]:
		arr.resize(cap)
	for arr in [hp, max_hp, radius, speed, dmg, flash, timer, age, orbit_cd, phase]:
		arr.resize(cap)
	kind.resize(cap)
	uid.resize(cap)
	cell_next.resize(cap)
	_is_dead.resize(cap)
	cell_head.resize(GW * GH)
	cell_count.resize(GW * GH)
	cell_sum.resize(GW * GH)
	cell_head.fill(-1)
	batch = Batch.new().setup(cap, SwarmShader)
	add_child(batch)

func spawn(p: Vector2, type: int, t: float, hp_mult: float = 1.0) -> int:
	if count >= max_count and type != Data.E.ELITE:
		return -1
	if count >= pos.size():
		return -1
	var d: Dictionary = Data.ENEMIES[type]
	var i := count
	count += 1
	pos[i] = p
	vel[i] = Vector2.ZERO
	knock[i] = Vector2.ZERO
	var h: float = d.hp * Data.hp_scale(t) * hp_mult
	hp[i] = h
	max_hp[i] = h
	kind[i] = type
	radius[i] = d.radius
	speed[i] = d.speed * randf_range(0.9, 1.1) * (1.0 + minf(t / 600.0, 1.0) * 0.18)
	dmg[i] = d.dmg * Data.dmg_scale(t)
	flash[i] = 0.0
	timer[i] = randf_range(1.0, 3.0) if type == Data.E.SPITTER else 0.0
	age[i] = 0.0
	orbit_cd[i] = 0.0
	uid[i] = _next_uid
	_next_uid += 1
	phase[i] = randf()
	_is_dead[i] = 0
	return i

func clear() -> void:
	count = 0

# ------------------------------------------------------------------ simulation
func update(dt: float, player_pos: Vector2, player_r: float) -> void:
	_build_grid(player_pos)
	var far_sq := pow(game.view_radius() * 1.9, 2.0)
	var knock_decay := exp(-7.0 * dt)
	var t: float = game.elapsed

	for i in count:
		if _is_dead[i] == 1:
			continue
		var p := pos[i]
		var to := player_pos - p
		var dist_sq := to.length_squared()
		var dist := sqrt(dist_sq)
		var dir := to / maxf(dist, 0.001)
		var k := kind[i]
		var r := radius[i]
		age[i] += dt
		if flash[i] > 0.0:
			flash[i] = maxf(0.0, flash[i] - dt * 7.0)
		if orbit_cd[i] > 0.0:
			orbit_cd[i] -= dt

		# recycle stragglers that fell far behind: re-enter ahead of the player
		if dist_sq > far_sq and k != Data.E.ELITE:
			var ahead: Vector2 = game.player.vel.normalized() if game.player.vel.length_squared() > 100.0 else Vector2.from_angle(randf() * TAU)
			var ang := ahead.angle() + randf_range(-0.9, 0.9)
			pos[i] = player_pos + Vector2.from_angle(ang) * game.view_radius() * 1.08
			vel[i] = Vector2.ZERO
			continue

		var spd := speed[i]
		var desired := dir * spd

		if k == Data.E.SPITTER:
			timer[i] -= dt
			if dist < 210.0:
				desired = -dir * spd * 0.7
			elif dist < 300.0:
				desired = Vector2(-dir.y, dir.x) * spd * (0.6 if phase[i] > 0.5 else -0.6)
			if timer[i] <= 0.0 and dist < 360.0:
				timer[i] = randf_range(3.2, 4.4)
				if game.projectiles.enemy_shoot(p + dir * r, dir * 150.0, dmg[i]):
					flash[i] = 0.4
		elif k == Data.E.BOMBER:
			if timer[i] > 0.0:
				timer[i] -= dt
				desired *= 0.25
				flash[i] = maxf(flash[i], 0.5 + 0.5 * sin(timer[i] * 40.0))
				if timer[i] <= 0.0:
					_bomber_explode(i)
					continue
			elif dist < r + player_r + 34.0:
				timer[i] = 0.65
		elif k == Data.E.DART:
			# darts commit to a heading and overshoot instead of hugging
			desired = vel[i].lerp(dir * spd, 0.5) if dist > 160.0 else vel[i].normalized() * spd
			if desired.length_squared() < 1.0:
				desired = dir * spd

		# crowd pressure: push away from dense cells and from the cell centroid
		var push := Vector2.ZERO
		var cx := int((p.x - grid_origin.x) / CELL)
		var cy := int((p.y - grid_origin.y) / CELL)
		if cx > 0 and cy > 0 and cx < GW - 1 and cy < GH - 1:
			var c := cy * GW + cx
			var n := cell_count[c]
			push.x = float(cell_count[c - 1] - cell_count[c + 1])
			push.y = float(cell_count[c - GW] - cell_count[c + GW])
			push *= 22.0
			if n > 1:
				var centroid := cell_sum[c] / float(n)
				var away := p - centroid
				var al := away.length()
				if al > 0.01:
					push += away / al * float(n - 1) * 30.0
				else:
					push += Vector2.from_angle(phase[i] * TAU) * 30.0
		var accel := 6.0 if k != Data.E.DART else 3.0
		var v := vel[i].lerp(desired + push, minf(1.0, accel * dt))
		vel[i] = v
		var kb := knock[i]
		p += (v + kb) * dt
		knock[i] = kb * knock_decay
		pos[i] = p

		# contact damage
		var touch := r + player_r
		if dist_sq < touch * touch:
			if k == Data.E.BOMBER:
				if timer[i] <= 0.0:
					timer[i] = 0.25
			else:
				game.player.hurt(dmg[i], p)
	reap()

func _build_grid(center: Vector2) -> void:
	grid_origin = center - Vector2(GW * CELL, GH * CELL) * 0.5
	cell_head.fill(-1)
	cell_count.fill(0)
	cell_sum.fill(Vector2.ZERO)
	for i in count:
		var p := pos[i]
		var cx := int((p.x - grid_origin.x) / CELL)
		var cy := int((p.y - grid_origin.y) / CELL)
		if cx < 0 or cy < 0 or cx >= GW or cy >= GH:
			cell_next[i] = -2
			continue
		var c := cy * GW + cx
		cell_next[i] = cell_head[c]
		cell_head[c] = i
		cell_count[c] += 1
		cell_sum[c] += p

func _bomber_explode(i: int) -> void:
	var p := pos[i]
	var r := 82.0
	game.fx.explosion(p, r, Data.ENEMIES[Data.E.BOMBER].color)
	Sfx.play("boom", randf_range(0.9, 1.1))
	game.shake(0.25)
	if p.distance_to(game.player.position) < r + game.player.radius:
		game.player.hurt(dmg[i], p, true)
	# friendly fire is half the fun
	var hits := query(p, r)
	for j in hits:
		if j != i:
			damage(j, 30.0 * Data.hp_scale(game.elapsed), (pos[j] - p).normalized() * 260.0)
	hp[i] = 0.0
	_mark_dead(i, false)

# ------------------------------------------------------------------ queries
## Indices of enemies whose body overlaps the circle. Valid until the next query.
func query(center: Vector2, r: float) -> PackedInt32Array:
	_query.clear()
	var x0 := int(floor((center.x - r - 24.0 - grid_origin.x) / CELL))
	var x1 := int(floor((center.x + r + 24.0 - grid_origin.x) / CELL))
	var y0 := int(floor((center.y - r - 24.0 - grid_origin.y) / CELL))
	var y1 := int(floor((center.y + r + 24.0 - grid_origin.y) / CELL))
	x0 = maxi(x0, 0); y0 = maxi(y0, 0)
	x1 = mini(x1, GW - 1); y1 = mini(y1, GH - 1)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var j := cell_head[cy * GW + cx]
			while j >= 0:
				if j < count and _is_dead[j] == 0:
					var rr := r + radius[j]
					if pos[j].distance_squared_to(center) < rr * rr:
						_query.append(j)
				j = cell_next[j]
	return _query

## Nearest living enemy within max_dist, or -1. Searches rings of cells outward.
func nearest(center: Vector2, max_dist: float, skip_uid: int = -1) -> int:
	var cx := int((center.x - grid_origin.x) / CELL)
	var cy := int((center.y - grid_origin.y) / CELL)
	var best := -1
	var best_d := max_dist * max_dist
	var max_ring := int(ceil(max_dist / CELL)) + 1
	for ring in range(0, max_ring + 1):
		if best >= 0 and float(ring - 1) * CELL > sqrt(best_d):
			break
		for yy in range(cy - ring, cy + ring + 1):
			if yy < 0 or yy >= GH:
				continue
			var step := 1 if (yy == cy - ring or yy == cy + ring) else ring * 2
			if step == 0:
				step = 1
			var xx := cx - ring
			while xx <= cx + ring:
				if xx >= 0 and xx < GW:
					var j := cell_head[yy * GW + xx]
					while j >= 0:
						if j < count and _is_dead[j] == 0 and uid[j] != skip_uid:
							var d := pos[j].distance_squared_to(center)
							if d < best_d:
								best_d = d
								best = j
						j = cell_next[j]
				xx += step
	return best

## Position of the most crowded cell within range (good spot for big hits).
func densest(center: Vector2, max_dist: float) -> Vector2:
	var cx := int((center.x - grid_origin.x) / CELL)
	var cy := int((center.y - grid_origin.y) / CELL)
	var rng := int(max_dist / CELL)
	var best := -1
	var best_n := 0
	for _k in 40:
		var x := cx + randi_range(-rng, rng)
		var y := cy + randi_range(-rng, rng)
		if x < 1 or y < 1 or x >= GW - 1 or y >= GH - 1:
			continue
		var c := y * GW + x
		var n := cell_count[c] + (cell_count[c - 1] + cell_count[c + 1] + cell_count[c - GW] + cell_count[c + GW]) / 2
		if n > best_n:
			best_n = n
			best = c
	if best < 0 or cell_count[best] == 0:
		var j := nearest(center, max_dist)
		return pos[j] if j >= 0 else Vector2.INF
	return cell_sum[best] / float(cell_count[best])

# ------------------------------------------------------------------ damage
## Returns true if this hit killed the enemy.
func damage(i: int, amount: float, kb: Vector2 = Vector2.ZERO) -> bool:
	if i < 0 or i >= count or _is_dead[i] == 1:
		return false
	hp[i] -= amount
	flash[i] = 1.0
	knock[i] += kb * Data.ENEMIES[kind[i]].knock
	game.on_damage_dealt(amount)
	if hp[i] <= 0.0:
		_mark_dead(i, true)
		return true
	return false

func _mark_dead(i: int, rewarded: bool) -> void:
	if _is_dead[i] == 1:
		return
	_is_dead[i] = 1
	_dead.append(i if rewarded else -(i + 1))

func reap() -> void:
	if _dead.is_empty():
		return
	# decode, then remove highest indices first so swaps never move a dead one
	var idx: Array[int] = []
	var reward := {}
	for v in _dead:
		var i := v if v >= 0 else -v - 1
		idx.append(i)
		reward[i] = v >= 0
	_dead.clear()
	idx.sort()
	idx.reverse()
	for i in idx:
		if i >= count:
			continue
		game.on_enemy_killed(kind[i], pos[i], reward[i])
		var last := count - 1
		if i != last:
			pos[i] = pos[last]; vel[i] = vel[last]; knock[i] = knock[last]
			hp[i] = hp[last]; max_hp[i] = max_hp[last]; kind[i] = kind[last]
			radius[i] = radius[last]; speed[i] = speed[last]; dmg[i] = dmg[last]
			flash[i] = flash[last]; timer[i] = timer[last]; age[i] = age[last]
			orbit_cd[i] = orbit_cd[last]; uid[i] = uid[last]; phase[i] = phase[last]
			_is_dead[i] = _is_dead[last]
		_is_dead[last] = 0
		count -= 1

## Kill everything on screen (bomb pickup). Elites only take heavy damage.
func nuke(center: Vector2, r: float) -> void:
	for i in count:
		if pos[i].distance_squared_to(center) < r * r:
			if kind[i] == Data.E.ELITE:
				damage(i, max_hp[i] * 0.3)
			else:
				damage(i, hp[i] + 1.0, (pos[i] - center).normalized() * 300.0)

# ------------------------------------------------------------------ render
func render(view: Rect2) -> void:
	batch.begin()
	var grow := view.grow(80.0)
	for i in count:
		var p := pos[i]
		if not grow.has_point(p):
			continue
		var r := radius[i]
		var s := r * 2.0 * PAD * 1.22 * minf(1.0, age[i] * 5.0 + 0.2)
		var v := vel[i]
		var facing := v.angle() if v.length_squared() > 4.0 else 0.0
		var a := 1.0
		batch.add(p.x, p.y, s, s, 0.0, Data.ENEMIES[kind[i]].color, float(kind[i]), facing, flash[i], phase[i] * a)
	batch.commit()
