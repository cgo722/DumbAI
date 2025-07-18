extends Node3D

# Level configuration resource
@export var level_config: Resource # Should be a custom LevelConfig resource

@export var ai_scene: PackedScene
@export var danger_zone_scene: PackedScene
@export var work_zone_scene: PackedScene

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	if not ai_scene or not nav_region or not level_config:
		push_error("AI scene, NavigationRegion3D, or level_config not set!")
		return
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)

func _on_nav_map_changed(nav_map_id):
	if nav_region.get_navigation_map() == nav_map_id:
		spawn_level_content()

func is_point_safe(point: Vector3, danger_positions: Array, min_distance: float) -> bool:
	for danger_pos in danger_positions:
		if point.distance_to(danger_pos) < min_distance:
			return false
	return true

func spawn_level_content():
	# Seed the random number generator for deterministic placement
	randomize()
	seed(level_config.level_hash)
	var nav_map = nav_region.get_navigation_map()
	var nav_origin = nav_region.global_transform.origin

	# Spawn AIs immediately
	for ai_data in level_config.ai_spawns:
		var spawn_point = null
		if ai_data.has("position"):
			var pos_val = ai_data["position"]
			if typeof(pos_val) == TYPE_VECTOR3:
				spawn_point = pos_val
			elif typeof(pos_val) == TYPE_NODE_PATH:
				var marker = get_node_or_null(pos_val)
				if marker:
					spawn_point = marker.global_transform.origin
				else:
					push_error("AI spawn marker not found: %s" % [pos_val])
		if typeof(spawn_point) == TYPE_VECTOR3 and ai_data.has("brain_index"):
			var brain_index = ai_data["brain_index"]
			print("Spawning AI at:", spawn_point, " with brain index:", brain_index)
			var ai_instance = ai_scene.instantiate()
			add_child(ai_instance)
			ai_instance.global_transform.origin = spawn_point
			ai_instance.nav_ready = true
			ai_instance.chosen_brain = ai_instance.ai_brain[brain_index]
			ai_instance.ai_state = ai_instance.ai_state_from_string(ai_instance.chosen_brain.ai_state_name)
			ai_instance.set_deferred("just_spawned", true)
			var timer = Timer.new()
			timer.wait_time = 0.5
			timer.one_shot = true
			timer.connect("timeout", Callable(ai_instance, "_on_spawn_delay_timeout"))
			ai_instance.add_child(timer)
			timer.start()
			if ai_instance.has_method("set_destination"):
				pass # Only set destination if you want the AI to move after spawn
				# (left intentionally blank to avoid overriding spawn position)
		else:
			push_error("ai_data missing valid spawn point (Vector3) or 'brain_index': %s" % [ai_data])

	# Start spawning Danger Zones over time (do not await)
	call_deferred("spawn_danger_zones_over_time", nav_map, nav_origin)

# Spawns danger zones one at a time with a delay and max active limit
func spawn_danger_zones_over_time(nav_map, nav_origin):
	await get_tree().create_timer(level_config.danger_zone_initial_delay).timeout
	var danger_zone_positions = []
	var active_danger_zones = []
	var total_spawned = 0
	while total_spawned < level_config.danger_zone_count:
		# Remove freed danger zones from active list
		active_danger_zones = active_danger_zones.filter(func(z): return is_instance_valid(z))
		if active_danger_zones.size() < level_config.danger_zone_max:
			var spawn_point = get_random_navmesh_point(nav_map, nav_origin, 15.0)
			var danger_instance = danger_zone_scene.instantiate()
			add_child(danger_instance)
			danger_instance.global_transform = Transform3D(danger_instance.global_transform.basis, spawn_point)
			if total_spawned < level_config.danger_zone_scales.size():
				danger_instance.scale = level_config.danger_zone_scales[total_spawned]
			danger_zone_positions.append(spawn_point)
			active_danger_zones.append(danger_instance)
			total_spawned += 1
		await get_tree().create_timer(level_config.danger_zone_spawn_delay).timeout
		# If max is reached, wait until at least one is freed
		while active_danger_zones.size() >= level_config.danger_zone_max:
			active_danger_zones = active_danger_zones.filter(func(z): return is_instance_valid(z))
			await get_tree().create_timer(0.2).timeout

func get_random_navmesh_point(nav_map, center: Vector3, radius: float) -> Vector3:
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
