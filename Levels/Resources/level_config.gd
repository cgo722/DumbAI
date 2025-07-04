extends Resource
class_name LevelConfig

@export var level_hash: int = 0
@export var ai_spawns: Array[Dictionary] = [] # Each dict: {position: Vector3, brain_index: int}
@export var danger_zone_count: int = 1
@export var work_zone_count: int = 1
@export var danger_zone_scales: Array[Vector3] = [] # Each Vector3 is a scale for a danger zone
@export var danger_zone_spawn_delay: float = 1.0 # seconds between spawns
@export var danger_zone_max: int = 5 # max danger zones at once
@export var work_zone_markers: Array[NodePath] = [] # NodePaths to marker nodes for work zone placement
