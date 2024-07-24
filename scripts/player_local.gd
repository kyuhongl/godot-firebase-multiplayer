extends CharacterBody2D

class_name PlayerLocal 

const MOVE_SPEED: float = 200

@export var sprite: Sprite2D

#applies random color and ID
var player_id: int = randi_range(100000, 999999) 
var player_color: Color = Color.from_hsv(randf(), 0.75, 1.0) 

func _ready() -> void:
	_set_random_spawn()
	
	sprite.modulate = player_color

func _physics_process(_delta: float) -> void:
	var dx = Input.get_axis("move_left", "move_right")
	var dy = Input.get_axis("move_up", "move_down")
	
	if dx != 0 or dy != 0:
		var dir = Vector2(dx, dy).normalized()
		velocity = dir * MOVE_SPEED
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _set_random_spawn() -> void:
	var border = 50
	var randx = randf_range(-border, border)
	var randy = randf_range(-border, border)
	global_position = global_position + Vector2(randx, randy)
