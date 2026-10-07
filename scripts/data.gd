extends Node
## Global definitions: palette, balance tables, theme, and persistent settings.
## Autoloaded as `Data`. Every balance number in the game lives here.

# ---------------------------------------------------------------- palette
const C_BG := Color("070b14")
const C_PANEL := Color("0e1524")
const C_PANEL_HI := Color("16213a")
const C_LINE := Color("26365a")
const C_TEXT := Color("e8f0ff")
const C_TEXT_DIM := Color("8a9bbf")
const C_ACCENT := Color("4ff0ff")
const C_XP := Color("3dffb0")
const C_HP := Color("ff4d6d")
const C_GOLD := Color("ffc94d")
const C_WARN := Color("ff6b3d")

# ---------------------------------------------------------------- run
const RUN_LENGTH := 600.0          # final boss arrives at 10:00
const MID_BOSS_TIME := 300.0
const ELITE_TIMES := [90.0, 210.0, 390.0, 510.0]
const SURGE_INTERVAL := 50.0        # a ring of enemies closes in this often
const FIRST_SURGE := 40.0

# ---------------------------------------------------------------- player
const PLAYER := {
	"hp": 100.0,
	"speed": 235.0,
	"radius": 13.0,
	"invuln": 0.55,
	"magnet": 75.0,
	"dash_time": 0.18,
	"dash_speed": 760.0,
	"dash_cooldown": 2.4,
}

# ---------------------------------------------------------------- enemies
enum E { MITE, DART, BRUTE, SPITTER, BOMBER, ELITE }

const ENEMIES := [
	# MITE: the popcorn. Cheap, slow-ish, everywhere.
	{"name": "Mite", "hp": 7.0, "speed": 92.0, "radius": 10.0, "dmg": 6.0, "xp": 1, "color": Color("ff3d81"), "knock": 1.0},
	# DART: fast flankers that punish standing still.
	{"name": "Dart", "hp": 6.0, "speed": 168.0, "radius": 9.0, "dmg": 5.0, "xp": 1, "color": Color("ffc23d"), "knock": 1.2},
	# BRUTE: slow walls of meat. Shrug off knockback.
	{"name": "Brute", "hp": 70.0, "speed": 58.0, "radius": 19.0, "dmg": 16.0, "xp": 6, "color": Color("ff5a3d"), "knock": 0.25},
	# SPITTER: keeps its distance and lobs slow, readable shots.
	{"name": "Spitter", "hp": 20.0, "speed": 72.0, "radius": 12.0, "dmg": 10.0, "xp": 3, "color": Color("a6ff3d"), "knock": 0.8},
	# BOMBER: rushes in, fuses, explodes. Also hurts its friends.
	{"name": "Bomber", "hp": 14.0, "speed": 118.0, "radius": 11.0, "dmg": 22.0, "xp": 2, "color": Color("ff8a1a"), "knock": 0.8},
	# ELITE: a champion mite. Drops a supply cache.
	{"name": "Champion", "hp": 900.0, "speed": 82.0, "radius": 26.0, "dmg": 20.0, "xp": 40, "color": Color("ffd84d"), "knock": 0.05},
]

## Time (seconds) each enemy type joins the regular spawn mix, and its weight.
const SPAWN_TABLE := [
	{"type": E.MITE, "from": 0.0, "weight": 10.0},
	{"type": E.DART, "from": 45.0, "weight": 3.5},
	{"type": E.BRUTE, "from": 120.0, "weight": 1.2},
	{"type": E.SPITTER, "from": 170.0, "weight": 1.6},
	{"type": E.BOMBER, "from": 260.0, "weight": 2.0},
]

## How many enemies the director tries to keep alive at time t.
static func target_population(t: float) -> float:
	var m := t / 60.0
	return 90.0 + 270.0 * m + 14.0 * m * m

## Enemy HP multiplier at time t. Player power outpaces this when building well.
static func hp_scale(t: float) -> float:
	var m := t / 60.0
	return 1.0 + 0.22 * m + 0.035 * m * m

static func dmg_scale(t: float) -> float:
	return 1.0 + 0.06 * (t / 60.0)

# ---------------------------------------------------------------- xp
static func xp_to_next(level: int) -> int:
	var l := float(level - 1)
	return int(round(10.0 + 12.0 * l + 2.5 * l * l))

# ---------------------------------------------------------------- upgrades
const MAX_LEVEL := 5
const MAX_WEAPONS := 4
const MAX_PASSIVES := 4

const WEAPONS := {
	"pulse": {
		"name": "Pulse Cannon", "color": Color("4ff0ff"),
		"desc": ["Fires bolts at the nearest enemy.", "+1 bolt.", "+40% damage, +1 pierce.", "+1 bolt, fires 15% faster.", "+2 bolts, +1 pierce."],
	},
	"orbit": {
		"name": "Halo Blades", "color": Color("8a7dff"),
		"desc": ["Two blades circle you, shredding anything close.", "+1 blade.", "+30% damage, +20% radius.", "+1 blade, spins faster.", "+2 blades, +30% damage."],
	},
	"arc": {
		"name": "Arc Coil", "color": Color("7dd8ff"),
		"desc": ["Lightning jumps between nearby enemies.", "+2 jumps.", "+40% damage.", "Casts twice.", "+3 jumps, recharges 30% faster."],
	},
	"nova": {
		"name": "Nova Pulse", "color": Color("ff6bd5"),
		"desc": ["Periodic blast that pushes the swarm back.", "+20% radius.", "+45% damage.", "Recharges 25% faster.", "+25% radius, +30% damage."],
	},
	"lance": {
		"name": "Rail Lance", "color": Color("ffe14d"),
		"desc": ["A piercing beam through the thickest crowd.", "+40% width.", "+50% damage.", "Fires a second beam.", "Recharges 30% faster, +1 beam."],
	},
	"mortar": {
		"name": "Cluster Mortar", "color": Color("ff9b3d"),
		"desc": ["Shells rain on distant packs.", "+1 shell.", "+25% blast radius.", "+45% damage.", "+2 shells."],
	},
}

const PASSIVES := {
	"power": {"name": "Overcharge", "color": Color("ff5f7a"), "desc": "+12% damage."},
	"rapid": {"name": "Coolant", "color": Color("4fb6ff"), "desc": "Weapons recharge 8% faster."},
	"reach": {"name": "Amplifier", "color": Color("c47dff"), "desc": "+12% area and range."},
	"swift": {"name": "Servos", "color": Color("4dffb8"), "desc": "+8% move speed, faster dash."},
	"vital": {"name": "Nanoplating", "color": Color("ff7d6b"), "desc": "+20 max HP, +0.5 HP/s regen."},
	"magnet": {"name": "Tractor Field", "color": Color("3dffb0"), "desc": "+35% pickup range, +8% XP."},
}

# ---------------------------------------------------------------- settings / save
var sound_on := true
var shake_on := true
var best_time := 0.0
var best_kills := 0
var wins := 0

var font_regular: Font
var font_bold: Font
var theme: Theme

const SAVE_PATH := "user://save.cfg"

func _ready() -> void:
	font_regular = load("res://assets/fonts/chakra-petch-latin-500-normal.woff")
	font_bold = load("res://assets/fonts/chakra-petch-latin-700-normal.woff")
	theme = _build_theme()
	_setup_input()
	_load()

func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"dash": [KEY_SPACE, KEY_SHIFT],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)
	for pair in [["dash", JOY_BUTTON_A], ["dash", JOY_BUTTON_RIGHT_SHOULDER], ["pause", JOY_BUTTON_START]]:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pair[1]
		InputMap.action_add_event(pair[0], jb)

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "sound", sound_on)
	cfg.set_value("settings", "shake", shake_on)
	cfg.set_value("stats", "best_time", best_time)
	cfg.set_value("stats", "best_kills", best_kills)
	cfg.set_value("stats", "wins", wins)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	sound_on = cfg.get_value("settings", "sound", true)
	shake_on = cfg.get_value("settings", "shake", true)
	best_time = cfg.get_value("stats", "best_time", 0.0)
	best_kills = cfg.get_value("stats", "best_kills", 0)
	wins = cfg.get_value("stats", "wins", 0)

func record_run(time: float, kills: int, won: bool) -> void:
	best_time = maxf(best_time, time)
	best_kills = maxi(best_kills, kills)
	if won:
		wins += 1
	save()

static func format_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]

# ---------------------------------------------------------------- theme
func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_regular
	t.default_font_size = 20
	t.set_color("font_color", "Label", C_TEXT)

	var normal := _box(C_PANEL, C_LINE)
	var hover := _box(C_PANEL_HI, C_ACCENT.darkened(0.25))
	var pressed := _box(C_ACCENT.darkened(0.65), C_ACCENT)
	for s in [["normal", normal], ["hover", hover], ["pressed", pressed], ["focus", _box(Color(0, 0, 0, 0), C_ACCENT, 2)], ["disabled", normal]]:
		t.set_stylebox(s[0], "Button", s[1])
	t.set_font("font", "Button", font_bold)
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	return t

static func _box(bg: Color, border: Color, bw: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.anti_aliasing = true
	return sb
