extends Control

@export var restart_button: TextureButton 
@export var main_menu_button: TextureButton
@export var dropdown: OptionButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	dropdown.item_selected.connect(_on_dropdown_selected)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_restart_pressed() -> void:
	var game_manager = get_tree().get_root().get_node("MainWorld") # Adjust path if needed
	game_manager.restart_level()

func _on_main_menu_pressed() -> void:
	var game_manager = get_tree().get_root().get_node("MainWorld") # Adjust path if needed
	# Unload the current level if it exists
	if game_manager.current_level_instance:
		game_manager.current_level_instance.queue_free()
		game_manager.current_level_instance = null
	if game_manager.has_method("change_state"):
		game_manager.change_state(game_manager.GameState.LEVEL_SELECT)
	self.queue_free()

func _on_dropdown_selected(index: int) -> void:
	match dropdown.get_item_text(index):
		"Resume":
			Engine.time_scale = 1.0
			get_tree().paused = false
		"Pause":
			get_tree().paused = not get_tree().paused
		"Speed Up":
			Engine.time_scale = 5.0
			get_tree().paused = false
