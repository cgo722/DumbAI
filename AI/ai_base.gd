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

@export var mesh_instance: MeshInstance3D

var nav_ready := false
var jumper_jump_check_timer := 0.0
@export var jumper_jump_check_interval := 0.75 # seconds between jump checks
@export var jumper_jump_chance := 0.15 # 40% chance per check

var stuck_timer := 0.0
var last_position := Vector3.ZERO
@export var stuck_threshold := 2.0  # seconds
@export var stuck_distance_threshold := 0.1  # minimal distance

var leader_agent: Node = null
var follow_time: float = 0.0
@export var max_follow_time: float = 10.0  # seconds to follow one leader
@export var follow_search_radius: float = 20.0  # max distance to look for leaders

var tapped_pause_timer := 0.0
@export var tapped_pause_duration := 1.0  # seconds to stay frozen

var swipe_direction: Vector3 = Vector3.ZERO
var swipe_timer := 0.0
@export var swipe_duration := 0.5
@export var swipe_speed := 8.0

func get_random_navmesh_point(center: Vector3, radius: float) -> Vector3:
	var nav_map = nav_agent.get_navigation_map()
	if nav_map == null:
		return center

	var tries := 0
	while tries < 20:
		# Pick a random point inside a circle in XZ plane
		var angle = randf() * TAU
		var distance = sqrt(randf()) * radius  # sqrt for uniform distribution inside circle
		var rand_x = cos(angle) * distance
		var rand_z = sin(angle) * distance

		var candidate = center + Vector3(rand_x, 0, rand_z)
		var closest = NavigationServer3D.map_get_closest_point(nav_map, candidate)

		# Check if closest is within a small threshold from candidate
		if closest.distance_to(candidate) < 1.0:
			return closest

		tries += 1
	return center  # fallback if no valid point found

func check_stuck(delta):
	if global_transform.origin.distance_to(last_position) < stuck_distance_threshold:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	last_position = global_transform.origin

	if stuck_timer > stuck_threshold:
		stuck_timer = 0.0
		var new_destination = get_random_navmesh_point(global_transform.origin, aimless_radius)
		set_destination(new_destination)
		nav_agent.set_target_position(new_destination)

func tick_state(state, _blob, delta):
	# TAP: freeze movement temporarily
	if tapped_pause_timer > 0:
		tapped_pause_timer -= delta
		velocity = Vector3.ZERO
		return

	# SWIPE: override normal AI movement
	if swipe_timer > 0:
		swipe_timer -= delta
		velocity = swipe_direction * swipe_speed
		move_and_slide()
		return

	check_stuck(delta)
	if state == AIState.AIMLESS:
		if nav_agent.is_navigation_finished() or global_transform.origin.distance_to(nav_agent.get_target_position()) < 0.5:
			var tries := 0
			while tries < 10:
				var new_destination = get_random_navmesh_point(global_transform.origin, aimless_radius)
				if global_transform.origin.distance_to(new_destination) > 1.0:
					destination = new_destination
					set_destination(destination)
					nav_agent.set_target_position(destination)
					break
				tries += 1

	if state == AIState.JUMPER:
		if nav_agent.is_navigation_finished() or global_transform.origin.distance_to(nav_agent.get_target_position()) < 0.5:
			var tries := 0
			while tries < 10:
				var new_destination = get_random_navmesh_point(global_transform.origin, aimless_radius)
				if global_transform.origin.distance_to(new_destination) > 1.0:
					destination = new_destination
					set_destination(destination)
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
		AIState.AIMLESS:
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin).normalized()
			self.velocity.x = direction.x * (chosen_brain.speed * 0.8)
			self.velocity.z = direction.z * (chosen_brain.speed * 0.8)
		AIState.FOLLOWER:
			follow_time += delta

			if leader_agent == null or follow_time > max_follow_time or not is_instance_valid(leader_agent):
				leader_agent = null
				var agents = get_tree().get_nodes_in_group("ai_agents")
				var nearest_dist = follow_search_radius + 1
				for agent in agents:
					if agent == self:
						continue
					if agent.ai_state == AIState.FOLLOWER:
						continue
					var dist = global_transform.origin.distance_to(agent.global_transform.origin)
					if dist < nearest_dist:
						nearest_dist = dist
						leader_agent = agent
				follow_time = 0.0

			if leader_agent != null:
				var target_pos = leader_agent.global_transform.origin
				nav_agent.set_target_position(target_pos)

				var next_pos = nav_agent.get_next_path_position()
				var direction = (next_pos - global_transform.origin).normalized()
				self.velocity.x = direction.x * chosen_brain.speed
				self.velocity.z = direction.z * chosen_brain.speed
			else:
				self.velocity = Vector3.ZERO

	# Apply gravity
	if not is_on_floor():
		self.velocity.y -= gravity * delta
	# Do NOT set velocity.y = 0 here, let the jump logic handle it!

	move_and_slide()

func on_tap():
	tapped_pause_timer = tapped_pause_duration
	velocity = Vector3.ZERO

func on_swipe(direction: Vector3):
	swipe_direction = direction.normalized()
	swipe_timer = swipe_duration

func _ready():
	add_to_group("ai_agents")
	chosen_brain = ai_brain[randi_range(0, ai_brain.size() - 1)]
	ai_state = ai_state_from_string(chosen_brain.ai_state_name)
	# Set mesh vertex color from brain
	if mesh_instance:
		if mesh_instance.mesh == null:
			print("MeshInstance3D has no mesh assigned!")
		else:
			var mesh = mesh_instance.mesh
			var surface_count = mesh.get_surface_count()
			print("Mesh has ", surface_count, " surface(s)")

			for i in range(surface_count):
				var mat = mesh_instance.get_active_material(i)
				if mat:
					print("Modifying material on surface ", i, ": ", mat)
					var new_mat = mat.duplicate()
					new_mat.albedo_color = chosen_brain.vertex_color
					mesh_instance.set_surface_override_material(i, new_mat)
				else:
					print("No material found on surface ", i)
	else:
		print("MeshInstance3D is not assigned!")
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)
	
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
