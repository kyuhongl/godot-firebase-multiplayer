extends CharacterBody2D

class_name PlayerRemote

@export var speed: float = 200.0
@export var sprite: Sprite2D

var player_id: String
var color: Color
var target_pos:  Vector2
var is_initialized: bool = false

func update_from_event(player_data: Dictionary) -> void:
	player_id = str(player_data["id"])
	color = Color.html(player_data["color"])
	sprite.modulate = color
	_move_to_target(player_data["position_x"], player_data["position_y"])

func _move_to_target(target_x, target_y) -> void:
	target_pos = Vector2(target_x, target_y)
	
	if not is_initialized:
		global_position = target_pos
		is_initialized = true

func _process(delta: float) -> void:
	var diff = target_pos - global_position
		
	if diff.length() < 1:
		global_position = target_pos
		velocity = Vector2.ZERO
	else:
		velocity = diff.normalized() * speed
		move_and_slide()
