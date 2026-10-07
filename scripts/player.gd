extends Node2D
## The hover-drone you pilot. Keyboard / gamepad / virtual stick movement,
## a dash with i-frames, short invulnerability after hits, and procedural art.

signal died

var game: Node
var radius: float = Data.PLAYER.radius
var max_hp: float = Data.PLAYER.hp
var hp: float = Data.PLAYER.hp
var speed: float = Data.PLAYER.speed
var magnet: float = Data.PLAYER.magnet
var vel := Vector2.ZERO
var facing := Vector2.RIGHT
var invuln := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.RIGHT
var hurt_flash := 0.0
var alive := true
var stick := Vector2.ZERO   # set by the touch joystick
var _recoil := Vector2.ZERO
var _trail: Array = []
var _t := 0.0

func setup(g: Node) -> void:
	game = g
	z_index = 2
	scale = Vector2(1.3, 1.3)

func reset() -> void:
	position = Vector2.ZERO
	vel = Vector2.ZERO
	alive = true
	invuln = 1.0
	dash_cd = 0.0
	dash_t = 0.0
	_trail.clear()
	refresh_stats()
	hp = max_hp
	visible = true

func refresh_stats() -> void:
	var w = game.weapons
	var old_max := max_hp
	max_hp = Data.PLAYER.hp + w.max_hp_bonus()
	if max_hp > old_max:
		hp += max_hp - old_max
	speed = Data.PLAYER.speed * w.move_mult()
	magnet = Data.PLAYER.magnet * w.magnet_mult()

func dash_cooldown() -> float:
	return Data.PLAYER.dash_cooldown * game.weapons.dash_cd_mult()

func try_dash() -> void:
	if not alive or dash_cd > 0.0 or game.paused_for_ui:
		return
	dash_dir = vel.normalized() if vel.length_squared() > 25.0 else facing
	dash_t = Data.PLAYER.dash_time
	dash_cd = dash_cooldown()
	invuln = maxf(invuln, Data.PLAYER.dash_time + 0.12)
	Sfx.play("dash")
	game.fx.burst(position, Data.C_ACCENT, 10, 200.0, 12.0, 0.3)

func update(dt: float) -> void:
	if not alive:
		return
	_t += dt
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if stick.length_squared() > 0.0:
		input = stick
	if input.length() > 1.0:
		input = input.normalized()

	invuln = maxf(0.0, invuln - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	hurt_flash = maxf(0.0, hurt_flash - dt * 4.0)
	hp = minf(max_hp, hp + (Data.PLAYER.regen + game.weapons.regen()) * dt)

	if dash_t > 0.0:
		dash_t -= dt
		vel = dash_dir * Data.PLAYER.dash_speed
		if int(_t * 60.0) % 2 == 0:
			_trail.append([position, 0.25])
	else:
		var target := input * speed
		var accel := 14.0 if input.length_squared() > 0.0 else 10.0
		vel = vel.lerp(target, minf(1.0, accel * dt))
	if input.length_squared() > 0.01:
		facing = input.normalized()
	position += vel * dt
	_recoil = _recoil.lerp(Vector2.ZERO, minf(1.0, 18.0 * dt))

	for tr in _trail:
		tr[1] -= dt
	_trail = _trail.filter(func(tr): return tr[1] > 0.0)
	queue_redraw()

func recoil(dir: Vector2) -> void:
	_recoil = -dir * 2.5

func hurt(amount: float, from: Vector2, ignore_iframes: bool = false) -> void:
	if not alive or game.paused_for_ui:
		return
	if dash_t > 0.0:
		return
	if invuln > 0.0 and not ignore_iframes:
		return
	hp -= amount
	invuln = Data.PLAYER.invuln
	hurt_flash = 1.0
	vel += (position - from).normalized() * 220.0
	game.on_player_hurt(amount)
	if hp <= 0.0:
		hp = 0.0
		alive = false
		visible = false
		game.fx.explosion(position, 120.0, Data.C_ACCENT)
		game.fx.burst(position, Color.WHITE, 30, 400.0, 18.0, 0.8)
		died.emit()

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	game.fx.text(position + Vector2(0, -34), "+%d" % int(amount), Data.C_XP, 22)

# ------------------------------------------------------------------ art
func _draw() -> void:
	var blink := invuln > 0.0 and dash_t <= 0.0 and int(_t * 20.0) % 2 == 0 and hurt_flash < 0.9
	var bob := sin(_t * 4.0) * 2.0

	for tr in _trail:
		var k: float = tr[1] / 0.25
		var lp: Vector2 = tr[0] - position
		draw_circle(lp + Vector2(0, -6), radius * 1.1, Color(Data.C_ACCENT, 0.22 * k))

	# ground shadow + light pool
	_ellipse(Vector2(2, 10), Vector2(radius * 1.3, radius * 0.55), Color(0, 0, 0.02, 0.5))
	_ellipse(Vector2(0, 8), Vector2(radius * 2.4, radius * 1.1), Color(Data.C_ACCENT, 0.05))

	var c := Vector2(0, -8 + bob) + _recoil
	var body := Color("1a2742")
	var rim := Data.C_ACCENT
	if hurt_flash > 0.0:
		body = body.lerp(Color(1, 0.3, 0.4), hurt_flash)
		rim = rim.lerp(Color.WHITE, hurt_flash)
	if blink:
		rim.a = 0.35
		body.a = 0.5

	# thruster glow under the hull
	var thrust := 0.6 + 0.4 * sin(_t * 30.0)
	draw_circle(c + Vector2(0, 6), radius * 0.9, Color(rim, 0.15 * thrust))

	# octagon hull, slightly rotated toward facing
	var ang := facing.angle()
	var hull := PackedVector2Array()
	for i in 8:
		var a := ang + TAU * float(i) / 8.0 + PI / 8.0
		hull.append(c + Vector2(cos(a), sin(a) * 0.86) * radius * 1.05)
	draw_colored_polygon(hull, body)
	hull.append(hull[0])
	draw_polyline(hull, rim, 2.0, true)

	# side pods
	for s in [-1.0, 1.0]:
		var side := Vector2.from_angle(ang + s * PI * 0.5)
		var pod := c + side * radius * 1.05
		draw_circle(pod, 4.5, body.lightened(0.15))
		draw_arc(pod, 4.5, 0, TAU, 16, Color(rim, 0.8), 1.5, true)

	# nose / cannon
	var nose := c + facing * radius * 0.95
	draw_line(c + facing * radius * 0.3, nose + facing * 4.0, rim.lightened(0.3), 4.0, true)

	# glowing core
	var pulse := 0.75 + 0.25 * sin(_t * 6.0)
	draw_circle(c, radius * 0.62, Color(rim, 0.25))
	draw_circle(c, radius * 0.42 * pulse, Color(rim, 0.9))
	draw_circle(c - Vector2(1.5, 1.5), radius * 0.18, Color(1, 1, 1, 0.95))

	# health bar under the drone, only when hurt
	if hp < max_hp:
		var w := 38.0
		var y := radius + 10.0
		draw_rect(Rect2(-w * 0.5 - 1, y - 1, w + 2, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, y, w * hp / max_hp, 4), Data.C_HP if hp / max_hp < 0.35 else Data.C_XP)

	# dash ready pip
	if dash_cd > 0.0:
		var k := 1.0 - dash_cd / dash_cooldown()
		draw_arc(c, radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * k, 32, Color(rim, 0.35), 2.0, true)

func _ellipse(off: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(off + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
