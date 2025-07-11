extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



func _on_mainmenu_pressed() -> void:
	var game_manager = get_tree().get_root().get_node("MainWorld") # Adjust path if needed
	# Unload the current level if it exists
	if game_manager.current_level_instance:
		game_manager.current_level_instance.queue_free()
		game_manager.current_level_instance = null
	if game_manager.has_method("change_state"):
		game_manager.change_state(game_manager.GameState.LEVEL_SELECT)
	self.queue_free()
	pass # Replace with function body.

func _on_retry_pressed() -> void:
	
	pass # Replace with function body.
