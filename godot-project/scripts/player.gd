extends CharacterBody3D

signal stamina_changed(current_stamina: float, max_stamina: float)
signal health_changed(current_health: float, max_health: float)
signal combat_event(event_name: String)

@export var walk_speed: float = 4.8
@export var sprint_speed: float = 8.6
@export var roll_speed: float = 12.0
@export var exhausted_speed: float = 2.4
@export var jump_velocity: float = 6.8
@export var rotation_speed: float = 12.0
@export var walk_accel: float = 16.0
@export var sprint_accel: float = 22.0
@export var ground_friction: float = 26.0
@export var air_control: float = 4.5

# Cinematic Third-Person Camera
@export var base_fov: float = 70.0
@export var sprint_fov: float = 76.0
@export var bow_fov: float = 52.0
@export var camera_shoulder_offset: float = 0.32
var current_camera_roll: float = 0.0

@export var max_health: float = 100.0
var health: float = 100.0

# Valheim Stamina System
@export var max_stamina: float = 100.0
var stamina: float = 100.0
var base_max_health: float = 80.0
var base_max_stamina: float = 80.0
var active_foods: Array = [] # Array of Dictionary {name, hp, stamina, time_left}
var is_near_fire: bool = false
var is_cold: bool = false
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
@onready var knight_model: Node3D = $VisualRoot/KnightModel
@onready var attack_area: Area3D = $VisualRoot/AttackArea
var anim_player: AnimationPlayer = null

# Combat state
enum WeaponType { SWORD_SHIELD, SPEAR, CLUB, BOW }
var current_weapon: WeaponType = WeaponType.SWORD_SHIELD
signal weapon_changed(new_weapon_name: String, damage_type: String)
signal trophies_changed(count: int)
var trophies: int = 0

var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_duration: float = 0.45
var combo_step: int = 0
var combo_reset_timer: float = 0.0

var is_charging_heavy: bool = false
var charge_timer: float = 0.0
var max_charge_time: float = 0.38
var heavy_attack_cost: float = 28.0
var spear_mesh_instance: Node3D = null
var bow_mesh_instance: Node3D = null
var arrow_scene = preload("res://scenes/arrow.tscn")
var is_aiming_bow: bool = false
var bow_draw_timer: float = 0.0

# Audio & VFX Assets
var sfx_swing = preload("res://assets/audio/sword_swing.wav")
var sfx_impact = preload("res://assets/audio/sword_impact.wav")
var sfx_blunt = preload("res://assets/audio/blunt_impact.wav")
var sfx_block = preload("res://assets/audio/shield_block.wav")
var sfx_parry = preload("res://assets/audio/parry_chime.wav")
var sfx_dodge = preload("res://assets/audio/dodge_roll.wav")
var sfx_bow = preload("res://assets/audio/bow_shoot.wav")
var sfx_step = preload("res://assets/audio/footstep_grass.wav")
var hit_sparks_scene = preload("res://scenes/vfx/hit_sparks.tscn")
var dust_puff_scene = preload("res://scenes/vfx/dust_puff.tscn")

# Procedural Idle Alive & Cat Dynamics
@onready var ear_l: MeshInstance3D = $VisualRoot/CatFeatures/EarL
@onready var ear_r: MeshInstance3D = $VisualRoot/CatFeatures/EarR
@onready var tail: MeshInstance3D = $VisualRoot/CatFeatures/Tail
var idle_alive_timer: float = 0.0
var step_audio_timer: float = 0.0

# Combat Attack Pipeline (Anticipation -> Active -> Recovery)
enum CombatStage { READY, WINDUP, ACTIVE, RECOVERY }
var combat_stage: CombatStage = CombatStage.READY
var combat_stage_timer: float = 0.0
var current_attack_dmg: float = 0.0
var current_attack_knock: float = 0.0
var current_attack_type: String = "slashing"
var attack_hit_registered: bool = false

var is_blocking: bool = false
var parry_timer: float = 0.0
var parry_window: float = 0.25

var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_duration: float = 0.45
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
	
	setup_knight_model()

func setup_knight_model() -> void:
	if knight_model == null:
		return
		
	# Find AnimationPlayer
	anim_player = knight_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player != null:
		anim_player.play("Idle")
		
	# Build procedural Flint Spear on handslot.r
	var handslot_r = knight_model.find_child("handslot.r", true, false)
	if handslot_r != null and spear_mesh_instance == null:
		spear_mesh_instance = Node3D.new()
		spear_mesh_instance.name = "Flint_Spear"
		var shaft = MeshInstance3D.new()
		var shaft_mesh = CylinderMesh.new()
		shaft_mesh.top_radius = 0.03
		shaft_mesh.bottom_radius = 0.03
		shaft_mesh.height = 1.9
		var wood_mat = StandardMaterial3D.new()
		wood_mat.albedo_color = Color(0.48, 0.32, 0.18)
		shaft.mesh = shaft_mesh
		shaft.material_override = wood_mat
		shaft.position = Vector3(0, 0.5, 0)
		spear_mesh_instance.add_child(shaft)
		
		var tip = MeshInstance3D.new()
		var tip_mesh = CylinderMesh.new()
		tip_mesh.top_radius = 0.005
		tip_mesh.bottom_radius = 0.07
		tip_mesh.height = 0.35
		var flint_mat = StandardMaterial3D.new()
		flint_mat.albedo_color = Color(0.28, 0.38, 0.44)
		flint_mat.metallic = 0.5
		tip.mesh = tip_mesh
		tip.material_override = flint_mat
		tip.position = Vector3(0, 1.55, 0)
		spear_mesh_instance.add_child(tip)
		
		handslot_r.add_child(spear_mesh_instance)
		spear_mesh_instance.visible = false
		
	# Build procedural Finewood Bow on handslot.l
	var handslot_l = knight_model.find_child("handslot.l", true, false)
	if handslot_l != null and bow_mesh_instance == null:
		bow_mesh_instance = Node3D.new()
		bow_mesh_instance.name = "Finewood_Bow"
		var bow_body = MeshInstance3D.new()
		var bow_mesh = TorusMesh.new()
		bow_mesh.inner_radius = 0.55
		bow_mesh.outer_radius = 0.62
		var bow_mat = StandardMaterial3D.new()
		bow_mat.albedo_color = Color(0.65, 0.45, 0.25)
		bow_body.mesh = bow_mesh
		bow_body.material_override = bow_mat
		bow_body.rotation.y = deg_to_rad(90)
		bow_body.scale = Vector3(0.5, 1.0, 0.5)
		bow_mesh_instance.add_child(bow_body)
		
		# Bow string
		var string_mesh_inst = MeshInstance3D.new()
		var s_mesh = CylinderMesh.new()
		s_mesh.top_radius = 0.005
		s_mesh.bottom_radius = 0.005
		s_mesh.height = 1.1
		var str_mat = StandardMaterial3D.new()
		str_mat.albedo_color = Color(0.95, 0.95, 0.95)
		string_mesh_inst.mesh = s_mesh
		string_mesh_inst.material_override = str_mat
		bow_mesh_instance.add_child(string_mesh_inst)
		
		handslot_l.add_child(bow_mesh_instance)
		bow_mesh_instance.visible = false
		
	switch_weapon(WeaponType.SWORD_SHIELD)

func switch_weapon(type: WeaponType) -> void:
	if is_attacking or is_rolling:
		return
	current_weapon = type
	is_aiming_bow = false
	bow_draw_timer = 0.0
	
	if knight_model == null:
		return
		
	var sword = knight_model.find_child("1H_Sword", true, false)
	var shield = knight_model.find_child("Round_Shield", true, false)
	var two_h = knight_model.find_child("2H_Sword", true, false)
	var weapons_to_hide = ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield"]
	for w in weapons_to_hide:
		var n = knight_model.find_child(w, true, false)
		if n != null: n.visible = false
		
	match current_weapon:
		WeaponType.SWORD_SHIELD:
			if sword: sword.visible = true
			if shield: shield.visible = true
			if two_h: two_h.visible = false
			if spear_mesh_instance: spear_mesh_instance.visible = false
			if bow_mesh_instance: bow_mesh_instance.visible = false
			spawn_text("⚔️ SWORD & SHIELD (Slashing)", Color(0.9, 0.9, 1.0), 1.2)
			weapon_changed.emit("Sword & Shield", "Slashing")
		WeaponType.SPEAR:
			if sword: sword.visible = false
			if shield: shield.visible = false
			if two_h: two_h.visible = false
			if spear_mesh_instance: spear_mesh_instance.visible = true
			if bow_mesh_instance: bow_mesh_instance.visible = false
			spawn_text("🗡️ FLINT SPEAR (Piercing)", Color(0.3, 0.9, 1.0), 1.2)
			weapon_changed.emit("Flint Spear", "Piercing")
		WeaponType.CLUB:
			if sword: sword.visible = false
			if shield: shield.visible = false
			if two_h: two_h.visible = true
			if spear_mesh_instance: spear_mesh_instance.visible = false
			if bow_mesh_instance: bow_mesh_instance.visible = false
			spawn_text("🔨 WAR CLUB (Blunt)", Color(1.0, 0.75, 0.2), 1.2)
			weapon_changed.emit("War Club", "Blunt")
		WeaponType.BOW:
			if sword: sword.visible = false
			if shield: shield.visible = false
			if two_h: two_h.visible = false
			if spear_mesh_instance: spear_mesh_instance.visible = false
			if bow_mesh_instance: bow_mesh_instance.visible = true
			spawn_text("🏹 FINEWOOD BOW (Ranged)", Color(0.4, 0.95, 0.6), 1.2)
			weapon_changed.emit("Finewood Bow", "Piercing")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-65.0), deg_to_rad(45.0))
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_1:
			switch_weapon(WeaponType.SWORD_SHIELD)
		elif event.keycode == KEY_2:
			switch_weapon(WeaponType.SPEAR)
		elif event.keycode == KEY_3:
			switch_weapon(WeaponType.CLUB)
		elif event.keycode == KEY_4:
			switch_weapon(WeaponType.BOW)
			
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					return
				if current_weapon == WeaponType.BOW:
					is_aiming_bow = true
					bow_draw_timer = 0.0
					play_anim("Blocking")
				else:
					is_charging_heavy = true
					charge_timer = 0.0
			else:
				if current_weapon == WeaponType.BOW:
					if is_aiming_bow:
						fire_arrow()
						is_aiming_bow = false
						bow_draw_timer = 0.0
				else:
					if is_charging_heavy:
						if charge_timer >= max_charge_time:
							try_heavy_attack()
						else:
							try_attack()
						is_charging_heavy = false
						charge_timer = 0.0

func _physics_process(delta: float) -> void:
	handle_stamina(delta)
	handle_combat(delta)
	handle_idle_alive(delta)
	
	# Block State (Right Click)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not is_rolling and not is_attacking:
		if not is_blocking:
			is_blocking = true
			parry_timer = parry_window
			play_anim("Blocking", 0.15)
	else:
		if is_blocking:
			is_blocking = false

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
	var wants_sprint: bool = (Input.is_key_pressed(KEY_SHIFT) or Input.is_action_pressed("sprint")) and input_dir.length_squared() > 0.0

	# Cinematic Camera update
	handle_cinematic_camera(delta, move_dir, wants_sprint)

	# Jump Mechanics (Space)
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not is_rolling and not is_exhausted and stamina >= jump_stamina_cost:
		velocity.y = jump_velocity
		consume_stamina(jump_stamina_cost)
		play_anim("Jump_Start", 0.12)

	# Dodge Roll (Q, Alt, or Shift+Space)
	var wants_dodge = (Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_ALT) or (Input.is_key_pressed(KEY_SPACE) and wants_sprint))
	if wants_dodge and is_on_floor() and not is_rolling and not is_exhausted and stamina >= roll_stamina_cost:
		var dodge_dir = move_dir if move_dir.length_squared() > 0.01 else -visual_root.global_transform.basis.z
		start_roll(dodge_dir.normalized())
		consume_stamina(roll_stamina_cost)

	# Handle Dodge Roll State
	if is_rolling:
		roll_timer -= delta
		var roll_progress = clamp(1.0 - (roll_timer / roll_duration), 0.0, 1.0)
		var curve_mult = sin(roll_progress * PI) * 1.35 + 0.35
		velocity.x = roll_direction.x * roll_speed * curve_mult
		velocity.z = roll_direction.z * roll_speed * curve_mult
		if roll_timer <= 0.0:
			is_rolling = false
			is_invincible = false
		move_and_slide()
		return

	# Determine Target Speed
	var target_speed := walk_speed
	
	if current_weapon == WeaponType.BOW and is_aiming_bow:
		target_speed = walk_speed * 0.45
		bow_draw_timer = min(1.0, bow_draw_timer + delta * 1.6)
		consume_stamina(12.0 * delta)
		var aim_yaw := atan2(cam_forward.x, cam_forward.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, aim_yaw, 16.0 * delta)
	else:
		if is_blocking:
			target_speed = walk_speed * 0.45
		elif is_exhausted:
			target_speed = exhausted_speed
		elif wants_sprint and stamina > 0.0:
			target_speed = sprint_speed
			consume_stamina(sprint_cost_per_sec * delta)
		else:
			target_speed = walk_speed

	# Apply Acceleration & Deceleration curves to horizontal velocity
	var target_vel = move_dir * target_speed
	var current_h_vel = Vector3(velocity.x, 0.0, velocity.z)
	
	if is_on_floor():
		if move_dir.length_squared() > 0.001:
			var accel = sprint_accel if (wants_sprint and not is_exhausted) else walk_accel
			current_h_vel = current_h_vel.move_toward(target_vel, accel * delta)
		else:
			current_h_vel = current_h_vel.move_toward(Vector3.ZERO, ground_friction * delta)
	else:
		current_h_vel = current_h_vel.move_toward(target_vel, air_control * delta)

	velocity.x = current_h_vel.x
	velocity.z = current_h_vel.z

	# Smooth Model Rotation toward movement vector
	if current_h_vel.length() > 0.2 and not (current_weapon == WeaponType.BOW and is_aiming_bow):
		var target_rot_y := atan2(current_h_vel.x, current_h_vel.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rot_y, rotation_speed * delta)

	# Locomotion Animation Blending & Tempo
	if is_on_floor():
		if not is_attacking and not is_blocking:
			var h_speed = current_h_vel.length()
			if h_speed > 0.25:
				if wants_sprint and not is_exhausted:
					var run_tempo = clamp(h_speed / sprint_speed, 0.85, 1.25)
					play_anim("Running_A", 0.22, run_tempo)
					step_audio_timer += delta
					if step_audio_timer > 0.32:
						step_audio_timer = 0.0
						play_sfx(sfx_step, 0.85, 1.15, -6.0)
						spawn_dust(global_position)
				else:
					var walk_tempo = clamp(h_speed / walk_speed, 0.75, 1.2)
					play_anim("Walking_A", 0.18, walk_tempo)
			else:
				play_anim("Idle", 0.28)
	else:
		if not is_attacking and not is_blocking:
			if velocity.y > 0.8:
				play_anim("Jump_Start", 0.12)
			else:
				play_anim("Jump_Idle", 0.2)

	move_and_slide()

func play_anim(anim_name: String, blend_time: float = 0.2, speed: float = 1.0) -> void:
	if anim_player != null and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name, blend_time, speed)

func start_roll(dir: Vector3) -> void:
	is_rolling = true
	is_invincible = true
	roll_timer = roll_duration
	roll_direction = dir
	
	# Calculate directional dodge relative to player's facing direction
	var char_forward = -visual_root.global_transform.basis.z
	var char_right = visual_root.global_transform.basis.x
	char_forward.y = 0.0
	char_right.y = 0.0
	char_forward = char_forward.normalized()
	char_right = char_right.normalized()
	
	var fwd_dot = char_forward.dot(dir)
	var right_dot = char_right.dot(dir)
	
	var anim_name = "Dodge_Forward"
	if fwd_dot > 0.45:
		anim_name = "Dodge_Forward"
		visual_root.rotation.y = atan2(dir.x, dir.z)
	elif fwd_dot < -0.45:
		anim_name = "Dodge_Backward"
	elif right_dot > 0.0:
		anim_name = "Dodge_Right"
	else:
		anim_name = "Dodge_Left"
		
	play_anim(anim_name, 0.1, 1.25)
	play_sfx(sfx_dodge, 0.95, 1.05)
	spawn_dust(global_position)
	spawn_text("DODGE", Color(0.6, 0.85, 1.0), 0.95)

func handle_cinematic_camera(delta: float, move_dir: Vector3, wants_sprint: bool) -> void:
	# 1. Dynamic FOV
	var target_fov = base_fov
	if current_weapon == WeaponType.BOW and is_aiming_bow:
		target_fov = bow_fov
	elif wants_sprint and not is_exhausted and move_dir.length_squared() > 0.1:
		target_fov = sprint_fov
	camera.fov = lerp(camera.fov, target_fov, 4.5 * delta)
	
	# 2. Shoulder offset for third-person action RPG framing
	var target_h_offset = camera_shoulder_offset * 1.25 if (current_weapon == WeaponType.BOW and is_aiming_bow) else camera_shoulder_offset
	
	# 3. Dynamic banking / roll tilt when turning while moving
	var turn_rate = 0.0
	if move_dir.length_squared() > 0.1:
		var cam_right = camera_pivot.global_transform.basis.x
		cam_right.y = 0.0
		turn_rate = move_dir.dot(cam_right.normalized())
	var target_roll = -turn_rate * deg_to_rad(1.4)
	current_camera_roll = lerp(current_camera_roll, target_roll, 5.0 * delta)
	camera.rotation.z = current_camera_roll
	
	# 4. Spring arm distance easing
	var target_arm_length = 3.8
	if current_weapon == WeaponType.BOW and is_aiming_bow:
		target_arm_length = 2.4
	elif is_blocking:
		target_arm_length = 3.2
	elif wants_sprint and move_dir.length_squared() > 0.1:
		target_arm_length = 4.2
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_arm_length, 5.0 * delta)
	
	# 5. Camera Trauma Shake
	if camera_shake_trauma > 0.0:
		camera_shake_trauma = move_toward(camera_shake_trauma, 0.0, delta * 2.2)
		var shake = camera_shake_trauma * camera_shake_trauma * 0.16
		camera.h_offset = target_h_offset + randf_range(-shake, shake)
		camera.v_offset = randf_range(-shake, shake)
	else:
		camera.h_offset = lerp(camera.h_offset, target_h_offset, 6.0 * delta)
		camera.v_offset = lerp(camera.v_offset, 0.0, 6.0 * delta)

func consume_stamina(amount: float) -> void:
	stamina = max(0.0, stamina - amount)
	regen_timer = stamina_regen_delay
	if stamina <= 0.0:
		is_exhausted = true
		spawn_text("EXHAUSTED!", Color(1.0, 0.4, 0.2), 1.2)
	stamina_changed.emit(stamina, max_stamina)

func consume_food(f_name: String, hp_buff: float, stam_buff: float, dur: float) -> void:
	# Keep up to 3 distinct food items (Valheim food limit)
	for f in active_foods:
		if f.name == f_name:
			f.time_left = dur
			recalculate_food_buffs()
			return
			
	if active_foods.size() >= 3:
		active_foods.pop_front()
		
	active_foods.append({
		"name": f_name,
		"hp": hp_buff,
		"stamina": stam_buff,
		"time_left": dur
	})
	recalculate_food_buffs()
	health = min(max_health, health + hp_buff * 0.5)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)

func recalculate_food_buffs() -> void:
	var extra_hp := 0.0
	var extra_stam := 0.0
	for f in active_foods:
		extra_hp += f.hp
		extra_stam += f.stamina
	max_health = base_max_health + extra_hp
	max_stamina = base_max_stamina + extra_stam
	health = min(health, max_health)
	stamina = min(stamina, max_stamina)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)

func update_food_timers(delta: float) -> void:
	var changed := false
	for i in range(active_foods.size() - 1, -1, -1):
		active_foods[i].time_left -= delta
		if active_foods[i].time_left <= 0.0:
			spawn_text("BUFF EXPIRED: " + active_foods[i].name, Color(0.8, 0.7, 0.6), 1.0)
			active_foods.remove_at(i)
			changed = true
	if changed:
		recalculate_food_buffs()

func handle_stamina(delta: float) -> void:
	update_food_timers(delta)
	
	if regen_timer > 0.0:
		regen_timer -= delta
	else:
		if stamina < max_stamina:
			var current_regen := stamina_regen_rate
			if is_near_fire:
				current_regen *= 2.0 # Rested buff (+100%)
			elif is_cold:
				current_regen *= 0.55 # Cold debuff (-45%)
			stamina = min(max_stamina, stamina + current_regen * delta)
			stamina_changed.emit(stamina, max_stamina)
			if is_exhausted and stamina >= 22.0:
				is_exhausted = false

func play_sfx(stream: AudioStream, pitch_min: float = 0.92, pitch_max: float = 1.08, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var asp = AudioStreamPlayer.new()
	asp.stream = stream
	asp.volume_db = volume_db
	asp.pitch_scale = randf_range(pitch_min, pitch_max)
	get_tree().root.add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)

func trigger_hit_stop(duration: float = 0.05) -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func spawn_sparks(pos: Vector3) -> void:
	var sparks = hit_sparks_scene.instantiate()
	get_parent().add_child(sparks)
	sparks.global_position = pos

func spawn_dust(pos: Vector3) -> void:
	var dust = dust_puff_scene.instantiate()
	get_parent().add_child(dust)
	dust.global_position = pos

func handle_idle_alive(delta: float) -> void:
	idle_alive_timer += delta
	# Subtle cat tail swaying
	if tail != null:
		tail.rotation.x = 0.707 + sin(idle_alive_timer * 3.2) * 0.12
		tail.rotation.z = sin(idle_alive_timer * 2.1) * 0.08
	# Subtle cat ear twitches
	if ear_l != null and ear_r != null:
		var twitch = sin(idle_alive_timer * 5.5)
		if twitch > 0.88:
			var angle = (twitch - 0.88) * 0.45
			ear_l.rotation.z = angle
			ear_r.rotation.z = -angle
		else:
			ear_l.rotation.z = 0.0
			ear_r.rotation.z = 0.0

func try_attack() -> void:
	var stam_cost := attack_stamina_cost
	if current_weapon == WeaponType.SPEAR:
		stam_cost = 9.0
	elif current_weapon == WeaponType.CLUB:
		stam_cost = 16.0

	if is_attacking or is_rolling or is_exhausted or stamina < stam_cost:
		return
		
	is_attacking = true
	attack_timer = attack_duration
	consume_stamina(stam_cost)
	
	combo_step = (combo_step % 3) + 1
	combo_reset_timer = 0.85
	
	var damage := 26.0
	var knock_force := 9.0
	var anim_to_play := "1H_Melee_Attack_Slice_Horizontal"
	var dmg_type := "slashing"
	
	match current_weapon:
		WeaponType.SWORD_SHIELD:
			dmg_type = "slashing"
			if combo_step == 1:
				damage = 26.0
				knock_force = 9.0
				anim_to_play = "1H_Melee_Attack_Slice_Horizontal"
			elif combo_step == 2:
				damage = 36.0
				knock_force = 12.0
				anim_to_play = "1H_Melee_Attack_Slice_Diagonal"
			elif combo_step == 3:
				damage = 56.0
				knock_force = 19.0
				anim_to_play = "1H_Melee_Attack_Chop"
				add_camera_shake(0.35)
		WeaponType.SPEAR:
			dmg_type = "piercing"
			anim_to_play = "1H_Melee_Attack_Stab"
			if combo_step == 1:
				damage = 24.0
				knock_force = 10.0
			elif combo_step == 2:
				damage = 34.0
				knock_force = 14.0
			elif combo_step == 3:
				damage = 52.0
				knock_force = 20.0
				add_camera_shake(0.3)
		WeaponType.CLUB:
			dmg_type = "blunt"
			if combo_step == 1:
				damage = 34.0
				knock_force = 15.0
				anim_to_play = "2H_Melee_Attack_Chop"
			elif combo_step == 2:
				damage = 48.0
				knock_force = 18.0
				anim_to_play = "2H_Melee_Attack_Slice"
			elif combo_step == 3:
				damage = 74.0
				knock_force = 24.0
				anim_to_play = "2H_Melee_Attack_Spin"
				add_camera_shake(0.4)
	
	play_anim(anim_to_play, 0.12, 1.15)
	play_sfx(sfx_swing, 0.95, 1.1)
	
	# Attack step / lunge
	var fwd = -visual_root.global_transform.basis.z
	velocity += fwd * 4.2
	
	# Initiate 3-stage combat pipeline: WINDUP -> ACTIVE -> RECOVERY
	combat_stage = CombatStage.WINDUP
	combat_stage_timer = 0.12
	current_attack_dmg = damage
	current_attack_knock = knock_force
	current_attack_type = dmg_type
	attack_hit_registered = false

func try_heavy_attack() -> void:
	if is_attacking or is_rolling or is_exhausted or stamina < heavy_attack_cost:
		try_attack()
		return
		
	is_attacking = true
	attack_timer = 0.65
	consume_stamina(heavy_attack_cost)
	
	var damage := 78.0
	var knock_force := 26.0
	var dmg_type := "slashing"
	var anim_to_play := "2H_Melee_Attack_Chop"
	
	match current_weapon:
		WeaponType.SWORD_SHIELD:
			damage = 84.0
			dmg_type = "slashing"
			anim_to_play = "1H_Melee_Attack_Chop"
			spawn_text("💥 HEAVY SLASH!", Color(1.0, 0.5, 0.2), 1.5)
		WeaponType.SPEAR:
			damage = 92.0
			dmg_type = "piercing"
			anim_to_play = "1H_Melee_Attack_Stab"
			knock_force = 26.0
			spawn_text("💥 HEAVY THRUST!", Color(0.2, 0.85, 1.0), 1.5)
		WeaponType.CLUB:
			damage = 112.0
			dmg_type = "blunt"
			anim_to_play = "2H_Melee_Attack_Spin"
			knock_force = 32.0
			spawn_text("💥 CRUSHING SLAM!", Color(1.0, 0.85, 0.2), 1.7)
			
	play_anim(anim_to_play, 0.15, 1.0)
	play_sfx(sfx_swing, 0.82, 0.94, 2.0)
	add_camera_shake(0.45)
	
	# Heavy forward lunge
	var fwd = -visual_root.global_transform.basis.z
	velocity += fwd * 5.8
	
	combat_stage = CombatStage.WINDUP
	combat_stage_timer = 0.18
	current_attack_dmg = damage
	current_attack_knock = knock_force
	current_attack_type = dmg_type
	attack_hit_registered = false

func execute_active_hitbox() -> void:
	var hit_count := 0
	var fwd = -visual_root.global_transform.basis.z
	
	for body in attack_area.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			var knockback_dir := (body.global_position - global_position).normalized()
			knockback_dir.y = 0.38
			
			# Check parry stagger
			if body.has_method("apply_parry_stagger") and current_attack_dmg > 75.0:
				body.apply_parry_stagger(32.0)
				
			body.take_damage(current_attack_dmg, knockback_dir * current_attack_knock, current_attack_type)
			hit_count += 1
			
			# VFX & Audio impact
			var spark_pos = body.global_position + Vector3(0, 1.0, 0)
			spawn_sparks(spark_pos)
			
	if hit_count > 0:
		if current_attack_type == "blunt":
			play_sfx(sfx_blunt, 0.9, 1.05)
		else:
			play_sfx(sfx_impact, 0.95, 1.1)
		trigger_hit_stop(0.06)
		add_camera_shake(0.25)
		attack_hit_registered = true

func handle_combat(delta: float) -> void:
	if is_charging_heavy:
		charge_timer += delta
		if charge_timer >= max_charge_time:
			pass

	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_step = 0

	# Attack Stage Pipeline
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			combat_stage = CombatStage.READY
			
		match combat_stage:
			CombatStage.WINDUP:
				combat_stage_timer -= delta
				if combat_stage_timer <= 0.0:
					combat_stage = CombatStage.ACTIVE
					combat_stage_timer = 0.15
					execute_active_hitbox()
			CombatStage.ACTIVE:
				combat_stage_timer -= delta
				# Secondary check in case an enemy walked into the swing
				if not attack_hit_registered:
					execute_active_hitbox()
				if combat_stage_timer <= 0.0:
					combat_stage = CombatStage.RECOVERY
					combat_stage_timer = 0.18
			CombatStage.RECOVERY:
				combat_stage_timer -= delta
				if combat_stage_timer <= 0.0:
					combat_stage = CombatStage.READY

func receive_attack(amount: float, knockback: Vector3, attacker: Node3D) -> String:
	if is_invincible:
		spawn_text("DODGED", Color(0.4, 0.8, 1.0), 1.1)
		return "DODGED"
		
	if is_blocking:
		if parry_timer > 0.0:
			# PERFECT PARRY!
			spawn_text("🛡️ PARRY!", Color(1.0, 0.85, 0.2), 1.6)
			play_sfx(sfx_parry, 0.98, 1.04, 3.0)
			trigger_hit_stop(0.08)
			add_camera_shake(0.45)
			play_anim("Block_Hit", 0.08)
			spawn_sparks(global_position + Vector3(0, 1.0, 0.6))
			if attacker != null and attacker.has_method("apply_parry_stagger"):
				attacker.apply_parry_stagger(38.0)
			return "PARRIED"
		else:
			# Normal Block
			var blocked_dmg := amount * 0.25
			health = max(0.0, health - blocked_dmg)
			health_changed.emit(health, max_health)
			consume_stamina(14.0)
			velocity += knockback * 0.35
			play_anim("Block_Hit", 0.1)
			play_sfx(sfx_block, 0.92, 1.05)
			spawn_text("BLOCKED " + str(int(amount - blocked_dmg)), Color(0.7, 0.8, 0.9), 1.0)
			return "BLOCKED"

	# Full Hit
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	velocity += knockback
	add_camera_shake(0.5)
	trigger_hit_stop(0.05)
	play_sfx(sfx_impact, 0.85, 0.95)
	play_anim("Hit_A", 0.08)
	spawn_sparks(global_position + Vector3(0, 1.0, 0))
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

func fire_arrow() -> void:
	if is_exhausted or stamina < 10.0:
		spawn_text("OUT OF STAMINA!", Color(1.0, 0.4, 0.2), 1.0)
		return
		
	consume_stamina(14.0)
	var arrow = arrow_scene.instantiate()
	get_tree().root.add_child(arrow)
	
	# Spawn arrow at player chest/hand
	var cam_fwd = -camera.global_transform.basis.z
	var spawn_pos = global_position + Vector3(0, 1.25, 0) + (cam_fwd * 0.75)
	arrow.global_position = spawn_pos
	
	var charge_ratio = clamp(bow_draw_timer, 0.25, 1.0)
	var arrow_speed = lerp(32.0, 56.0, charge_ratio)
	var arrow_dmg = lerp(40.0, 92.0, charge_ratio)
	
	arrow.launch(cam_fwd, arrow_speed, arrow_dmg, self)
	add_camera_shake(0.2)
	play_sfx(sfx_bow, 0.95, 1.05)
	play_anim("1H_Melee_Attack_Stab", 0.08)
	spawn_text("🏹 ARROW (%.0f dmg)" % arrow_dmg, Color(0.4, 0.95, 0.6), 1.1)

func add_trophy(amount: int = 1) -> void:
	trophies += amount
	trophies_changed.emit(trophies)
	spawn_text("🏆 +%d TROPHY! (Total: %d)" % [amount, trophies], Color(1.0, 0.85, 0.2), 1.6)
