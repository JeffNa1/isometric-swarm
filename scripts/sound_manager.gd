extends Node

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 14

var players: Array[AudioStreamPlayer] = []
var player_idx: int = 0

var priority_players: Array[AudioStreamPlayer] = []
var priority_idx: int = 0

var bgm_player: AudioStreamPlayer = null

var snd_laser: AudioStreamWAV
var snd_flame: AudioStreamWAV
var snd_shockwave: AudioStreamWAV
var snd_splat: AudioStreamWAV
var snd_hit: AudioStreamWAV
var snd_levelup: AudioStreamWAV
var snd_missile_launch: AudioStreamWAV
var snd_missile_explode: AudioStreamWAV
var snd_scythe_slice: AudioStreamWAV
var snd_gem: AudioStreamWAV
var snd_alarm: AudioStreamWAV
var snd_chest: AudioStreamWAV
var snd_nuke: AudioStreamWAV
var snd_tesla: AudioStreamWAV
var snd_mortar: AudioStreamWAV
var snd_acid: AudioStreamWAV
var snd_crate: AudioStreamWAV
var snd_ui_hover: AudioStreamWAV
var snd_ui_click: AudioStreamWAV
var snd_ui_back: AudioStreamWAV
var snd_bgm: AudioStreamWAV
var snd_sub_bass: AudioStreamWAV

# Dopamine gem chime streak tracking & rapid pickup queue
var gem_streak: int = 0
var gem_streak_timer: float = 0.0
var queued_gem_pickups: int = 0
var gem_queue_timer: float = 0.0
const GEM_INTERVAL: float = 0.038
const PENTATONIC_SCALE: Array[int] = [
	0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31, 33, 36
]

# Sound throttling to prevent audio popping & voice stealing
var cooldowns: Dictionary = {
	"splat": 0.045,
	"hit": 0.04,
	"flame": 0.06,
	"laser": 0.04,
	"gem": 0.025,
	"acid": 0.08,
	"tesla": 0.04
}
var sound_cooldown_timers: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Normal SFX players (round-robin)
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)

	# Dedicated priority players (never stolen by splats/projectiles)
	for i in range(3):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		priority_players.append(p)

	# Dedicated BGM player
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -15.0
	add_child(bgm_player)

	_generate_all_sounds()

	# Start looping BGM
	if snd_bgm:
		bgm_player.stream = snd_bgm
		bgm_player.play()

func _process(delta: float) -> void:
	if gem_streak_timer > 0.0:
		gem_streak_timer -= delta
		if gem_streak_timer <= 0.0:
			gem_streak = 0

	if queued_gem_pickups > 0:
		gem_queue_timer -= delta
		if gem_queue_timer <= 0.0:
			gem_queue_timer = GEM_INTERVAL
			queued_gem_pickups -= 1
			_play_gem_note()

func _generate_all_sounds() -> void:
	snd_laser = _synth_laser()
	snd_flame = _synth_flame()
	snd_shockwave = _synth_shockwave()
	snd_splat = _synth_splat()
	snd_hit = _synth_hit()
	snd_levelup = _synth_levelup()
	snd_missile_launch = _synth_missile_launch()
	snd_missile_explode = _synth_missile_explode()
	snd_scythe_slice = _synth_scythe_slice()
	snd_gem = _synth_gem()
	snd_alarm = _synth_alarm()
	snd_chest = _synth_chest()
	snd_nuke = _synth_nuke()
	snd_tesla = _synth_tesla()
	snd_mortar = _synth_mortar()
	snd_acid = _synth_acid()
	snd_crate = _synth_crate()
	snd_ui_hover = _synth_ui_hover()
	snd_ui_click = _synth_ui_click()
	snd_ui_back = _synth_ui_back()
	snd_sub_bass = _synth_sub_bass()
	snd_bgm = _synth_dark_synthwave_bgm()

func play_ui_hover() -> void:
	_play_priority(snd_ui_hover, -10.0, randf_range(0.96, 1.04))

func play_ui_click() -> void:
	_play_priority(snd_ui_click, -6.0, randf_range(0.98, 1.02))

func play_ui_back() -> void:
	_play_priority(snd_ui_back, -7.0, 1.0)

func set_master_volume(linear_val: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	if linear_val <= 0.001:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamp(linear_val, 0.001, 1.0)))

func play_laser() -> void:
	if _is_throttled("laser"): return
	_play(snd_laser, -5.0, randf_range(0.93, 1.07))

func play_flame() -> void:
	if _is_throttled("flame"): return
	_play(snd_flame, -9.0, randf_range(0.88, 1.12))

func play_shockwave() -> void:
	_play(snd_shockwave, -1.0, randf_range(0.95, 1.05))

func play_splat() -> void:
	if _is_throttled("splat"): return
	_play(snd_splat, -11.0, randf_range(0.85, 1.25))

func play_hit() -> void:
	if _is_throttled("hit"): return
	_play(snd_hit, -7.0, randf_range(0.9, 1.1))

func play_levelup() -> void:
	_play_priority(snd_levelup, -2.5, 1.0)

func play_missile_launch() -> void:
	_play(snd_missile_launch, -6.0, randf_range(0.9, 1.1))

func play_missile_explode() -> void:
	_play(snd_missile_explode, -3.0, randf_range(0.92, 1.08))

func play_scythe_slice() -> void:
	_play(snd_scythe_slice, -7.0, randf_range(0.92, 1.15))

func play_nuke() -> void:
	_play_priority(snd_nuke, 1.5, 1.0)

func play_tesla() -> void:
	if _is_throttled("tesla"): return
	_play(snd_tesla, -6.5, randf_range(0.9, 1.15))

func play_mortar() -> void:
	_play(snd_mortar, -5.0, randf_range(0.92, 1.08))

func play_acid() -> void:
	if _is_throttled("acid"): return
	_play(snd_acid, -10.0, randf_range(0.88, 1.15))

func play_crate_break() -> void:
	_play(snd_crate, -4.5, randf_range(0.9, 1.1))

func enqueue_gem_pickup(count: int = 1) -> void:
	queued_gem_pickups = min(36, queued_gem_pickups + count)

func play_gem_pickup() -> void:
	enqueue_gem_pickup(1)

func _play_gem_note() -> void:
	gem_streak = min(PENTATONIC_SCALE.size() - 1, gem_streak + 1)
	gem_streak_timer = 0.85
	var semitones = PENTATONIC_SCALE[gem_streak]
	var pitch = pow(2.0, float(semitones) / 12.0)
	var vol = -8.5 + (float(gem_streak) / float(PENTATONIC_SCALE.size())) * 2.5
	_play(snd_gem, vol, pitch)

func play_sub_bass_impact() -> void:
	if snd_sub_bass:
		_play_priority(snd_sub_bass, 1.5, 1.0)

func play_alarm() -> void:
	_play_priority(snd_alarm, -2.0, 1.0)

func play_chest() -> void:
	_play_priority(snd_chest, -1.5, 1.0)

func _is_throttled(snd_key: String) -> bool:
	var now = Time.get_ticks_msec() * 0.001
	var cd = cooldowns.get(snd_key, 0.04)
	if sound_cooldown_timers.get(snd_key, 0.0) > now:
		return true
	sound_cooldown_timers[snd_key] = now + cd
	return false

func _play(stream: AudioStreamWAV, volume_db: float, pitch: float) -> void:
	if not stream:
		return
	var p = players[player_idx]
	player_idx = (player_idx + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

func _play_priority(stream: AudioStreamWAV, volume_db: float, pitch: float) -> void:
	if not stream:
		return
	for p in priority_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	var p = priority_players[priority_idx]
	priority_idx = (priority_idx + 1) % priority_players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

# Synth: Dark Synthwave Background Music Loop (4.0s @ 120 BPM)
func _synth_dark_synthwave_bgm() -> AudioStreamWAV:
	var duration = 4.0
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	# 16-step bassline in D minor (120 BPM -> 0.25s per 16th note)
	var notes = [
		73.42, 73.42, 87.31, 73.42,   # D2, D2, F2, D2
		98.00, 73.42, 87.31, 65.41,   # G2, D2, F2, C2
		73.42, 73.42, 87.31, 110.0,   # D2, D2, F2, A2
		98.00, 87.31, 82.41, 73.42    # G2, F2, E2, D2
	]
	var step_samples = int(float(total_samples) / 16.0)

	var phase_bass = 0.0
	var phase_sub = 0.0
	var phase_pad = 0.0

	for i in range(total_samples):
		var step_idx = mini(15, int(float(i) / float(step_samples)))
		var note_freq = notes[step_idx]
		var step_t = float(i % step_samples) / float(step_samples)

		# Bass synth: Sawtooth + Sub Sine with punchy decay envelope
		phase_bass += TAU * note_freq / float(SAMPLE_RATE)
		phase_sub += TAU * (note_freq * 0.5) / float(SAMPLE_RATE)
		phase_pad += TAU * 220.0 / float(SAMPLE_RATE) # Warm D minor pad tone

		var env = pow(1.0 - step_t * 0.85, 2.0)
		var saw = (fmod(phase_bass, TAU) / PI) - 1.0
		var sub = sin(phase_sub)
		var pad = sin(phase_pad) * 0.15

		# 4-on-the-floor subtle kick transient on beats 0, 4, 8, 12
		var kick = 0.0
		if (step_idx % 4) == 0 and step_t < 0.25:
			var kick_t = step_t / 0.25
			kick = sin(TAU * lerp(120.0, 40.0, kick_t) * (float(i % step_samples) / float(SAMPLE_RATE))) * (1.0 - kick_t) * 0.45

		var sample = (saw * 0.35 + sub * 0.45) * env + pad + kick
		var val_16 = int(clamp(sample * 0.7, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data, true)

# Synth: Crystal Gem Chime
func _synth_gem() -> AudioStreamWAV:
	var duration = 0.14
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase1 = 0.0
	var phase2 = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		phase1 += TAU * 880.0 / float(SAMPLE_RATE)
		phase2 += TAU * 1760.0 / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 2.5)
		var sample = (sin(phase1) * 0.7 + sin(phase2) * 0.3) * env
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth: Swarm Surge Siren Alarm
func _synth_alarm() -> AudioStreamWAV:
	var duration = 0.65
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = 480.0 + sin(t * TAU * 3.5) * 160.0
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = sin(t * PI)
		var sample = (sin(phase) + 0.3 * sin(phase * 3.0)) * env * 0.8
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth: Jackpot Chest Fanfare
func _synth_chest() -> AudioStreamWAV:
	var duration = 0.55
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var notes = [440.0, 554.37, 659.25, 880.0]
	var seg_len = int(float(total_samples) / 4.0)

	var phase = 0.0
	for i in range(total_samples):
		var note_idx = mini(3, int(float(i) / float(seg_len)))
		var freq = notes[note_idx]
		phase += TAU * freq / float(SAMPLE_RATE)
		var seg_t = float(i % seg_len) / float(seg_len)
		var env = pow(1.0 - seg_t * 0.4, 1.5)
		var sample = (sin(phase) + 0.25 * sin(phase * 2.0)) * env * 0.75
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 1: Piercing Magnetic Railgun
func _synth_laser() -> AudioStreamWAV:
	var duration = 0.16
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(1800.0, 140.0, t * t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 2.2)
		var crack = randf_range(-1.0, 1.0) * max(0.0, 1.0 - t * 7.0) * 0.45
		var sample = (sin(phase) * 0.75 + crack) * env
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 2: Flame Roar
func _synth_flame() -> AudioStreamWAV:
	var duration = 0.1
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var last_out = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var noise = randf_range(-1.0, 1.0)
		last_out = lerp(last_out, noise, 0.22)
		var env = sin(t * PI)
		var val_16 = int(clamp(last_out * env * 0.85, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 3: Shockwave Cataclysm
func _synth_shockwave() -> AudioStreamWAV:
	var duration = 0.45
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	var noise_out = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(150.0, 28.0, sqrt(t))
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 1.6)
		var sub = sin(phase) * env
		var noise = randf_range(-1.0, 1.0) * max(0.0, 1.0 - t * 3.5) * 0.65
		noise_out = lerp(noise_out, noise, 0.4)
		var sample = (sub * 0.8 + noise_out * 0.45)
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 4: Missile Launch
func _synth_missile_launch() -> AudioStreamWAV:
	var duration = 0.18
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	var filter = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(200.0, 750.0, t * t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var noise = randf_range(-1.0, 1.0)
		filter = lerp(filter, noise, 0.3)
		var env = sin(t * PI)
		var sample = (sin(phase) * 0.4 + filter * 0.6) * env
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 5: Missile Explode
func _synth_missile_explode() -> AudioStreamWAV:
	var duration = 0.28
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	var noise_out = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(220.0, 45.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 2.0)
		var noise = randf_range(-1.0, 1.0) * max(0.0, 1.0 - t * 4.0) * 0.7
		noise_out = lerp(noise_out, noise, 0.35)
		var sample = (sin(phase) * 0.65 + noise_out) * env
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 6: Scythe Slash
func _synth_scythe_slice() -> AudioStreamWAV:
	var duration = 0.12
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(1200.0, 400.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = sin(t * PI)
		var sample = (sin(phase) + randf_range(-0.3, 0.3)) * env * 0.7
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 7: Splat / Pop
func _synth_splat() -> AudioStreamWAV:
	var duration = 0.06
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(850.0, 80.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = 1.0 - t
		var sample = (sin(phase) + randf_range(-0.4, 0.4)) * env * 0.6
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 8: Hit Crunch
func _synth_hit() -> AudioStreamWAV:
	var duration = 0.05
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(280.0, 60.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = (1.0 - t) * (1.0 - t)
		var sample = sin(phase) * env * 0.7
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 9: Level Up Triumph
func _synth_levelup() -> AudioStreamWAV:
	var duration = 0.42
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var notes = [523.25, 659.25, 783.99, 1046.50]
	var note_dur = int(float(total_samples) / 4.0)

	var phase = 0.0
	for i in range(total_samples):
		var note_idx = mini(3, int(float(i) / float(note_dur)))
		var freq = notes[note_idx]
		phase += TAU * freq / float(SAMPLE_RATE)
		var note_t = float(i % note_dur) / float(note_dur)
		var env = (1.0 - note_t * 0.5)
		var sample = sin(phase) * env * 0.5 + sin(phase * 2.0) * env * 0.15
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 10: Screen-Clearing EMP Nuke
func _synth_nuke() -> AudioStreamWAV:
	var duration = 0.8
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	var noise_out = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(160.0, 20.0, sqrt(t))
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 1.4)
		var noise = randf_range(-1.0, 1.0) * max(0.0, 1.0 - t * 2.5)
		noise_out = lerp(noise_out, noise, 0.45)
		var sample = (sin(phase) * 0.75 + noise_out * 0.7) * env
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 11: Tesla Arc Crackle
func _synth_tesla() -> AudioStreamWAV:
	var duration = 0.14
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(1600.0, 350.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 1.8)
		var zap = 1.0 if sin(phase * 3.0) > 0.3 else -1.0
		var sample = (sin(phase) * 0.5 + zap * 0.45) * env
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 12: Bio-Mortar Canister Thump
func _synth_mortar() -> AudioStreamWAV:
	var duration = 0.16
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(220.0, 70.0, sqrt(t))
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 2.0)
		var sample = sin(phase) * env * 0.85
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 13: Corrosive Acid Sizzle
func _synth_acid() -> AudioStreamWAV:
	var duration = 0.22
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var noise_out = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var noise = randf_range(-1.0, 1.0)
		noise_out = lerp(noise_out, noise, 0.6)
		var env = sin(t * PI)
		var sample = noise_out * env * 0.75
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 14: Crate Crunch
func _synth_crate() -> AudioStreamWAV:
	var duration = 0.12
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(340.0, 80.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = 1.0 - t
		var crack = randf_range(-0.5, 0.5)
		var sample = (sin(phase) * 0.5 + crack * 0.5) * env
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

func _make_wav(data: PackedByteArray, is_loop: bool = false) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = data
	if is_loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(float(data.size()) / 2.0)
	return wav

# Synth 15: UI Hover Blip
func _synth_ui_hover() -> AudioStreamWAV:
	var duration = 0.035
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(1400.0, 1950.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 2.2)
		var sample = sin(phase) * env * 0.4
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 16: UI Click Chirp
func _synth_ui_click() -> AudioStreamWAV:
	var duration = 0.055
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(600.0, 1400.0, sqrt(t))
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 1.6)
		var sample = (sin(phase) * 0.7 + sin(phase * 2.0) * 0.3) * env * 0.55
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 17: UI Back / Dismiss Click
func _synth_ui_back() -> AudioStreamWAV:
	var duration = 0.05
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(420.0, 210.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 2.0)
		var sample = sin(phase) * env * 0.45
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 18: Heavy Sub-Bass Impact Boom
func _synth_sub_bass() -> AudioStreamWAV:
	var duration = 0.55
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(80.0, 24.0, sqrt(t))
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = pow(1.0 - t, 1.6)
		var sample = (sin(phase) + 0.35 * sin(phase * 0.5)) * env * 0.95
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)
