# craft.gd
# A point-mass spacecraft. No parts yet — just position, velocity, mass.
# Uses the Integrator for physics.
extends Node2D

# ─── State ────────────────────────────────────────────────────────────────────

var craft_position: Vector2 = Vector2.ZERO   # World space, meters
var craft_velocity: Vector2 = Vector2.ZERO   # m/s
var craft_mass: float = 1000.0               # kg
var gravity_parent: String = "Earth"

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Place craft in LEO: Earth's position + (radius + 400km)
	add_to_group("crafts")
	var earth_pos = solarsystem.get_position("Earth")
	var earth_radius = constants.BODIES["Earth"]["radius"]
	var altitude = 400_000.0   # 400 km in meters

	craft_position = earth_pos + Vector2(earth_radius + altitude, 0.0)

	# Circular orbital velocity at this altitude
	var speed = constants.orbital_velocity("Earth", altitude)

	# Velocity must be perpendicular to the radius vector.
	# Radius vector points RIGHT (positive X), so velocity points UP (negative Y)
	# In Godot 2D, Y increases downward, so "up" in screen space = negative Y
	craft_velocity = Vector2(0.0, -speed)

	# Register with the selection system so Tab/Q can focus it
	selection.register({"name": "Craft", "type": "craft", "node": self})
	print("Craft placed at LEO. Speed: ", speed, " m/s")

# ─── Physics ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# How many seconds pass this frame in simulation time?
	var dt = delta * solarsystem.time_scale

	# Sub-step the integrator to reduce numerical error at high time warp
	# Instead of one big step of dt, take multiple smaller steps
	var steps = 10
	var sub_dt = dt / steps
	for i in steps:
		_verlet_step(sub_dt)

func _check_soi() -> void:
	var parent_pos = solarsystem.get_position(gravity_parent)
	var dist = craft_position.distance_to(parent_pos)

	# ── Exiting current SOI? ──────────────────────────────────────────────────
	var current_soi = constants.soi_radius(gravity_parent)
	if dist > current_soi:
		var parent_of_parent = constants.BODIES[gravity_parent]["parent"]
		if parent_of_parent != "":
			print("Exiting ", gravity_parent, " SOI → entering ", parent_of_parent, " SOI")
			gravity_parent = parent_of_parent
			return   # Re-evaluate next frame with new parent

	# ── Entering a child SOI? ─────────────────────────────────────────────────
	# Check all bodies whose parent is our current gravity_parent
	for body_name in constants.BODIES:
		# Skip bodies that aren't children of our current parent
		if constants.BODIES[body_name]["parent"] != gravity_parent:
			continue
		# Skip the parent itself
		if body_name == gravity_parent:
			continue

		var child_pos = solarsystem.get_position(body_name)
		var child_dist = craft_position.distance_to(child_pos)
		var child_soi = constants.soi_radius(body_name)

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

	# Update position: x += v*dt + 0.5*a*dt²
	craft_position += craft_velocity * dt + 0.5 * a0 * dt * dt

	# Update velocity: v += 0.5*(a0+a1)*dt
	craft_velocity += 0.5 * (a0 + a1) * dt

func _gravity_at(pos: Vector2) -> Vector2:
	# Gravitational acceleration toward the current parent body
	var body_pos = solarsystem.get_position(gravity_parent)
	var r_vec = body_pos - pos                  # Vector pointing toward body
	var r_sq = r_vec.length_squared()

	if r_sq < 1.0:                              # Safety: avoid divide by zero
		return Vector2.ZERO

	var r = sqrt(r_sq)
	var mu = constants.G * constants.BODIES[gravity_parent]["mass"]

	# Acceleration = GM/r² in the direction of r_vec
	return r_vec / r * (mu / r_sq)
