extends Node2D

# --- CONFIGURATION ---
const BIOME_COLORS = {
	1: Color(0.05, 0.05, 0.08),
	2: Color(0.02, 0.08, 0.05),
	3: Color(0.08, 0.02, 0.08),
	4: Color(0.1, 0.02, 0.02)
}

# --- STATE ---
enum State { MENU, PLAYING, GAMEOVER }
var current_state = State.MENU

var player: Player
var cam: Camera2D
var ambient_particles = []
var level_end_x = 0.0

func _ready():
	randomize()
	get_window().title = "Eco Silencioso (Refactored)"
	
	# Environment
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_strength = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	world_env.environment = env
	add_child(world_env)
	
	# Camera
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.zoom = Vector2(0.9, 0.9)
	add_child(cam)
	
	_init_ambient_particles()
	
	# Setup Input Actions
	_setup_input()
	
	_set_state(State.MENU)

func _setup_input():
	# Clear existing actions to ensure clean state
	var actions = ["move_left", "move_right", "move_up", "move_down", "jump", "hook"]
	for action in actions:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)

	# Helper to add key
	var add_key = func(action, key):
		var ev = InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
		
	# Helper to add mouse
	var add_mouse = func(action, button):
		var ev = InputEventMouseButton.new()
		ev.button_index = button
		InputMap.action_add_event(action, ev)

	# Configure Keys (WASD + Arrows)
	add_key.call("move_left", KEY_A)
	add_key.call("move_left", KEY_LEFT)
	
	add_key.call("move_right", KEY_D)
	add_key.call("move_right", KEY_RIGHT)
	
	add_key.call("move_up", KEY_W)
	add_key.call("move_up", KEY_UP)
	
	add_key.call("move_down", KEY_S)
	add_key.call("move_down", KEY_DOWN)
	
	add_key.call("jump", KEY_SPACE)
	
	# Configure Mouse
	add_mouse.call("hook", MOUSE_BUTTON_LEFT)

func _process(delta):
	queue_redraw()
	_update_ambient_particles(delta)
	
	if current_state == State.PLAYING:
		if player:
			var target = player.global_position
			target.y = clamp(target.y, -800, 1200)
			cam.global_position = lerp(cam.global_position, target, 5 * delta)
			
			if player.global_position.y > 1500:
				_game_over()

func _set_state(new_state):
	current_state = new_state
	if new_state == State.PLAYING:
		_start_game()
	elif new_state == State.MENU:
		cam.position = Vector2.ZERO

func _start_game():
	# Clear old
	get_tree().call_group("entities", "queue_free")
	if player: player.queue_free()
	
	# Create Player
	player = Player.new()
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector2(0, 0)
	
	_generate_level(1)

func _generate_level(_level_idx):
	# Clear existing platforms/enemies
	for c in get_children():
		if c is Platform or c is Enemy:
			c.queue_free()
			
	# Level 1 Design
	_spawn_platform(Rect2(-200, 100, 500, 20), true)
	_spawn_platform(Rect2(400, 100, 200, 20), true)
	_spawn_platform(Rect2(700, 50, 200, 20), true)
	
	# Hook point
	_spawn_platform(Rect2(1000, -100, 100, 20), true)
	_spawn_platform(Rect2(1300, 100, 300, 20), true)
	
	# Enemy
	var e = Enemy.new()
	e.position = Vector2(1400, 50)
	add_child(e)

func _spawn_platform(rect: Rect2, stable: bool):
	var p = Platform.new()
	p.rect = rect
	p.is_stable = stable
	add_child(p)

func _init_ambient_particles():
	for i in range(200):
		ambient_particles.append({
			"pos": Vector2(randf_range(-1000, 1000), randf_range(-1000, 1000)),
			"vel": Vector2(randf_range(-4, 4), randf_range(-4, 4)),
			"size": randf_range(1, 3),
			"alpha": randf_range(0.1, 0.6)
		})

func _update_ambient_particles(delta):
	var bounds = Rect2(cam.global_position - get_viewport_rect().size, get_viewport_rect().size * 2)
	for p in ambient_particles:
		p.pos += p.vel * delta
		if not bounds.has_point(p.pos):
			p.pos = bounds.position + Vector2(randf() * bounds.size.x, randf() * bounds.size.y)

func _draw():
	var vp = get_viewport_rect()
	var cam_pos = cam.global_position
	
	# Background
	draw_rect(Rect2(cam_pos - vp.size, vp.size * 2), BIOME_COLORS[1], true)
	
	# Particles
	for p in ambient_particles:
		draw_circle(p.pos, p.size, Color(1, 1, 1, p.alpha))
		
	# UI
	draw_set_transform_matrix(get_canvas_transform().affine_inverse())
	if current_state == State.MENU:
		draw_string(ThemeDB.fallback_font, Vector2(vp.size.x/2 - 100, vp.size.y/2), "PRESS SPACE TO START", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
	elif current_state == State.GAMEOVER:
		draw_string(ThemeDB.fallback_font, Vector2(vp.size.x/2 - 100, vp.size.y/2), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color.RED)

func _unhandled_input(event):
	if event.is_action_pressed("jump"):
		if current_state == State.MENU or current_state == State.GAMEOVER:
			_set_state(State.PLAYING)

func _game_over():
	current_state = State.GAMEOVER
