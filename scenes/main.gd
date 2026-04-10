extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	print("Earth SOI: ", constants.soi_radius("Earth") / 1000.0, " km")
	print("LEO velocity: ", constants.orbital_velocity("Earth", 400e3), " m/s")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
