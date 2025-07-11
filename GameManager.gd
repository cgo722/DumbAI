extends Node

enum GameState {
	PLAYING,
	GAME_OVER,
	MAINMENU,
	WIN,
	LEVEL_SELECT
}
var game_state : GameState = GameState.MAINMENU
@export var player : PackedScene
@export var employee : PackedScene
@export var mainMenu : PackedScene
@export var gameOver : PackedScene
@export var pauseMenu : PackedScene
@export var levels : Array[PackedScene] = []
@export var hud : PackedScene
@export var winScreen : PackedScene # Add this in the editor
@export var levelSelect : PackedScene # Add this in the editor
var current_level_instance: Node = null
var current_hud_instance: Node = null
var current_win_instance: Node = null
var current_level_select_instance: Node = null


func _ready():
	# Initialize the game state
	change_state(GameState.MAINMENU)

# State machine functions
func change_state(new_state: GameState) -> void:
	game_state = new_state
	match game_state:
		GameState.MAINMENU:
			show_main_menu()
		GameState.LEVEL_SELECT:
			show_level_select()
		GameState.PLAYING:
			start_game()
		GameState.GAME_OVER:
			show_game_over()
		GameState.WIN:
			show_win_screen()

func show_main_menu() -> void:
	print("Showing main menu")
	if mainMenu:
		var menu_instance = mainMenu.instantiate()
		menu_instance.connect("start_game", Callable(self, "_on_main_menu_start_game"))
		add_child(menu_instance)

func _on_main_menu_start_game():
	change_state(GameState.LEVEL_SELECT)

func show_level_select() -> void:
	print("Showing level select")
	if levelSelect:
		current_level_select_instance = levelSelect.instantiate()
		current_level_select_instance.connect("level_selected", Callable(self, "_on_level_selected"))
		add_child(current_level_select_instance)

func _on_level_selected(level_index):
	if current_level_select_instance:
		current_level_select_instance.queue_free()
	current_level_select_instance = null
	# Store selected level index for use in start_game
	_selected_level_index = level_index
	change_state(GameState.PLAYING)

var _selected_level_index := 0

func start_game() -> void:
	print("Starting game")
	# Remove previous HUD, win screen, and level select if they exist
	if current_hud_instance:
		current_hud_instance.queue_free()
	if current_win_instance:
		current_win_instance.queue_free()
	if current_level_select_instance:
		current_level_select_instance.queue_free()
	# Spawn HUD
	current_hud_instance = hud.instantiate()
	add_child(current_hud_instance)
	# Spawn the selected level
	if levels.size() > _selected_level_index and levels[_selected_level_index]:
		current_level_instance = levels[_selected_level_index].instantiate()
		add_child(current_level_instance)
		# Listen for work zone destroyed signal
		if current_level_instance.has_signal("work_zone_destroyed"):
			current_level_instance.connect("work_zone_destroyed", Callable(self, "_on_work_zone_destroyed"))

func show_game_over() -> void:
	print("Game over")
	if gameOver:
		var game_over_instance = gameOver.instantiate()
		add_child(game_over_instance)

func show_win_screen() -> void:
	print("You win!")
	if winScreen:
		current_win_instance = winScreen.instantiate()
		add_child(current_win_instance)

func restart_level() -> void:
	print("Restarting level")
	if current_level_instance:
		current_level_instance.queue_free()
	# Respawn the current level (using _selected_level_index)
	if levels.size() > _selected_level_index and levels[_selected_level_index]:
		current_level_instance = levels[_selected_level_index].instantiate()
		add_child(current_level_instance)
	# Optionally reset other variables as needed

# Called when a work zone is destroyed in the level
var work_zones_remaining := 0
func _on_work_zone_destroyed():
	work_zones_remaining -= 1
	if work_zones_remaining <= 0:
		change_state(GameState.WIN)
		show_win_screen()

func lose_level():
	print("Player lost the level!")
	change_state(GameState.GAME_OVER)
