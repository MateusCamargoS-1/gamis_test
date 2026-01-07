class_name Enemy
extends CharacterBody2D

@onready var state_machine: StateMachine = StateMachine.new()
@onready var health: HealthComponent = HealthComponent.new()

var target: Node2D
var radius: float = 15.0

func _ready():
	add_child(health)
	
	# Create Collision Shape
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	
	add_child(state_machine)
	
	var patrol = EnemyPatrolState.new(); patrol.name = "Patrol"; state_machine.add_child(patrol)
	var chase = EnemyChaseState.new(); chase.name = "Chase"; state_machine.add_child(chase)
	
	state_machine.initial_state = patrol
	
	target = get_tree().get_first_node_in_group("player")

func _process(_delta):
	queue_redraw()

func _physics_process(_delta):
	move_and_slide()

func _draw():
	var col = Color(1.0, 0.2, 0.4)
	draw_circle(Vector2.ZERO, radius, col)
	
	# Spiky effect
	var pts = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16 + Time.get_ticks_msec() * 0.002
		var r = radius + sin(angle * 3 + Time.get_ticks_msec() * 0.01) * 5
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	pts.append(pts[0])
	draw_polyline(pts, col, 2.0)
