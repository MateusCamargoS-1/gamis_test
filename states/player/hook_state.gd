class_name PlayerHookState
extends PlayerState

const HOOK_SPEED = 2500.0
const SWING_FORCE = 1500.0
const CLIMB_SPEED = 200.0

var hook_target_pos: Vector2
var rope_length: float = 0.0
var current_hook_pos: Vector2
var is_shooting: bool = false
var hooked_object: Node2D = null

func enter(params: Dictionary = {}):
	hook_target_pos = params.get("target_pos", Vector2.ZERO)
	hooked_object = params.get("target_obj", null)
	current_hook_pos = player.global_position
	is_shooting = true
	player.velocity = Vector2.ZERO # Pause gravity momentarily while shooting? Or keep momentum?
	# Original code kept momentum or reset it? 
	# Original: hook_active = false, hook_shooting = true.
	
func physics_update(delta: float):
	if is_shooting:
		_handle_shooting(delta)
	else:
		_handle_swinging(delta)

	if Input.is_action_just_pressed("jump"):
		_jump_off()

	if Input.is_action_just_released("hook"):
		state_machine.change_state("fall")

func _handle_shooting(delta: float):
	var speed = HOOK_SPEED * delta
	var dist = current_hook_pos.distance_to(hook_target_pos)
	
	if dist < speed:
		current_hook_pos = hook_target_pos
		is_shooting = false
		rope_length = player.global_position.distance_to(hook_target_pos)
		rope_length = max(rope_length * 0.9, 40.0)
		
		# Apply initial pull
		var dir = (hook_target_pos - player.global_position).normalized()
		player.velocity += dir * 250
	else:
		current_hook_pos = current_hook_pos.move_toward(hook_target_pos, speed)
		# While shooting, maybe apply some gravity or drag?
		player.velocity.y += movement.gravity * delta

func _handle_swinging(delta: float):
	# Update target if object moved
	if is_instance_valid(hooked_object) and "rect" in hooked_object:
		hook_target_pos = hooked_object.rect.get_center() # Assuming Platform class structure
	
	var to_hook = hook_target_pos - player.global_position
	var dist = to_hook.length()
	var dir = to_hook.normalized()
	
	# Climbing
	var climb_dir = Input.get_axis("move_up", "move_down")
	if climb_dir:
		rope_length -= climb_dir * CLIMB_SPEED * delta
		rope_length = max(rope_length, 30.0)
	
	# Swing Input
	var input_dir = Input.get_axis("move_left", "move_right")
	var tangent = Vector2(-dir.y, dir.x)
	if input_dir:
		player.velocity += tangent * input_dir * SWING_FORCE * delta
	
	# Gravity
	player.velocity.y += movement.gravity * delta
	
	# Rope Constraint
	if dist > rope_length:
		var radial_vel = player.velocity.dot(dir)
		if radial_vel < 0:
			player.velocity -= dir * radial_vel
		
		# Spring correction
		var correction = (dist - rope_length) * 5.0
		player.velocity += dir * correction
	
	# Damping
	player.velocity *= 0.99

func _jump_off():
	state_machine.change_state("jump")
	# Add extra boost?
	player.velocity.y = movement.jump_force
