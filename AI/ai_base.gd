extends CharacterBody3D

enum AIState {
	COWARD,
	JUMPER,
	THRILLSEEKER,
	AIMLESS,
	FOLLOWER,
	NULL
}

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var chosen_brain: Resource
@export var speed: float = 3.0

@export var ai_state: AIState = AIState.NULL

@export var ai_brain: Array[Resource] = []


func tick_state(state, _blob, _delta):
	if nav_agent.is_navigation_finished():
		return

	match state:
		AIState.THRILLSEEKER:
			print("Thrillseeker state active")
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			var velocity = direction * chosen_brain.speed
			move_and_slide()
		AIState.COWARD:
			print("Coward state active")
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			var velocity = direction * chosen_brain.speed * 1.2  # example: cowards move faster
			move_and_slide()
		AIState.JUMPER:
			print("Jumper state active")
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			var velocity = direction * chosen_brain.speed
			move_and_slide()
		AIState.AIMLESS:
			print("Aimless state active")
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			var velocity = direction * (chosen_brain.speed * 0.8)
			move_and_slide()
		AIState.FOLLOWER:
			print("Follower state active")
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			var velocity = direction * chosen_brain.speed
			move_and_slide()

func _ready():
	chosen_brain = ai_brain[randi_range(0, ai_brain.size() - 1)]
	ai_state = ai_state_from_string(chosen_brain.ai_state_name)
	
func _process(_delta):
	if ai_state != AIState.NULL:
		tick_state(ai_state, null, _delta)
	else:
		print("AI state is NULL, no action taken.")
	pass

func ai_state_from_string(state_name: String) -> AIState:
	match state_name.to_upper():
		"COWARD":
			return AIState.COWARD
		"JUMPER":
			return AIState.JUMPER
		"THRILLSEEKER":
			return AIState.THRILLSEEKER
		"AIMLESS":
			return AIState.AIMLESS
		"FOLLOWER":
			return AIState.FOLLOWER
		_:
			return AIState.NULL
