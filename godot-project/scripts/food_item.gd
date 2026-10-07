extends Area3D
class_name FoodItem

@export var food_name: String = "Red Mushroom"
@export var hp_bonus: float = 25.0
@export var stamina_bonus: float = 20.0
@export var duration: float = 90.0

var floating_text_scene = preload("res://scenes/floating_text.tscn")
var is_collected: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	if body.has_method("consume_food"):
		is_collected = true
		body.consume_food(food_name, hp_bonus, stamina_bonus, duration)
		
		var ft = floating_text_scene.instantiate()
		get_parent().add_child(ft)
		ft.global_position = global_position + Vector3(0, 1.2, 0)
		ft.set_text("🍄 " + food_name + " (+%d HP, +%d Stam)" % [int(hp_bonus), int(stamina_bonus)], Color(0.95, 0.85, 0.35))
		
		# Disappear with quick shrink
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tween.tween_callback(self.queue_free)
