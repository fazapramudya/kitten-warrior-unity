extends CharacterBody3D

signal died

@export var max_health: float = 90.0
var health: float = 90.0

@export var move_speed: float = 3.6
@export var attack_range: float = 2.0
@export var aggro_distance: float = 18.0
@export var attack_damage: float = 22.0

var player: CharacterBody3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)

@onready var visual_root: Node3D = $VisualRoot
@onready var model: Node3D = $VisualRoot/SkeletonModel
@onready var attack_area: Area3D = $VisualRoot/AttackArea
var anim_player: AnimationPlayer = null

var is_dead: bool = false
var is_attacking: bool = false
var attack_cooldown: float = 0.0
var floating_text_scene = preload("res://scenes/floating_text.tscn")

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	
	if model != null:
		anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player != null and anim_player.has_animation("Idle_Combat"):
			anim_player.play("Idle_Combat")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player != null and not is_attacking:
		var dist := global_position.distance_to(player.global_position)
		if dist < aggro_distance:
			# Look towards player smoothly
			var target_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
			var look_dir = (target_pos - global_position).normalized()
			if look_dir.length() > 0.1:
				var target_rot_y = atan2(look_dir.x, look_dir.z)
				visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rot_y, 8.0 * delta)
			
			if dist <= attack_range:
				velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
				if attack_cooldown <= 0.0:
					perform_attack()
			else:
				# Approach player
				var dir := (player.global_position - global_position).normalized()
				dir.y = 0.0
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				
				if anim_player != null and anim_player.current_animation != "Running_A":
					anim_player.play("Running_A")
		else:
			# Idle
			velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
			if anim_player != null and anim_player.current_animation != "Idle_Combat":
				anim_player.play("Idle_Combat")

	move_and_slide()

func perform_attack() -> void:
	is_attacking = true
	attack_cooldown = 1.8
	
	if anim_player != null:
		if randf() > 0.5 and anim_player.has_animation("1H_Melee_Attack_Chop"):
			anim_player.play("1H_Melee_Attack_Chop")
		elif anim_player.has_animation("1H_Melee_Attack_Slice_Horizontal"):
			anim_player.play("1H_Melee_Attack_Slice_Horizontal")
			
	# Windup delay before dealing damage
	await get_tree().create_timer(0.4).timeout
	if is_dead:
		return
		
	if player != null and global_position.distance_to(player.global_position) <= attack_range + 0.8:
		var knock := (player.global_position - global_position).normalized() * 7.5
		player.receive_attack(attack_damage, knock, self)
		
	await get_tree().create_timer(0.5).timeout
	is_attacking = false

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
		
	health -= amount
	velocity = knockback
	spawn_text(str(int(amount)), Color(1.0, 0.85, 0.3), 1.1)
	
	if anim_player != null and not is_attacking and anim_player.has_animation("Hit_A"):
		anim_player.play("Hit_A")
		
	if health <= 0.0:
		die()

func spawn_text(txt: String, col: Color, sz: float) -> void:
	var ft = floating_text_scene.instantiate()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector3(0, 1.8, 0)
	ft.setup(txt, col, sz)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	
	collision_layer = 0
	collision_mask = 0
	
	if anim_player != null:
		if anim_player.has_animation("Death_C_Skeletons"):
			anim_player.play("Death_C_Skeletons")
		elif anim_player.has_animation("Death_A"):
			anim_player.play("Death_A")
			
	var main_node = get_tree().current_scene
	if main_node.has_method("on_enemy_killed"):
		main_node.on_enemy_killed()
		
	await get_tree().create_timer(1.8).timeout
	queue_free()
