extends Control

@export var restart_button: TextureButton 
@export var dropdown: OptionButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	dropdown.item_selected.connect(_on_dropdown_selected)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_restart_pressed() -> void:
	var game_manager = get_tree().get_root().get_node("MainWorld") # Adjust path if needed
	game_manager.restart_level()

func _on_dropdown_selected(index: int) -> void:
	match dropdown.get_item_text(index):
		"Options":
			_show_options_menu()
		"Exit":
			get_tree().quit()

func _show_options_menu() -> void:
	# Implement your options menu logic here
	print("Options menu selected")
