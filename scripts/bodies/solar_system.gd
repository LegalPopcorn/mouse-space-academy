# solar_system.gd
# Autoload — tracks simulated world positions of all celestial bodies.
# For now uses simple circular orbits. Later can be upgraded to full Kepler.
extends Node

# Simulated positions in world space (meters)
var positions: Dictionary = {}

# Simulated time elapsed (seconds)
var sim_time: float = 0.0

var time_scale: float = 1.0

func _ready() -> void:
	# Initialise all body positions
	for body_name in constants.BODIES:
		positions[body_name] = _compute_position(body_name, 0.0)
		#selection connect
		selection.register({"name": body_name, "type": "body"})

func _process(delta: float) -> void:
	sim_time += delta * time_scale
	for body_name in constants.BODIES:
		positions[body_name] = _compute_position(body_name, sim_time)

# Returns world position of a body at time t
func get_position(body_name: String) -> Vector2:
	return positions.get(body_name, Vector2.ZERO)

# Circular orbit position from orbital period
# T = 2π * sqrt(a³ / GM_parent)
func _compute_position(body_name: String, t: float) -> Vector2:
	var body = constants.BODIES[body_name]
	if body["parent"] == "":
		return Vector2.ZERO   # Sun stays at origin

	var parent_pos = get_position(body["parent"])
	var a = body["orbit_radius"]
	var parent_mass = constants.BODIES[body["parent"]]["mass"]
	var period = 2.0 * PI * sqrt(pow(a, 3.0) / (constants.G * parent_mass))
	var angle = (2.0 * PI * t) / period

	return parent_pos + Vector2(cos(angle), sin(angle)) * a
