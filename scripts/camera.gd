extends Camera2D

@export var max_offset: Vector2 = Vector2(24.0, 16.0)
@export var max_roll: float = 0.03
@export var trauma_decay: float = 1.8

var trauma: float = 0.0
var time: float = 0.0

func _ready() -> void:
	add_to_group("camera")

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
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
