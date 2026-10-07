extends StaticBody3D
class_name ChoppableTree

signal tree_felled(pos)

@export var max_health: float = 80.0
var health: float = 80.0
var is_felled: bool = false
var original_rotation: Vector3

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
var floating_text_scene = preload("res://scenes/floating_text.tscn")

func _ready() -> void:
	health = max_health
	original_rotation = rotation
	add_to_group("choppable_trees")

func take_damage(amount: float, hit_dir: Vector3 = Vector3.ZERO) -> void:
	if is_felled:
		return
		
	health -= amount
	
	# Spawn floating hit indicator
	var ft = floating_text_scene.instantiate()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector3(0, 2.5, 0)
	ft.set_text("🌲 -%d (Wood)" % int(amount), Color(0.85, 0.65, 0.4))
	
	# Tree wobble effect
	var tween = create_tween()
	var wobble_angle = 0.05
	tween.tween_property(self, "rotation:z", original_rotation.z + wobble_angle, 0.08)
	tween.tween_property(self, "rotation:z", original_rotation.z - wobble_angle * 0.7, 0.08)
	tween.tween_property(self, "rotation:z", original_rotation.z, 0.08)
	
	if health <= 0:
		fell_tree(hit_dir)

func fell_tree(fall_direction: Vector3) -> void:
	if is_felled:
		return
	is_felled = true
	
	# Floating notification
	var ft = floating_text_scene.instantiate()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector3(0, 3.2, 0)
	ft.set_text("🪓 TREE FELLED! +8 Wood", Color(1.0, 0.9, 0.3))
	
	# Determine falling direction
	var fall_dir = fall_direction.normalized()
	if fall_dir.length_squared() < 0.1:
		fall_dir = Vector3(1, 0, 0)
	
	var fall_axis = Vector3(-fall_dir.z, 0, fall_dir.x).normalized()
	
	# Disable collision so player doesn't get stuck
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		
	# Fall animation tween
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", rotation + fall_axis * 1.5, 1.4)
	tween.tween_callback(self._on_fall_completed)

func _on_fall_completed() -> void:
	tree_felled.emit(global_position)
	# Slowly sink or disappear after yielding resources
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 1.0)
	tween.tween_callback(self.queue_free)
