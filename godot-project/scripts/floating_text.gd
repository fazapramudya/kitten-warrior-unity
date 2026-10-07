extends Node3D

@onready var label: Label3D = $Label3D
var velocity: Vector3 = Vector3(0, 2.5, 0)
var lifetime: float = 0.85
var age: float = 0.0
var base_scale: float = 1.0

func setup(text: String, color: Color = Color.WHITE, scale_mult: float = 1.0) -> void:
	if label == null:
		label = $Label3D
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_render_priority = 1
	label.outline_size = 4
	label.outline_modulate = Color(0, 0, 0, 0.85)
	base_scale = scale_mult
	scale = Vector3.ONE * (scale_mult * 0.4)
	velocity = Vector3(randf_range(-0.6, 0.6), randf_range(2.4, 3.6), randf_range(-0.6, 0.6))

func _process(delta: float) -> void:
	age += delta
	position += velocity * delta
	velocity.y -= 4.2 * delta
	velocity.x = move_toward(velocity.x, 0.0, delta * 0.8)
	velocity.z = move_toward(velocity.z, 0.0, delta * 0.8)
	
	# Punch pop scale curve
	if age < 0.14:
		var pop_ratio = age / 0.14
		var s = lerp(base_scale * 0.4, base_scale * 1.35, pop_ratio)
		scale = Vector3.ONE * s
	elif age < 0.28:
		var settle_ratio = (age - 0.14) / 0.14
		var s = lerp(base_scale * 1.35, base_scale, settle_ratio)
		scale = Vector3.ONE * s
	else:
		scale = Vector3.ONE * base_scale
	
	# Smooth alpha fade out
	var alpha_progress = clamp((age - 0.25) / (lifetime - 0.25), 0.0, 1.0)
	label.modulate.a = max(0.0, 1.0 - alpha_progress * alpha_progress)
	
	if age >= lifetime:
		queue_free()
