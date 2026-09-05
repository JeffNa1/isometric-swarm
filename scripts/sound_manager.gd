extends Node

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 12

var players: Array[AudioStreamPlayer] = []
var player_idx: int = 0

var snd_laser: AudioStreamWAV
var snd_flame: AudioStreamWAV
var snd_shockwave: AudioStreamWAV
var snd_splat: AudioStreamWAV
var snd_hit: AudioStreamWAV
var snd_levelup: AudioStreamWAV
var snd_missile_launch: AudioStreamWAV
var snd_missile_explode: AudioStreamWAV
var snd_scythe_slice: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)

	_generate_all_sounds()

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

func play_laser() -> void:
	_play(snd_laser, -5.0, randf_range(0.93, 1.07))

func play_flame() -> void:
	_play(snd_flame, -9.0, randf_range(0.88, 1.12))

func play_shockwave() -> void:
	_play(snd_shockwave, -1.0, randf_range(0.95, 1.05))

func play_splat() -> void:
	_play(snd_splat, -11.0, randf_range(0.85, 1.25))

func play_hit() -> void:
	_play(snd_hit, -7.0, randf_range(0.9, 1.1))

func play_levelup() -> void:
	_play(snd_levelup, -2.5, 1.0)

func play_missile_launch() -> void:
	_play(snd_missile_launch, -6.0, randf_range(0.9, 1.1))

func play_missile_explode() -> void:
	_play(snd_missile_explode, -3.0, randf_range(0.92, 1.08))

func play_scythe_slice() -> void:
	_play(snd_scythe_slice, -7.0, randf_range(0.92, 1.15))

func _play(stream: AudioStreamWAV, volume_db: float, pitch: float) -> void:
	if not stream:
		return
	var p = players[player_idx]
	player_idx = (player_idx + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

# Synth 1: Piercing Magnetic Railgun (Crack + Ion Sweep)
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
		
		# Magnetic distortion burst at t < 0.2
		var crack = randf_range(-1.0, 1.0) * max(0.0, 1.0 - t * 7.0) * 0.45
		var sample = (sin(phase) * 0.75 + crack) * env
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 2: Flame Roar (Filtered White Noise Burst)
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

# Synth 3: Shockwave Cataclysm (Sub-bass rumble + seismic crack)
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

# Synth 4: Missile Launch (Ascending Whoosh)
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

# Synth 5: Missile Explode (Compact Punchy Bang + Shrapnel)
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

# Synth 6: Scythe Slash (Metallic Swish)
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
	var note_dur = total_samples / 4

	var phase = 0.0
	for i in range(total_samples):
		var note_idx = min(3, i / note_dur)
		var freq = notes[note_idx]
		phase += TAU * freq / float(SAMPLE_RATE)
		var note_t = float(i % note_dur) / float(note_dur)
		var env = (1.0 - note_t * 0.5)
		var sample = sin(phase) * env * 0.5 + sin(phase * 2.0) * env * 0.15
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = data
	return wav
