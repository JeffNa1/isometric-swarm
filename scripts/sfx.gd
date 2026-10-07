extends Node
## Procedurally synthesised sound effects. Autoloaded as `Sfx`.
## Every sound is rate-limited so a thousand kills a second stays pleasant.

const RATE := 22050
const VOICES := 20

var _streams := {}
var _last_play := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV

## name -> [min interval between plays (s), volume dB]
const LIMITS := {
	"shoot": [0.07, -21.0],
	"hit": [0.045, -24.0],
	"pop": [0.035, -17.0],
	"gem": [0.03, -19.0],
	"zap": [0.08, -18.0],
	"nova": [0.1, -14.0],
	"lance": [0.1, -15.0],
	"boom": [0.06, -13.0],
	"hurt": [0.12, -9.0],
	"dash": [0.1, -14.0],
	"level": [0.2, -10.0],
	"pick": [0.1, -11.0],
	"alarm": [0.5, -12.0],
	"boss": [1.0, -6.0],
	"click": [0.05, -14.0],
	"win": [1.0, -8.0],
	"lose": [1.0, -8.0],
	"bomb": [0.3, -6.0],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -15.0
	add_child(_music)
	_build()

func play(name: String, pitch: float = 1.0, vol_offset: float = 0.0) -> void:
	if not Data.sound_on or not _streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var lim: Array = LIMITS.get(name, [0.05, -12.0])
	if now - float(_last_play.get(name, -10.0)) < lim[0]:
		return
	_last_play[name] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = lim[1] + vol_offset
	p.play()

## Start (or keep) the in-run music loop. intensity 0..1 raises its volume.
func music(on: bool) -> void:
	if not on or not Data.sound_on:
		_music.stop()
		return
	if _music_stream == null:
		_music_stream = _make_music()
	if not _music.playing:
		_music.stream = _music_stream
		_music.play()

func set_music_intensity(k: float) -> void:
	_music.volume_db = lerpf(-17.0, -11.0, clampf(k, 0.0, 1.0))

# ------------------------------------------------------------------ synthesis
## Two bars of driving minor-key synth: kick, offbeat hats, filtered saw bass.
func _make_music() -> AudioStreamWAV:
	var bpm := 132.0
	var beat := 60.0 / bpm
	var eighth := beat * 0.5
	var bars := 4
	var n := int(beat * 4.0 * bars * RATE)
	var bass := [55.0, 55.0, 110.0, 55.0, 65.41, 65.41, 130.81, 73.42, 55.0, 55.0, 110.0, 55.0, 49.0, 49.0, 98.0, 61.74]
	var lead := [440.0, 0.0, 523.25, 0.0, 659.25, 0.0, 587.33, 523.25, 440.0, 0.0, 392.0, 0.0, 440.0, 0.0, 0.0, 0.0]
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var phase_b := 0.0
	var phase_l := 0.0
	var prev_noise := 0.0
	for i in n:
		var t := float(i) / RATE
		var bar := int(t / (beat * 4.0))
		var tb := fmod(t, beat)
		var te := fmod(t, eighth)
		var step := int(t / eighth) % 16
		# kick on every beat
		var kf := lerpf(140.0, 42.0, minf(tb / 0.09, 1.0))
		var kick := sin(TAU * kf * tb) * exp(-tb * 16.0)
		# offbeat hat: high-passed noise
		var nz := randf() * 2.0 - 1.0
		var hp := nz - prev_noise
		prev_noise = nz
		var hat := hp * exp(-fmod(t + eighth, beat) * 60.0) * 0.5
		# bass: saw through a one-pole low-pass, plucked per eighth
		var bf: float = bass[step]
		phase_b = fmod(phase_b + bf / RATE, 1.0)
		var saw := phase_b * 2.0 - 1.0
		var cutoff := 0.04 + 0.22 * exp(-te * 14.0)
		lp += (saw - lp) * cutoff
		var bass_v := lp * (0.55 + 0.45 * exp(-te * 6.0))
		# sparse lead on the second half (bars 3-4) for variation
		var lead_v := 0.0
		if bar >= 2:
			var lf: float = lead[step]
			if lf > 0.0:
				phase_l = fmod(phase_l + lf / RATE, 1.0)
				lead_v = (1.0 if phase_l < 0.25 else -1.0) * exp(-te * 9.0) * 0.12
		var v := kick * 0.6 + bass_v * 0.42 + hat * 0.2 + lead_v
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s

func _build() -> void:
	_streams["shoot"] = _make(0.07, func(t, _i): return _sq(t, lerpf(980.0, 520.0, t / 0.07), 0.25) * _env(t, 0.003, 0.07))
	_streams["hit"] = _make(0.04, func(t, _i): return _noise() * _env(t, 0.001, 0.04) * 0.5 + sin(TAU * 1600.0 * t) * _env(t, 0.0, 0.02) * 0.3)
	_streams["pop"] = _make(0.11, func(t, _i): return (sin(TAU * lerpf(520.0, 140.0, t / 0.11) * t) * 0.7 + _noise() * 0.35) * _env(t, 0.002, 0.11))
	_streams["gem"] = _make(0.09, func(t, _i): return (sin(TAU * 1760.0 * t) * 0.6 + sin(TAU * 2640.0 * t) * 0.25) * _env(t, 0.002, 0.09))
	_streams["zap"] = _make(0.16, func(t, _i): return _sq(t, 140.0 + 900.0 * absf(sin(t * 260.0)), 0.5) * 0.35 * _env(t, 0.002, 0.16) + _noise() * 0.2 * _env(t, 0.0, 0.08))
	_streams["nova"] = _make(0.42, func(t, _i): return (sin(TAU * lerpf(90.0, 40.0, t / 0.42) * t) * 0.8 + _noise() * 0.25 * _env(t, 0.0, 0.25)) * _env(t, 0.005, 0.42))
	_streams["lance"] = _make(0.32, func(t, _i): return (_saw(t, lerpf(1400.0, 180.0, pow(t / 0.32, 0.5))) * 0.4 + sin(TAU * 70.0 * t) * 0.4) * _env(t, 0.002, 0.32))
	_streams["boom"] = _make(0.45, func(t, _i): return (_noise() * 0.7 * _env(t, 0.001, 0.3) + sin(TAU * lerpf(110.0, 35.0, t / 0.45) * t) * 0.8) * _env(t, 0.002, 0.45))
	_streams["bomb"] = _make(1.1, func(t, _i): return (_noise() * 0.6 * _env(t, 0.001, 0.8) + sin(TAU * lerpf(70.0, 25.0, t / 1.1) * t) * 0.9) * _env(t, 0.002, 1.1))
	_streams["hurt"] = _make(0.22, func(t, _i): return (_sq(t, lerpf(220.0, 90.0, t / 0.22), 0.5) * 0.4 + _noise() * 0.3) * _env(t, 0.002, 0.22))
	_streams["dash"] = _make(0.2, func(t, _i): return _noise() * 0.5 * sin(PI * t / 0.2) * (0.4 + 0.6 * t / 0.2))
	_streams["level"] = _make(0.6, func(t, _i): return _arp(t, [523.25, 659.25, 783.99, 1046.5], 0.09) * _env(t, 0.005, 0.6))
	_streams["pick"] = _make(0.35, func(t, _i): return _arp(t, [783.99, 1174.66], 0.08) * _env(t, 0.003, 0.35))
	_streams["alarm"] = _make(0.9, func(t, _i): return _sq(t, 440.0 if fmod(t, 0.3) < 0.15 else 330.0, 0.5) * 0.3 * _env(t, 0.01, 0.9))
	_streams["boss"] = _make(1.6, func(t, _i): return (_saw(t, 55.0) * 0.35 + _saw(t, 55.7) * 0.35 + sin(TAU * 27.5 * t) * 0.4) * _env(t, 0.15, 1.6))
	_streams["click"] = _make(0.05, func(t, _i): return sin(TAU * 1200.0 * t) * _env(t, 0.001, 0.05) * 0.6)
	_streams["win"] = _make(1.3, func(t, _i): return _arp(t, [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0], 0.12) * _env(t, 0.005, 1.3))
	_streams["lose"] = _make(1.2, func(t, _i): return _arp(t, [392.0, 329.63, 261.63, 196.0], 0.22) * _env(t, 0.005, 1.2))
	_music_stream = _make_music()

func _make(length: float, fn: Callable) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v := clampf(fn.call(t, i), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s

static func _env(t: float, attack: float, length: float) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	var k := clampf((t - attack) / maxf(length - attack, 0.0001), 0.0, 1.0)
	return pow(1.0 - k, 2.0)

static func _sq(t: float, f: float, duty: float) -> float:
	return 1.0 if fmod(t * f, 1.0) < duty else -1.0

static func _saw(t: float, f: float) -> float:
	return fmod(t * f, 1.0) * 2.0 - 1.0

static func _noise() -> float:
	return randf() * 2.0 - 1.0

static func _arp(t: float, notes: Array, step: float) -> float:
	var idx := mini(int(t / step), notes.size() - 1)
	var f: float = notes[idx]
	return (sin(TAU * f * t) * 0.6 + _sq(t, f, 0.5) * 0.12) * (1.0 - fmod(t, step) / step * 0.3)
