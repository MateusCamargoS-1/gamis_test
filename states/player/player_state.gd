class_name PlayerState
extends State

var player: Player
var movement: MovementComponent

func setup():
	player = entity as Player
	movement = player.movement

func get_movement_input() -> float:
	return Input.get_axis("move_left", "move_right")

func handle_input(event: InputEvent):
	if event.is_action_pressed("hook"):
		_try_hook(player.get_global_mouse_position())

func _try_hook(target_pos: Vector2):
	var closest_dist = 99999.0
	var hit_obj = null
	
	# Find closest platform to mouse click
	for p in player.get_tree().get_nodes_in_group("platforms"):
		if "broken" in p and p.broken: continue
		if "rect" in p:
			# Check if click is near platform (using a generous hit area)
			var expanded = p.rect.grow(40)
			if expanded.has_point(target_pos):
				var dist = player.global_position.distance_to(p.rect.get_center())
				if dist < closest_dist:
					closest_dist = dist
					hit_obj = p
	
	if hit_obj:
		state_machine.change_state("hook", {
			"target_pos": hit_obj.rect.get_center(),
			"target_obj": hit_obj
		})
	else:
		# Optional: Shoot hook into void (visual only) or fail
		pass
