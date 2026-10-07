extends Node3D

@onready var fire_light: OmniLight3D = $OmniLight3D
var base_energy: float = 2.5
var noise_time: float = 0.0

func _process(delta: float) -> void:
	noise_time += delta * 8.0
	fire_light.light_energy = base_energy + sin(noise_time) * 0.4 + sin(noise_time * 2.3) * 0.25
