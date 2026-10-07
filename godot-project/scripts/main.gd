extends Node3D

@onready var player = $Player
@onready var health_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/HealthBar
@onready var stamina_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/StaminaBar
@onready var kill_label: Label = $HUD/MarginContainer/VBoxContainer/KillLabel

var kills: int = 0
var slime_scene = preload("res://scenes/slime.tscn")
var spawn_timer: float = 0.0
var spawn_interval: float = 8.0

func _ready() -> void:
	if player:
		player.health_changed.connect(_on_health_changed)
		player.stamina_changed.connect(_on_stamina_changed)
		_on_health_changed(player.health, player.max_health)
		_on_stamina_changed(player.stamina, player.max_stamina)
	update_kill_ui()

func _process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_slime_around_player()

func _on_health_changed(curr: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = curr

func _on_stamina_changed(curr: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = curr

func on_enemy_killed() -> void:
	kills += 1
	update_kill_ui()

func update_kill_ui() -> void:
	if kill_label:
		kill_label.text = "⚔️ Kills: " + str(kills)

func spawn_slime_around_player() -> void:
	if player == null:
		return
	# Count existing slimes
	var existing = get_tree().get_nodes_in_group("enemies")
	if existing.size() >= 12:
		return
		
	var angle := randf() * TAU
	var dist := randf_range(12.0, 24.0)
	var spawn_pos = player.global_position + Vector3(cos(angle) * dist, 1.0, sin(angle) * dist)
	
	var slime = slime_scene.instantiate()
	slime.global_position = spawn_pos
	add_child(slime)
