class_name SaveManager
extends RefCounted

const SAVE_PATH: String = "user://save_data.json"

static var nanites: int = 0
static var selected_operative: String = "vex"
static var unlocked_operatives: Array = ["vex", "pyro", "volt", "colossus"]

static var meta_upgrades: Dictionary = {
	"max_health": 0,    # Max 10: +10 HP each
	"armor": 0,         # Max 5: -1 damage taken each
	"regen": 0,         # Max 5: +0.5 HP/s each
	"move_speed": 0,    # Max 5: +5% speed each
	"magnet": 0,        # Max 5: +15% radius each
	"damage": 0,        # Max 10: +3% damage each
	"cooldown": 0,      # Max 5: -2.5% CD each
	"crit": 0,          # Max 5: +3% crit chance each
	"rerolls": 0,       # Max 3: +1 reroll per run
	"banishes": 0,      # Max 3: +1 banish per run
	"nanite_gain": 0    # Max 5: +10% nanite gain
}

static var max_upgrade_levels: Dictionary = {
	"max_health": 10,
	"armor": 5,
	"regen": 5,
	"move_speed": 5,
	"magnet": 5,
	"damage": 10,
	"cooldown": 5,
	"crit": 5,
	"rerolls": 3,
	"banishes": 3,
	"nanite_gain": 5
}

static var base_upgrade_costs: Dictionary = {
	"max_health": 100,
	"armor": 200,
	"regen": 250,
	"move_speed": 150,
	"magnet": 100,
	"damage": 200,
	"cooldown": 300,
	"crit": 250,
	"rerolls": 500,
	"banishes": 500,
	"nanite_gain": 200
}

static var upgrade_defs: Dictionary = {
	"max_health": {"name": "LÕI SINH LỰC", "desc": "+10 Máu tối đa mỗi cấp", "icon": "hp", "unit": "+10 HP"},
	"armor": {"name": "GIÁP COMPOSITE", "desc": "-1 Sát thương nhận vào mỗi đòn", "icon": "armor", "unit": "+1 Giáp"},
	"regen": {"name": "NANO TỰ HỒI", "desc": "+0.5 Máu hồi mỗi giây", "icon": "regen", "unit": "+0.5 HP/s"},
	"move_speed": {"name": "ĐỘNG CƠ PHẢN LỰC", "desc": "+5% Tốc độ di chuyển", "icon": "speed", "unit": "+5% Tốc độ"},
	"magnet": {"name": "TRƯỜNG TỪ TÍNH", "desc": "+15% Phạm vi hút ngọc kinh nghiệm", "icon": "magnet", "unit": "+15% Tầm hút"},
	"damage": {"name": "CHÍP XUNG KÍCH", "desc": "+3% Tổng sát thương mọi vũ khí", "icon": "damage", "unit": "+3% Sát thương"},
	"cooldown": {"name": "BỘ LÀM MÁT LỎNG", "desc": "-2.5% Hồi chiêu mọi vũ khí", "icon": "cooldown", "unit": "-2.5% Hồi chiêu"},
	"crit": {"name": "LĂNG KÍNH CHÍ MẠNG", "desc": "+3% Tỉ lệ chí mạng (x2.0 dmg)", "icon": "crit", "unit": "+3% Chí mạng"},
	"rerolls": {"name": "ĐIỀU HƯỚNG TẬP LỆNH", "desc": "+1 Lượt đổi thẻ khi lên cấp", "icon": "reroll", "unit": "+1 Lượt đổi"},
	"banishes": {"name": "GIAO THỨC TẨY TRỪ", "desc": "+1 Lượt loại bỏ thẻ vĩnh viễn trong run", "icon": "banish", "unit": "+1 Lượt bỏ"},
	"nanite_gain": {"name": "BỘ THU NANITE", "desc": "+10% Nanites thu thập mỗi trận", "icon": "nanite", "unit": "+10% Nanite"}
}

static var operative_defs: Dictionary = {
	"vex": {
		"name": "VEX - PHÁ THIÊN",
		"title": "BÓNG MA ĐỘT KÍCH",
		"weapon": "Railgun",
		"desc": "+15% Tốc chạy, +10% Chí mạng, +5% Sát thương. Chuyên gia luồn lách và tỉa laser kép.",
		"color": Color(0.2, 0.9, 1.0)
	},
	"pyro": {
		"name": "PYRO - HỎA TRẬN",
		"title": "BẬC THẦY HỎA NGỤC",
		"weapon": "Flamethrower",
		"desc": "+25% Phạm vi nổ/lửa, +15% HP. Thiêu đốt quét sạch mọi quái vật áp sát.",
		"color": Color(1.0, 0.45, 0.15)
	},
	"volt": {
		"name": "VOLT - LÔI TỘC",
		"title": "THỢ SĂN SẤM SÉT",
		"weapon": "Tesla Coil",
		"desc": "-15% Hồi chiêu, +20% Phạm vi hút ngọc. Xả điện liên hoàn giật nát bầy đàn.",
		"color": Color(0.9, 0.85, 0.2)
	},
	"colossus": {
		"name": "COLOSSUS - KIM CƯƠNG",
		"title": "PHÁO ĐÀI BỌC THÉP",
		"weapon": "Blade Orbit",
		"desc": "+4 Giáp sắt cản đòn, +50 HP tối đa, -10% Tốc chạy. Thiết giáp bất tử cận chiến.",
		"color": Color(0.3, 1.0, 0.5)
	}
}

static var total_kills: int = 0
static var best_time: float = 0.0
static var total_runs: int = 0

static var _loaded: bool = false

static func refund_all_upgrades() -> void:
	var total_refund = 0
	for k in meta_upgrades.keys():
		var lvl = meta_upgrades[k]
		var base = base_upgrade_costs.get(k, 100)
		for i in range(lvl):
			total_refund += int(base * pow(1.65, i))
		meta_upgrades[k] = 0
	nanites += total_refund
	save_game()

static func init_and_load() -> void:
	if _loaded:
		return
	_loaded = true
	load_game()

static func get_upgrade_cost(id: String) -> int:
	var lvl = meta_upgrades.get(id, 0)
	var max_lvl = max_upgrade_levels.get(id, 5)
	if lvl >= max_lvl:
		return -1
	var base = base_upgrade_costs.get(id, 100)
	return int(base * pow(1.65, lvl))

static func buy_upgrade(id: String) -> bool:
	var cost = get_upgrade_cost(id)
	if cost == -1 or nanites < cost:
		return false
	nanites -= cost
	meta_upgrades[id] = meta_upgrades.get(id, 0) + 1
	save_game()
	return true

static func get_bonus(id: String) -> float:
	var lvl = float(meta_upgrades.get(id, 0))
	match id:
		"max_health": return lvl * 10.0
		"armor": return lvl * 1.0
		"regen": return lvl * 0.5
		"move_speed": return lvl * 0.05
		"magnet": return lvl * 0.15
		"damage": return lvl * 0.03
		"cooldown": return lvl * 0.025
		"crit": return lvl * 0.03
		"rerolls": return lvl
		"banishes": return lvl
		"nanite_gain": return lvl * 0.10
		_: return 0.0

static func add_nanites(amount: int) -> void:
	var mult = 1.0 + get_bonus("nanite_gain")
	nanites += int(amount * mult)
	save_game()

static func record_run_stats(run_time: float, run_kills: int) -> void:
	total_runs += 1
	total_kills += run_kills
	if run_time > best_time:
		best_time = run_time
	save_game()

static func save_game() -> void:
	var data = {
		"nanites": nanites,
		"selected_operative": selected_operative,
		"unlocked_operatives": unlocked_operatives,
		"meta_upgrades": meta_upgrades,
		"total_kills": total_kills,
		"best_time": best_time,
		"total_runs": total_runs
	}
	var tmp_path = SAVE_PATH + ".tmp"
	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file:
		var json = JSON.stringify(data, "\t")
		file.store_string(json)
		file.close()
		DirAccess.rename_absolute(tmp_path, SAVE_PATH)

static func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	var test_json_conv = JSON.new()
	var error = test_json_conv.parse(content)
	if error != OK:
		return
	var data = test_json_conv.data
	if typeof(data) == TYPE_DICTIONARY:
		nanites = int(data.get("nanites", 0))
		selected_operative = str(data.get("selected_operative", "vex"))
		if data.has("unlocked_operatives"):
			unlocked_operatives = data["unlocked_operatives"]
		if data.has("meta_upgrades"):
			for k in data["meta_upgrades"].keys():
				if meta_upgrades.has(k):
					meta_upgrades[k] = int(data["meta_upgrades"][k])
		total_kills = int(data.get("total_kills", 0))
		best_time = float(data.get("best_time", 0.0))
		total_runs = int(data.get("total_runs", 0))
