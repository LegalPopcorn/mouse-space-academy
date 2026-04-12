# integrator.gd
# Velocity Verlet integrator for orbital mechanics.
# Operates entirely in world space (meters, seconds).
# Attach this to any node that needs to move under gravity.
extends Node

# ─── State ───────────────────────────────────────────────────────────────────

var position: Vector2 = Vector2.ZERO       # meters
var velocity: Vector2 = Vector2.ZERO       # meters/second
var mass: float = 1.0                      # kg (for the craft — bodies use Constants)

# Which body is currently the gravitational parent
var gravity_parent: String = "Earth"

# Time acceleration (1 = realtime, 10 = 10x, etc)
var time_scale: float = 1.0

# ─── Physics step ─────────────────────────────────────────────────────────────

func step(delta: float) -> void:
	var dt = delta * time_scale

	# Current acceleration
	var a0 = _gravitational_acceleration(position, gravity_parent)

	# Verlet position update
	# x(t+dt) = x(t) + v(t)*dt + 0.5*a(t)*dt²
	position += velocity * dt + 0.5 * a0 * dt * dt

	# Acceleration at new position
	var a1 = _gravitational_acceleration(position, gravity_parent)

	# Verlet velocity update
	# v(t+dt) = v(t) + 0.5*(a(t) + a(t+dt))*dt
	velocity += 0.5 * (a0 + a1) * dt

	# Check if we've left this body's SOI
	_check_soi()

# ─── Gravity ──────────────────────────────────────────────────────────────────

func _gravitational_acceleration(pos: Vector2, body_name: String) -> Vector2:
	var body_pos = SolarSystem.get_position(body_name)
	var r_vec = body_pos - pos                        # vector toward body
	var r_sq = r_vec.length_squared()                 # distance squared

	if r_sq < 1.0:                                    # avoid division by zero
		return Vector2.ZERO

	var r = sqrt(r_sq)
	var mu = Constants.G * Constants.BODIES[body_name]["mass"]

	# F = GMm/r² — but we want acceleration (F/m), so just GM/r²
	# Direction: unit vector toward body
	return r_vec / r * (mu / r_sq)

# ─── SOI transitions ──────────────────────────────────────────────────────────

func _check_soi() -> void:
	var body_pos = SolarSystem.get_position(gravity_parent)
	var dist = position.distance_to(body_pos)
	var soi = Constants.soi_radius(gravity_parent)

	# Left current SOI — switch to parent
	if dist > soi:
		var parent_name = Constants.BODIES[gravity_parent]["parent"]
		if parent_name != "":
			gravity_parent = parent_name
			print("SOI exit → now orbiting ", gravity_parent)
			return

	# Check if we've entered a child body's SOI
	for body_name in Constants.BODIES:
		if Constants.BODIES[body_name]["parent"] != gravity_parent:
			continue
		if body_name == gravity_parent:
			continue
		var child_pos = SolarSystem.get_position(body_name)
		var child_dist = position.distance_to(child_pos)
		var child_soi = Constants.soi_radius(body_name)
		if child_dist < child_soi:
			gravity_parent = body_name
			print("SOI enter → now orbiting ", gravity_parent)
			return
