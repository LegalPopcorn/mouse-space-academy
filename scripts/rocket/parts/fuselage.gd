# fuselage.gd
# Fuel tank. The workhorse of the rocket.
extends "res://scripts/rocket/part.gd"

@export var fuel_capacity: float = 5000.0   # kg of fuel
var fuel: float = 5000.0                     # current fuel

func _ready() -> void:
	part_name = "Fuselage"
	dry_mass = 500.0
	height = 6.0
	width = 3.0

# Override: total mass = dry mass + remaining fuel
func current_mass() -> float:
	return dry_mass + fuel

# Drain fuel, return how much was actually drained (may be less if nearly empty)
func drain(amount: float) -> float:
	var drained = min(amount, fuel)
	fuel -= drained
	return drained

func _draw() -> void:
	# Draw as a rectangle
	var rect = Rect2(-width * 10, -height * 5, width * 20, height * 10)
	draw_rect(rect, Color(0.5, 0.5, 0.6))
	# Fuel gauge — fill proportion
	var fill_height = (height * 10) * (fuel / fuel_capacity)
	var fill_rect = Rect2(-width * 10, height * 5 - fill_height, width * 20, fill_height)
	draw_rect(fill_rect, Color(0.3, 0.6, 1.0, 0.5))
