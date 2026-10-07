extends CharacterBody3D

signal boss_health_changed(curr: float, max_val: float)
signal boss_defeated
signal boss_phase_changed(phase_num: int)

@export var max_health: float = 850.0
var health: float = 850.0

@export var walk_speed: float = 4.2
@export var charge_speed: float = 14.0
@export var aggro_distance: float = 35.0

var player: CharacterBody3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)

enum State {
	IDLE,
	CHASE,
	MELEE_SWEEP,
	GROUND_STOMP,
	HORN_CHARGE,
	SUMMON_HOWL,
	STAGGERED,
	DEFEATED
}

var state: State = State.IDLE
var state_timer: float = 0.0
var phase: int = 1
var is_enraged: bool = false

# Stagger system
var stagger_meter: float = 0.0
var stagger_threshold: float = 110.0
var stagger_duration: float = 3.5

# Combat cooldowns
var stomp_cooldown: float = 7.0
var charge_cooldown: float = 10.0
var summon_cooldown: float = 24.0

var stomp_timer: float = 4.0
var charge_timer: float = 6.0
var summon_timer: float = 15.0

var charge_direction: Vector3 = Vector3.FORWARD
var goblin_scene = preload("res://scenes/goblin.tscn")
var skeleton_scene = preload("res://scenes/skeleton.tscn")
var floating_text_scene = preload("res://scenes/floating_text.tscn")

@onready var visual_root: Node3D = $VisualRoot
@onready var stomp_area: Area3D = $VisualRoot/StompArea
@onready var sweep_area: Area3D = $VisualRoot/SweepArea
@onready var eyes_light: OmniLight3D = $VisualRoot/EyesLight

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	boss_health_changed.emit(health, max_health)
	boss_phase_changed.emit(phase)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if player == null:
		player = get_tree().get_first_node_in_group("player")
		
	if state == State.DEFEATED:
		move_and_slide()
		return
		
	state_timer += delta
	stomp_timer = max(0.0, stomp_timer - delta)
	charge_timer = max(0.0, charge_timer - delta)
	summon_timer = max(0.0, summon_timer - delta)
	
	# Phase transition at 50% HP
	if not is_enraged and health <= max_health * 0.5:
		enter_enrage()
		
	if player != null:
		var dist_to_player := global_position.distance_to(player.global_position)
		
		match state:
			State.IDLE:
				if dist_to_player < aggro_distance:
					state = State.CHASE
					state_timer = 0.0
					
			State.CHASE:
				look_at_smooth(player.global_position, delta * 3.5)
				var dir := (player.global_position - global_position).normalized()
				dir.y = 0.0
				var cur_speed = walk_speed * (1.35 if is_enraged else 1.0)
				velocity.x = dir.x * cur_speed
				velocity.z = dir.z * cur_speed
				
				# Choose attack based on distance and cooldowns
				if dist_to_player <= 4.2:
					start_melee_sweep()
				elif stomp_timer <= 0.0 and dist_to_player <= 9.0:
					start_ground_stomp()
				elif charge_timer <= 0.0 and dist_to_player >= 9.0:
					start_horn_charge()
				elif summon_timer <= 0.0 and is_enraged:
					start_summon_howl()
					
			State.MELEE_SWEEP:
				velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
				if state_timer >= 0.45 and state_timer - delta < 0.45:
					execute_melee_sweep()
				if state_timer >= 1.1:
					state = State.CHASE
					state_timer = 0.0
					
			State.GROUND_STOMP:
				velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
				if state_timer >= 0.7 and state_timer - delta < 0.7:
					execute_ground_stomp()
				if state_timer >= 1.6:
					state = State.CHASE
					state_timer = 0.0
					
			State.HORN_CHARGE:
				velocity.x = charge_direction.x * charge_speed
				velocity.z = charge_direction.z * charge_speed
				# Crash into trees and player
				check_charge_collisions()
				if state_timer >= 2.2:
					# End charge
					state = State.CHASE
					state_timer = 0.0
					charge_timer = charge_cooldown
					
			State.SUMMON_HOWL:
				velocity.x = 0.0
				velocity.z = 0.0
				if state_timer >= 1.0 and state_timer - delta < 1.0:
					execute_summon()
				if state_timer >= 2.0:
					state = State.CHASE
					state_timer = 0.0
					
			State.STAGGERED:
				velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
				if state_timer >= stagger_duration:
					state = State.CHASE
					state_timer = 0.0
					stagger_meter = 0.0
					spawn_text("RECOVERED!", Color(0.4, 0.9, 0.6), 1.3)
					
	move_and_slide()

func look_at_smooth(target: Vector3, weight: float) -> void:
	var target_y = Vector3(target.x, global_position.y, target.z)
	var dir = (target_y - global_position).normalized()
	if dir.length_squared() > 0.01:
		var target_rot = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, weight)

func enter_enrage() -> void:
	is_enraged = true
	phase = 2
	boss_phase_changed.emit(phase)
	spawn_text("🔥 ENRAGED! PHASE 2", Color(1.0, 0.2, 0.2), 2.2)
	if eyes_light:
		eyes_light.light_color = Color(1.0, 0.15, 0.15)
		eyes_light.light_energy = 5.0
	stomp_cooldown = 4.5
	charge_cooldown = 6.0

func start_melee_sweep() -> void:
	state = State.MELEE_SWEEP
	state_timer = 0.0
	spawn_text("CLAW SWEEP", Color(1.0, 0.6, 0.2), 1.2)

func execute_melee_sweep() -> void:
	if sweep_area != null:
		for b in sweep_area.get_overlapping_bodies():
			if b == player and b.has_method("receive_attack"):
				var knock = (player.global_position - global_position).normalized() * 16.0
				knock.y = 4.0
				b.receive_attack(38.0, knock, self)

func start_ground_stomp() -> void:
	state = State.GROUND_STOMP
	state_timer = 0.0
	stomp_timer = stomp_cooldown
	spawn_text("⚡ TITAN STOMP!", Color(1.0, 0.85, 0.1), 1.8)

func execute_ground_stomp() -> void:
	if player != null and player.has_method("add_camera_shake"):
		player.add_camera_shake(0.65)
		
	if stomp_area != null:
		for b in stomp_area.get_overlapping_bodies():
			if b == player and b.has_method("receive_attack"):
				var knock = (player.global_position - global_position).normalized() * 22.0
				knock.y = 7.0
				b.receive_attack(52.0, knock, self)
			elif b.has_method("chop"):
				b.chop(90.0, "blunt")

func start_horn_charge() -> void:
	state = State.HORN_CHARGE
	state_timer = 0.0
	charge_direction = (player.global_position - global_position).normalized()
	charge_direction.y = 0.0
	rotation.y = atan2(charge_direction.x, charge_direction.z)
	spawn_text("🐗 HORN CHARGE!", Color(1.0, 0.3, 0.1), 2.0)

func check_charge_collisions() -> void:
	if sweep_area != null:
		for b in sweep_area.get_overlapping_bodies():
			if b == player and b.has_method("receive_attack"):
				var knock = charge_direction * 28.0
				knock.y = 6.0
				b.receive_attack(68.0, knock, self)
			elif b.has_method("chop"):
				b.chop(150.0, "blunt") # Knocks down trees!

func start_summon_howl() -> void:
	state = State.SUMMON_HOWL
	state_timer = 0.0
	summon_timer = summon_cooldown
	spawn_text("🐺 HOWL OF THE WOODS!", Color(0.8, 0.3, 1.0), 2.0)

func execute_summon() -> void:
	for i in range(2):
		var spawn_p = global_position + Vector3(randf_range(-6, 6), 0.5, randf_range(-6, 6))
		var monster = (goblin_scene if randf() > 0.5 else skeleton_scene).instantiate()
		get_parent().add_child(monster)
		monster.global_position = spawn_p

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, damage_type: String = "slashing") -> void:
	if state == State.DEFEATED:
		return
		
	var final_amount := amount
	# Weakness / Resistance logic
	if damage_type == "piercing":
		# Thick hide resists light piercing slightly, but arrows to head still crit
		final_amount *= 0.95
	elif damage_type == "slashing":
		final_amount *= 1.15 # Weak to axes/blades
	elif damage_type == "blunt":
		final_amount *= 1.0
		apply_parry_stagger(amount * 0.4)
		
	if state == State.STAGGERED:
		final_amount *= 2.0 # Critical damage window!
		spawn_text("💥 CRIT! %d" % int(final_amount), Color(1.0, 0.25, 0.1), 1.8)
	else:
		spawn_text("%d" % int(final_amount), Color(1.0, 0.95, 0.9), 1.2)
		
	health = max(0.0, health - final_amount)
	boss_health_changed.emit(health, max_health)
	
	if health <= 0.0:
		defeat_boss()

func apply_parry_stagger(stagger_force: float) -> void:
	if state == State.DEFEATED or state == State.STAGGERED:
		return
		
	stagger_meter += stagger_force
	if stagger_meter >= stagger_threshold:
		state = State.STAGGERED
		state_timer = 0.0
		velocity = -global_transform.basis.z * 5.0
		spawn_text("⚡ STAGGERED! WEAKNESS EXPOSED", Color(1.0, 0.85, 0.1), 2.0)
		if player != null and player.has_method("add_camera_shake"):
			player.add_camera_shake(0.4)

func defeat_boss() -> void:
	state = State.DEFEATED
	boss_defeated.emit()
	spawn_text("👑 ANCIENT GUARDIAN DEFEATED!", Color(1.0, 0.9, 0.2), 2.8)
	
	if player != null and player.has_method("add_trophy"):
		player.add_trophy(5) # 5 trophies reward!
		
	var main_node = get_tree().current_scene
	if main_node != null and main_node.has_method("on_boss_defeated"):
		main_node.on_boss_defeated()
		
	await get_tree().create_timer(3.0).timeout
	queue_free()

func spawn_text(txt: String, col: Color, sz: float) -> void:
	var ft = floating_text_scene.instantiate()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector3(0, 3.8, 0)
	ft.setup(txt, col, sz)
