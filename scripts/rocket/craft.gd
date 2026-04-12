# craft.gd
# A point-mass spacecraft. No parts yet — just position, velocity, mass.
# Uses the Integrator for physics.
extends Node2D

var fuselage: Node2D  # Or whatever type fuselage.gd extends
var engine: Node2D
# ─── State ────────────────────────────────────────────────────────────────────

var craft_position: Vector2 = Vector2.ZERO   # World space, meters
var craft_velocity: Vector2 = Vector2.ZERO   # m/s
var craft_mass: float = 1000.0               # kg
var gravity_parent: String = "Earth"

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Place craft in LEO: Earth's position + (radius + 400km)
	add_to_group("crafts")
	var earth_pos = SolarSystem.get_position("Earth")
	var earth_radius = Constants.BODIES["Earth"]["radius"]
	var altitude = 400_000.0   # 400 km in meters
	# Build the rocket: capsule on top, fuselage in middle, engine at bottom
	# Parts are stacked along local Y axis (negative Y = up in Godot)
	var capsule = load("res://scripts/rocket/parts/capsule.gd").new()
	var fuselage = load("res://scripts/rocket/parts/fuselage.gd").new()
	var engine_part = load("res://scripts/rocket/parts/engine.gd").new()

	add_child(capsule)
	add_child(fuselage)
	add_child(engine_part)

# Stack vertically — each part sits below the previous
	capsule.position = Vector2(0, -60)
	fuselage.position = Vector2(0, 0)
	engine_part.position = Vector2(0, 70)

# Store references for physics
	self.fuselage = fuselage
	self.engine = engine_part

	craft_position = earth_pos + Vector2(Constants.BODIES["Earth"]["radius"] + altitude, 0)
	craft_velocity = Vector2(0.0, -Constants.orbital_velocity("Earth", altitude))
	# Circular orbital velocity at this altitude
	var speed = Constants.orbital_velocity("Earth", altitude)

	# Velocity must be perpendicular to the radius vector.
	# Radius vector points RIGHT (positive X), so velocity points UP (negative Y)
	# In Godot 2D, Y increases downward, so "up" in screen space = negative Y
	craft_velocity = Vector2(0.0, -speed)

	# Register with the Selection system so Tab/Q can focus it
	Selection.register({"name": "Craft", "type": "craft", "node": self})
	print("Craft placed at LEO. Speed: ", speed, " m/s")

# ─── Physics ──────────────────────────────────────────────────────────────────
func total_mass() -> float:
	var m = 0.0
	for child in get_children():
		if child.has_method("current_mass"):
			m += child.current_mass()
	return m

# In _process, handle thrust input
func _process(delta: float) -> void:
	# Z = fire engine
	if Input.is_action_pressed("ui_accept") and engine and fuselage:
		engine.throttle = 1.0
		engine.is_firing = true
		# Drain fuel proportional to mass flow rate
		var dt = delta * SolarSystem.time_scale
		fuselage.drain(engine.mass_flow_rate() * dt)
	else:
		if engine:
			engine.throttle = 0.0
			engine.is_firing = false

	# Physics (sub-stepped)
	var dt = delta * SolarSystem.time_scale
	var steps = 10
	var sub_dt = dt / steps
	for i in steps:
		_verlet_step(sub_dt)

func _check_soi() -> void:
	var parent_pos = SolarSystem.get_position(gravity_parent)
	var dist = craft_position.distance_to(parent_pos)

	# ── Exiting current SOI? ──────────────────────────────────────────────────
	var current_soi = Constants.soi_radius(gravity_parent)
	if dist > current_soi:
		var parent_of_parent = Constants.BODIES[gravity_parent]["parent"]
		if parent_of_parent != "":
			print("Exiting ", gravity_parent, " SOI → entering ", parent_of_parent, " SOI")
			gravity_parent = parent_of_parent
			return   # Re-evaluate next frame with new parent

	# ── Entering a child SOI? ─────────────────────────────────────────────────
	# Check all bodies whose parent is our current gravity_parent
	for body_name in Constants.BODIES:
		# Skip bodies that aren't children of our current parent
		if Constants.BODIES[body_name]["parent"] != gravity_parent:
			continue
		# Skip the parent itself
		if body_name == gravity_parent:
			continue

		var child_pos = SolarSystem.get_position(body_name)
		var child_dist = craft_position.distance_to(child_pos)
		var child_soi = Constants.soi_radius(body_name)

		if child_dist < child_soi:
			print("Entering ", body_name, " SOI")
			gravity_parent = body_name
			return

func _verlet_step(dt: float) -> void:
	var a0 = _gravity_at(craft_position)
	craft_position += craft_velocity * dt + 0.5 * a0 * dt * dt
	var a1 = _gravity_at(craft_position)
	craft_velocity += 0.5 * (a0 + a1) * dt
	_check_soi()   # ← add this line

func _gravity_at(pos: Vector2) -> Vector2:
	# Gravitational acceleration toward the current parent body
	var body_pos = SolarSystem.get_position(gravity_parent)
	var r_vec = body_pos - pos                  # Vector pointing toward body
	var r_sq = r_vec.length_squared()

	if r_sq < 1.0:                              # Safety: avoid divide by zero
		return Vector2.ZERO

	var r = sqrt(r_sq)
	var mu = Constants.G * Constants.BODIES[gravity_parent]["mass"]

	# Acceleration = GM/r² in the direction of r_vec
	return r_vec / r * (mu / r_sq)
