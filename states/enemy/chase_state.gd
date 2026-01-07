class_name EnemyChaseState
extends EnemyState

func physics_update(delta: float):
	if not enemy.target:
		state_machine.change_state("patrol")
		return
		
	var dir = (enemy.target.global_position - enemy.global_position).normalized()
	enemy.velocity = enemy.velocity.move_toward(dir * 180, 400 * delta)
	
	if enemy.global_position.distance_to(enemy.target.global_position) > 500:
		state_machine.change_state("patrol")
