extends StaticBody2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const LightHelper = preload("res://scripts/light_helper.gd")

static var pylon_tex: ImageTexture = null

@onready var pylon_light: PointLight2D = $PointLight2D

func _ready() -> void:
	if not pylon_tex:
		pylon_tex = SpriteFactory.create_pylon_texture()
	
	if pylon_light:
		pylon_light.texture = LightHelper.get_radial_texture(128)
		pylon_light.energy = 0.85
		pylon_light.color = Color(0.2, 0.8, 1.2, 1.0)
		pylon_light.texture_scale = 1.8
	
	queue_redraw()

func _draw() -> void:
	if pylon_tex:
		# Draw texture with base contact at (0, 0)
		draw_texture(pylon_tex, Vector2(-24.0, -80.0))
