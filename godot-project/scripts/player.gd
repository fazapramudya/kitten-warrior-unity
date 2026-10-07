extends CharacterBody3D

signal stamina_changed(current_stamina: float, max_stamina: float)
signal health_changed(current_health: float, max_health: float)

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var exhausted_speed: float = 2.5
@export var jump_velocity: float = 7.0
@export var rotation_speed: float = 12.0

@export var max_health: float = 100.0
var health: float = 100.0

# Valheim Stamina System
@export var max_stamina: float = 100.0
var stamina: float = 100.0
@export var sprint_cost_per_sec: float = 18.0
@export var jump_stamina_cost: float = 12.0
@export var attack_stamina_cost: float = 15.0
@export var stamina_regen_rate: float = 22.0
@export var stamina_regen_delay: float = 1.0

var regen_timer: float = 0.0
var is_exhausted: bool = false

# Camera & Mouse Look
@export var mouse_sensitivity: float = 0.003
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var visual_root: Node3D = $VisualRoot
@onready var sword_pivot: Node3D = $VisualRoot/SwordPivot
@onready var attack_area: Area3D = $VisualRoot/AttackArea

# Combat state
var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_duration: float = 0.35

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)

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
			
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			try_attack()

func _physics_process(delta: float) -> void:
	handle_stamina(delta)
	handle_combat(delta)
	
	# Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_exhausted and stamina >= jump_stamina_cost:
		velocity.y = jump_velocity
		consume_stamina(jump_stamina_cost)

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

	# Determine Speed based on Sprint / Stamina
	var target_speed := walk_speed
	var wants_sprint: bool = (Input.is_key_pressed(KEY_SHIFT) or Input.is_action_pressed("sprint")) and input_dir.length_squared() > 0.0
	
	if is_exhausted:
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
		visual_root.position.y = abs(sin(Time.get_ticks_msec() * 0.012)) * 0.12
	else:
		velocity.x = move_toward(velocity.x, 0.0, target_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, target_speed * 10.0 * delta)
		visual_root.position.y = move_toward(visual_root.position.y, 0.0, delta * 2.0)

	move_and_slide()

func consume_stamina(amount: float) -> void:
	stamina = max(0.0, stamina - amount)
	regen_timer = stamina_regen_delay
	if stamina <= 0.0:
		is_exhausted = true
	stamina_changed.emit(stamina, max_stamina)

func handle_stamina(delta: float) -> void:
	if regen_timer > 0.0:
		regen_timer -= delta
	else:
		if stamina < max_stamina:
			stamina = min(max_stamina, stamina + stamina_regen_rate * delta)
			stamina_changed.emit(stamina, max_stamina)
			if is_exhausted and stamina >= 20.0:
				is_exhausted = false

func try_attack() -> void:
	if is_attacking or is_exhausted or stamina < attack_stamina_cost:
		return
		
	is_attacking = true
	attack_timer = attack_duration
	consume_stamina(attack_stamina_cost)
	
	# Detect hit targets in attack area
	var hit_count := 0
	for body in attack_area.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			var knockback_dir := (body.global_position - global_position).normalized()
			knockback_dir.y = 0.35
			body.take_damage(35.0, knockback_dir * 10.0)
			hit_count += 1

func handle_combat(delta: float) -> void:
	if is_attacking:
		attack_timer -= delta
		# Procedural sword slash rotation
		var progress := 1.0 - (attack_timer / attack_duration)
		sword_pivot.rotation.y = sin(progress * PI) * 2.2
		sword_pivot.rotation.x = -sin(progress * PI) * 1.0
		if attack_timer <= 0.0:
			is_attacking = false
			sword_pivot.rotation = Vector3.ZERO

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	velocity += knockback
	if health <= 0.0:
		# Respawn at center
		global_position = Vector3(0, 2, 0)
		health = max_health
		stamina = max_stamina
		health_changed.emit(health, max_health)
		stamina_changed.emit(stamina, max_stamina)
