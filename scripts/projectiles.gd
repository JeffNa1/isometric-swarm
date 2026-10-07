extends Node2D
## Player bolts and enemy shots. Plain arrays, drawn as additive glow batches.

const GlowShader := preload("res://shaders/glow.gdshader")

var game: Node

# player bolts
var b_pos := PackedVector2Array()
var b_vel := PackedVector2Array()
var b_dmg := PackedFloat32Array()
var b_life := PackedFloat32Array()
var b_pierce := PackedInt32Array()
var b_last := PackedInt32Array()
var b_col: Array[Color] = []

# enemy shots
var e_pos := PackedVector2Array()
var e_vel := PackedVector2Array()
var e_dmg := PackedFloat32Array()
var e_life := PackedFloat32Array()

var bolt_batch: Batch
var enemy_batch: Batch

func setup(g: Node) -> void:
	game = g
	bolt_batch = Batch.new().setup(600, GlowShader)
	enemy_batch = Batch.new().setup(300, GlowShader)
	add_child(bolt_batch)
	add_child(enemy_batch)

func clear() -> void:
	for a in [b_pos, b_vel, b_dmg, b_life, b_pierce, b_last, e_pos, e_vel, e_dmg, e_life]:
		a.clear()
	b_col.clear()

func shoot(p: Vector2, v: Vector2, dmg: float, pierce: int, col: Color) -> void:
	if b_pos.size() >= 600:
		return
	b_pos.append(p); b_vel.append(v); b_dmg.append(dmg)
	b_life.append(0.9); b_pierce.append(pierce); b_last.append(-1); b_col.append(col)

func enemy_shoot(p: Vector2, v: Vector2, dmg: float) -> void:
	if e_pos.size() >= 300:
		return
	e_pos.append(p); e_vel.append(v); e_dmg.append(dmg); e_life.append(4.5)

func update(dt: float) -> void:
	var swarm = game.swarm
	var i := 0
	while i < b_pos.size():
		var p := b_pos[i] + b_vel[i] * dt
		b_pos[i] = p
		b_life[i] -= dt
		var dead := b_life[i] <= 0.0
		if not dead:
			var hits: PackedInt32Array = swarm.query(p, 6.0)
			for j in hits:
				if swarm.uid[j] == b_last[i]:
					continue
				b_last[i] = swarm.uid[j]
				swarm.damage(j, b_dmg[i], b_vel[i].normalized() * 70.0)
				game.fx.sparks(p, b_col[i], 3)
				Sfx.play("hit", randf_range(0.9, 1.2))
				b_pierce[i] -= 1
				if b_pierce[i] < 0:
					dead = true
				break
			if not dead:
				var boss = game.boss_at(p, 6.0)
				if boss:
					boss.take_damage(b_dmg[i])
					game.fx.sparks(p, b_col[i], 3)
					dead = true
		if dead:
			_remove_bolt(i)
		else:
			i += 1

	var pp: Vector2 = game.player.position
	var pr: float = game.player.radius
	i = 0
	while i < e_pos.size():
		var p := e_pos[i] + e_vel[i] * dt
		e_pos[i] = p
		e_life[i] -= dt
		var dead := e_life[i] <= 0.0
		if not dead and p.distance_squared_to(pp) < (pr + 7.0) * (pr + 7.0):
			game.player.hurt(e_dmg[i], p)
			dead = true
		if dead:
			_remove_shot(i)
		else:
			i += 1

func _remove_bolt(i: int) -> void:
	var last := b_pos.size() - 1
	b_pos[i] = b_pos[last]; b_vel[i] = b_vel[last]; b_dmg[i] = b_dmg[last]
	b_life[i] = b_life[last]; b_pierce[i] = b_pierce[last]; b_last[i] = b_last[last]; b_col[i] = b_col[last]
	b_pos.resize(last); b_vel.resize(last); b_dmg.resize(last)
	b_life.resize(last); b_pierce.resize(last); b_last.resize(last); b_col.resize(last)

func _remove_shot(i: int) -> void:
	var last := e_pos.size() - 1
	e_pos[i] = e_pos[last]; e_vel[i] = e_vel[last]; e_dmg[i] = e_dmg[last]; e_life[i] = e_life[last]
	e_pos.resize(last); e_vel.resize(last); e_dmg.resize(last); e_life.resize(last)

## Clear enemy shots (bomb pickup, level start).
func clear_enemy_shots() -> void:
	for p in e_pos:
		game.fx.sparks(p, Color("ff3d81"), 2)
	e_pos.clear(); e_vel.clear(); e_dmg.clear(); e_life.clear()

func render() -> void:
	bolt_batch.begin()
	for i in b_pos.size():
		var v := b_vel[i]
		bolt_batch.add(b_pos[i].x, b_pos[i].y, 34.0, 12.0, v.angle(), b_col[i], 0.42, 0.9)
	bolt_batch.commit()
	enemy_batch.begin()
	var t := Time.get_ticks_msec() / 1000.0
	for i in e_pos.size():
		var s := 26.0 + sin(t * 12.0 + i) * 3.0
		enemy_batch.add(e_pos[i].x, e_pos[i].y, s, s, 0.0, Color(1.0, 0.25, 0.55), 0.5, 1.0)
	enemy_batch.commit()
