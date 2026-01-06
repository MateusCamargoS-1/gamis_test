extends Node2D

# --- CONFIGURATION & CONSTANTS ---
const GRAVITY = 1200.0
const WALK_SPEED = 350.0
const JUMP_FORCE = -600.0
const HOOK_SPEED = 2500.0
const SWING_FORCE = 1500.0
const CLIMB_SPEED = 200.0
const AIR_CONTROL = 0.8
const FRICTION = 0.1
const COYOTE_TIME = 0.15
const MAX_HEALTH = 3

# Colors (Neon/Cyberpunk Palette)
const COL_FG = Color(0.9, 0.9, 0.95)
const COL_UNSTABLE = Color(0.4, 0.4, 0.5, 0.2)
const COL_STABLE = Color(0.0, 1.0, 1.0)
const COL_ENEMY = Color(1.0, 0.2, 0.4)
const COL_SHARD = Color(1.0, 0.9, 0.2)
const COL_HOOK = Color(0.0, 1.0, 1.0, 0.8)
const COL_PORTAL = Color(0.8, 0.2, 1.0)
const COL_CRACKING = Color(1.0, 0.5, 0.0) # Orange
const COL_GHOST = Color(0.6, 0.6, 1.0, 0.3)

# Biome Background Colors
const BIOME_COLORS = {
	1: Color(0.05, 0.05, 0.08),
	2: Color(0.02, 0.08, 0.05),
	3: Color(0.08, 0.02, 0.08),
	4: Color(0.1, 0.02, 0.02)
}

# --- STATE VARIABLES ---
enum State { MENU, INTRO, PLAYING, GAMEOVER }
var current_state = State.MENU
var current_level = 1
var score = 0
var high_score = 0
var health = MAX_HEALTH
var story_text = ""
var story_fade = 0.0

# Intro Animation
var intro_timer = 0.0
var intro_duration = 2.5
var portal_scale = 0.0
var menu_button_rect = Rect2()

# Player
var player: CharacterBody2D
var player_shape: CollisionShape2D
var coyote_timer = 0.0
var jump_buffer = 0.0
var jump_count = 0
const MAX_JUMPS = 2
var player_trail = []
var player_visible = true

# Rolling Mechanics
var is_rolling = false
var roll_direction = 0
var roll_pivot = Vector2()
var roll_angle_moved = 0.0
var roll_target_angle = deg_to_rad(120)
var roll_speed = 10.0 # Radians per second

# Triangle Geometry (Radius 12)
# Height from center to side = 6
# Distance from center to vertex = 12
# Side half-width = 10.392 (approx 10.4)
const TRI_R = 12.0
const TRI_H = 6.0
const TRI_W = 10.4

# Hook
var hook_active = false
var hook_target_pos = Vector2()
var hook_current_pos = Vector2()
var hook_shooting = false
var hooked_object = null
var rope_length = 0.0

# World
var platforms = []
var enemies = []
var shards = []
var particles = []
var ambient_particles = []
var cam: Camera2D
var level_end_x = 0.0
var noise = FastNoiseLite.new()

# Audio
var music_player: AudioStreamPlayer

# --- INNER CLASSES ---
class Platform:
	var body: StaticBody2D
	var shape: CollisionShape2D
	var rect: Rect2
	var is_stable: bool = false
	var stability_timer: float = 0.0
	
	# Types
	enum Type { NORMAL, MOVING, CRACKING, GHOST }
	var type = Type.NORMAL
	
	# Moving
	var start_pos: Vector2
	var move_offset: Vector2 = Vector2.ZERO
	var move_speed: float = 0.0
	var time_offset: float = 0.0
	
	# Cracking
	var crack_time: float = 0.0
	var broken: bool = false
	
	# Ghost
	var ghost_cycle: float = 0.0

class Enemy:
	var pos: Vector2
	var vel: Vector2
	var radius: float = 15.0
	var active: bool = true
	var offset_seed: float = 0.0

class Shard:
	var pos: Vector2
	var active: bool = true

# --- MAIN FUNCTIONS ---

func _ready():
	randomize()
	get_window().title = "Eco Silencioso"
	
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_strength = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	world_env.environment = env
	add_child(world_env)
	
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.zoom = Vector2(0.9, 0.9)
	add_child(cam)
	
	noise.seed = randi()
	noise.frequency = 0.01
	
	if not InputMap.has_action("ui_click"):
		InputMap.add_action("ui_click")
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		InputMap.action_add_event("ui_click", ev)

	_add_key_map("ui_left", KEY_A)
	_add_key_map("ui_right", KEY_D)
	_add_key_map("ui_up", KEY_W)
	_add_key_map("ui_down", KEY_S)
	_add_key_map("ui_accept", KEY_SPACE)
	
	_create_player()
	_init_ambient_particles()
	_load_high_score()
	_start_music()
	_set_state(State.MENU)

func _add_key_map(action, key):
	var ev = InputEventKey.new()
	ev.keycode = key
	if not InputMap.has_action(action): InputMap.add_action(action)
	InputMap.action_add_event(action, ev)

func _create_player():
	if player: player.queue_free()
	player = CharacterBody2D.new()
	player_shape = CollisionShape2D.new()
	
	# Equilateral Triangle Shape
	var pts = PackedVector2Array([
		Vector2(0, -TRI_R),          # Top
		Vector2(TRI_W, TRI_H),       # Bottom Right
		Vector2(-TRI_W, TRI_H)       # Bottom Left
	])
	var shape = ConvexPolygonShape2D.new()
	shape.points = pts
	player_shape.shape = shape
	
	player.add_child(player_shape)
	add_child(player)
	player.visible = false

func _init_ambient_particles():
	ambient_particles.clear()
	for i in range(300):
		ambient_particles.append({
			"pos": Vector2(randf_range(-1000, 1000), randf_range(-1000, 1000)),
			"vel": Vector2(randf_range(-4, 4), randf_range(-4, 4)),
			"size": randf_range(1, 3),
			"alpha": randf_range(0.1, 0.6),
			"depth": randf_range(0.1, 0.9)
		})

func _physics_process(delta):
	match current_state:
		State.MENU: _update_menu(delta)
		State.INTRO: _update_intro(delta)
		State.PLAYING: _update_playing(delta)
	queue_redraw()

func _update_menu(delta):
	cam.position.x += 60 * delta
	cam.position.y = sin(Time.get_ticks_msec() * 0.0002) * 50
	var vp_width = get_viewport_rect().size.x / cam.zoom.x
	if cam.position.x + vp_width > level_end_x: _generate_level(1, true)
	_cleanup_platforms(cam.position.x - vp_width - 500)
	_update_ambient_particles(delta)

func _update_intro(delta):
	intro_timer += delta
	if intro_timer < 1.0:
		portal_scale = ease(intro_timer, 0.5) * 1.5
		player.visible = false
	elif intro_timer < 1.5:
		portal_scale = 1.5
		player.visible = true
		player.modulate.a = (intro_timer - 1.0) * 2.0
	elif intro_timer < 2.5:
		portal_scale = 1.5 * (1.0 - (intro_timer - 1.5))
		player.modulate.a = 1.0
	else:
		current_state = State.PLAYING
		player.visible = true
		player.modulate.a = 1.0
		_play_sound(600, 0.5)
	_update_ambient_particles(delta)
	cam.position = player.global_position

func _update_playing(delta):
	_update_player(delta)
	_update_hook(delta)
	_update_enemies(delta)
	_update_world(delta)
	_check_collisions()
	_update_camera(delta)
	if player.global_position.x > level_end_x: _complete_level()
	if player.global_position.y > 1500:
		_take_damage()
		_respawn_player()

func _update_player(delta):
	# Gravity
	if not is_rolling:
		player.velocity.y += GRAVITY * delta

	# Jump Input (Can interrupt rolling)
	if Input.is_action_just_pressed("ui_accept"): jump_buffer = 0.2
	jump_buffer -= delta
	
	if jump_buffer > 0:
		if coyote_timer > 0:
			_perform_jump()
		elif jump_count < MAX_JUMPS:
			_perform_double_jump()
			
	if Input.is_action_just_released("ui_accept") and player.velocity.y < 0:
		player.velocity.y *= 0.5

	# Hook Physics
	if hook_active:
		is_rolling = false # No rolling on hook
		var to_hook = hook_target_pos - player.global_position
		var dist = to_hook.length()
		var dir = to_hook.normalized()
		
		# Climbing
		var climb_dir = Input.get_axis("ui_up", "ui_down")
		if climb_dir:
			rope_length -= climb_dir * CLIMB_SPEED * delta
			rope_length = max(rope_length, 30.0)
			
		# Swing Input
		var input_dir = Input.get_axis("ui_left", "ui_right")
		var tangent = Vector2(-dir.y, dir.x)
		if input_dir:
			player.velocity += tangent * input_dir * SWING_FORCE * delta
			
		# Rope Constraint
		if dist > rope_length:
			var radial_vel = player.velocity.dot(dir)
			if radial_vel < 0: player.velocity -= dir * radial_vel
			# Damped spring force to prevent violent snapping
			var correction = (dist - rope_length) * 5.0
			player.velocity += dir * correction
			
		# Damping
		player.velocity *= 0.99
		
		# Jump from hook
		if Input.is_action_just_pressed("ui_accept"):
			_release_hook()
			player.velocity.y = JUMP_FORCE
			jump_count = 1
			_play_sound(400, 0.1)

	# Ground Movement & Rolling
	elif not is_rolling:
		# Normal Movement
		if player.is_on_floor():
			coyote_timer = COYOTE_TIME
			jump_count = 0
			
			player.velocity.x = 0
			player.rotation = 0
			
			var input = 0
			if Input.is_action_pressed("ui_right"): input = 1
			elif Input.is_action_pressed("ui_left"): input = -1
			
			if input != 0:
				_start_roll(input)
		else:
			coyote_timer -= delta
			if coyote_timer <= 0 and jump_count == 0: jump_count = 1
			
			# Air Control
			var input = Input.get_axis("ui_left", "ui_right")
			if input:
				player.velocity.x = move_toward(player.velocity.x, input * WALK_SPEED * 0.8, WALK_SPEED * delta)
	
	else:
		# Rolling Physics
		var step_angle = roll_speed * delta
		var remaining = roll_target_angle - roll_angle_moved
		
		if step_angle > remaining:
			step_angle = remaining
			
		roll_angle_moved += step_angle
		
		# Rotate around pivot
		var current_pos = player.global_position
		var rel = current_pos - roll_pivot
		var rotated_rel = rel.rotated(step_angle * roll_direction)
		var target_pos = roll_pivot + rotated_rel
		
		# Set velocity to reach target
		player.velocity = (target_pos - current_pos) / delta
		player.rotation += step_angle * roll_direction
		
		if roll_angle_moved >= roll_target_angle:
			# Finish Roll Step
			is_rolling = false
			player.rotation = 0
			player.velocity = Vector2.ZERO
			_play_sound(100, 0.3)
			_create_pulse(player.global_position + Vector2(0, TRI_H), COL_FG)

	player.move_and_slide()
	
func _perform_jump():
	is_rolling = false # Cancel roll
	player.rotation = 0
	player.velocity.y = JUMP_FORCE
	coyote_timer = 0
	jump_buffer = 0
	jump_count = 1
	_play_sound(400, 0.1)
	_create_pulse(player.global_position, COL_FG)

func _perform_double_jump():
	is_rolling = false
	player.rotation = 0
	player.velocity.y = JUMP_FORCE * 0.9
	jump_buffer = 0
	jump_count += 1
	_play_sound(500, 0.1)
	_create_pulse(player.global_position, COL_HOOK)

func _start_roll(dir):
	is_rolling = true
	roll_direction = dir
	roll_angle_moved = 0.0
	
	# Calculate Pivot (Bottom Left or Bottom Right vertex)
	# Local offsets when rotation is 0:
	# Bottom Right: (10.4, 6)
	# Bottom Left: (-10.4, 6)
	
	var offset = Vector2(TRI_W * dir, TRI_H)
	# Apply current rotation if any (should be 0 on start)
	roll_pivot = player.global_position + offset.rotated(player.rotation)

func _update_hook(delta):
	if Input.is_action_just_pressed("ui_click"): _shoot_hook(get_global_mouse_position())
	elif Input.is_action_just_released("ui_click"): _release_hook()
	if hook_shooting:
		var speed = HOOK_SPEED * delta
		var dist = hook_current_pos.distance_to(hook_target_pos)
		if dist < speed:
			hook_current_pos = hook_target_pos
			hook_shooting = false
			_on_hook_hit()
		else:
			hook_current_pos = hook_current_pos.move_toward(hook_target_pos, speed)
	if hook_active and hooked_object:
		# Update target pos if object moved
		hook_target_pos = hooked_object.rect.get_center()

func _shoot_hook(target: Vector2):
	hook_shooting = true
	hook_active = false
	hook_current_pos = player.global_position
	var closest_dist = 99999.0
	var hit_obj = null
	for p in platforms:
		if p.broken: continue
		var expanded = p.rect.grow(40)
		if expanded.has_point(target):
			var dist = player.global_position.distance_to(p.rect.get_center())
			if dist < closest_dist:
				closest_dist = dist
				hit_obj = p
	if hit_obj:
		hook_target_pos = hit_obj.rect.get_center()
		hooked_object = hit_obj
		_play_sound(1200, 0.1) # Sharp launch sound
	else:
		var dir = (target - player.global_position).normalized()
		hook_target_pos = player.global_position + dir * 600
		hooked_object = null
		_play_sound(1200, 0.1) # Sharp launch sound (miss)

func _on_hook_hit():
	if hooked_object:
		hook_active = true
		rope_length = player.global_position.distance_to(hook_target_pos)
		rope_length = max(rope_length * 0.9, 40.0)
		_stabilize_platform(hooked_object)
		_play_sound(400, 0.2) # Solid hit sound
		_create_pulse(hook_target_pos, COL_STABLE)
		var dir = (hook_target_pos - player.global_position).normalized()
		player.velocity += dir * 250 
	else:
		hook_shooting = false

func _release_hook():
	if hook_active:
		if player.velocity.y < 0: player.velocity.y *= 1.2
	hook_active = false
	hook_shooting = false
	hooked_object = null

func _stabilize_platform(p: Platform):
	if p.is_stable: return
	for other in platforms:
		if other != p and other.is_stable:
			other.is_stable = false
			other.body.process_mode = Node.PROCESS_MODE_DISABLED
			other.stability_timer = 0.5
	p.is_stable = true
	p.body.process_mode = Node.PROCESS_MODE_INHERIT
	p.stability_timer = 1.0

func _update_enemies(delta):
	for e in enemies:
		if not e.active: continue
		var target = player.global_position
		if hook_active: target = (player.global_position + hook_target_pos) * 0.5
		e.offset_seed += delta * 2.0
		var swirl = Vector2(cos(e.offset_seed), sin(e.offset_seed)) * 50
		var dir = (target - e.pos).normalized()
		e.vel = e.vel.move_toward(dir * 180, 400 * delta)
		e.pos += (e.vel + swirl) * delta
		if hook_active:
			var closest = Geometry2D.get_closest_point_to_segment(e.pos, player.global_position, hook_target_pos)
			if e.pos.distance_to(closest) < e.radius + 15:
				_release_hook()
				e.active = false
				score += 150
				_play_sound(900, 0.2)
				_create_pulse(e.pos, COL_ENEMY)

func _update_world(delta):
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.life -= delta
		p.pos += p.vel * delta
		if p.life <= 0: particles.remove_at(i)
	_update_ambient_particles(delta)
	
	var time = Time.get_ticks_msec() * 0.001
	
	for p in platforms:
		if p.broken: continue
		
		# Stability Fade
		if not p.is_stable and p.stability_timer > 0:
			p.stability_timer -= delta
			
		# Moving Logic
		if p.type == Platform.Type.MOVING:
			var offset = Vector2(cos(time * p.move_speed + p.time_offset), sin(time * p.move_speed * 0.5 + p.time_offset)) * p.move_offset
			var new_pos = p.start_pos + offset
			p.rect.position = new_pos
			p.body.position = p.rect.get_center()
			
		# Ghost Logic
		if p.type == Platform.Type.GHOST:
			p.ghost_cycle += delta
			var alpha = (sin(p.ghost_cycle * 2.0) + 1.0) * 0.5
			if alpha < 0.2:
				p.body.process_mode = Node.PROCESS_MODE_DISABLED
			elif p.is_stable:
				p.body.process_mode = Node.PROCESS_MODE_INHERIT

func _update_ambient_particles(delta):
	var cam_pos = cam.global_position
	var vp_size = get_viewport_rect().size / cam.zoom
	var bounds = Rect2(cam_pos - vp_size/2, vp_size)
	var player_pos = player.global_position
	for p in ambient_particles:
		p.pos += p.vel * delta * p.depth
		if current_state == State.PLAYING:
			var dist = p.pos.distance_to(player_pos)
			if dist < 100:
				var dir = (p.pos - player_pos).normalized()
				p.pos += dir * (100 - dist) * 2.0 * delta
		if p.pos.x < bounds.position.x - 50: p.pos.x += bounds.size.x + 100
		if p.pos.x > bounds.end.x + 50: p.pos.x -= bounds.size.x + 100
		if p.pos.y < bounds.position.y - 50: p.pos.y += bounds.size.y + 100
		if p.pos.y > bounds.end.y + 50: p.pos.y -= bounds.size.y + 100

func _check_collisions():
	for s in shards:
		if s.active and player.global_position.distance_to(s.pos) < 30:
			s.active = false
			score += 100
			_play_sound(1200, 0.1)
			_create_pulse(s.pos, COL_SHARD)
	for e in enemies:
		if e.active and player.global_position.distance_to(e.pos) < 25:
			if player.velocity.y > 0 and player.global_position.y < e.pos.y:
				e.active = false
				player.velocity.y = -500
				score += 200
				_play_sound(800, 0.2)
				_create_pulse(e.pos, COL_ENEMY)
			else:
				_take_damage()
				_create_pulse(e.pos, COL_ENEMY)
				player.velocity = (player.global_position - e.pos).normalized() * 800

func _update_camera(delta):
	var target = player.global_position + player.velocity * 0.3
	target.y = clamp(target.y, -800, 1200)
	cam.global_position = lerp(cam.global_position, target, 5 * delta)

func _take_damage():
	health -= 1
	_play_sound(150, 0.4)
	cam.offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	if health <= 0: _game_over()

func _respawn_player():
	player.global_position -= Vector2(300, 0)
	player.velocity = Vector2.ZERO
	_release_hook()

# --- GENERATION ---

func _generate_level(level_idx, append=false):
	if not append:
		for p in platforms: p.body.queue_free()
		platforms.clear()
		enemies.clear()
		shards.clear()
		level_end_x = 0
		player.global_position = Vector2(0, 0)
		noise.seed = randi()
	
	current_level = level_idx
	var _x_cursor = level_end_x
	
	# Fixed Level 1 Design
	if level_idx == 1:
		# 1. Start Area (Safe)
		_add_platform(Rect2(-200, 100, 500, 20), true)
		
		# 2. Basic Jumps (Learning Rolling/Jumping)
		_add_platform(Rect2(400, 100, 200, 20), true)
		_add_platform(Rect2(700, 50, 200, 20), true)
		_add_platform(Rect2(1000, 100, 200, 20), true)
		
		# 3. Hook Introduction (Large Gap)
		_add_platform(Rect2(1300, -100, 100, 20), true) # Hook point high up
		_add_platform(Rect2(1600, 100, 300, 20), true) # Landing
		
		# 4. Moving Platforms (Timing)
		var p1 = _add_platform(Rect2(2000, 100, 120, 20), false)
		p1.type = Platform.Type.MOVING
		p1.start_pos = p1.rect.position
		p1.move_offset = Vector2(0, 150)
		p1.move_speed = 2.0
		
		var p2 = _add_platform(Rect2(2300, 100, 120, 20), false)
		p2.type = Platform.Type.MOVING
		p2.start_pos = p2.rect.position
		p2.move_offset = Vector2(0, -150)
		p2.move_speed = 2.0
		p2.time_offset = 1.5
		
		_add_platform(Rect2(2600, 100, 200, 20), true) # Checkpoint
		
		# 5. Challenge (Cracking + Enemies)
		var p3 = _add_platform(Rect2(2900, 100, 100, 20), true)
		p3.type = Platform.Type.CRACKING
		
		var p4 = _add_platform(Rect2(3100, 50, 100, 20), true)
		p4.type = Platform.Type.CRACKING
		
		var e1 = Enemy.new()
		e1.pos = Vector2(3100, -100)
		e1.vel = Vector2.ZERO
		enemies.append(e1)
		
		# 6. Final Stretch
		_add_platform(Rect2(3400, 100, 400, 20), true)
		
		level_end_x = 3800
		
	else:
		# Procedural Generation for other levels (simplified for now)
		_add_platform(Rect2(-200, 100, 400, 20), true)
		var x = 200
		for i in range(20):
			x += 200
			_add_platform(Rect2(x, 100 + randf_range(-50, 50), 150, 20), true)
		level_end_x = x + 200
		_add_platform(Rect2(level_end_x, 0, 300, 20), true)

func _cleanup_platforms(min_x):
	for i in range(platforms.size() - 1, -1, -1):
		if platforms[i].rect.end.x < min_x:
			platforms[i].body.queue_free()
			platforms.remove_at(i)
	for i in range(shards.size() - 1, -1, -1):
		if shards[i].pos.x < min_x: shards.remove_at(i)
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].pos.x < min_x: enemies.remove_at(i)

func _add_platform(rect: Rect2, stable: bool) -> Platform:
	var p = Platform.new()
	p.rect = rect
	p.is_stable = stable
	p.start_pos = rect.position # Default
	p.body = StaticBody2D.new()
	p.shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = rect.size
	p.shape.shape = rect_shape
	p.body.add_child(p.shape)
	p.body.position = rect.get_center()
	if not stable: p.body.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(p.body)
	platforms.append(p)
	return p

# --- DRAWING ---

func _draw():
	var vp = get_viewport_rect()
	var cam_pos = cam.global_position
	
	# Background
	var bg_col = BIOME_COLORS.get(current_level, BIOME_COLORS[1])
	draw_rect(Rect2(cam_pos - vp.size, vp.size * 2), bg_col, true)
	
	# Ambient Particles
	for p in ambient_particles:
		var col = Color(1, 1, 1, p.alpha)
		draw_circle(p.pos, p.size, col)
	
	# Grid
	var grid_size = 200.0
	var offset = Vector2(fmod(cam_pos.x, grid_size), fmod(cam_pos.y, grid_size))
	var grid_col = Color(1, 1, 1, 0.05)
	for x in range(-1, int(vp.size.x / grid_size) + 2):
		var lx = x * grid_size - offset.x + cam_pos.x - vp.size.x/2
		draw_line(Vector2(lx, cam_pos.y - vp.size.y), Vector2(lx, cam_pos.y + vp.size.y), grid_col, 1.0)
	
	# Platforms
	for p in platforms:
		if p.broken: continue
		if not Rect2(cam_pos - vp.size, vp.size*2).intersects(p.rect): continue
		
		var color = COL_UNSTABLE
		var thickness = 1.0
		
		# Type Colors
		if p.type == Platform.Type.CRACKING:
			color = COL_CRACKING
			color.a = 0.5
		elif p.type == Platform.Type.GHOST:
			color = COL_GHOST
			
		if p.is_stable:
			color = COL_STABLE
			thickness = 3.0
			if p.type == Platform.Type.CRACKING:
				color = COL_CRACKING
				# Shake effect if cracking
				if p.crack_time > 0:
					var shake = Vector2(randf_range(-1,1), randf_range(-1,1)) * (p.crack_time * 2.0)
					p.rect.position += shake
			
			draw_rect(p.rect, Color(color.r, color.g, color.b, 0.2), true)
		elif p.stability_timer > 0:
			color = COL_STABLE.lerp(COL_UNSTABLE, 1.0 - p.stability_timer)
			
		draw_rect(p.rect, color, false, thickness)
		
		# Tech details
		if p.is_stable:
			draw_line(p.rect.position, p.rect.end, color, 1.0)
			draw_line(Vector2(p.rect.position.x, p.rect.end.y), Vector2(p.rect.end.x, p.rect.position.y), color, 1.0)

	# Shards
	for s in shards:
		if s.active:
			draw_circle(s.pos, 4.0, COL_SHARD)
			draw_arc(s.pos, 8.0 + sin(Time.get_ticks_msec() * 0.005) * 3, 0, TAU, 6, COL_SHARD, 1.0)

	# Enemies
	for e in enemies:
		if e.active:
			var pts = PackedVector2Array()
			for i in range(16):
				var angle = i * TAU / 16 + Time.get_ticks_msec() * 0.002
				var r = e.radius + sin(angle * 3 + Time.get_ticks_msec() * 0.01) * 5
				pts.append(e.pos + Vector2(cos(angle), sin(angle)) * r)
			pts.append(pts[0])
			draw_polyline(pts, COL_ENEMY, 2.0)
			draw_circle(e.pos, 3.0, COL_ENEMY)

	# Player & Trail
	if current_state == State.PLAYING or current_state == State.INTRO:
		if player_trail.size() > 1 and player.visible:
			draw_polyline(PackedVector2Array(player_trail), Color(COL_FG.r, COL_FG.g, COL_FG.b, 0.3), 2.0)
			
		if player.visible:
			var p_pos = player.global_position
			var rot = player.rotation
			
			# Draw Triangle matching collider
			var pts = PackedVector2Array([
				Vector2(0, -TRI_R),
				Vector2(TRI_W, TRI_H),
				Vector2(-TRI_W, TRI_H)
			])
			
			var rotated_pts = PackedVector2Array()
			for p in pts:
				rotated_pts.append(p_pos + p.rotated(rot))
				
			var mod_col = COL_FG
			mod_col.a = player.modulate.a
			draw_colored_polygon(rotated_pts, mod_col)
			draw_polyline(rotated_pts + PackedVector2Array([rotated_pts[0]]), COL_STABLE, 2.0)
		
		if hook_active or hook_shooting:
			draw_line(player.global_position, hook_current_pos, COL_HOOK, 2.0)
			draw_circle(hook_current_pos, 4.0, COL_HOOK)
			if hook_active:
				var t = float(Time.get_ticks_msec() % 500) / 500.0
				var pulse_pos = player.global_position.lerp(hook_current_pos, t)
				draw_circle(pulse_pos, 3.0, Color.WHITE)

	# Portal Effect (Intro)
	if current_state == State.INTRO and portal_scale > 0.01:
		var center = player.global_position
		var radius = 50.0 * portal_scale
		draw_arc(center, radius, 0, TAU, 32, COL_PORTAL, 3.0)
		for i in range(8):
			var angle = i * TAU / 8 + Time.get_ticks_msec() * 0.005
			var p1 = center + Vector2(cos(angle), sin(angle)) * radius
			var p2 = center + Vector2(cos(angle + PI), sin(angle + PI)) * (radius * 0.5)
			draw_line(p1, p2, COL_PORTAL, 1.0)

	# Particles
	for p in particles:
		draw_circle(p.pos, p.life * 4.0, p.color)

	# UI
	draw_set_transform_matrix(get_canvas_transform().affine_inverse())
	var vp_size = get_viewport_rect().size
	
	if current_state == State.MENU:
		_draw_text_centered("ECO SILENCIOSO", Vector2(vp_size.x/2, vp_size.y/3), 60, COL_STABLE)
		_draw_text_centered("A última âncora da realidade", Vector2(vp_size.x/2, vp_size.y/3 + 70), 24, COL_UNSTABLE)
		
		# Start Button
		var btn_w = 200.0
		var btn_h = 50.0
		var btn_pos = Vector2(vp_size.x/2 - btn_w/2, vp_size.y/2 + 80)
		menu_button_rect = Rect2(btn_pos, Vector2(btn_w, btn_h))
		
		# Adjust mouse pos for canvas transform
		var screen_mouse = get_viewport().get_mouse_position()
		var is_hover = menu_button_rect.has_point(screen_mouse)
		
		var btn_col = COL_FG
		if is_hover: 
			btn_col = COL_STABLE
			draw_rect(menu_button_rect, Color(btn_col.r, btn_col.g, btn_col.b, 0.1), true)
			
		draw_rect(menu_button_rect, btn_col, false, 2.0)
		_draw_text_centered("INICIAR", menu_button_rect.get_center() + Vector2(0, 8), 24, btn_col)
		
	elif current_state == State.PLAYING:
		draw_string(ThemeDB.fallback_font, Vector2(30, 50), "MEMÓRIAS: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COL_SHARD)
		draw_string(ThemeDB.fallback_font, Vector2(30, 80), "ESTABILIDADE: %d" % health, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COL_ENEMY)
		
		if story_fade > 0:
			var col = COL_FG
			col.a = story_fade
			_draw_text_centered(story_text, Vector2(vp_size.x/2, vp_size.y * 0.8), 24, col)
			story_fade -= get_process_delta_time() * 0.3
			
	elif current_state == State.GAMEOVER:
		_draw_text_centered("O SILÊNCIO RETORNOU", Vector2(vp_size.x/2, vp.size.y/3), 50, COL_ENEMY)
		_draw_text_centered("Tudo o que não é lembrado, desaparece.", Vector2(vp.size.x/2, vp.size.y/2), 20, COL_FG)

func _draw_text_centered(text, pos, size, color):
	var font = ThemeDB.fallback_font
	var s = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	draw_string(font, pos - Vector2(s.x/2, -s.y/4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _create_pulse(pos, color):
	for i in range(8):
		var vel = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(50, 150)
		particles.append({ "pos": pos, "vel": vel, "life": randf_range(0.3, 0.6), "color": color })

func _game_over():
	_set_state(State.GAMEOVER)
	_play_sound(50, 1.0)
	cam.offset = Vector2.ZERO

func _set_state(new_state):
	current_state = new_state
	if new_state == State.PLAYING:
		pass 
	elif new_state == State.INTRO:
		_generate_level(1)
		score = 0
		health = MAX_HEALTH
		intro_timer = 0.0
		player.global_position = Vector2(0, 0)
		player.velocity = Vector2.ZERO
		_show_story("Aqui havia vozes. Milhões delas.\nAgora só resta o contorno do que foi observado.")
	elif new_state == State.MENU:
		_generate_level(1, true)
	elif new_state == State.GAMEOVER:
		_save_high_score()

func _complete_level():
	current_level += 1
	if current_level > 4: current_level = 1
	_generate_level(current_level)
	_play_sound(600, 0.5)
	match current_level:
		2: _show_story("Floresta Estática: A natureza esperava ser vista para crescer.\nSem olhos, ela congelou para sempre.")
		3: _show_story("Mar de Dados: Tudo o que foi escrito, compartilhado, amado...\nagora apenas dados sem leitor.")
		4: _show_story("O Núcleo: Eu sou a última memória.\nE isso é suficiente.")

func _show_story(text):
	story_text = text
	story_fade = 5.0

func _unhandled_input(event):
	if current_state == State.MENU:
		if event.is_action_pressed("ui_click"):
			if menu_button_rect.has_point(event.position):
				_set_state(State.INTRO)
		elif event.is_action_pressed("ui_accept"):
			_set_state(State.INTRO)
			
	elif current_state == State.GAMEOVER:
		if event.is_action_pressed("ui_click") or event.is_action_pressed("ui_accept"):
			_set_state(State.INTRO)

func _play_sound(hz, duration):
	var stream_player = AudioStreamPlayer.new()
	stream_player.stream = _generate_tone(hz, duration)
	stream_player.finished.connect(stream_player.queue_free)
	add_child(stream_player)
	stream_player.play()

func _generate_tone(hz, duration):
	var sample_rate = 44100
	var frame_count = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(frame_count * 2)
	for i in range(frame_count):
		var t = float(i) / sample_rate
		var sample = sin(t * hz * TAU) * (1.0 - t/duration)
		var val = int(clamp(sample * 32767, -32768, 32767))
		buffer.encode_s16(i*2, val)
	var s = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.data = buffer
	return s

func _start_music():
	if music_player:
		music_player.stop()
		music_player.queue_free()
	
	music_player = AudioStreamPlayer.new()
	var stream = load("res://sound/music1.mp3")
	if stream:
		music_player.stream = stream
		music_player.volume_db = -10
		music_player.autoplay = true
		add_child(music_player)
		music_player.play()
	else:
		print("Music file not found, skipping.")

func _save_high_score():
	var cfg = ConfigFile.new()
	cfg.set_value("game", "score", max(score, high_score))
	cfg.save("user://save.cfg")

func _load_high_score():
	var cfg = ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		high_score = cfg.get_value("game", "score", 0)
