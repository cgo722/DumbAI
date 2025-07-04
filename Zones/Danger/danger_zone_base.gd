extends Area3D

@export var health : int = 3
@export var freeze_duration : float = 2.0 # seconds to freeze AI/player

func on_danger_click():
	health -= 1
	scale *= 0.9  # Shrink by 10%
	if health <= 0:
		queue_free()

func _on_body_entered(_body:Node3D) -> void:
	if "just_spawned" in _body and _body.just_spawned:
		return
	# Freeze AI or player for a few seconds instead of destroying
	if "frozen" in _body and not _body.frozen:
		_body.frozen = true
		var timer = Timer.new()
		timer.wait_time = freeze_duration
		timer.one_shot = true
		timer.connect("timeout", Callable(self, "_on_unfreeze_body").bind(_body))
		add_child(timer)
		timer.start()
	elif _body.has_method("freeze"):
		_body.freeze(freeze_duration)
	# Optionally, handle player-specific logic here if needed
	# (e.g., emit signal or call method to disable input)
	# pass

func _on_unfreeze_body(_body):
	if is_instance_valid(_body):
		_body.frozen = false

func _on_input_event(_camera:Node, event:InputEvent, _event_position:Vector3, _normal:Vector3, _shape_idx:int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		on_danger_click()
	pass # Replace with function body.
