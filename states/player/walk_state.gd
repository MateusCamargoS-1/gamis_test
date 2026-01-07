class_name PlayerWalkState
extends PlayerState

func physics_update(delta: float):
	if not player.is_on_floor():
		state_machine.change_state("fall")
		return

	if Input.is_action_just_pressed("jump"):
		state_machine.change_state("jump")
		return

	var input = get_movement_input()
	if input == 0:
		state_machine.change_state("idle")
		return
	
	movement.move(input, delta)
