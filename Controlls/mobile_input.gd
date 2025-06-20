extends Node

@export var camera: Camera3D
@export var swipe_min_distance: int = 50  # pixels

var touch_start_pos := Vector2.ZERO
var is_dragging := false
var touched_agent = null
var grabbed_agent: Node = null
var drag_plane: Plane
var drag_offset: Vector3 = Vector3.ZERO

func _unhandled_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			grabbed_agent = raycast_ai(event.position)
			if grabbed_agent:
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
				grabbed_agent = null

	elif event is InputEventScreenDrag and grabbed_agent:
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000
		var intersect = drag_plane.intersects_ray(from, to)
		if intersect != null:
			var new_pos = intersect - drag_offset
			grabbed_agent.global_transform.origin = new_pos

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
