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
	# Load or instantiate mainMenu scene here if needed

func start_game() -> void:
	print("Starting game")
	score = 0
	# Load or instantiate player and employee scenes here if needed

func show_game_over() -> void:
	print("Game over")
	if score > high_score:
		high_score = score
	# Load or instantiate gameOver scene here if needed
