class_name PlayerJumpState
extends PlayerState

func enter(_params: Dictionary = {}):
	movement.jump()

func physics_update(delta: float):
	if player.velocity.y > 0:
		state_machine.change_state("fall")
		return
	
	if Input.is_action_just_released("jump"):
		movement.cut_jump()
	
	# Air control
	var input = get_movement_input()
	movement.move(input, delta)
	
	# Double Jump check could go here or in a separate logic
	if Input.is_action_just_pressed("jump") and movement.jump_count < movement.max_jumps:
		movement.jump()
