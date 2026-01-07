class_name EnemyPatrolState
extends EnemyState

var move_dir: Vector2
var change_dir_timer: float = 0.0

func enter(_params: Dictionary = {}):
	_pick_random_direction()

func physics_update(delta: float):
	enemy.velocity = move_dir * 100.0
	
	change_dir_timer -= delta
	if change_dir_timer <= 0:
		_pick_random_direction()
	
	# Check for player
	if enemy.target and enemy.global_position.distance_to(enemy.target.global_position) < 300:
		state_machine.change_state("chase")

func _pick_random_direction():
	var angle = randf() * TAU
	move_dir = Vector2(cos(angle), sin(angle))
	change_dir_timer = randf_range(1.0, 3.0)
