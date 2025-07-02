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

func spawn_level_content():
	var nav_map = nav_region.get_navigation_map()
	var nav_origin = nav_region.global_transform.origin

	# Spawn AIs
	for ai_data in level_config.ai_spawns:
		var spawn_point = ai_data["position"]
		var brain_index = ai_data["brain_index"]
		var ai_instance = ai_scene.instantiate()
		add_child(ai_instance)
		ai_instance.global_transform = Transform3D(ai_instance.global_transform.basis, spawn_point)
		ai_instance.nav_ready = true
		if ai_instance.has("ai_brain") and ai_instance.has("chosen_brain"):
			ai_instance.chosen_brain = ai_instance.ai_brain[brain_index]
			ai_instance.ai_state = ai_instance.ai_state_from_string(ai_instance.chosen_brain.ai_state_name)
		if ai_instance.has_method("set_destination"):
			var destination = get_random_navmesh_point(nav_map, nav_origin, 10.0)
			ai_instance.set_destination(destination)

	# Spawn Danger Zones
	for danger_pos in level_config.danger_zones:
		var danger_instance = danger_zone_scene.instantiate()
		add_child(danger_instance)
		danger_instance.global_transform = Transform3D(danger_instance.global_transform.basis, danger_pos)
		# Optionally randomize scale or other properties here

	# Spawn Work Zones
	for work_pos in level_config.work_zones:
		var work_instance = work_zone_scene.instantiate()
		add_child(work_instance)
		work_instance.global_transform = Transform3D(work_instance.global_transform.basis, work_pos)

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