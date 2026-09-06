extends Camera2D

@export var max_offset: Vector2 = Vector2(24.0, 15.0)
@export var max_roll: float = 0.035
@export var trauma_decay: float = 2.4
@export var max_trauma_cap: float = 0.95

var trauma: float = 0.0
var trauma_added_this_frame: float = 0.0
var punch_impulse: Vector2 = Vector2.ZERO

var noise: FastNoiseLite
var noise_sample_pos: float = 0.0
var base_zoom: Vector2 = Vector2(1.0, 1.0)
var zoom_punch_tween: Tween

func _ready() -> void:
	add_to_group("camera")
	base_zoom = zoom
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 4.5
	noise.fractal_octaves = 2

func add_trauma(amount: float) -> void:
	# Blend trauma cleanly without runaway exponential spikes
	trauma_added_this_frame = max(trauma_added_this_frame, amount)
	var blended = max(trauma, trauma_added_this_frame) + (trauma_added_this_frame * 0.2)
	trauma = clamp(blended, 0.0, max_trauma_cap)

func add_directional_trauma(amount: float, dir: Vector2) -> void:
	add_trauma(amount)
	punch_impulse += dir.normalized() * (amount * 24.0)
	punch_impulse = punch_impulse.limit_length(32.0)

func trigger_zoom_punch(factor: float = 0.06, duration: float = 0.24) -> void:
	if zoom_punch_tween and zoom_punch_tween.is_valid():
		zoom_punch_tween.kill()
	zoom_punch_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	zoom = base_zoom * (1.0 + factor)
	zoom_punch_tween.tween_property(self, "zoom", base_zoom, duration).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	trauma_added_this_frame = 0.0
	noise_sample_pos += delta * 60.0

	punch_impulse = punch_impulse.move_toward(Vector2.ZERO, 95.0 * delta)

	if trauma > 0.0 or punch_impulse != Vector2.ZERO:
		trauma = max(0.0, trauma - trauma_decay * delta)
		var shake = trauma * trauma # Non-linear quadratic falloff
		
		# Organic FastNoiseLite multi-axis shake
		var n_x = noise.get_noise_2d(noise_sample_pos, 0.0)
		var n_y = noise.get_noise_2d(noise_sample_pos, 150.0)
		var n_r = noise.get_noise_2d(noise_sample_pos, 300.0)
		
		var shake_x = max_offset.x * shake * n_x + punch_impulse.x
		var shake_y = max_offset.y * shake * n_y + punch_impulse.y
		offset = Vector2(shake_x, shake_y)
		rotation = max_roll * shake * n_r
	else:
		offset = Vector2.ZERO
		rotation = 0.0

