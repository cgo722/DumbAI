extends Node

enum GameState {
	PLAYING,
	GAME_OVER,
	MAINMENU
}
var game_state : GameState = GameState.MAINMENU
@export var player : PackedScene
@export var employee : PackedScene
@export var mainMenu : PackedScene
@export var gameOver : PackedScene
@export var pauseMenu : PackedScene
@export var levels : Array[PackedScene] = []
@export var hud : PackedScene
var current_level_instance: Node = null
var current_hud_instance: Node = null

func _ready():
	# Initialize the game state
	change_state(GameState.MAINMENU)


# State machine functions
func change_state(new_state: GameState) -> void:
	game_state = new_state
	match game_state:
		GameState.MAINMENU:
			show_main_menu()
		GameState.PLAYING:
			start_game()
		GameState.GAME_OVER:
			show_game_over()

func show_main_menu() -> void:
	print("Showing main menu")
	if mainMenu:
		var menu_instance = mainMenu.instantiate()
		menu_instance.connect("start_game", Callable(self, "_on_main_menu_start_game"))
		add_child(menu_instance)

func _on_main_menu_start_game():
	change_state(GameState.PLAYING)

func start_game() -> void:
	print("Starting game")
	# Remove previous HUD and level if they exist
	if current_hud_instance:
		current_hud_instance.queue_free()
	if current_level_instance:
		current_level_instance.queue_free()
	# Spawn HUD
	current_hud_instance = hud.instantiate()
	add_child(current_hud_instance)
	# Spawn the first level from levels[0]
	if levels.size() > 0 and levels[0]:
		current_level_instance = levels[0].instantiate()
		add_child(current_level_instance)

func show_game_over() -> void:
	print("Game over")
	# Load or instantiate gameOver scene here if needed

func restart_level() -> void:
	print("Restarting level")
	if current_level_instance:
		current_level_instance.queue_free()
	# Respawn the current level (assuming levels[0] for now)
	if levels.size() > 0 and levels[0]:
		current_level_instance = levels[0].instantiate()
		add_child(current_level_instance)
	# Optionally reset other variables as needed
