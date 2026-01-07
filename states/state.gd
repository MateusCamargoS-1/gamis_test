class_name State
extends Node

var state_machine: StateMachine
var entity: CharacterBody2D # Assuming CharacterBody2D for now, can be generic Node2D

func setup():
	pass

func enter(_params: Dictionary = {}):
	pass

func exit():
	pass

func update(_delta: float):
	pass

func physics_update(_delta: float):
	pass

func handle_input(_event: InputEvent):
	pass
