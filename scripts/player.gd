extends CharacterBody2D

const LightHelper = preload("res://scripts/light_helper.gd")
const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const SaveManagerClass = preload("res://scripts/save_manager.gd")

signal health_changed(current: float, maximum: float)
signal xp_changed(current: int, target: int, lvl: int)
signal leveled_up(new_level: int)
signal player_died()

@export var max_health: float = 100.0
@export var base_speed: float = 250.0

var current_health: float = 100.0
var move_speed: float = 250.0
var pickup_radius: float = 48.0
var armor: float = 0.0
var regen_rate: float = 0.0
var damage_multiplier: float = 1.0
var cooldown_reduction: float = 0.0
var crit_chance: float = 0.0

var xp: int = 0
var level: int = 1
var xp_to_next: int = 73

var walk_cycle: float = 0.0
var facing_right: bool = true
var is_invulnerable: bool = false
var invuln_timer: float = 0.0
var hurt_flash_timer: float = 0.0
var hurt_sfx_timer: float = 0.0

var sound_mgr: Node = null
var camera_node: Camera2D = null
var particle_mgr: Node2D = null

@onready var aura_light: PointLight2D = $AuraLight
@onready var railgun_weapon: Node2D = $Weapons/Railgun
@onready var flame_weapon: Node2D = $Weapons/Flamethrower
@onready var shockwave_weapon: Node2D = $Weapons/Shockwave
@onready var missile_weapon: Node2D = $Weapons/MagicMissile
@onready var blade_weapon: Node2D = $Weapons/BladeOrbit
@onready var tesla_weapon: Node2D = $Weapons/TeslaCoil
@onready var mortar_weapon: Node2D = $Weapons/BioMortar

var player_frames: Array[ImageTexture] = []
var active_frame: int = 0
var recoil_offset: Vector2 = Vector2.ZERO
var sprite_scale: Vector2 = Vector2.ONE
var step_accumulator: float = 0.0
var overclock_timer: float = 0.0

# Operative class trait
var operative_id: String = "vex"

# Damage contribution tracking for Run Debriefing
var weapon_damage_dealt: Dictionary = {
	"railgun": 0.0,
	"flame": 0.0,
	"shockwave": 0.0,
	"missile": 0.0,
	"blade": 0.0,
	"tesla": 0.0,
	"mortar": 0.0
}

# --- Incremental Progression Inventories ---
var weapon_levels = {
	"railgun": 0,
	"flame": 0,
	"shockwave": 0,
	"missile": 0,
	"blade": 0,
	"tesla": 0,
	"mortar": 0
}

var passive_levels = {
	"energy_core": 0,
	"nano_armor": 0,
	"thrusters": 0,
	"magnet": 0,
	"amp": 0
}

var evolved_weapons = {
	"railgun": false,
	"flame": false,
	"shockwave": false,
	"missile": false,
	"blade": false,
	"tesla": false,
	"mortar": false
}

func _ready() -> void:
	SaveManagerClass.init_and_load()
	operative_id = SaveManagerClass.selected_operative

	_apply_meta_progression()
	_apply_operative_traits()

	current_health = max_health
	xp_to_next = get_xp_needed(level)
	health_changed.emit(current_health, max_health)
	xp_changed.emit(xp, xp_to_next, level)

	player_frames = SpriteFactory.create_operative_frames(operative_id)
	
	if aura_light:
		aura_light.texture = LightHelper.get_radial_texture(128)
		aura_light.energy = 0.95
		match operative_id:
			"pyro": aura_light.color = Color(1.4, 0.6, 0.15, 1.0)
			"volt": aura_light.color = Color(1.3, 1.2, 0.3, 1.0)
			"colossus": aura_light.color = Color(0.2, 1.3, 0.6, 1.0)
			_: aura_light.color = Color(0.25, 0.7, 1.2, 1.0)

	_setup_initial_weapons()
	_get_managers()
	queue_redraw()

func _apply_meta_progression() -> void:
	max_health += SaveManagerClass.get_bonus("max_health")
	armor += SaveManagerClass.get_bonus("armor")
	regen_rate += SaveManagerClass.get_bonus("regen")
	move_speed = base_speed * (1.0 + SaveManagerClass.get_bonus("move_speed"))
	pickup_radius = 48.0 * (1.0 + SaveManagerClass.get_bonus("magnet"))
	damage_multiplier = 1.0 + SaveManagerClass.get_bonus("damage")
	cooldown_reduction = SaveManagerClass.get_bonus("cooldown")
	crit_chance = SaveManagerClass.get_bonus("crit")

func _apply_operative_traits() -> void:
	match operative_id:
		"pyro":
			max_health *= 1.15
			if flame_weapon and "flame_range" in flame_weapon:
				flame_weapon.flame_range *= 1.25
				flame_weapon.flame_angle += 15.0
		"volt":
			cooldown_reduction += 0.15
			pickup_radius *= 1.20
		"colossus":
			max_health += 50.0
			armor += 4.0
			move_speed *= 0.90
		_: # "vex"
			move_speed *= 1.15
			crit_chance += 0.10
			damage_multiplier *= 1.05

func _setup_initial_weapons() -> void:
	# Disable all first
	_set_weapon_active(railgun_weapon, false)
	_set_weapon_active(flame_weapon, false)
	_set_weapon_active(shockwave_weapon, false)
	_set_weapon_active(missile_weapon, false)
	_set_weapon_active(blade_weapon, false)
	_set_weapon_active(tesla_weapon, false)
	_set_weapon_active(mortar_weapon, false)

	# Enable operative starting weapon
	match operative_id:
		"pyro":
			weapon_levels["flame"] = 1
			_set_weapon_active(flame_weapon, true)
		"volt":
			weapon_levels["tesla"] = 1
			_set_weapon_active(tesla_weapon, true)
		"colossus":
			weapon_levels["blade"] = 1
			_set_weapon_active(blade_weapon, true)
		_: # "vex"
			weapon_levels["railgun"] = 1
			_set_weapon_active(railgun_weapon, true)

func record_weapon_damage(w_id: String, dmg: float) -> void:
	if weapon_damage_dealt.has(w_id):
		weapon_damage_dealt[w_id] += dmg

func _set_weapon_active(weapon_node: Node2D, active: bool) -> void:
	if weapon_node:
		weapon_node.visible = active
		weapon_node.set_process(active)
		weapon_node.set_physics_process(active)

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		sound_mgr = cur.get_node_or_null("SoundManager")
		camera_node = cur.get_node_or_null("Camera2D")
		particle_mgr = cur.get_node_or_null("ParticleManager")

func trigger_overclock(duration: float = 10.0) -> void:
	overclock_timer = duration
	if particle_mgr:
		particle_mgr.spawn_sparks(global_position, Color(3.5, 3.0, 0.4, 1.0), 20)

func _physics_process(delta: float) -> void:
	if hurt_sfx_timer > 0.0:
		hurt_sfx_timer -= delta

	if invuln_timer > 0.0:
		invuln_timer -= delta
		if invuln_timer <= 0.0:
			is_invulnerable = false

	if overclock_timer > 0.0:
		overclock_timer -= delta
		if particle_mgr and randf() < 0.3:
			particle_mgr.spawn_sparks(global_position, Color(3.5, 2.5, 0.2, 1.0), 3)

	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
		queue_redraw()

	if recoil_offset.length_squared() > 0.001:
		recoil_offset = recoil_offset.move_toward(Vector2.ZERO, 70.0 * delta)

	sprite_scale = sprite_scale.lerp(Vector2.ONE, 16.0 * delta)

	# Health Regeneration (Nano Armor + Meta-Shop Regen)
	var total_regen = regen_rate + (1.5 * float(passive_levels["nano_armor"]))
	if total_regen > 0.0:
		heal(total_regen * delta)

	var input_x = Input.get_action_raw_strength("move_right") - Input.get_action_raw_strength("move_left")
	var input_y = Input.get_action_raw_strength("move_down") - Input.get_action_raw_strength("move_up")
	var raw_input = Vector2(input_x, input_y)

	var current_spd = move_speed * (1.45 if overclock_timer > 0.0 else 1.0)

	if raw_input.length_squared() > 0.0:
		var input_norm = raw_input.normalized()
		var iso_dir = Vector2(input_norm.x, input_norm.y * 0.75).normalized()
		velocity = velocity.move_toward(iso_dir * current_spd, 1800.0 * delta)
		walk_cycle += delta * (20.0 if overclock_timer > 0.0 else 14.0)
		active_frame = int(fmod(walk_cycle, 6.0))
		if input_x != 0.0:
			facing_right = input_x > 0.0

		# Walk cycle dynamic squash-and-stretch
		var walk_squash = sin(walk_cycle * 2.0) * 0.06
		sprite_scale.y = lerp(sprite_scale.y, 1.0 + walk_squash, 14.0 * delta)
		sprite_scale.x = lerp(sprite_scale.x, 1.0 - walk_squash * 0.5, 14.0 * delta)

		# Footstep dust plume
		step_accumulator += delta * (22.0 if overclock_timer > 0.0 else 14.0)
		if step_accumulator >= 1.0:
			step_accumulator = 0.0
			if particle_mgr and particle_mgr.has_method("spawn_steam_plume"):
				particle_mgr.spawn_steam_plume(global_position + Vector2(0, 4), Color(0.4, 0.5, 0.6, 0.28), 1)

		if particle_mgr and randf() < 0.35:
			var jet_pos = global_position + Vector2(-8 if facing_right else 8, 2)
			var jet_col = Color(3.5, 2.5, 0.4, 1.0) if overclock_timer > 0.0 else Color(0.3, 1.5, 3.0, 1.0)
			particle_mgr.spawn_sparks(jet_pos, jet_col, 2)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 2000.0 * delta)
		walk_cycle = 0.0
		active_frame = 0

	move_and_slide()
	queue_redraw()

func trigger_squash(s: Vector2) -> void:
	sprite_scale = s

func apply_recoil(dir: Vector2, force: float) -> void:
	recoil_offset += dir.normalized() * force
	recoil_offset = recoil_offset.limit_length(10.0)
	trigger_squash(Vector2(0.90, 1.14))
	queue_redraw()

func trigger_hit_stop(duration: float = 0.035) -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	var cur = get_tree().current_scene
	var hud_node = cur.get_node_or_null("HUD") if cur else null
	if hud_node:
		var lvl_modal = hud_node.get_node_or_null("LevelUpModal")
		if lvl_modal and lvl_modal.visible:
			return
		var p_modal = hud_node.get_node_or_null("PauseModal")
		if p_modal and p_modal.visible:
			return
		var ch_modal = hud_node.get_node_or_null("ChestModal")
		if ch_modal and ch_modal.visible:
			return
		var go_modal = hud_node.get_node_or_null("GameOverModal")
		if go_modal and go_modal.visible:
			return
	get_tree().paused = false

func roll_crit(base_dmg: float) -> Dictionary:
	var is_crit = randf() < crit_chance
	var final_dmg = base_dmg * damage_multiplier * (2.0 if is_crit else 1.0)
	return {"damage": final_dmg, "is_crit": is_crit}

func take_damage(amount: float) -> void:
	if current_health <= 0.0 or is_invulnerable:
		return

	is_invulnerable = true
	invuln_timer = 0.35

	# Non-linear diminishing returns armor formula (RPG standard)
	var effective_dmg = max(1.0, amount * (60.0 / (60.0 + armor)))
	current_health = max(0.0, current_health - effective_dmg)
	health_changed.emit(current_health, max_health)

	if hurt_sfx_timer <= 0.0:
		hurt_sfx_timer = 0.14
		hurt_flash_timer = 0.12
		trigger_squash(Vector2(1.24, 0.76))
		if not sound_mgr:
			_get_managers()
		if sound_mgr and sound_mgr.has_method("play_hit"):
			sound_mgr.play_hit()
		if camera_node and camera_node.has_method("add_trauma"):
			camera_node.add_trauma(0.35)
		if camera_node and camera_node.has_method("trigger_zoom_punch"):
			camera_node.trigger_zoom_punch(0.04, 0.18)

		var cur = get_tree().current_scene
		if cur and cur.has_method("trigger_damage_vignette"):
			cur.trigger_damage_vignette(0.7, 0.25)
		if cur and cur.has_method("trigger_chromatic_aberration_pulse"):
			cur.trigger_chromatic_aberration_pulse(0.02, 0.15)

		trigger_hit_stop(0.03)
		queue_redraw()

	if current_health <= 0.0:
		player_died.emit()

func get_xp_needed(lvl: int) -> int:
	return int(45.0 + pow(float(lvl), 1.65) * 28.0)

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = get_xp_needed(level)

		if not sound_mgr:
			_get_managers()
		if sound_mgr and sound_mgr.has_method("play_levelup"):
			sound_mgr.play_levelup()

		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)

func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func apply_upgrade(upgrade_id: String) -> void:
	# 1. Check Super Evolutions
	match upgrade_id:
		"railgun_evo":
			evolved_weapons["railgun"] = true
			if railgun_weapon and railgun_weapon.has_method("evolve_hyperion"):
				railgun_weapon.evolve_hyperion()
			return
		"flame_evo":
			evolved_weapons["flame"] = true
			if flame_weapon and flame_weapon.has_method("evolve_sunstorm"):
				flame_weapon.evolve_sunstorm()
			return
		"shockwave_evo":
			evolved_weapons["shockwave"] = true
			if shockwave_weapon and shockwave_weapon.has_method("evolve_supernova"):
				shockwave_weapon.evolve_supernova()
			return
		"missile_evo":
			evolved_weapons["missile"] = true
			if missile_weapon and missile_weapon.has_method("evolve_barrage"):
				missile_weapon.evolve_barrage()
			return
		"blade_evo":
			evolved_weapons["blade"] = true
			if blade_weapon and blade_weapon.has_method("evolve_vortex"):
				blade_weapon.evolve_vortex()
			return
		"tesla_evo":
			evolved_weapons["tesla"] = true
			if tesla_weapon and tesla_weapon.has_method("evolve_mjolnir"):
				tesla_weapon.evolve_mjolnir()
			return
		"mortar_evo":
			evolved_weapons["mortar"] = true
			if mortar_weapon and mortar_weapon.has_method("evolve_chernobyl"):
				mortar_weapon.evolve_chernobyl()
			return

	# 2. Weapons Unlock & Upgrade
	match upgrade_id:
		"railgun":
			if weapon_levels["railgun"] == 0:
				weapon_levels["railgun"] = 1
				_set_weapon_active(railgun_weapon, true)
			else:
				weapon_levels["railgun"] = min(5, weapon_levels["railgun"] + 1)
				if railgun_weapon: railgun_weapon.upgrade_beam()
		"flame":
			if weapon_levels["flame"] == 0:
				weapon_levels["flame"] = 1
				_set_weapon_active(flame_weapon, true)
			else:
				weapon_levels["flame"] = min(5, weapon_levels["flame"] + 1)
				if flame_weapon: flame_weapon.upgrade_flame()
		"shockwave":
			if weapon_levels["shockwave"] == 0:
				weapon_levels["shockwave"] = 1
				_set_weapon_active(shockwave_weapon, true)
			else:
				weapon_levels["shockwave"] = min(5, weapon_levels["shockwave"] + 1)
				if shockwave_weapon: shockwave_weapon.upgrade_blast()
		"missile":
			if weapon_levels["missile"] == 0:
				weapon_levels["missile"] = 1
				_set_weapon_active(missile_weapon, true)
			else:
				weapon_levels["missile"] = min(5, weapon_levels["missile"] + 1)
				if missile_weapon: missile_weapon.upgrade_missile()
		"blade":
			if weapon_levels["blade"] == 0:
				weapon_levels["blade"] = 1
				_set_weapon_active(blade_weapon, true)
			else:
				weapon_levels["blade"] = min(5, weapon_levels["blade"] + 1)
				if blade_weapon: blade_weapon.upgrade_blade()
		"tesla":
			if weapon_levels["tesla"] == 0:
				weapon_levels["tesla"] = 1
				_set_weapon_active(tesla_weapon, true)
			else:
				weapon_levels["tesla"] = min(5, weapon_levels["tesla"] + 1)
				if tesla_weapon: tesla_weapon.upgrade_tesla()
		"mortar":
			if weapon_levels["mortar"] == 0:
				weapon_levels["mortar"] = 1
				_set_weapon_active(mortar_weapon, true)
			else:
				weapon_levels["mortar"] = min(5, weapon_levels["mortar"] + 1)
				if mortar_weapon: mortar_weapon.upgrade_mortar()

		# 3. Passive Items
		"energy_core":
			passive_levels["energy_core"] = min(5, passive_levels["energy_core"] + 1)
			if railgun_weapon: railgun_weapon.upgrade_speed(0.88)
			if shockwave_weapon: shockwave_weapon.cooldown = max(0.8, shockwave_weapon.cooldown * 0.88)
			if missile_weapon: missile_weapon.upgrade_speed(0.88)
			if tesla_weapon: tesla_weapon.upgrade_speed(0.88)
			if mortar_weapon: mortar_weapon.upgrade_speed(0.88)
		"nano_armor":
			passive_levels["nano_armor"] = min(5, passive_levels["nano_armor"] + 1)
			max_health += 30.0
			armor += 1.0
			heal(60.0)
		"thrusters":
			passive_levels["thrusters"] = min(5, passive_levels["thrusters"] + 1)
			move_speed += 35.0
		"magnet":
			passive_levels["magnet"] = min(5, passive_levels["magnet"] + 1)
			pickup_radius += 20.0
		"amp":
			passive_levels["amp"] = min(5, passive_levels["amp"] + 1)
			damage_multiplier += 0.20

func _draw() -> void:
	# 1. BÓNG ĐỔ ISOMETRIC 2:1 ĐỘC LẬP TẠI MẶT SÀN (Ground Contact Plane)
	# Không bị giật bởi recoil_offset hay flip_h!
	var shadow_rx = 13.0
	if active_frame == 1:
		shadow_rx = 14.5 # Frame dẫm mạnh hấp thụ lực
	elif active_frame == 3:
		shadow_rx = 11.5 # Frame nhấc chân bung cao
	draw_isometric_drop_shadow(self, Vector2.ZERO, shadow_rx, 0.50, 0.0)

	# 2. THÂN THỂ CHIẾN BINH (Operative Body Sprite)
	if player_frames.is_empty():
		return

	var tex = player_frames[clampi(active_frame, 0, player_frames.size() - 1)]
	var flip = 1.0 if facing_right else -1.0
	var col = Color(5.0, 1.5, 1.5, 1.0) if hurt_flash_timer > 0.0 else Color.WHITE
	if is_invulnerable:
		var pulse = (int(float(Time.get_ticks_msec()) / 80.0) % 2) * 0.5 + 0.5
		col = Color(1.0, 3.0, 3.0, pulse)

	draw_set_transform(recoil_offset, 0.0, Vector2(flip * sprite_scale.x, sprite_scale.y))
	draw_texture(tex, Vector2(-24.0, -41.0), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func draw_isometric_drop_shadow(canvas: CanvasItem, center: Vector2, radius_x: float, base_alpha: float, height_z: float = 0.0) -> void:
	var scale_factor = clampf(1.0 - (height_z / 300.0) * 0.4, 0.3, 1.0)
	var final_alpha = clampf(base_alpha * (1.0 - (height_z / 300.0) * 0.6), 0.05, 1.0)
	var rx = radius_x * scale_factor
	canvas.draw_set_transform(center, 0.0, Vector2(1.0, 0.5))
	canvas.draw_circle(Vector2.ZERO, rx, Color(0.0, 0.0, 0.0, final_alpha * 0.35))
	canvas.draw_circle(Vector2.ZERO, rx * 0.65, Color(0.0, 0.0, 0.0, final_alpha * 0.55))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

