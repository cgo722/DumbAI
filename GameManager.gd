extends Node

enum GameState {
	PLAYING,
	GAME_OVER,
	MAINMENU
}
var game_state : GameState = GameState.MAINMENU
var score : int = 0
var high_score : int = 0
@export var player : PackedScene
@export var employee : PackedScene
@export var mainMenu : PackedScene
@export var gameOver : PackedScene
@export var pauseMenu : PackedScene
@export var levels : Array[PackedScene] = []

func _ready():
	# Initialize the game state
	change_state(GameState.MAINMENU)
	score = 0
	high_score = 0


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
	score = 0
	# Spawn the first level from levels[0]
	if levels.size() > 0 and levels[0]:
		var level_instance = levels[0].instantiate()
		add_child(level_instance)

func show_game_over() -> void:
	print("Game over")
	if score > high_score:
		high_score = score
	# Load or instantiate gameOver scene here if needed
