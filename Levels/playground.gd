extends Node3D

@export var ai_scene: PackedScene
@export var ai_count: int = 5
@export var spawn_radius: float = 10.0
@export var danger_zone_scene: PackedScene
@export var danger_zone_count: int = 1
@export var danger_spawn_radius: float = 15.0
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	if not ai_scene or not nav_region:
		push_error("AI scene or NavigationRegion3D not set!")
		return
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)

func _on_nav_map_changed(nav_map_id):
	if nav_region.get_navigation_map() == nav_map_id:
		spawn_ais()

func spawn_ais():
	var nav_map = nav_region.get_navigation_map()
	var nav_origin = nav_region.global_transform.origin

	for i in range(ai_count):
		var spawn_point = get_random_navmesh_point(nav_map, nav_origin, spawn_radius)
		var ai_instance = ai_scene.instantiate()
		add_child(ai_instance)
		ai_instance.global_transform = Transform3D(ai_instance.global_transform.basis, spawn_point)

		# Optional: mark as ready and assign destination if needed
		ai_instance.nav_ready = true

		if ai_instance.has_method("set_destination"):
			var destination = get_random_navmesh_point(nav_map, nav_origin, spawn_radius)
			ai_instance.set_destination(destination)

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


func _on_timer_timeout() -> void:
	var nav_map = nav_region.get_navigation_map()
	var nav_origin = nav_region.global_transform.origin

	for i in range(danger_zone_count):
		var spawn_point = get_random_navmesh_point(nav_map, nav_origin, danger_spawn_radius)
		var danger_instance = danger_zone_scene.instantiate()
		add_child(danger_instance)
		danger_instance.global_transform = Transform3D(danger_instance.global_transform.basis, spawn_point)

		# Apply random non-uniform scale between 0.5 and 1.5 for each axis
		var random_scale = Vector3(
			randf_range(0.5, 6.5),
			randf_range(0.5, 2.5),
			randf_range(0.5, 6.5)
		)
		danger_instance.scale = random_scale