class_name Player
extends CharacterBody2D

@onready var state_machine: StateMachine = StateMachine.new()
@onready var movement: MovementComponent = MovementComponent.new()
@onready var health: HealthComponent = HealthComponent.new()

# Visuals
var trail: Array = []
const TRI_R = 12.0
const TRI_H = 6.0
const TRI_W = 10.4

func _ready():
	# Setup Components
	add_child(movement)
	movement.body = self
	
	add_child(health)
	
	# Create Collision Shape
	var shape = CollisionShape2D.new()
	var poly = ConvexPolygonShape2D.new()
	poly.points = PackedVector2Array([
		Vector2(0, -TRI_R),
		Vector2(TRI_W, TRI_H),
		Vector2(-TRI_W, TRI_H)
	])
	shape.shape = poly
	add_child(shape)
	
	# Setup State Machine
	add_child(state_machine)
	
	# Add States
	var idle = PlayerIdleState.new(); idle.name = "Idle"; state_machine.add_child(idle)
	var walk = PlayerWalkState.new(); walk.name = "Walk"; state_machine.add_child(walk)
	var jump = PlayerJumpState.new(); jump.name = "Jump"; state_machine.add_child(jump)
	var fall = PlayerFallState.new(); fall.name = "Fall"; state_machine.add_child(fall)
	var roll = PlayerRollState.new(); roll.name = "Roll"; state_machine.add_child(roll)
	var hook = PlayerHookState.new(); hook.name = "Hook"; state_machine.add_child(hook)
	
	state_machine.initial_state = idle
	
	# Visuals
	# (In a real project, use a Sprite or AnimatedSprite)

func _process(_delta):
	queue_redraw()
	
	# Trail logic
	if velocity.length() > 100:
		trail.append(global_position)
		if trail.size() > 20: trail.pop_front()
	
func _physics_process(_delta):
	# State machine updates automatically via its own _physics_process if added to tree
	# But we need to ensure move_and_slide is called.
	# The states call movement.move(), which sets velocity.
	# We call move_and_slide here.
	move_and_slide()

func _draw():
	# Draw Trail
	if trail.size() > 1:
		var local_trail = PackedVector2Array()
		for p in trail: local_trail.append(to_local(p))
		draw_polyline(local_trail, Color(0.9, 0.9, 0.95, 0.3), 2.0)

	# Draw Player Triangle
	var pts = PackedVector2Array([
		Vector2(0, -TRI_R),
		Vector2(TRI_W, TRI_H),
		Vector2(-TRI_W, TRI_H)
	])
	
	var col = Color(0.9, 0.9, 0.95)
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.0, 1.0, 1.0), 2.0)
	
	# Draw Hook Line if active
	if state_machine.current_state and state_machine.current_state.name == "Hook":
		var hook_state = state_machine.current_state
		draw_line(Vector2.ZERO, to_local(hook_state.current_hook_pos), Color(0.0, 1.0, 1.0, 0.8), 2.0)
		draw_circle(to_local(hook_state.current_hook_pos), 4.0, Color(0.0, 1.0, 1.0))
