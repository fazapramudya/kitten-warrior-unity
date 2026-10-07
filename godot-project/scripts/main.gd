extends Node3D

@onready var player = $Player
@onready var health_bar: ProgressBar = $HUD/MarginContainer/PanelContainer/Margin/VBoxContainer/HealthBar
@onready var stamina_bar: ProgressBar = $HUD/MarginContainer/PanelContainer/Margin/VBoxContainer/StaminaBar
@onready var kill_label: Label = $HUD/MarginContainer/PanelContainer/Margin/VBoxContainer/KillLabel
@onready var status_label: Label = $HUD/MarginContainer/PanelContainer/Margin/VBoxContainer/TitleRow/StatusLabel
@onready var sun_light: DirectionalLight3D = $SunLight

var kills: int = 0
var slime_scene = preload("res://scenes/slime.tscn")
var goblin_scene = preload("res://scenes/goblin.tscn")
var skeleton_scene = preload("res://scenes/skeleton.tscn")

var spawn_timer: float = 0.0
var spawn_interval: float = 5.5

# Valheim Day/Night System
var day_cycle_time: float = 0.0
var day_cycle_length: float = 180.0 # 3 minutes full cycle
var is_night: bool = false

func _ready() -> void:
	if player:
		player.health_changed.connect(_on_health_changed)
		player.stamina_changed.connect(_on_stamina_changed)
		_on_health_changed(player.health, player.max_health)
		_on_stamina_changed(player.stamina, player.max_stamina)
	update_kill_ui()

func _process(delta: float) -> void:
	day_cycle_time += delta
	if day_cycle_time >= day_cycle_length:
		day_cycle_time = 0.0
		
	handle_day_night_cycle(delta)
	handle_player_environment_states()
	
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_monster_around_player()

func handle_day_night_cycle(delta: float) -> void:
	var progress := day_cycle_time / day_cycle_length # 0.0 -> 1.0
	var angle := progress * TAU - PI * 0.5
	
	if sun_light:
		sun_light.rotation.x = angle
		# Sun color transition
		if progress < 0.2: # Dawn
			sun_light.light_color = Color(1.0, 0.65, 0.35)
			sun_light.light_energy = 1.4
			is_night = false
		elif progress < 0.65: # Full Day
			sun_light.light_color = Color(1.0, 0.88, 0.72)
			sun_light.light_energy = 1.85
			is_night = false
		elif progress < 0.75: # Dusk
			sun_light.light_color = Color(0.98, 0.48, 0.22)
			sun_light.light_energy = 1.2
			is_night = false
		else: # Night
			sun_light.light_color = Color(0.28, 0.38, 0.65)
			sun_light.light_energy = 0.4
			is_night = true

func handle_player_environment_states() -> void:
	if player == null:
		return
		
	# Check campfire proximity (Campsite is located near (0, 0, 0))
	var dist_to_fire = player.global_position.distance_to(Vector3(0, 0, 0))
	player.is_near_fire = (dist_to_fire <= 10.0)
	player.is_cold = (is_night and not player.is_near_fire)
	
	if status_label:
		if player.is_exhausted:
			status_label.text = "⚡ EXHAUSTED!"
			status_label.modulate = Color(1.0, 0.35, 0.2)
		elif player.is_near_fire:
			status_label.text = "🔥 RESTED (+100% Stam)"
			status_label.modulate = Color(1.0, 0.85, 0.3)
		elif player.is_cold:
			status_label.text = "❄️ COLD (-45% Stam)"
			status_label.modulate = Color(0.4, 0.75, 1.0)
		elif player.stamina >= player.max_stamina * 0.95:
			status_label.text = "🛡️ READY"
			status_label.modulate = Color(0.5, 0.9, 0.6)
		else:
			status_label.text = ""

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
	
	# Weighted random: Day vs Night
	var roll := randf()
	var monster_scene = skeleton_scene
	if is_night:
		# Night spawns are dangerous! 75% Skeletons, 20% Goblins, 5% Slimes
		if roll < 0.05:
			monster_scene = slime_scene
		elif roll < 0.25:
			monster_scene = goblin_scene
		else:
			monster_scene = skeleton_scene
	else:
		# Day spawns: 40% Skeletons, 35% Goblins, 25% Slimes
		if roll < 0.25:
			monster_scene = slime_scene
		elif roll < 0.60:
			monster_scene = goblin_scene
		else:
			monster_scene = skeleton_scene
		
	var monster = monster_scene.instantiate()
	monster.global_position = spawn_pos
	add_child(monster)
