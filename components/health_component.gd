class_name HealthComponent
extends Node

signal health_changed(current, max)
signal died

@export var max_health: int = 3
var current_health: int

func _ready():
	current_health = max_health

func take_damage(amount: int):
	current_health -= amount
	emit_signal("health_changed", current_health, max_health)
	if current_health <= 0:
		emit_signal("died")

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)
