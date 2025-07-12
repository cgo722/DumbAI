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

@export var level_hash: int = 0 # Set this per level in the editor or via code

var nav_ready := false
var jumper_jump_check_timer := 0.0
@export var jumper_jump_check_interval := 0.75 # seconds between jump checks
@export var jumper_jump_chance := .2 # 100% chance per check (for testing)

var stuck_timer := 0.0
var last_position := Vector3.ZERO
@export var stuck_threshold := 2.0  # seconds
@export var stuck_distance_threshold := 0.1  # minimal distance

var leader_agent: Node = null
var follow_time: float = 0.0
@export var max_follow_time: float = 10.0  # seconds to follow one leader

var tapped_pause_timer := 0.0
@export var tapped_pause_duration := 1.0  # seconds to stay frozen

var swipe_direction: Vector3 = Vector3.ZERO
var swipe_timer := 0.0
@export var swipe_duration := 0.5
@export var swipe_speed := 8.0

var focused_danger: Node = null

var is_stopped := false
var stopped_timer := 0.0
var stopped_interval := 0.5

var _was_on_floor := false

var is_being_held := false
var held_height := 5.0 # Height to lift the AI when picked up
var original_y := 0.0

var just_spawned := true

var frozen := false

@export var drop_marker_scene: PackedScene
var drop_marker: Node3D = null
var drop_raycast: RayCast3D = null

var gravity_enabled := true

@export var min_wander_distance: float = 4.0  # Minimum distance for wander destinations

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

func get_random_navmesh_point_anywhere() -> Vector3:
	var nav_map = nav_agent.get_navigation_map()
	if nav_map == null:
		return global_transform.origin
	# Get the navmesh bounding box (approximate)
	var aabb = nav_agent.get_parent().get_aabb() if nav_agent.get_parent().has_method("get_aabb") else null
	if aabb == null:
		return global_transform.origin
	var best_point = global_transform.origin
	var best_dist = -1.0
	var y = global_transform.origin.y
	for i in range(50):
		var rand_x = randf_range(aabb.position.x, aabb.position.x + aabb.size.x)
		var rand_z = randf_range(aabb.position.z, aabb.position.z + aabb.size.z)
		var candidate = Vector3(rand_x, y, rand_z)
		var closest = NavigationServer3D.map_get_closest_point(nav_map, candidate)
		var dist = global_transform.origin.distance_to(closest)
		if dist > chosen_brain.min_wander_distance and dist > best_dist:
			best_dist = dist
			best_point = closest
	return best_point

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



func get_nearest_danger() -> Array:
	var dangers = get_tree().get_nodes_in_group("danger")
	var nearest = null
	var min_dist = INF
	for danger in dangers:
		var dist = global_transform.origin.distance_to(danger.global_transform.origin)
		if dist < min_dist:
			min_dist = dist
			nearest = danger
	return [nearest, min_dist]

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

	# Only pick a new destination when navigation is finished or just arrived
	if nav_agent.is_navigation_finished() or global_transform.origin.distance_to(nav_agent.get_target_position()) < 0.5:
		match state:
			AIState.AIMLESS, AIState.JUMPER, AIState.THRILLSEEKER, AIState.COWARD:
				var best_distance := -1.0
				var best_destination := global_transform.origin
				for i in range(10):
					# Use a random point anywhere on the navmesh
					var candidate = get_random_navmesh_point_anywhere()
					var dist = global_transform.origin.distance_to(candidate)
					if dist > chosen_brain.min_wander_distance and dist > best_distance:
						best_distance = dist
						best_destination = candidate
				if best_distance > chosen_brain.min_wander_distance:
					destination = best_destination
					set_destination(destination)
			AIState.FOLLOWER:
				# Follower logic handled below
				pass

	match state:
		AIState.THRILLSEEKER:
			# If no focused danger or it's invalid, act like AIMLESS
			if focused_danger == null or not is_instance_valid(focused_danger):
				# AIMLESS wander logic
				var best_distance := -1.0
				var best_destination := global_transform.origin
				for i in range(10):
					var candidate = get_random_navmesh_point_anywhere()
					var dist = global_transform.origin.distance_to(candidate)
					if dist > chosen_brain.min_wander_distance and dist > best_distance:
						best_distance = dist
						best_destination = candidate
				if best_distance > chosen_brain.min_wander_distance:
					destination = best_destination
					set_destination(destination)
			else:
				var dist = global_transform.origin.distance_to(focused_danger.global_transform.origin)
				if dist < chosen_brain.detection_range:
					# Drop current destination and immediately move towards danger
					destination = focused_danger.global_transform.origin
					nav_agent.set_target_position(destination)
				else:
					focused_danger = null

			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_transform.origin)
			if direction.length() > 0.01:
				direction = direction.normalized()
			else:
				direction = Vector3.ZERO
			self.velocity.x = direction.x * chosen_brain.speed * 0.8
			self.velocity.z = direction.z * chosen_brain.speed * 0.8
		AIState.COWARD:
			# If no focused danger or it's invalid, find a new one
			if focused_danger == null or not is_instance_valid(focused_danger):
				focused_danger = null
				# Danger disappeared, pick a new random destination immediately
				var tries := 0
				while tries < 10:
					var new_destination = get_random_navmesh_point(global_transform.origin, aimless_radius)
					if global_transform.origin.distance_to(new_destination) > 1.0:
						destination = new_destination
						set_destination(destination)
						break
					tries += 1
			else:
				var dist = global_transform.origin.distance_to(focused_danger.global_transform.origin)
				if dist < chosen_brain.detection_range:
					# Run directly away from the focused danger
					var escape_direction = (global_transform.origin - focused_danger.global_transform.origin).normalized()
					var escape_pos = global_transform.origin + escape_direction * aimless_radius
					if nav_agent.get_target_position() != escape_pos:
						nav_agent.set_target_position(escape_pos)
				else:
					focused_danger = null  # Lost interest, out of range

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
				if is_on_floor():
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
				var nearest_dist = chosen_brain.detection_range + 1
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
	else:
		if not _was_on_floor:
			# Just landed, reset vertical velocity
			self.velocity.y = 0.0
	_was_on_floor = is_on_floor()

	move_and_slide()

func on_tap():
	tapped_pause_timer = tapped_pause_duration
	velocity = Vector3.ZERO

func on_swipe(direction: Vector3):
	swipe_direction = direction.normalized()
	swipe_timer = swipe_duration

func _ready():
	add_to_group("ai_agents")
	# Use level_hash to deterministically pick a brain
	if ai_brain.size() > 0:
		var hash_value = int(hash(str(level_hash)))
		var brain_index = abs(hash_value) % ai_brain.size()
		# Duplicate the brain resource so each AI gets its own instance
		chosen_brain = ai_brain[brain_index].duplicate()
		ai_state = ai_state_from_string(chosen_brain.ai_state_name)
		print("Spawning AI at:%s with brain index:%s" % [global_transform.origin, brain_index])
		print("AI state: %s, vertex_color: %s" % [ai_state, chosen_brain.vertex_color]) # Debug output
		update_mesh_color() # Ensure color is set after chosen_brain is assigned
	else:
		chosen_brain = null
		ai_state = AIState.NULL
	# Set mesh vertex color from brain
	if mesh_instance and chosen_brain:
		if mesh_instance.mesh == null:
			print("MeshInstance3D has no mesh assigned!")
		else:
			var mesh = mesh_instance.mesh
			var surface_count = mesh.get_surface_count()
			for i in range(surface_count):
				var mat = mesh_instance.get_active_material(i)
				if mat:
					var new_mat = mat.duplicate()
					new_mat.albedo_color = chosen_brain.vertex_color
					mesh_instance.set_surface_override_material(i, new_mat)
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)
	# Optionally, you can also call _check_nav_ready() after a short delay
	get_tree().create_timer(0.1).timeout.connect(_on_spawn_delay_timeout)
	# Create a RayCast3D pointing down for drop marker
	drop_raycast = RayCast3D.new()
	drop_raycast.target_position = Vector3(0, -10, 0)
	drop_raycast.enabled = true
	add_child(drop_raycast)
	# Instance custom drop marker asset if provided
	if drop_marker_scene:
		drop_marker = drop_marker_scene.instantiate()
		drop_marker.visible = false
		add_child(drop_marker)
	else:
		# Fallback: create a default disc marker
		drop_marker = MeshInstance3D.new()
		drop_marker.mesh = CylinderMesh.new()
		drop_marker.scale = Vector3(0.4, 0.01, 0.4)
		drop_marker.material_override = StandardMaterial3D.new()
		drop_marker.material_override.albedo_color = Color(0, 0, 0, 0.5)
		drop_marker.visible = false
		add_child(drop_marker)
	update_mesh_color()

func _on_nav_map_changed(nav_map_id):
	# Only set nav_ready if this is our agent's map
	if nav_agent.get_navigation_map() == nav_map_id:
		nav_ready = true

func _process(delta):
	if not nav_ready:
		return
	if self.frozen:
		velocity = Vector3.ZERO
		# Prevent dragging while frozen
		if is_being_held:
			is_being_held = false
			var pos = global_transform.origin
			pos.y = original_y
			global_transform.origin = pos
		return
	# If stopped, do not tick state
	if is_stopped:
		stopped_timer += delta
		if stopped_timer >= stopped_interval:
			maybe_resume_movement()
			stopped_timer = 0.0
		return
	if ai_state != AIState.NULL:
		tick_state(ai_state, null, delta)
	else:
		print("AI state is NULL, no action taken.")
	# Only apply gravity if enabled
	if gravity_enabled:
		if not is_on_floor():
			self.velocity.y -= gravity * delta
		else:
			if not _was_on_floor:
				# Just landed, reset vertical velocity
				self.velocity.y = 0.0
		_was_on_floor = is_on_floor()
	move_and_slide()

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

func update_mesh_color():
	if mesh_instance and chosen_brain:
		var color = Color(1,1,1)
		if chosen_brain.has_method("get"):
			var vcolor = chosen_brain.get("vertex_color")
			if typeof(vcolor) == TYPE_COLOR:
				color = vcolor
		print("AI mesh color for state %s: %s" % [ai_state, color]) # Debug output
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var new_mat = StandardMaterial3D.new()
				new_mat.albedo_color = color
				mesh_instance.set_surface_override_material(i, new_mat)

func set_ai_state(new_state):
	ai_state = new_state
	update_mesh_color()

func set_destination(target_position: Vector3) -> void:
	nav_agent.set_target_position(target_position)

func get_state():
	return chosen_brain.ai_state_name

func stop_movement():
	is_stopped = true
	stopped_timer = 0.0
	velocity = Vector3.ZERO
	# Optionally, you can also stop the NavigationAgent3D
	nav_agent.set_target_position(global_transform.origin)

func maybe_resume_movement(chance := -1.0):
	# If chance is not provided, use chosen_brain.leave_chance if it exists, else default to 0.2
	var actual_chance = chance
	if actual_chance < 0.0:
		if "leave_chance" in chosen_brain:
			actual_chance = chosen_brain.leave_chance
		else:
			actual_chance = 0.2
	if is_stopped and randf() < actual_chance:
		is_stopped = false

func detach_from_mouse():
	# If this AI is currently grabbed by mobile_input, release it
	var mobile_input = get_tree().get_root().find_child("mobile_input", true, false)
	if mobile_input and "release_agent" in mobile_input:
		mobile_input.release_agent(self)

func on_pickup():
	if self.frozen:
		return
	if not is_being_held:
		is_being_held = true
		gravity_enabled = false
		original_y = global_transform.origin.y
		var pos = global_transform.origin
		pos.y += held_height
		global_transform.origin = pos
		# Use raycast to find floor and snap marker (show marker when picked up)
		if drop_raycast and drop_marker:
			drop_raycast.global_transform.origin = global_transform.origin
			drop_raycast.force_raycast_update()
			if drop_raycast.is_colliding():
				var hit_pos = drop_raycast.get_collision_point()
				if drop_marker is Node3D:
					drop_marker.global_transform.origin = hit_pos + Vector3(0, 0.02, 0)
					drop_marker.visible = true
				elif drop_marker.has_method("set_position"):
					drop_marker.set_position(hit_pos + Vector3(0, 0.02, 0))
					drop_marker.visible = true
			else:
				print("Drop marker: Raycast did not hit the floor.")
		else:
			print("Drop marker: Raycast or marker not set up.")

func on_release():
	if is_being_held:
		is_being_held = false
		gravity_enabled = true
		# Do not snap Y position back to original_y; leave AI at dropped position
		# Hide marker when released
		if drop_marker:
			drop_marker.visible = false

func _hide_drop_marker():
	if drop_marker:
		drop_marker.visible = false

func _on_spawn_delay_timeout():
	just_spawned = false
