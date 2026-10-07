extends Node2D
## Bosses. Tier 1 = Broodmother (mid-run), tier 2 = Hive Queen (finale).
## Every attack is telegraphed: rings flash before bursts, lines before charges.

var game: Node
var tier := 1
var title := ""
var radius := 46.0
var max_hp := 9000.0
var hp := 9000.0
var speed := 70.0
var contact := 24.0
var color := Color("ff3d81")
var vel := Vector2.ZERO
var flash := 0.0
var _t := 0.0
var _attack_t := 3.0
var _spawn_t := 5.0
var _state := "chase"   # chase / windup / charge / burst
var _state_t := 0.0
var _charge_dir := Vector2.ZERO
var _spiral := 0.0
var _pattern := 0
var dead := false

func setup(g: Node, t: int) -> void:
	game = g
	tier = t
	z_index = 2
	if tier == 1:
		title = "BROODMOTHER"
		radius = 46.0
		max_hp = 6500.0
		speed = 74.0
		color = Color("ff3d81")
	else:
		title = "HIVE QUEEN"
		radius = 62.0
		max_hp = 30000.0
		speed = 84.0
		contact = 32.0
		color = Color("c47dff")
	hp = max_hp

func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	flash = 1.0
	game.on_damage_dealt(amount)
	if randf() < 0.15:
		game.fx.text(position + Vector2(randf_range(-30, 30), -radius - 10), str(int(amount)), Color(1, 0.9, 0.7), 18)
	if hp <= 0.0:
		dead = true
		game.on_boss_killed(self)

func update(dt: float) -> void:
	_t += dt
	flash = maxf(0.0, flash - dt * 6.0)
	var pp: Vector2 = game.player.position
	var to := pp - position
	var dir := to.normalized()
	var enraged := hp < max_hp * 0.5

	match _state:
		"chase":
			vel = vel.lerp(dir * speed * (1.25 if enraged else 1.0), minf(1.0, 3.0 * dt))
			_attack_t -= dt
			_spawn_t -= dt
			if _attack_t <= 0.0:
				_pattern = (_pattern + 1) % (3 if tier == 1 else 4)
				_state = "windup"
				_state_t = 0.0
				_charge_dir = dir
				vel *= 0.2
			if _spawn_t <= 0.0:
				_spawn_t = 7.0 if tier == 1 else 5.5
				_spawn_brood()
		"windup":
			_state_t += dt
			vel = vel.lerp(Vector2.ZERO, minf(1.0, 6.0 * dt))
			if _pattern == 0:
				_charge_dir = _charge_dir.slerp(dir, minf(1.0, 2.0 * dt))
			if _state_t >= 0.85:
				_state_t = 0.0
				match _pattern:
					0:
						_state = "charge"
						Sfx.play("dash", 0.6)
					1:
						_radial(18 if tier == 1 else 26, 165.0)
						if tier == 2:
							_radial(26, 120.0, PI / 26.0)
						_end_attack()
					2:
						_state = "burst"
						_spiral = dir.angle()
					3:
						_aimed_fan(dir)
						_end_attack()
		"charge":
			_state_t += dt
			vel = _charge_dir * (560.0 if tier == 1 else 640.0)
			if int(_t * 60.0) % 3 == 0:
				game.fx.burst(position, color, 3, 80.0, 18.0, 0.4)
			if _state_t >= 0.65:
				_end_attack()
		"burst":
			_state_t += dt
			vel = Vector2.ZERO
			if int(_state_t * 60.0) % 4 == 0:
				var arms := 3 if tier == 1 else 5
				for a in arms:
					var ang := _spiral + TAU * float(a) / float(arms)
					game.projectiles.enemy_shoot(position + Vector2.from_angle(ang) * radius, Vector2.from_angle(ang) * 150.0, contact * 0.5, true)
				_spiral += 0.21
			if _state_t >= 1.6:
				_end_attack()

	position += vel * dt
	if to.length() < radius + game.player.radius:
		game.player.hurt(contact, position)
	queue_redraw()

func _end_attack() -> void:
	_state = "chase"
	var enraged := hp < max_hp * 0.5
	_attack_t = (2.2 if enraged else 3.0) * (0.85 if tier == 2 else 1.0)

func _radial(n: int, spd: float, offset: float = 0.0) -> void:
	for k in n:
		var a := TAU * float(k) / float(n) + offset + _t
		game.projectiles.enemy_shoot(position + Vector2.from_angle(a) * radius, Vector2.from_angle(a) * spd, contact * 0.5, true)
	game.fx.ring(position, radius * 2.2, color, 0.4, 8.0, radius)
	Sfx.play("nova", 0.6)

func _aimed_fan(dir: Vector2) -> void:
	for k in 9:
		var a := dir.angle() + (float(k) - 4.0) * 0.12
		game.projectiles.enemy_shoot(position + Vector2.from_angle(a) * radius, Vector2.from_angle(a) * 210.0, contact * 0.5, true)
	Sfx.play("zap", 0.6)

func _spawn_brood() -> void:
	var n := 18 if tier == 1 else 26
	var type := Data.E.MITE if tier == 1 else Data.E.DART
	for k in n:
		var a := TAU * float(k) / float(n)
		game.swarm.spawn(position + Vector2.from_angle(a) * (radius + 20.0), type, game.elapsed)
	game.fx.ring(position, radius * 2.0, color, 0.5, 6.0, radius)

# ------------------------------------------------------------------ art
func _draw() -> void:
	var r := radius
	var bob := sin(_t * 2.5) * 3.0
	var face: float = vel.angle() if vel.length() > 10.0 else (game.player.position - position).angle()

	# telegraphs drawn first, on the ground
	if _state == "windup":
		var k := _state_t / 0.85
		match _pattern:
			0:
				var w := r * 1.6
				var end := _charge_dir * (560.0 if tier == 1 else 640.0) * 0.65
				draw_line(Vector2.ZERO, end, Color(color, 0.12 + 0.18 * k), w, true)
				draw_line(Vector2.ZERO, end * k, Color(color, 0.35), 3.0, true)
			1, 3:
				draw_arc(Vector2.ZERO, r * (2.4 - 1.2 * k), 0, TAU, 64, Color(color, 0.25 + 0.5 * k), 4.0, true)
			2:
				for a in 6:
					var ang := _t * 2.0 + TAU * a / 6.0
					draw_line(Vector2.ZERO, Vector2.from_angle(ang) * r * 2.0 * k, Color(color, 0.4), 3.0, true)

	# shadow
	var sh := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		sh.append(Vector2(cos(a) * r * 1.25 + 6, sin(a) * r * 0.5 + r * 0.55))
	draw_colored_polygon(sh, Color(0, 0, 0.02, 0.5))

	var c := Vector2(0, -r * 0.25 + bob)
	var base := color.darkened(0.55)
	if flash > 0.0:
		base = base.lerp(Color.WHITE, flash * 0.6)

	# legs
	for s in [-1.0, 1.0]:
		for k in 4:
			var la: float = face + s * (0.7 + k * 0.5)
			var wig := sin(_t * 9.0 + k * 1.3 + s) * 0.12
			var hip := c + Vector2.from_angle(la) * r * 0.7
			var knee := c + Vector2.from_angle(la + wig) * r * 1.35 + Vector2(0, -8)
			var foot := c + Vector2.from_angle(la + wig * 2.0) * r * 1.6 + Vector2(0, r * 0.35)
			draw_polyline(PackedVector2Array([hip, knee, foot]), base.darkened(0.3), 6.0 if tier == 1 else 8.0, true)

	# abdomen plates
	var back := c - Vector2.from_angle(face) * r * 0.55
	for k in 3:
		var pr := r * (0.95 - k * 0.18)
		draw_circle(back - Vector2.from_angle(face) * k * r * 0.28, pr, base.lightened(0.05 * k))
		draw_arc(back - Vector2.from_angle(face) * k * r * 0.28, pr, 0, TAU, 40, Color(color, 0.45), 2.0, true)

	# head + carapace
	draw_circle(c, r, base)
	draw_arc(c, r, 0, TAU, 48, color.lightened(0.2), 3.0, true)
	draw_arc(c, r * 0.68, face - 1.2, face + 1.2, 24, Color(color, 0.5), 3.0, true)
	# glowing sac
	var pulse := 0.7 + 0.3 * sin(_t * (8.0 if _state == "windup" else 3.0))
	draw_circle(c - Vector2.from_angle(face) * r * 0.1, r * 0.38, Color(color, 0.35 * pulse))
	draw_circle(c - Vector2.from_angle(face) * r * 0.1, r * 0.2, Color(color.lightened(0.5), 0.9 * pulse))
	# eyes
	for s in [-1.0, 1.0]:
		var e := c + Vector2.from_angle(face + s * 0.38) * r * 0.72
		draw_circle(e, r * 0.11, Color(1, 0.95, 0.9))
		draw_circle(e, r * 0.2, Color(color, 0.3))
	if tier == 2:
		# crown spikes
		for k in 5:
			var a: float = face + PI + (float(k) - 2.0) * 0.35
			var b := c + Vector2.from_angle(a) * r * 0.9
			draw_line(b, b + Vector2.from_angle(a) * r * 0.45, Color(color.lightened(0.3), 0.9), 5.0, true)
