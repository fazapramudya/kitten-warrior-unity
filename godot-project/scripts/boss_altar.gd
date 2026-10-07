extends Node3D

signal boss_summoned(boss_instance)

@export var trophies_required: int = 3
var is_player_nearby: bool = false
var is_boss_alive: bool = false
var player_ref: Node3D = null

var boss_scene = preload("res://scenes/boss_forest_beast.tscn")
var floating_text_scene = preload("res://scenes/floating_text.tscn")

@onready var prompt_label: Label3D = $PromptLabel
@onready var rune_light: OmniLight3D = $RuneLight
@onready var interact_area: Area3D = $InteractArea

var light_pulse_timer: float = 0.0

func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	update_prompt_ui()

func _process(delta: float) -> void:
	light_pulse_timer += delta * 2.5
	if rune_light != null:
		rune_light.light_energy = 2.0 + sin(light_pulse_timer) * 0.8
		
	if is_player_nearby and not is_boss_alive:
		if Input.is_key_pressed(KEY_E) or Input.is_action_just_pressed("interact"):
			try_summon_boss()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_nearby = true
		player_ref = body
		update_prompt_ui()
		if prompt_label != null:
			prompt_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body == player_ref:
		is_player_nearby = false
		player_ref = null
		if prompt_label != null:
			prompt_label.visible = false

func update_prompt_ui() -> void:
	if prompt_label == null:
		return
	if is_boss_alive:
		prompt_label.text = "⚔️ BOSS BATTLE IN PROGRESS!"
		prompt_label.modulate = Color(1.0, 0.3, 0.2)
		return
		
	var count := 0
	if player_ref != null and "trophies" in player_ref:
		count = player_ref.trophies
		
	if count >= trophies_required:
		prompt_label.text = "👑 TEKAN [E] PERSEMBAHKAN 3 TROPHY\n(Siap Memanggil Penjaga Rimba!)"
		prompt_label.modulate = Color(1.0, 0.85, 0.2)
	else:
		prompt_label.text = "🏛️ ALTAR PENJAGA RIMBA\nKumpulkan Trophy (%d/%d) untuk Ritual" % [count, trophies_required]
		prompt_label.modulate = Color(0.6, 0.85, 1.0)

func try_summon_boss() -> void:
	if is_boss_alive:
		return
		
	if player_ref == null or not ("trophies" in player_ref):
		return
		
	if player_ref.trophies < trophies_required:
		spawn_text("❌ BUTUH 3 TROPHY! Kalahkan Goblin/Skeleton.", Color(1.0, 0.4, 0.3), 1.2)
		return
		
	# Consume trophies
	player_ref.trophies -= trophies_required
	if player_ref.has_signal("trophies_changed"):
		player_ref.trophies_changed.emit(player_ref.trophies)
		
	is_boss_alive = true
	update_prompt_ui()
	
	spawn_text("⚡ RITUAL PEMANGGILAN DIMULAI!", Color(0.9, 0.4, 1.0), 2.2)
	
	# Thunder effect on rune light
	if rune_light != null:
		rune_light.light_color = Color(1.0, 0.2, 0.2)
		rune_light.light_energy = 8.0
		
	# Spawn Boss at center
	var boss = boss_scene.instantiate()
	get_parent().add_child(boss)
	boss.global_position = global_position + Vector3(0, 0.5, -4.0)
	boss.boss_defeated.connect(_on_boss_defeated)
	
	boss_summoned.emit(boss)
	
	var main_scene = get_tree().current_scene
	if main_scene != null and main_scene.has_method("activate_boss_encounter"):
		main_scene.activate_boss_encounter(boss)

func _on_boss_defeated() -> void:
	is_boss_alive = false
	if rune_light != null:
		rune_light.light_color = Color(0.2, 0.8, 1.0)
		rune_light.light_energy = 2.0
	update_prompt_ui()
	spawn_text("✨ RIMBA KEMBALI TENANG", Color(0.4, 1.0, 0.6), 1.6)

func spawn_text(txt: String, col: Color, sz: float) -> void:
	var ft = floating_text_scene.instantiate()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector3(0, 2.5, 0)
	ft.setup(txt, col, sz)
