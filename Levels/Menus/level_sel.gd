extends Control

signal level_selected(level_index)

@onready var grid_container := $GridContainer # Make sure your GridContainer node is named 'GridContainer'

func _ready() -> void:
	var game_manager = get_tree().get_root().find_child("GameManager", true, false)
	if not game_manager:
		game_manager = get_tree().get_root().find_child("MainWorld", true, false)
	if not game_manager:
		push_error("GameManager not found!")
		return
	if not grid_container:
		push_error("GridContainer node not found! Make sure you have a node named 'GridContainer' in your scene.")
		return
	var levels = game_manager.levels
	for i in range(levels.size()):
		var btn = Button.new()
		btn.text = "Level %d" % (i + 1)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		btn.custom_minimum_size.y = 64
		btn.pressed.connect(_on_level_button_pressed.bind(i))
		grid_container.add_child(btn)

func _on_level_button_pressed(level_index):
	emit_signal("level_selected", level_index)
