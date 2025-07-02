extends Area3D

# The AI's current state in the work zone. Can be set in the editor or by code.
@export var current_state: String = "IDLE"
@export var max_health: int = 10
var health: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.body_entered.connect(_on_body_entered)
	self.body_exited.connect(_on_body_exited)
	# Create a timer for health
	score_timer = Timer.new()
	score_timer.wait_time = 1.0
	score_timer.one_shot = false
	score_timer.autostart = false
	score_timer.timeout.connect(_on_score_timer_timeout)
	add_child(score_timer)
	health = max_health


# Called when a body enters the area. Signal must be connected in the editor.
var ai_stopped := false
var score_timer: Timer = null
var stopped_ai = null

func _on_body_entered(body):
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
			score_timer.start()
		else:
			print("AI state does not match work zone state. AI: %s, Zone: %s" % [ai_state, current_state])
	else:
		print("Entered body does not have a 'get_state' method.")

func _on_body_exited(_body):
	ai_stopped = false
	stopped_ai = null
	score_timer.stop()
	var mobile_input = get_tree().get_root().find_child("mobile_input", true, false)
	if mobile_input and "clear_agent_in_workzone" in mobile_input:
		mobile_input.clear_agent_in_workzone()

func _on_score_timer_timeout():
	# Decrease health every second while AI is stopped
	health -= 1
	print("Work zone health:", health)
	if health <= 0:
		print("Work zone destroyed!")
		queue_free()
