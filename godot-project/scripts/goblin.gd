extends CharacterBody3D

signal died

@export var max_health: float = 85.0
var health: float = 85.0

@export var move_speed: float = 4.2
@export var aggro_distance: float = 18.0

var player: CharacterBody3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)

enum State { IDLE, CIRCLE, WINDUP, THRUST, STAGGERED, RECOVER }
var state: State = State.IDLE
var state_timer: float = 0.0

@onready var visual_root: Node3D = $VisualRoot
@onready var spear_pivot: Node3D = $VisualRoot/SpearPivot
@onready var attack_area: Area3D = $VisualRoot/SpearPivot/SpearArea

var floating_text_scene = preload("res://scenes/floating_text.tscn")

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if player == null:
		player = get_tree().get_first_node_in_group("player")
		
	state_timer += delta

	if player != null and state != State.STAGGERED:
		var dist_to_player := global_position.distance_to(player.global_position)
		
		match state:
			State.IDLE:
				if dist_to_player < aggro_distance:
					state = State.CIRCLE
					state_timer = 0.0
					
			State.CIRCLE:
				# Look at player
				var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
				look_at(look_target, Vector3.UP)
				
				# Circle around player while closing in
				var to_player := (player.global_position - global_position).normalized()
				to_player.y = 0.0
				var tangent := Vector3(-to_player.z, 0, to_player.x)
				
				if dist_to_player > 3.5:
					velocity.x = (to_player * 0.7 + tangent * 0.7).x * move_speed
					velocity.z = (to_player * 0.7 + tangent * 0.7).z * move_speed
				else:
					velocity.x = tangent.x * move_speed
					velocity.z = tangent.z * move_speed
					
				if state_timer >= 2.0 and dist_to_player < 4.5:
					# Windup attack
					state = State.WINDUP
					state_timer = 0.0
					velocity.x = 0
					velocity.z = 0
					
			State.WINDUP:
				# Pull spear back
				spear_pivot.rotation.x = deg_to_rad(-45.0)
				spear_pivot.position.z = -0.3
				if state_timer >= 0.55:
					state = State.THRUST
					state_timer = 0.0
					# Lunge forward
					var lunge_dir := (player.global_position - global_position).normalized()
					lunge_dir.y = 0
					velocity.x = lunge_dir.x * 9.0
					velocity.z = lunge_dir.z * 9.0
					
			State.THRUST:
				# Thrust spear forward
				spear_pivot.rotation.x = deg_to_rad(15.0)
				spear_pivot.position.z = 0.8
				
				# Check hit on player
				for body in attack_area.get_overlapping_bodies():
					if body.is_in_group("player") and body.has_method("receive_attack"):
						var damage := 18.0
						var knockback := (player.global_position - global_position).normalized() * 8.0
						var attack_result = body.receive_attack(damage, knockback, self)
						if attack_result == "PARRIED":
							get_parried()
							return
							
				if state_timer >= 0.35:
					state = State.RECOVER
					state_timer = 0.0
					
			State.RECOVER:
				spear_pivot.rotation = Vector3.ZERO
				spear_pivot.position = Vector3(0.4, 0.5, 0.2)
				velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
				if state_timer >= 0.8:
					state = State.CIRCLE
					state_timer = 0.0
	elif state == State.STAGGERED:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		visual_root.rotation.x = deg_to_rad(25.0) # bent backwards
		if state_timer >= 1.6:
			state = State.CIRCLE
			state_timer = 0.0
			visual_root.rotation.x = 0.0

	move_and_slide()

func get_parried() -> void:
	state = State.STAGGERED
	state_timer = 0.0
	velocity = -global_transform.basis.z * 7.0 # knock backward
	spawn_text("STAGGERED!", Color(1.0, 0.8, 0.2), 1.4)

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	# Extra critical damage if staggered
	if state == State.STAGGERED:
		amount *= 1.8
		spawn_text("CRIT! " + str(int(amount)), Color(1.0, 0.3, 0.2), 1.5)
	else:
		spawn_text(str(int(amount)), Color(1.0, 0.9, 0.9), 1.0)
		
	health -= amount
	velocity = knockback
	if health <= 0.0:
		die()

func spawn_text(txt: String, col: Color, sz: float) -> void:
	var ft = floating_text_scene.instantiate()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector3(0, 1.8, 0)
	ft.setup(txt, col, sz)

func die() -> void:
	died.emit()
	var main_node = get_tree().current_scene
	if main_node.has_method("on_enemy_killed"):
		main_node.on_enemy_killed()
	queue_free()
