extends Camera2D

@export var max_offset: Vector2 = Vector2(14.0, 9.0)
@export var max_roll: float = 0.012
@export var trauma_decay: float = 2.8
@export var max_trauma_cap: float = 0.55

var trauma: float = 0.0
var time: float = 0.0
var trauma_added_this_frame: float = 0.0

func _ready() -> void:
	add_to_group("camera")

func add_trauma(amount: float) -> void:
	# Anti-stacking: Take highest trauma in frame, blend without runaway addition
	trauma_added_this_frame = max(trauma_added_this_frame, amount)
	var blended = max(trauma, trauma_added_this_frame) + (trauma_added_this_frame * 0.15)
	trauma = clamp(blended, 0.0, max_trauma_cap)

func _process(delta: float) -> void:
	trauma_added_this_frame = 0.0
	time += delta * 45.0

	if trauma > 0.0:
		trauma = max(0.0, trauma - trauma_decay * delta)
		var shake = trauma * trauma # Non-linear quadratic shake feel
		
		# High frequency 2D noise shake
		var shake_x = max_offset.x * shake * sin(time * 1.4)
		var shake_y = max_offset.y * shake * cos(time * 1.7)
		offset = Vector2(shake_x, shake_y)
		rotation = max_roll * shake * sin(time * 2.1)
	else:
		offset = Vector2.ZERO
		rotation = 0.0
