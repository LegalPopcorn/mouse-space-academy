# capsule.gd
# The command pod. Contains the crew (eventually).
# Has no fuel — just structural mass.
extends "res://scripts/rocket/part.gd"

func _ready() -> void:
	part_name = "Capsule"
	dry_mass = 840.0    # kg — roughly Apollo capsule mass
	height = 3.0
	width = 3.0

func _draw() -> void:
	# Draw as a triangle pointing up
	# In Godot 2D, Y increases downward, so "up" = negative Y
	var points = PackedVector2Array([
		Vector2(0, -height * 10),       # tip (top)
		Vector2(-width * 10, height * 5), # bottom left
		Vector2(width * 10, height * 5)   # bottom right
	])
	draw_colored_polygon(points, Color(0.7, 0.7, 0.8))
