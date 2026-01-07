class_name PlayerRollState
extends PlayerState

var roll_direction: int = 0
var roll_pivot: Vector2
var roll_angle_moved: float = 0.0
var roll_target_angle: float = deg_to_rad(120)
var roll_speed: float = 10.0 # Radians per second

# Triangle geometry constants (from original code)
const TRI_R = 12.0
const TRI_H = 6.0
const TRI_W = 10.4

func enter(params: Dictionary = {}):
	roll_direction = params.get("direction", 1)
	roll_angle_moved = 0.0
	
	# Calculate Pivot
	var offset = Vector2(TRI_W * roll_direction, TRI_H)
	roll_pivot = player.global_position + offset.rotated(player.rotation)
	
	player.velocity = Vector2.ZERO # Reset velocity for controlled roll

func physics_update(delta: float):
	var step_angle = roll_speed * delta
	var remaining = roll_target_angle - roll_angle_moved
	
	if step_angle > remaining:
		step_angle = remaining
		
	roll_angle_moved += step_angle
	
	# Rotate around pivot
	var current_pos = player.global_position
	var rel = current_pos - roll_pivot
	var rotated_rel = rel.rotated(step_angle * roll_direction)
	var target_pos = roll_pivot + rotated_rel
	
	# Set velocity to reach target (kinematic movement via velocity)
	player.velocity = (target_pos - current_pos) / delta
	player.rotation += step_angle * roll_direction
	
	if roll_angle_moved >= roll_target_angle:
		state_machine.change_state("idle")
		player.rotation = 0
		player.velocity = Vector2.ZERO
		# Play sound/effect here
