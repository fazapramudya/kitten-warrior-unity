extends Area3D

@export var speed: float = 38.0
@export var damage: float = 65.0
@export var gravity: float = 9.8
@export var max_lifetime: float = 5.0

var velocity: Vector3 = Vector3.ZERO
var shooter: Node3D = null
var lifetime: float = 0.0
var has_hit: bool = false

var floating_text_scene = preload("res://scenes/floating_text.tscn")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(direction: Vector3, launch_speed: float, dmg: float, owner_node: Node3D) -> void:
	velocity = direction.normalized() * launch_speed
	damage = dmg
	shooter = owner_node
	# Look towards trajectory
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP)

func _physics_process(delta: float) -> void:
	if has_hit:
		return
		
	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return
		
	# Apply gravity drop to trajectory
	velocity.y -= gravity * delta
	global_position += velocity * delta
	
	if velocity.length_squared() > 0.1:
		look_at(global_position + velocity, Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if has_hit or body == shooter:
		return
		
	has_hit = true
	
	if body.has_method("take_damage"):
		var knock_dir = velocity.normalized()
		knock_dir.y = 0.25
		# Bow arrows deal Piercing damage
		body.take_damage(damage, knock_dir * 14.0, "piercing")
		spawn_hit_effect()
	elif body.has_method("chop"):
		# Hit tree
		var chop_dmg = damage * 0.45 # Piercing deals less to trees
		body.chop(chop_dmg, "piercing")
		spawn_hit_effect()
	else:
		# Hit ground or rock
		spawn_hit_effect()
		
	queue_free()

func spawn_hit_effect() -> void:
	if floating_text_scene != null:
		var txt = floating_text_scene.instantiate()
		get_tree().root.add_child(txt)
		txt.global_position = global_position + Vector3(0, 0.5, 0)
		txt.setup("🎯 ARROW HIT", Color(1.0, 0.9, 0.4), 0.9)
