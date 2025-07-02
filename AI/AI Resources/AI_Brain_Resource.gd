extends Resource
class_name AI_Brain

@export var ai_state_name: String = "aimless"   # Example states: "pyromaniac", "jumper", "aimless"
@export var speed: float = 100.0            # Movement speed in pixels/sec
@export var jump_height: float = 300.0      # Jump impulse strength
@export var detection_range: float = 50.0   # Radius to detect targets
@export var reaction_delay: float = 0.5     # Seconds delay before reacting
@export var vertex_color: Color = Color(1, 1, 1)  # Default to white
@export var leave_chance : float = 1