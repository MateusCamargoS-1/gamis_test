class_name MovementComponent
extends Node

@export var body: CharacterBody2D
@export var speed: float = 350.0
@export var gravity: float = 1200.0
@export var jump_force: float = -600.0
@export var friction: float = 0.1
@export var air_control: float = 0.8
@export var max_jumps: int = 2

var jump_count: int = 0
var coyote_timer: float = 0.0
const COYOTE_TIME: float = 0.15

func _physics_process(delta):
	if not body: return
	
	# Apply Gravity
	if not body.is_on_floor():
		body.velocity.y += gravity * delta
		coyote_timer -= delta
	else:
		jump_count = 0
		coyote_timer = COYOTE_TIME

func move(direction: float, delta: float):
	if not body: return
	
	var target_speed = direction * speed
	var accel = 1.0
	
	if not body.is_on_floor():
		accel = air_control
		
	if direction != 0:
		body.velocity.x = move_toward(body.velocity.x, target_speed, speed * 10 * delta * accel)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0, speed * friction * 60 * delta)

func jump():
	if not body: return
	
	if coyote_timer > 0 or jump_count < max_jumps:
		body.velocity.y = jump_force
		if coyote_timer <= 0:
			jump_count += 1
		else:
			jump_count = 1 # First jump from ground
		coyote_timer = 0
		return true
	return false

func cut_jump():
	if body and body.velocity.y < 0:
		body.velocity.y *= 0.5

func reset_velocity():
	if body:
		body.velocity = Vector2.ZERO
