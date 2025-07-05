extends Area3D

# The AI's current state in the work zone. Can be set in the editor or by code.
@export var current_state: String = "IDLE"
@export var max_health: int = 10
var health: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.body_entered.connect(_on_body_entered)
	self.body_exited.connect(_on_body_exited)
	health = max_health

# Called when a body enters the area. Signal must be connected in the editor.
var ai_stopped := false
var stopped_ai = null

# Damage interval in seconds
var damage_interval := 1.0
var damage_timer := 0.0
var damage_amount := 1

func _process(delta):
	if ai_stopped and stopped_ai != null:
		damage_timer += delta
		if damage_timer >= damage_interval:
			health -= damage_amount
			print("Work zone health:", health)
			damage_timer = 0.0
			if health <= 0:
				print("Work zone destroyed!")
				queue_free()

func _on_body_entered(body):
	if "just_spawned" in body and body.just_spawned:
		return
	if ai_stopped:
		return # Only allow one AI to be stopped at a time
	print("yo")
	# Check if the body has a 'state' property (customize as needed)
	if body.has_method("get_state"):
		var ai_state = body.get_state()
		if ai_state == current_state:
			print("AI state matches work zone state: %s" % ai_state)
			# Stop AI movement
			if body.has_method("stop_movement"):
				body.stop_movement()
			# Detach from mouse if needed
			if body.has_method("detach_from_mouse"):
				body.detach_from_mouse()
			# Inform mobile_input to block this agent
			var mobile_input = get_tree().get_root().find_child("mobile_input", true, false)
			if mobile_input and "set_agent_in_workzone" in mobile_input:
				mobile_input.set_agent_in_workzone(body)
			# Snap AI to the center of the work zone
			if body.has_method("set_global_position"):
				body.global_transform.origin = global_transform.origin
			ai_stopped = true
			stopped_ai = body
			damage_timer = 0.0 # Reset timer when AI enters
		else:
			print("AI state does not match work zone state. AI: %s, Zone: %s" % [ai_state, current_state])
	else:
		print("Entered body does not have a 'get_state' method.")

func _on_body_exited(_body):
	ai_stopped = false
	stopped_ai = null
	damage_timer = 0.0
	var mobile_input = get_tree().get_root().find_child("mobile_input", true, false)
	if mobile_input and "clear_agent_in_workzone" in mobile_input:
		mobile_input.clear_agent_in_workzone()
