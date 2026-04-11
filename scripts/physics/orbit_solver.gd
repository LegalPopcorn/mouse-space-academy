# orbit_solver.gd
# Converts position + velocity into Kepler orbital elements,
# then generates points to draw the orbit ellipse.
extends Node

# ─── Orbital elements from state vectors ──────────────────────────────────────
# pos: craft position relative to parent body (meters)
# vel: craft velocity (m/s)
# mu:  standard gravitational parameter of parent (GM)
# Returns a Dictionary of orbital elements, or empty dict if invalid

func state_to_elements(pos: Vector2, vel: Vector2, mu: float) -> Dictionary:
	var r = pos.length()       # Distance from parent center
	var v = vel.length()       # Speed

	if r < 1.0:
		return {}   # Too close, invalid

	# Specific orbital energy (měrná orbitální energie)
	# ε = v²/2 - μ/r
	# Negative = bound orbit (ellipse), positive = escape (hyperbola)
	var energy = (v * v) / 2.0 - mu / r

	# Semi-major axis from energy
	# a = -μ / (2ε)
	var a = -mu / (2.0 * energy)

	# Eccentricity vector — points from focus toward periapsis (closest point)
	# e_vec = (v²/μ - 1/r)*pos - (pos·vel/μ)*vel
	var e_vec = pos * (v * v / mu - 1.0 / r) - vel * (pos.dot(vel) / mu)
	var e = e_vec.length()   # Eccentricity scalar

	# Argument of periapsis — angle of the orbit's closest point
	var arg_pe = atan2(e_vec.y, e_vec.x)

	return {
		"a": a,           # Semi-major axis (m)
		"e": e,           # Eccentricity
		"arg_pe": arg_pe, # Argument of periapsis (radians)
		"energy": energy  # Negative = ellipse, positive = hyperbola
	}

# ─── Generate screen points for drawing ───────────────────────────────────────
# elements: result of state_to_elements()
# parent_screen_pos: where the parent body is on screen (pixels)
# meters_per_pixel: current camera zoom
# Returns an array of Vector2 screen positions

func orbit_points(elements: Dictionary, parent_screen_pos: Vector2,
		meters_per_pixel: float, point_count: int = 180) -> PackedVector2Array:

	var points = PackedVector2Array()

	if elements.is_empty():
		return points

	var a = elements["a"]
	var e = elements["e"]
	var arg_pe = elements["arg_pe"]

	# Only draw closed orbits (ellipses)
	# e >= 1 means escape trajectory — skip for now
	if e >= 1.0 or a <= 0.0:
		return points

	# Semi-minor axis: b = a * sqrt(1 - e²)
	var b = a * sqrt(1.0 - e * e)

	# Center of the ellipse is offset from the focus by: a * e
	# In the direction of periapsis
	var focus_offset = Vector2(cos(arg_pe), sin(arg_pe)) * a * e

	# Generate points around the ellipse
	for i in point_count:
		var angle = (float(i) / point_count) * TAU   # TAU = 2*PI

		# Point on ellipse centered at origin, before rotation
		var local_point = Vector2(a * cos(angle), b * sin(angle))

		# Rotate by arg_pe so the ellipse is oriented correctly
		var rotated = local_point.rotated(arg_pe)

		# Offset from focus to ellipse center, then convert to screen space
		# The parent body is at one focus, so we subtract the focus offset
		var world_point = (rotated - focus_offset)
		var screen_point = parent_screen_pos + world_point / meters_per_pixel

		points.append(screen_point)

	return points
