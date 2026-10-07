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
var stagger_meter: float = 0.0
var max_stagger: float = 40.0
var is_staggered: bool = false
var stagger_timer: float = 0.0
var floating_text_scene = preload("res://scenes/floating_text.tscn")

var spawn_position: Vector3 = Vector3.ZERO
var patrol_target: Vector3 = Vector3.ZERO
var patrol_wait_timer: float = 0.0
var is_alerted: bool = false
var alert_timer: float = 0.0

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	spawn_position = global_position
	patrol_target = spawn_position
	
	if model != null:
		anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player != null and anim_player.has_animation("Idle"):
			anim_player.play("Idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if is_staggered:
		stagger_timer -= delta
		if stagger_timer <= 0.0:
			is_staggered = false
			stagger_meter = 0.0
		return

	if stagger_meter > 0.0 and not is_staggered:
		stagger_meter = max(0.0, stagger_meter - delta * 8.0)
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if alert_timer > 0.0:
		alert_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return

	if player != null and not is_attacking:
		var dist := global_position.distance_to(player.global_position)
		if dist < aggro_distance:
			if not is_alerted:
				# First detection alert!
				is_alerted = true
				alert_timer = 0.6
				spawn_text("❗", Color(1.0, 0.3, 0.2), 1.5)
				if anim_player != null and anim_player.has_animation("Taunt"):
					anim_player.play("Taunt", 0.15)
				return
				
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
				# Approach player with running animation
				var dir := (player.global_position - global_position).normalized()
				dir.y = 0.0
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				
				if anim_player != null and anim_player.current_animation != "Running_A":
					anim_player.play("Running_A", 0.2)
		else:
			is_alerted = false
			# Natural patrol loop around spawn position
			patrol_wait_timer -= delta
			var dist_to_patrol = global_position.distance_to(patrol_target)
			
			if patrol_wait_timer <= 0.0:
				if dist_to_patrol < 1.0:
					# Pick new patrol spot within 6 meters of spawn
					var angle = randf() * TAU
					var r = randf_range(2.0, 7.0)
					patrol_target = spawn_position + Vector3(cos(angle) * r, 0, sin(angle) * r)
					patrol_wait_timer = randf_range(2.5, 5.0)
					if anim_player != null and anim_player.has_animation("Idle"):
						anim_player.play("Idle", 0.3)
				else:
					# Walk towards patrol target
					var p_dir = (patrol_target - global_position).normalized()
					p_dir.y = 0.0
					velocity.x = p_dir.x * (move_speed * 0.45)
					velocity.z = p_dir.z * (move_speed * 0.45)
					var p_rot_y = atan2(p_dir.x, p_dir.z)
					visual_root.rotation.y = lerp_angle(visual_root.rotation.y, p_rot_y, 4.0 * delta)
					if anim_player != null and anim_player.has_animation("Walking_D_Skeletons"):
						anim_player.play("Walking_D_Skeletons", 0.25)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
				if anim_player != null and anim_player.current_animation != "Idle":
					anim_player.play("Idle", 0.3)

	move_and_slide()

func perform_attack() -> void:
	is_attacking = true
	attack_cooldown = 2.0
	
	# Telegraph warning icon
	spawn_text("⚔️", Color(1.0, 0.4, 0.2), 1.2)
	if anim_player != null:
		if randf() > 0.5 and anim_player.has_animation("1H_Melee_Attack_Chop"):
			anim_player.play("1H_Melee_Attack_Chop", 0.15, 0.9)
		elif anim_player.has_animation("1H_Melee_Attack_Slice_Horizontal"):
			anim_player.play("1H_Melee_Attack_Slice_Horizontal", 0.15, 0.9)
			
	# Windup delay before dealing damage (readable telegraph for player dodge/parry!)
	await get_tree().create_timer(0.42).timeout
	if is_dead or is_staggered:
		is_attacking = false
		return
		
	if player != null and global_position.distance_to(player.global_position) <= attack_range + 0.9:
		var knock := (player.global_position - global_position).normalized() * 8.5
		player.receive_attack(attack_damage, knock, self)
		
	# Attack recovery window
	await get_tree().create_timer(0.45).timeout
	is_attacking = false

func apply_parry_stagger(amount: float) -> void:
	if is_dead:
		return
	stagger_meter += amount
	if stagger_meter >= max_stagger or not is_staggered:
		trigger_stagger()

func trigger_stagger() -> void:
	is_staggered = true
	stagger_timer = 2.2
	is_attacking = false
	velocity = -transform.basis.z * 5.0
	spawn_text("⚡ STAGGERED! (2x CRIT)", Color(1.0, 0.9, 0.2), 1.5)
	if anim_player != null and anim_player.has_animation("Hit_A"):
		anim_player.play("Hit_A")

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, damage_type: String = "slashing") -> void:
	if is_dead:
		return
		
	var final_dmg := amount
	var type_text := ""
	
	if damage_type == "blunt":
		final_dmg *= 1.75 # Skeletons are weak to blunt crushing damage!
		stagger_meter += amount * 0.95
		type_text = "🔨 CRUSH "
	elif damage_type == "piercing":
		final_dmg *= 0.75 # Skeletons resist piercing
		type_text = "RESIST "
	else:
		stagger_meter += amount * 0.45
		
	if is_staggered:
		final_dmg *= 2.0 # Valheim 2x Critical Damage window!
		spawn_text("⚡ CRIT %d!" % int(final_dmg), Color(1.0, 0.3, 0.1), 1.6)
	else:
		if stagger_meter >= max_stagger:
			trigger_stagger()
		if type_text != "":
			spawn_text("%s%d" % [type_text, int(final_dmg)], Color(1.0, 0.75, 0.2), 1.3)
		else:
			spawn_text(str(int(final_dmg)), Color(1.0, 0.85, 0.3), 1.1)
		
	health -= final_dmg
	velocity = knockback
	
	# Flinch scale punch
	var orig_scale = visual_root.scale
	visual_root.scale = orig_scale * Vector3(1.15, 0.85, 1.15)
	var tw = create_tween()
	tw.tween_property(visual_root, "scale", orig_scale, 0.16)
	
	if anim_player != null and not is_attacking and anim_player.has_animation("Hit_A"):
		anim_player.play("Hit_A", 0.08)
		
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
	velocity = Vector3.ZERO
	spawn_text("💀 DEFEATED", Color(0.9, 0.85, 0.7), 1.4)
	
	if anim_player != null:
		if anim_player.has_animation("Death_C_Skeletons"):
			anim_player.play("Death_C_Skeletons", 0.1)
		elif anim_player.has_animation("Death_A"):
			anim_player.play("Death_A", 0.1)
			
	var main_node = get_tree().current_scene
	if main_node.has_method("on_enemy_killed"):
		main_node.on_enemy_killed()
	if player != null and player.has_method("add_trophy"):
		player.add_trophy(1)
		
	await get_tree().create_timer(2.0).timeout
	queue_free()
