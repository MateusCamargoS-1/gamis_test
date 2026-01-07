class_name StateMachine
extends Node

signal state_changed(current_state, previous_state)

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready():
	# Wait for the parent (Player/Enemy) to be fully ready
	# This ensures that all states added via code in the parent's _ready() 
	# are present as children before we iterate them.
	var parent = get_parent()
	if not parent.is_node_ready():
		await parent.ready
		
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.entity = parent
			child.setup()
	
	if initial_state:
		change_state(initial_state.name.to_lower())

func _physics_process(delta):
	if current_state:
		current_state.physics_update(delta)

func _process(delta):
	if current_state:
		current_state.update(delta)

func _unhandled_input(event):
	if current_state:
		current_state.handle_input(event)

func change_state(state_name: String, params: Dictionary = {}):
	var new_state = states.get(state_name.to_lower())
	if not new_state:
		push_warning("State not found: " + state_name)
		return
		
	if current_state == new_state:
		return
		
	var previous_state = current_state
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter(params)
	emit_signal("state_changed", current_state, previous_state)
