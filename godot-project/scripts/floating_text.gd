extends Node3D

@onready var label: Label3D = $Label3D
var velocity: Vector3 = Vector3(0, 2.5, 0)
var lifetime: float = 0.8
var age: float = 0.0

func setup(text: String, color: Color = Color.WHITE, scale_mult: float = 1.0) -> void:
	if label == null:
		label = $Label3D
	label.text = text
	label.modulate = color
	scale = Vector3.ONE * scale_mult
	velocity = Vector3(randf_range(-0.5, 0.5), randf_range(2.0, 3.2), randf_range(-0.5, 0.5))

func _process(delta: float) -> void:
	age += delta
	position += velocity * delta
	velocity.y -= 3.0 * delta # gravity
	
	# Fade out
	var alpha := 1.0 - (age / lifetime)
	label.modulate.a = max(0.0, alpha)
	
	if age >= lifetime:
		queue_free()
