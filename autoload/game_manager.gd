extends Node

var score: int = 0
var high_score: int = 0
var current_level: int = 1

func _ready():
	_load_high_score()

func add_score(amount: int):
	score += amount
	if score > high_score:
		high_score = score
		_save_high_score()

func _save_high_score():
	var cfg = ConfigFile.new()
	cfg.set_value("game", "score", high_score)
	cfg.save("user://save.cfg")

func _load_high_score():
	var cfg = ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		high_score = cfg.get_value("game", "score", 0)
