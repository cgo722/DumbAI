extends Area3D

# The AI's brain resource in the work zone. Can be set in the editor or by code.
@export var brain_resource: Resource
@export var max_health: float = 20.0
@export var min_health: float = 0.0
var health: float
var gameover: bool = false
@onready var visual_mesh := $CSGBox3D

var default_color := Color(1,1,1,1)

# UI health bar reference (assumes a child Control named HealthBar2D with a TextureProgressBar)
@onready var health_bar := $HealthBar2D/TextureProgressBar
@onready var health_bar_2d := $HealthBar2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.body_entered.connect(_on_body_entered)
	self.body_exited.connect(_on_body_exited)
	health = 10.0 # Start at midpoint
	if health_bar_2d:
		health_bar_2d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if health_bar:
		health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	default_color = visual_mesh.material_override.albedo_color if visual_mesh.material_override else Color(1,1,1,1)
	update_zone_color()
	update_health_bar()

func update_zone_color():
	if brain_resource:
		_set_visual_color(brain_resource.vertex_color)
	else:
		_set_visual_color(default_color)

func _set_visual_color(color: Color):
	if visual_mesh:
		var new_mat := StandardMaterial3D.new()
		new_mat.albedo_color = color
		visual_mesh.material_override = new_mat

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Update health bar position to hover above the work zone and face camera
	if health_bar_2d:
		var cam = get_viewport().get_camera_3d()
		if cam:
			var world_pos = global_transform.origin + Vector3(0, 2.5, 0) # Adjust Y offset as needed
			var screen_pos = cam.unproject_position(world_pos)
			health_bar_2d.position = screen_pos
	if ai_stopped and stopped_ai != null:
		damage_timer += delta
		if damage_timer >= damage_interval:
			health -= damage_amount
			print("Work zone health:", health)
			damage_timer = 0.0
			update_health_bar()
			if health <= min_health:
				print("Work zone fully worked!")
				queue_free()
	else:
		# Not being worked, health increases slowly
		damage_timer += delta
		if damage_timer >= idle_damage_interval:
			health += damage_amount
			print("Work zone health:", health)
			damage_timer = 0.0
			update_health_bar()
			if health >= max_health:
				print("Work zone failed! Player loses level.")
				var game_manager = get_tree().root.get_node("MainWorld")
				if game_manager and game_manager.has_method("change_state") and gameover == false:
					game_manager.change_state(1)
					gameover = true
				# Ensure GameManager is notified before queue_free

func update_health_bar():
	if health_bar:
		# Smooth bar fill: normalized between 0 and 1, then scale to max_value
		var fill_value = clamp((abs(health - 10.0)) / 10.0, 0, 1) * health_bar.max_value
		health_bar.value = fill_value
		health_bar.max_value = 10
		if health < 10.0:
			# Being worked, fill green
			health_bar.tint_progress = Color(0, 1, 0)
		elif health > 10.0:
			# Not being worked, fill red
			health_bar.tint_progress = Color(1, 0, 0)
		else:
			# Neutral
			health_bar.tint_progress = Color(1, 1, 1)

# Called when a body enters the area. Signal must be connected in the editor.
var ai_stopped := false
var stopped_ai = null

# Damage interval in seconds
var damage_interval := 1.0
var idle_damage_interval := 4.0 # 4x slower when idle (health increasing)
var damage_timer := 0.0
var damage_amount := 1.0

func _on_body_entered(body):
	if "just_spawned" in body and body.just_spawned:
		return
	if ai_stopped:
		return # Only allow one AI to be stopped at a time
	print("yo")
	# Check if the body has a 'get_chosen_brain' method and matches brain_resource
	if body.has_method("get_chosen_brain"):
		var chosen_brain = body.get_chosen_brain()
		if chosen_brain == brain_resource:
			print("AI brain matches work zone brain resource")
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
			update_health_bar()
		else:
			print("AI brain does not match work zone brain resource.")
	else:
		print("Entered body does not have a 'get_chosen_brain' method.")

func _on_body_exited(_body):
	ai_stopped = false
	stopped_ai = null
	damage_timer = 0.0
	update_health_bar()
	var mobile_input = get_tree().get_root().find_child("mobile_input", true, false)
	if mobile_input and "clear_agent_in_workzone" in mobile_input:
		mobile_input.clear_agent_in_workzone()

func get_expected_state() -> String:
	if brain_resource:
		return brain_resource.ai_state_name
	return ""
