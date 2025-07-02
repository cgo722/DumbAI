extends Resource
class_name LevelConfig

@export var level_hash: int = 0
@export var ai_spawns: Array[Dictionary] = [] # Each dict: {position: Vector3, brain_index: int}
@export var danger_zones: Array[Vector3] = []
@export var work_zones: Array[Vector3] = []
