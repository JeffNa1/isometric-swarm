extends Node

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 8

var players: Array[AudioStreamPlayer] = []
var player_idx: int = 0

var snd_laser: AudioStreamWAV
var snd_flame: AudioStreamWAV
var snd_shockwave: AudioStreamWAV
var snd_splat: AudioStreamWAV
var snd_hit: AudioStreamWAV
var snd_levelup: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Create pool of audio players
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

func play_laser() -> void:
	_play(snd_laser, -6.0, randf_range(0.95, 1.05))

func play_flame() -> void:
	_play(snd_flame, -10.0, randf_range(0.9, 1.1))

func play_shockwave() -> void:
	_play(snd_shockwave, -2.0, 1.0)

func play_splat() -> void:
	_play(snd_splat, -12.0, randf_range(0.85, 1.25))

func play_hit() -> void:
	_play(snd_hit, -8.0, randf_range(0.9, 1.1))

func play_levelup() -> void:
	_play(snd_levelup, -3.0, 1.0)

func _play(stream: AudioStreamWAV, volume_db: float, pitch: float) -> void:
	if not stream:
		return
	var p = players[player_idx]
	player_idx = (player_idx + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

# Synth 1: Piercing Laser (Sine sweeping 1400Hz -> 180Hz)
func _synth_laser() -> AudioStreamWAV:
	var duration = 0.12
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples) # 0 to 1
		var freq = lerp(1400.0, 180.0, t * t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = (1.0 - t) * (1.0 - t)
		var sample = sin(phase) * env
		# Add a touch of square harmonic
		sample += (1.0 if sin(phase * 2.0) > 0.0 else -1.0) * env * 0.2
		var val_16 = int(clamp(sample * 0.7, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 2: Flame Whoosh (Filtered White Noise Burst)
func _synth_flame() -> AudioStreamWAV:
	var duration = 0.09
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var last_out = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var noise = randf_range(-1.0, 1.0)
		# Lowpass filter smoothing
		last_out = lerp(last_out, noise, 0.25)
		var env = sin(t * PI)
		var val_16 = int(clamp(last_out * env * 0.8, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 3: Shockwave Mega Boom (Sub-bass rumble + impact crunch)
func _synth_shockwave() -> AudioStreamWAV:
	var duration = 0.38
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	var noise_out = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(120.0, 32.0, sqrt(t))
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = (1.0 - t) * (1.0 - t)
		
		# Low sub sine + crunchy noise burst at onset
		var sub = sin(phase) * env
		var noise = randf_range(-1.0, 1.0) * max(0.0, 1.0 - t * 4.0) * 0.5
		noise_out = lerp(noise_out, noise, 0.35)
		
		var sample = (sub + noise_out) * 0.85
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 4: Splat / Pop (Chitin squish)
func _synth_splat() -> AudioStreamWAV:
	var duration = 0.06
	var total_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerp(800.0, 80.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env = 1.0 - t
		var sample = (sin(phase) + randf_range(-0.4, 0.4)) * env * 0.6
		var val_16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val_16)

	return _make_wav(data)

# Synth 5: Hit Crunch
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

# Synth 6: Level Up Triumph Arpeggio (C5 -> E5 -> G5 -> C6)
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
