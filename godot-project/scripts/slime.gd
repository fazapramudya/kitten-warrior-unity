extends CharacterBody3D

signal died

@export var max_health: float = 60.0
var health: float = 60.0

@export var hop_force: float = 5.5
@export var move_speed: float = 3.5
@export var aggro_distance: float = 16.0

var player: CharacterBody3D = null
var hop_timer: float = 0.0
var hop_interval: float = 1.2
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
var flash_timer: float = 0.0

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	hop_interval = randf_range(0.9, 1.4)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Hit flash effect decay
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0 and mesh_instance.material_override != null:
			mesh_instance.material_override = null

	# AI Logic
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		
	if player != null:
		var dist_to_player := global_position.distance_to(player.global_position)
		if dist_to_player < aggro_distance:
			hop_timer += delta
			if hop_timer >= hop_interval and is_on_floor():
				hop_timer = 0.0
				# Hop toward player
				var dir := (player.global_position - global_position).normalized()
				dir.y = 0.0
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				velocity.y = hop_force
				
				# Face the player
				look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		else:
			# Friction when idle
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)

	# Damage player on contact
	if is_on_floor() and player != null:
		if global_position.distance_to(player.global_position) < 1.3:
			player.take_damage(12.0, (player.global_position - global_position).normalized() * 6.0)

	move_and_slide()

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	health -= amount
	velocity = knockback
	flash_timer = 0.15
	
	# Create flash material
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.2, 0.2)
	mesh_instance.material_override = flash_mat
	
	if health <= 0.0:
		die()

func die() -> void:
	died.emit()
	var main_node = get_tree().current_scene
	if main_node.has_method("on_enemy_killed"):
		main_node.on_enemy_killed()
	queue_free()
