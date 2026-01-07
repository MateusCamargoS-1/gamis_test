class_name Platform
extends StaticBody2D

enum Type { NORMAL, MOVING, CRACKING, GHOST }

@export var type: Type = Type.NORMAL
@export var is_stable: bool = false
@export var rect: Rect2

var stability_timer: float = 0.0
var crack_time: float = 0.0
var ghost_cycle: float = 0.0
var broken: bool = false

# Moving platform vars
var start_pos: Vector2
var move_offset: Vector2
var move_speed: float = 0.0
var time_offset: float = 0.0

func _ready():
	add_to_group("platforms")
	# Create collision shape based on rect
	var shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	add_child(shape)
	
	position = rect.get_center()
	
	if not is_stable:
		process_mode = Node.PROCESS_MODE_DISABLED

func _process(delta):
	queue_redraw()
	
	if broken: return
	
	if not is_stable and stability_timer > 0:
		stability_timer -= delta
		
	match type:
		Type.MOVING:
			var time = Time.get_ticks_msec() * 0.001
			var offset = Vector2(cos(time * move_speed + time_offset), sin(time * move_speed * 0.5 + time_offset)) * move_offset
			position = start_pos + offset
			rect.position = position - rect.size / 2
			
		Type.GHOST:
			ghost_cycle += delta
			var alpha = (sin(ghost_cycle * 2.0) + 1.0) * 0.5
			if alpha < 0.2:
				process_mode = Node.PROCESS_MODE_DISABLED
			elif is_stable:
				process_mode = Node.PROCESS_MODE_INHERIT

func _draw():
	var color = Color(0.4, 0.4, 0.5, 0.2) # COL_UNSTABLE
	var thickness = 1.0
	
	if type == Type.CRACKING:
		color = Color(1.0, 0.5, 0.0, 0.5)
	elif type == Type.GHOST:
		color = Color(0.6, 0.6, 1.0, 0.3)
		
	if is_stable:
		color = Color(0.0, 1.0, 1.0) # COL_STABLE
		thickness = 3.0
		draw_rect(Rect2(-rect.size/2, rect.size), Color(color.r, color.g, color.b, 0.2), true)
	
	draw_rect(Rect2(-rect.size/2, rect.size), color, false, thickness)
