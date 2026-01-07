class_name PlayerFallState
extends PlayerState

func physics_update(delta: float):
	if player.is_on_floor():
		state_machine.change_state("idle")
		return
	
	# Air control
	var input = get_movement_input()
	movement.move(input, delta)

	# Double Jump check
	if Input.is_action_just_pressed("jump") and movement.jump_count < movement.max_jumps:
		state_machine.change_state("jump")
