extends Area3D

@export var health : int = 3

func on_danger_click():
	health -= 1
	scale *= 0.9  # Shrink by 10%
	if health <= 0:
		queue_free()

func _on_body_entered(_body:Node3D) -> void:
	if "just_spawned" in _body and _body.just_spawned:
		return
	_body.queue_free()  # Free the body when it enters the area
	pass # Replace with function body.


func _on_input_event(camera:Node, event:InputEvent, event_position:Vector3, normal:Vector3, shape_idx:int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		on_danger_click()
	pass # Replace with function body.
