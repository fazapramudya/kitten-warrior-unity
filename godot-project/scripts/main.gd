extends Node3D

@onready var player = $Player
@onready var health_bar: ProgressBar = $HUD/MarginContainer/PanelContainer/Margin/VBoxContainer/HealthBar
@onready var stamina_bar: ProgressBar = $HUD/MarginContainer/PanelContainer/Margin/VBoxContainer/StaminaBar
@onready var kill_label: Label = $HUD/MarginContainer/PanelContainer/Margin/VBoxContainer/KillLabel
@onready var status_label: Label = $HUD/MarginContainer/PanelContainer/Margin/VBoxContainer/TitleRow/StatusLabel

var kills: int = 0
var slime_scene = preload("res://scenes/slime.tscn")
var goblin_scene = preload("res://scenes/goblin.tscn")
var skeleton_scene = preload("res://scenes/skeleton.tscn")

var spawn_timer: float = 0.0
var spawn_interval: float = 5.5

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
		spawn_monster_around_player()

func _on_health_changed(curr: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = curr

func _on_stamina_changed(curr: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = curr
		
	if status_label and player:
		if player.is_exhausted:
			status_label.text = "⚡ EXHAUSTED!"
			status_label.modulate = Color(1.0, 0.35, 0.2)
		elif curr >= max_val * 0.95:
			status_label.text = "🛡️ RESTED"
			status_label.modulate = Color(0.5, 0.9, 0.6)
		else:
			status_label.text = ""

func on_enemy_killed() -> void:
	kills += 1
	update_kill_ui()

func update_kill_ui() -> void:
	if kill_label:
		kill_label.text = "⚔️ Kills: " + str(kills)

func spawn_monster_around_player() -> void:
	if player == null:
		return
	var existing = get_tree().get_nodes_in_group("enemies")
	if existing.size() >= 14:
		return
		
	var angle := randf() * TAU
	var dist := randf_range(14.0, 26.0)
	var spawn_pos = player.global_position + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
	
	# Weighted random: 40% Skeleton, 35% Goblin, 25% Slime
	var roll := randf()
	var monster_scene = skeleton_scene
	if roll < 0.25:
		monster_scene = slime_scene
	elif roll < 0.60:
		monster_scene = goblin_scene
	else:
		monster_scene = skeleton_scene
		
	var monster = monster_scene.instantiate()
	monster.global_position = spawn_pos
	add_child(monster)
