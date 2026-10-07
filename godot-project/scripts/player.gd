extends CharacterBody3D

signal stamina_changed(current_stamina: float, max_stamina: float)
signal health_changed(current_health: float, max_health: float)
signal combat_event(event_name: String)

@export var walk_speed: float = 4.8
@export var sprint_speed: float = 8.6
@export var roll_speed: float = 12.0
@export var exhausted_speed: float = 2.4
@export var jump_velocity: float = 6.8
@export var rotation_speed: float = 14.0

@export var max_health: float = 100.0
var health: float = 100.0

# Valheim Stamina System
@export var max_stamina: float = 100.0
var stamina: float = 100.0
@export var sprint_cost_per_sec: float = 16.0
@export var jump_stamina_cost: float = 10.0
@export var roll_stamina_cost: float = 16.0
@export var attack_stamina_cost: float = 12.0
@export var stamina_regen_rate: float = 24.0
@export var stamina_regen_delay: float = 1.0

var regen_timer: float = 0.0
var is_exhausted: bool = false

# Camera & Mouse Look
@export var mouse_sensitivity: float = 0.003
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var visual_root: Node3D = $VisualRoot
@onready var sword_pivot: Node3D = $VisualRoot/SwordPivot
@onready var shield_pivot: Node3D = $VisualRoot/ShieldPivot
@onready var cape_node: Node3D = $VisualRoot/Cape
@onready var attack_area: Area3D = $VisualRoot/AttackArea

# Combat state
var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_duration: float = 0.32
var combo_step: int = 0
var combo_reset_timer: float = 0.0

var is_blocking: bool = false
var parry_timer: float = 0.0
var parry_window: float = 0.25

var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_duration: float = 0.42
var roll_direction: Vector3 = Vector3.FORWARD
var is_invincible: bool = false

var camera_shake_trauma: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)

var floating_text_scene = preload("res://scenes/floating_text.tscn")

func _ready() -> void:
	health = max_health
	stamina = max_stamina
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stamina_changed.emit(stamina, max_stamina)
	health_changed.emit(health, max_health)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-65.0), deg_to_rad(45.0))
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
			
		if event.button_index == MOUSE_BUTTON_LEFT:
			try_attack()

func _physics_process(delta: float) -> void:
	handle_stamina(delta)
	handle_combat(delta)
	handle_camera_shake(delta)
	
	# Block State (Right Click)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not is_rolling and not is_attacking:
		if not is_blocking:
			is_blocking = true
			parry_timer = parry_window
			shield_pivot.position = Vector3(0.0, 0.5, 0.45) # raise shield
			shield_pivot.rotation.y = deg_to_rad(90.0)
	else:
		if is_blocking:
			is_blocking = false
			shield_pivot.position = Vector3(-0.45, 0.5, 0.05) # lower shield
			shield_pivot.rotation.y = 0.0

	if parry_timer > 0.0:
		parry_timer -= delta

	# Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Movement Input
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("move_forward"): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("move_backward"): input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"): input_dir.x += 1
	input_dir = input_dir.normalized()

	# Direction relative to camera orbit
	var cam_forward: Vector3 = -camera_pivot.global_transform.basis.z
	var cam_right: Vector3 = camera_pivot.global_transform.basis.x
	cam_forward.y = 0.0
	cam_right.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	
	var move_dir := (cam_forward * -input_dir.y + cam_right * input_dir.x).normalized()

	# Dodge Roll (Space or Q while moving or Shift+Space)
	if (Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_Q)) \
		and is_on_floor() and not is_rolling and not is_exhausted and stamina >= roll_stamina_cost and move_dir.length() > 0.1:
		start_roll(move_dir)
		consume_stamina(roll_stamina_cost)

	# Handle Dodge Roll State
	if is_rolling:
		roll_timer -= delta
		velocity.x = roll_direction.x * roll_speed
		velocity.z = roll_direction.z * roll_speed
		# Roll 360 spin
		var roll_progress := 1.0 - (roll_timer / roll_duration)
		visual_root.rotation.x = roll_progress * TAU
		if roll_timer <= 0.0:
			is_rolling = false
			is_invincible = false
			visual_root.rotation.x = 0.0
		move_and_slide()
		return

	# Determine Speed
	var target_speed := walk_speed
	var wants_sprint: bool = (Input.is_key_pressed(KEY_SHIFT) or Input.is_action_pressed("sprint")) and input_dir.length_squared() > 0.0
	
	if is_blocking:
		target_speed = walk_speed * 0.5
	elif is_exhausted:
		target_speed = exhausted_speed
	elif wants_sprint and stamina > 0.0:
		target_speed = sprint_speed
		consume_stamina(sprint_cost_per_sec * delta)
	else:
		target_speed = walk_speed

	# Apply horizontal velocity
	if move_dir.length() > 0.0:
		velocity.x = move_dir.x * target_speed
		velocity.z = move_dir.z * target_speed
		
		# Rotate visual model smoothly toward movement direction
		var target_rot_y := atan2(move_dir.x, move_dir.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rot_y, rotation_speed * delta)
		
		# Procedural cat running bobbing
		visual_root.position.y = abs(sin(Time.get_ticks_msec() * 0.013)) * 0.12
		
		# Cape sway
		if cape_node != null:
			cape_node.rotation.x = deg_to_rad(-25.0) - (velocity.length() / sprint_speed) * 0.4
	else:
		velocity.x = move_toward(velocity.x, 0.0, target_speed * 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, target_speed * 12.0 * delta)
		visual_root.position.y = move_toward(visual_root.position.y, 0.0, delta * 2.0)
		if cape_node != null:
			cape_node.rotation.x = move_toward(cape_node.rotation.x, deg_to_rad(-8.0), delta * 2.0)

	move_and_slide()

func start_roll(dir: Vector3) -> void:
	is_rolling = true
	is_invincible = true
	roll_timer = roll_duration
	roll_direction = dir
	visual_root.rotation.y = atan2(dir.x, dir.z)
	spawn_text("ROLL", Color(0.6, 0.8, 1.0), 0.9)

func consume_stamina(amount: float) -> void:
	stamina = max(0.0, stamina - amount)
	regen_timer = stamina_regen_delay
	if stamina <= 0.0:
		is_exhausted = true
		spawn_text("EXHAUSTED!", Color(1.0, 0.4, 0.2), 1.2)
	stamina_changed.emit(stamina, max_stamina)

func handle_stamina(delta: float) -> void:
	if regen_timer > 0.0:
		regen_timer -= delta
	else:
		if stamina < max_stamina:
			stamina = min(max_stamina, stamina + stamina_regen_rate * delta)
			stamina_changed.emit(stamina, max_stamina)
			if is_exhausted and stamina >= 22.0:
				is_exhausted = false

func try_attack() -> void:
	if is_attacking or is_rolling or is_exhausted or stamina < attack_stamina_cost:
		return
		
	is_attacking = true
	attack_timer = attack_duration
	consume_stamina(attack_stamina_cost)
	
	combo_step = (combo_step % 3) + 1
	combo_reset_timer = 0.85
	
	var damage := 26.0
	var knock_force := 9.0
	if combo_step == 2:
		damage = 34.0
		knock_force = 11.0
	elif combo_step == 3:
		damage = 52.0
		knock_force = 18.0
		add_camera_shake(0.35)
	
	# Detect hit targets in attack area
	var hit_count := 0
	for body in attack_area.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			var knockback_dir := (body.global_position - global_position).normalized()
			knockback_dir.y = 0.35
			body.take_damage(damage, knockback_dir * knock_force)
			hit_count += 1
			
	if hit_count > 0:
		add_camera_shake(0.18)

func handle_combat(delta: float) -> void:
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_step = 0

	if is_attacking:
		attack_timer -= delta
		var progress := 1.0 - (attack_timer / attack_duration)
		if combo_step == 1:
			sword_pivot.rotation.y = sin(progress * PI) * 2.4
			sword_pivot.rotation.x = -sin(progress * PI) * 0.8
		elif combo_step == 2:
			sword_pivot.rotation.y = -sin(progress * PI) * 2.4
			sword_pivot.rotation.x = -sin(progress * PI) * 0.8
		else:
			# Overhead slash
			sword_pivot.rotation.x = -sin(progress * PI) * 2.6
			sword_pivot.rotation.y = 0.0
			
		if attack_timer <= 0.0:
			is_attacking = false
			sword_pivot.rotation = Vector3.ZERO

func receive_attack(amount: float, knockback: Vector3, attacker: Node3D) -> String:
	if is_invincible:
		spawn_text("DODGED", Color(0.4, 0.8, 1.0), 1.1)
		return "DODGED"
		
	if is_blocking:
		if parry_timer > 0.0:
			# PERFECT PARRY!
			spawn_text("🛡️ PARRY!", Color(1.0, 0.85, 0.2), 1.6)
			add_camera_shake(0.4)
			return "PARRIED"
		else:
			# Normal Block
			var blocked_dmg := amount * 0.25
			health = max(0.0, health - blocked_dmg)
			health_changed.emit(health, max_health)
			consume_stamina(14.0)
			velocity += knockback * 0.35
			spawn_text("BLOCKED " + str(int(amount - blocked_dmg)), Color(0.7, 0.8, 0.9), 1.0)
			return "BLOCKED"

	# Full Hit
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	velocity += knockback
	add_camera_shake(0.5)
	spawn_text("-" + str(int(amount)), Color(1.0, 0.2, 0.2), 1.2)
	
	if health <= 0.0:
		# Respawn
		global_position = Vector3(0, 2, 0)
		health = max_health
		stamina = max_stamina
		health_changed.emit(health, max_health)
		stamina_changed.emit(stamina, max_stamina)
		spawn_text("REVIVED", Color(1.0, 0.9, 0.4), 1.5)
		
	return "HIT"

func add_camera_shake(amount: float) -> void:
	camera_shake_trauma = min(1.0, camera_shake_trauma + amount)

func handle_camera_shake(delta: float) -> void:
	if camera_shake_trauma > 0.0:
		camera_shake_trauma = move_toward(camera_shake_trauma, 0.0, delta * 2.2)
		var shake := camera_shake_trauma * camera_shake_trauma * 0.15
		camera.h_offset = randf_range(-shake, shake)
		camera.v_offset = randf_range(-shake, shake)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func spawn_text(txt: String, col: Color, sz: float) -> void:
	var ft = floating_text_scene.instantiate()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector3(0, 1.8, 0)
	ft.setup(txt, col, sz)
