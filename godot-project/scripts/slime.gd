extends CharacterBody3D

signal died

@export var max_health: float = 60.0
var health: float = 60.0

@export var hop_force: float = 6.2
@export var move_speed: float = 4.0
@export var aggro_distance: float = 16.0

var player: CharacterBody3D = null
var hop_timer: float = 0.0
var hop_interval: float = 1.1
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)

@onready var visual_root: Node3D = $VisualRoot
@onready var model: Node3D = $VisualRoot/Model
@onready var death_particles: GPUParticles3D = $DeathParticles
var anim_player: AnimationPlayer = null

var flash_timer: float = 0.0
var floating_text_scene = preload("res://scenes/floating_text.tscn")
var is_dead: bool = false

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	hop_interval = randf_range(0.85, 1.3)
	
	if model != null:
		anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player != null and anim_player.has_animation("Slime_Idle"):
			anim_player.play("Slime_Idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta
		visual_root.scale = visual_root.scale.lerp(Vector3(0.85, 1.25, 0.85), 10.0 * delta)
	else:
		visual_root.scale = visual_root.scale.lerp(Vector3(1.15, 0.85, 1.15), 12.0 * delta)

	# AI Logic
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		
	if player != null:
		var dist := global_position.distance_to(player.global_position)
		if dist < aggro_distance:
			hop_timer += delta
			if hop_timer >= hop_interval and is_on_floor():
				hop_timer = 0.0
				var dir := (player.global_position - global_position).normalized()
				dir.y = 0.0
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				velocity.y = hop_force
				
				if anim_player != null and anim_player.has_animation("Slime_JumpLoop"):
					anim_player.play("Slime_JumpLoop")
				
				var target_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
				look_at(target_pos, Vector3.UP)
		else:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
				if anim_player != null and anim_player.has_animation("Slime_Idle"):
					anim_player.play("Slime_Idle")

	# Damage player on contact
	if is_on_floor() and player != null:
		if global_position.distance_to(player.global_position) < 1.4:
			var knock := (player.global_position - global_position).normalized() * 6.5
			player.receive_attack(14.0, knock, self)

	move_and_slide()

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, damage_type: String = "slashing") -> void:
	if is_dead:
		return
	var final_amount := amount
	var prefix := ""
	if damage_type == "slashing":
		final_amount *= 1.4 # Slimes slice easily
		prefix = "SLASH "
	elif damage_type == "blunt":
		knockback *= 1.6 # Slimes bounce away when hammered
		prefix = "BOUNCE "
		
	health -= final_amount
	velocity = knockback
	
	if prefix != "":
		spawn_text("%s%d" % [prefix, int(final_amount)], Color(0.9, 1.0, 0.4), 1.2)
	else:
		spawn_text(str(int(final_amount)), Color(0.9, 1.0, 0.4), 1.0)
	
	if health <= 0.0:
		die()

func spawn_text(txt: String, col: Color, sz: float) -> void:
	var ft = floating_text_scene.instantiate()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector3(0, 1.4, 0)
	ft.setup(txt, col, sz)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	
	visual_root.visible = false
	collision_layer = 0
	collision_mask = 0
	
	if death_particles != null:
		death_particles.emitting = true
		
	var main_node = get_tree().current_scene
	if main_node.has_method("on_enemy_killed"):
		main_node.on_enemy_killed()
		
	await get_tree().create_timer(0.6).timeout
	queue_free()
