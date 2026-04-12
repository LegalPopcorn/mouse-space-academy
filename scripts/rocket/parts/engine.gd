# engine.gd
# Produces thrust by burning fuel from connected fuselage.
extends "res://scripts/rocket/part.gd"

@export var thrust: float = 50000.0    # Newtons
@export var isp: float = 350.0         # Specific impulse (seconds)

# g₀ = standard gravity, used in rocket equation
const G0 := 9.80665

var throttle: float = 0.0              # 0.0 to 1.0
var is_firing: bool = false

func _ready() -> void:
	part_name = "Engine"
	dry_mass = 200.0
	height = 2.0
	width = 2.0

# Mass flow rate: ṁ = F / (Isp × g₀)
func mass_flow_rate() -> float:
	return (thrust * throttle) / (isp * G0)

# Thrust vector — points "up" from the engine (negative Y in Godot)
func thrust_vector() -> Vector2:
	if not is_firing:
		return Vector2.ZERO
	# global_transform.basis_xform rotates a local vector into world space
	# So local "up" (-Y) becomes whatever direction the rocket is pointing
	return global_transform.basis_xform(Vector2(0, -1)) * thrust * throttle

func _draw() -> void:
	# Draw as a trapezoid (nozzle shape)
	var points = PackedVector2Array([
		Vector2(-width * 5, -height * 5),   # top left
		Vector2(width * 5, -height * 5),    # top right
		Vector2(width * 10, height * 10),   # bottom right (wide nozzle)
		Vector2(-width * 10, height * 10)   # bottom left
	])
	draw_colored_polygon(points, Color(0.4, 0.4, 0.5))

	# Draw flame if firing
	if is_firing:
		var flame = PackedVector2Array([
			Vector2(-width * 8, height * 10),
			Vector2(width * 8, height * 10),
			Vector2(0, height * 10 + 30 * throttle)
		])
		draw_colored_polygon(flame, Color(1.0, 0.5, 0.1, 0.8))
