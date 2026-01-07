class_name PlayerIdleState
extends PlayerState

func enter(_params: Dictionary = {}):
	movement.move(0, 0) # Stop movement

func physics_update(delta: float):
	if not player.is_on_floor():
		state_machine.change_state("fall")
		return

	if Input.is_action_just_pressed("jump"):
		state_machine.change_state("jump")
		return

	var input = get_movement_input()
	if input != 0:
		state_machine.change_state("walk")
		return
	
	movement.move(0, delta) # Apply friction
