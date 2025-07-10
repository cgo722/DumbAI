extends Node

@export var camera: Camera3D
@export var swipe_min_distance: int = 50  # pixels

var touch_start_pos := Vector2.ZERO
var is_dragging := false
var touched_agent = null
var grabbed_agent: Node = null
var agent_in_workzone: Node = null
var drag_plane: Plane
var drag_offset: Vector3 = Vector3.ZERO

func _unhandled_input(event):
	if agent_in_workzone:
		grabbed_agent = null
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			var candidate = raycast_ai(event.position)
# Only grab if candidate is not stopped and not frozen
			if candidate and (not ("is_stopped" in candidate) or not candidate.is_stopped) and (not ("frozen" in candidate) or not candidate.frozen):
				grabbed_agent = candidate
				if "on_pickup" in grabbed_agent:
					grabbed_agent.on_pickup()
				var from = camera.project_ray_origin(event.position)
				var to = from + camera.project_ray_normal(event.position) * 1000
				drag_plane = Plane(Vector3.UP, grabbed_agent.global_transform.origin.y)
				var intersect = drag_plane.intersects_ray(from, to)
				if intersect != null:
					drag_offset = intersect - grabbed_agent.global_transform.origin
				else:
					drag_offset = Vector3.ZERO
		else:
			if grabbed_agent:
				if "on_release" in grabbed_agent:
					grabbed_agent.on_release()
				grabbed_agent = null

	elif event is InputEventScreenDrag and grabbed_agent:
		# Prevent dragging if agent is frozen
		if ("frozen" in grabbed_agent) and grabbed_agent.frozen:
			return
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000
		# Use a raycast to find the first walkable surface (floor)
		var space_state = camera.get_world_3d().direct_space_state
		var params = PhysicsRayQueryParameters3D.new()
		params.from = from
		params.to = to
		params.collision_mask = 1 << 0  # Default to layer 1 for floors, adjust if needed
		params.exclude = []
		var result = space_state.intersect_ray(params)
		if result:
			var above_floor_pos = result.position + Vector3(0, 5, 0)
			grabbed_agent.global_transform.origin = above_floor_pos
			# --- NavMesh region fix: force NavigationAgent3D to update region ---
			if "nav_agent" in grabbed_agent and grabbed_agent.nav_agent:
				grabbed_agent.nav_agent.set_navigation_map(grabbed_agent.nav_agent.get_navigation_map())
				grabbed_agent.nav_agent.set_target_position(above_floor_pos)

func raycast_ai(screen_pos: Vector2) -> Node:
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000

	var space_state = camera.get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.collision_mask = 1 << 2  # Layer 3 (0-based index)
	params.exclude = []

	var result = space_state.intersect_ray(params)
	if result:
		# do something with result
		if result.collider and result.collider.is_in_group("ai_agents"):
			return result.collider
	return null

func release_agent(agent):
	if grabbed_agent == agent:
		grabbed_agent = null

func set_agent_in_workzone(agent):
	agent_in_workzone = agent
	if grabbed_agent == agent:
		grabbed_agent = null

func clear_agent_in_workzone():
	agent_in_workzone = null
