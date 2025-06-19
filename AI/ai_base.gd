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
@export var gravity: float = 9.8

@export var ai_state: AIState = AIState.NULL

@export var ai_brain: Array[Resource] = []

@export var destination: Vector3 = Vector3.ZERO
@export var aimless_radius: float = 10.0

var nav_ready := false
var jumper_jump_check_timer := 0.0
@export var jumper_jump_check_interval := 0.75 # seconds between jump checks
@export var jumper_jump_chance := 0.15 # 40% chance per check

func get_random_navmesh_point(center: Vector3, radius: float) -> Vector3:
	var nav_map = nav_agent.get_navigation_map()
	if nav_map == null:
		return center
	var tries := 0
	while tries < 10:
		var rand_offset = Vector3(
			randf_range(-radius, radius),
			0,
			randf_range(-radius, radius)
		)
		var candidate = center + rand_offset
		var closest = NavigationServer3D.map_get_closest_point(nav_map, candidate)
		if center.distance_to(closest) <= radius:
			return closest
		tries += 1
	return center

func tick_state(state, _blob, delta):
	if state == AIState.AIMLESS:
		if global_transform.origin.distance_to(destination) < 0.5 or nav_agent.is_navigation_finished():
			var tries := 0
			while tries < 10:
				var new_destination = get_random_navmesh_point(global_transform.origin, aimless_radius)
				if global_transform.origin.distance_to(new_destination) > 1.0:
					destination = new_destination
					set_destination(destination)
					print("New AIMLESS destination: ", destination)
					break
				tries += 1

	if state == AIState.JUMPER:
		if global_transform.origin.distance_to(destination) < 0.5 or nav_agent.is_navigation_finished():
			var tries := 0
			while tries < 10:
				var new_destination = get_random_navmesh_point(global_transform.origin, aimless_radius)
				if global_transform.origin.distance_to(new_destination) > 1.0:
					destination = new_destination
					set_destination(destination)
					print("New JUMPER destination: ", destination)
					break
				tries += 1

	match state:
		AIState.THRILLSEEKER:
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			self.velocity.x = direction.x * chosen_brain.speed
			self.velocity.z = direction.z * chosen_brain.speed
		AIState.COWARD:
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			self.velocity.x = direction.x * chosen_brain.speed * 1.2
			self.velocity.z = direction.z * chosen_brain.speed * 1.2
		AIState.JUMPER:
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			self.velocity.x = direction.x * (chosen_brain.speed * 0.8)
			self.velocity.z = direction.z * (chosen_brain.speed * 0.8)
			# Time-based sporadic jump logic
			jumper_jump_check_timer += delta
			if jumper_jump_check_timer >= jumper_jump_check_interval:
				jumper_jump_check_timer = 0.0
				if is_on_floor() and randf() < jumper_jump_chance:
					self.velocity.y = chosen_brain.jump_height
					print("jump")
		AIState.AIMLESS:
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			self.velocity.x = direction.x * (chosen_brain.speed * 0.8)
			self.velocity.z = direction.z * (chosen_brain.speed * 0.8)
		AIState.FOLLOWER:
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			self.velocity.x = direction.x * chosen_brain.speed
			self.velocity.z = direction.z * chosen_brain.speed

	# Apply gravity
	if not is_on_floor():
		self.velocity.y -= gravity * delta
	# Do NOT set velocity.y = 0 here, let the jump logic handle it!

	move_and_slide()

func _ready():
	chosen_brain = ai_brain[randi_range(0, ai_brain.size() - 1)]
	ai_state = ai_state_from_string(chosen_brain.ai_state_name)
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)
	print(chosen_brain.ai_state_name)
	# Optionally, you can also call _check_nav_ready() after a short delay

func _on_nav_map_changed(nav_map_id):
	# Only set nav_ready if this is our agent's map
	if nav_agent.get_navigation_map() == nav_map_id:
		nav_ready = true

func _process(delta):
	if not nav_ready:
		return
	if ai_state != AIState.NULL:
		tick_state(ai_state, null, delta)
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

func set_destination(target_position: Vector3) -> void:
	nav_agent.set_target_position(target_position)
