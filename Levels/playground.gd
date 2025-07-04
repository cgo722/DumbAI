extends Node3D

# Level configuration resource
@export var level_config: Resource # Should be a custom LevelConfig resource

@export var ai_scene: PackedScene
@export var danger_zone_scene: PackedScene
@export var work_zone_scene: PackedScene

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

var work_zone_respawn_delay := 2.0 # seconds to wait before respawning a work zone
var active_work_zones := {}
var available_work_zone_slots := []

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

	# Start spawning Danger Zones over time (do not await)
	spawn_danger_zones_over_time(nav_map, nav_origin)

	# Spawn Work Zones using marker nodes if provided
	if "work_zone_markers" in level_config and level_config.work_zone_markers.size() > 0:
		available_work_zone_slots = level_config.work_zone_markers.duplicate()
		active_work_zones.clear()
		for i in range(min(level_config.work_zone_count, available_work_zone_slots.size())):
			_spawn_work_zone_at_marker_slot(i)
	else:
		# Fallback: random spawn if no markers
		for i in range(level_config.work_zone_count):
			var spawn_point = get_random_navmesh_point(nav_map, nav_origin, 15.0)
			var work_instance = work_zone_scene.instantiate()
			add_child(work_instance)
			work_instance.global_transform = Transform3D(work_instance.global_transform.basis, spawn_point)
			# Set scale if provided
			if i < level_config.work_zone_scales.size():
				work_instance.scale = level_config.work_zone_scales[i]

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

func _spawn_work_zone_at_marker_slot(slot_idx):
	if slot_idx >= available_work_zone_slots.size():
		return
	var marker_path = available_work_zone_slots[slot_idx]
	var marker = get_node_or_null(marker_path)
	if marker:
		var work_instance = work_zone_scene.instantiate()
		add_child(work_instance)
		work_instance.global_transform = Transform3D(work_instance.global_transform.basis, marker.global_transform.origin)
		work_instance.scale = marker.scale
		active_work_zones[marker_path] = work_instance
		work_instance.connect("tree_exited", Callable(self, "_on_work_zone_completed").bind(marker_path))
	else:
		push_error("Work zone marker not found: %s" % [marker_path])

func _on_work_zone_completed(marker_path):
	if marker_path in active_work_zones:
		active_work_zones.erase(marker_path)
		# Wait, then respawn if under max count
		call_deferred("_delayed_respawn_work_zone", marker_path)

func _delayed_respawn_work_zone(marker_path):
	await get_tree().create_timer(work_zone_respawn_delay).timeout
	if marker_path in available_work_zone_slots and not active_work_zones.has(marker_path):
		if active_work_zones.size() < level_config.work_zone_count:
			_spawn_work_zone_at_marker_slot(available_work_zone_slots.find(marker_path))

# Spawns danger zones one at a time with a delay and max active limit
func spawn_danger_zones_over_time(nav_map, nav_origin):
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
