# flight.gd
# The main flight scene. Owns craft physics, input, rendering.
# Saves to GameState every frame so map view can read it.
extends Node2D

# ─── Craft state ──────────────────────────────────────────────────────────────

var craft_position: Vector2 = Vector2.ZERO
var craft_velocity: Vector2 = Vector2.ZERO
var craft_rotation: float = 0.0          # radians — 0 = pointing right, -PI/2 = up
var gravity_parent: String = "Earth"

# ─── Rocket properties (built from GameState.rocket_parts) ────────────────────

var dry_mass: float = 0.0
var fuel: float = 0.0
var max_thrust: float = 50000.0          # Newtons
var isp: float = 350.0                   # Specific impulse
var throttle: float = 0.0
var engine_on: bool = false

# ─── Camera (floating origin) ─────────────────────────────────────────────────

var cam_focus: Vector2 = Vector2.ZERO
var meters_per_pixel: float = 5.0e6     # Start zoomed in on Earth
const ZOOM_MIN := 1.0e2
const ZOOM_MAX := 1.0e12
var _panning := false
var _pan_start_mouse: Vector2
var _pan_start_focus: Vector2

# ─── HUD references ───────────────────────────────────────────────────────────

@onready var hud_body     := $CanvasLayer/Control/hud_body
@onready var hud_warp     := $CanvasLayer/Control/hud_warp
@onready var hud_time     := $CanvasLayer/Control/hud_time
@onready var hud_velocity := $CanvasLayer/Control/hud_velocity
@onready var hud_altitude := $CanvasLayer/Control/hud_altitude
@onready var hud_throttle := $CanvasLayer/Control/hud_throttle

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_rocket_from_gamestate()

	if GameState.craft_exists:
		# Returning from map — restore physics state
		craft_position = GameState.craft_position
		craft_velocity = GameState.craft_velocity
		craft_rotation = GameState.craft_rotation
		gravity_parent = GameState.gravity_parent
	else:
		# Fresh launch from launch site
		_place_on_launch_site()

	cam_focus = craft_position

func _build_rocket_from_gamestate() -> void:
	# Sum up mass and fuel from all parts in the rocket definition
	dry_mass = 0.0
	fuel = 0.0
	for part in GameState.rocket_parts:
		match part["type"]:
			"capsule":  dry_mass += 840.0
			"fuselage":
				dry_mass += 500.0
				fuel += part["fuel"]
			"engine":   dry_mass += 200.0
# Compute the instantaneous velocity of a body in heliocentric space
# For circular orbits: v = sqrt(GM_parent / a), perpendicular to position
func _get_body_velocity(body_name: String) -> Vector2:
	var body = Constants.BODIES[body_name]
	if body["parent"] == "":
		return Vector2.ZERO  # Sun doesn't move

	var parent_name = body["parent"]
	var parent_pos = SolarSystem.get_position(parent_name)
	var body_pos = SolarSystem.get_position(body_name)

	# Vector from parent to body
	var r_vec = body_pos - parent_pos
	var r = r_vec.length()

	# Orbital speed
	var speed = sqrt(Constants.G * Constants.BODIES[parent_name]["mass"] / r)

	# Perpendicular direction (rotate 90° counterclockwise = multiply by Vector2(-y, x))
	var tangent = Vector2(-r_vec.y, r_vec.x).normalized()

	# Recursively add parent's velocity too (handles Moon case: Moon vel = Earth vel + Moon-around-Earth vel)
	return tangent * speed + _get_body_velocity(parent_name)

func _place_on_launch_site() -> void:
	var site_data = LaunchSiteManager.get_world_position(GameState.launch_site_name)
	if site_data.is_empty():
		# Fallback: LEO
		var earth_pos = SolarSystem.get_position("Earth")
		craft_position = earth_pos + Vector2(Constants.BODIES["Earth"]["radius"] + 400_000, 0)
		craft_velocity = Vector2(0, -Constants.orbital_velocity("Earth", 400_000))
		craft_rotation = -PI / 2.0
		return

	craft_position = site_data["position"]
	craft_velocity = Vector2.ZERO
	#the parent body's velocity in heliocentric space
	craft_velocity += _get_body_velocity(gravity_parent)

	# Rocket points away from planet center
	# atan2 of the normal vector gives us the angle, then subtract PI/2
	# because our rocket sprite's "up" is local -Y
	craft_rotation = atan2(site_data["normal"].y, site_data["normal"].x) - PI / 2.0
	# Actually get the body from the site definition
	var site = LaunchSiteManager.get_site(GameState.launch_site_name)
	gravity_parent = site["body"]

# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# ── Scene switching ──────────────────────────────────────────────────────
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			_save_to_gamestate()
			GameState.go_to(GameState.Scene.MAP)
			return
		if event.keycode == KEY_B:
			# Only allow going to builder if landed
			if _is_landed():
				_save_to_gamestate()
				GameState.craft_exists = false
				GameState.go_to(GameState.Scene.BUILD)
			else:
				print("Cannot open builder while in flight")
			return

	# ── Time warp ─────────────────────────────────────────────────────────
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_PERIOD:
			SolarSystem.time_scale = min(SolarSystem.time_scale * 10.0, 1.0e6)
		elif event.keycode == KEY_COMMA:
			SolarSystem.time_scale = max(SolarSystem.time_scale / 10.0, 1.0)

	# ── Camera zoom ───────────────────────────────────────────────────────
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_toward(event.position, 0.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_toward(event.position, 1.25)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_panning = true
				_pan_start_mouse = event.position
				_pan_start_focus = cam_focus
			else:
				_panning = false

	if event is InputEventMouseMotion and _panning:
		cam_focus = _pan_start_focus - (event.position - _pan_start_mouse) * meters_per_pixel

# ─── Per-frame update ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_handle_flight_input(delta)
	_physics_step(delta)
	_update_hud()
	_save_to_gamestate()
	cam_focus = craft_position   # camera tracks craft
	queue_redraw()

func _handle_flight_input(delta: float) -> void:
	# Rotation — A/D or Left/Right arrows
	var rotate_speed = 1.5   # radians per second
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		craft_rotation -= rotate_speed * delta
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		craft_rotation += rotate_speed * delta

	# Throttle — W/S or Up/Down arrows
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle = min(throttle + 0.5 * delta, 1.0)
		engine_on = true
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle = max(throttle - 0.5 * delta, 0.0)
		if throttle == 0.0:
			engine_on = false

	# Space = cut throttle
	if Input.is_key_pressed(KEY_SPACE):
		throttle = 0.0
		engine_on = false

# ─── Physics ──────────────────────────────────────────────────────────────────

func _physics_step(delta: float) -> void:
	var dt = delta * SolarSystem.time_scale

	# Don't allow time warp while engine is on — numerical errors get bad
	if engine_on:
		SolarSystem.time_scale = 1.0

	var steps = 10
	var sub_dt = dt / steps
	for i in steps:
		_verlet_step(sub_dt)

func _verlet_step(dt: float) -> void:
	var a0 = _total_acceleration()
	craft_position += craft_velocity * dt + 0.5 * a0 * dt * dt
	var a1 = _total_acceleration()
	craft_velocity += 0.5 * (a0 + a1) * dt
	_check_soi()
	_check_surface_collision()

func _total_acceleration() -> Vector2:
	var grav = _gravity_at(craft_position)
	var thrust_acc = Vector2.ZERO

	if engine_on and fuel > 0.0:
		# Rocket "up" in world space — local -Y rotated by craft_rotation
		var thrust_dir = Vector2(0, -1).rotated(craft_rotation)
		var current_mass = dry_mass + fuel
		thrust_acc = thrust_dir * (max_thrust * throttle) / current_mass

		# Burn fuel: ṁ = F / (Isp × g₀)
		# But we only burn for the sub-step dt, handled in _process
		# We drain here per sub-step
		var g0 = 9.80665
		var mass_flow = (max_thrust * throttle) / (isp * g0)
		# Note: dt here is the full delta, approximate — fuel drain is good enough
		fuel = max(fuel - mass_flow * (get_process_delta_time() * SolarSystem.time_scale / 10.0), 0.0)
		if fuel <= 0.0:
			engine_on = false
			print("Engine out — no fuel")

	return grav + thrust_acc

func _gravity_at(pos: Vector2) -> Vector2:
	var body_pos = SolarSystem.get_position(gravity_parent)
	var r_vec = body_pos - pos
	var r_sq = r_vec.length_squared()
	if r_sq < 1.0:
		return Vector2.ZERO
	var r = sqrt(r_sq)
	var mu = Constants.G * Constants.BODIES[gravity_parent]["mass"]
	return r_vec / r * (mu / r_sq)

func _check_soi() -> void:
	var parent_pos = SolarSystem.get_position(gravity_parent)
	var dist = craft_position.distance_to(parent_pos)
	var soi = Constants.soi_radius(gravity_parent)

	if dist > soi:
		var parent_of_parent = Constants.BODIES[gravity_parent]["parent"]
		if parent_of_parent != "":
			gravity_parent = parent_of_parent
			print("Exited SOI → now in ", gravity_parent, " SOI")
			return

	for body_name in Constants.BODIES:
		if Constants.BODIES[body_name]["parent"] != gravity_parent:
			continue
		if body_name == gravity_parent:
			continue
		var child_pos = SolarSystem.get_position(body_name)
		var child_dist = craft_position.distance_to(child_pos)
		if child_dist < Constants.soi_radius(body_name):
			gravity_parent = body_name
			print("Entered ", body_name, " SOI")
			return

func _check_surface_collision() -> void:
	var body_pos = SolarSystem.get_position(gravity_parent)
	var dist = craft_position.distance_to(body_pos)
	var radius = Constants.BODIES[gravity_parent]["radius"]

	if dist <= radius:
		# Landed or crashed
		# Push back to surface
		var normal = (craft_position - body_pos).normalized()
		craft_position = body_pos + normal * radius

		# Kill velocity component pointing into surface
		var radial_vel = craft_velocity.dot(normal)
		if radial_vel < 0:
			craft_velocity -= normal * radial_vel   # remove inward velocity

		if craft_velocity.length() < 10.0:
			craft_velocity = Vector2.ZERO
			print("Landed on ", gravity_parent)
		else:
			print("Crashed on ", gravity_parent, " at ", craft_velocity.length(), " m/s")

func _is_landed() -> bool:
	var body_pos = SolarSystem.get_position(gravity_parent)
	var dist = craft_position.distance_to(body_pos)
	return dist <= Constants.BODIES[gravity_parent]["radius"] + 100.0

# ─── State persistence ────────────────────────────────────────────────────────

func _save_to_gamestate() -> void:
	GameState.craft_position = craft_position
	GameState.craft_velocity = craft_velocity
	GameState.craft_rotation = craft_rotation
	GameState.gravity_parent = gravity_parent
	GameState.craft_exists = true

# ─── Camera helpers ───────────────────────────────────────────────────────────

func world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos - cam_focus) / meters_per_pixel + get_viewport_rect().size / 2.0

func screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - get_viewport_rect().size / 2.0) * meters_per_pixel + cam_focus

func _zoom_toward(screen_pos: Vector2, factor: float) -> void:
	var w = screen_to_world(screen_pos)
	meters_per_pixel = clamp(meters_per_pixel * factor, ZOOM_MIN, ZOOM_MAX)
	cam_focus += w - screen_to_world(screen_pos)

# ─── Rendering ────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Draw all celestial bodies
	for body_name in Constants.BODIES:
		var world_pos = SolarSystem.get_position(body_name)
		var screen_pos = world_to_screen(world_pos)
		var pixel_radius = max(Constants.BODIES[body_name]["radius"] / meters_per_pixel, 3.0)
		draw_circle(screen_pos, pixel_radius, Constants.BODIES[body_name]["color"])
		if pixel_radius > 2.0:
			draw_string(ThemeDB.fallback_font, screen_pos + Vector2(pixel_radius + 4, 4),
				body_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# Draw orbit prediction
	var parent_world = SolarSystem.get_position(gravity_parent)
	var rel_pos = craft_position - parent_world
	var mu = Constants.G * Constants.BODIES[gravity_parent]["mass"]
	var elements = OrbitSolver.state_to_elements(rel_pos, craft_velocity, mu)
	var points = OrbitSolver.orbit_points(elements, world_to_screen(parent_world), meters_per_pixel)
	if points.size() > 2:
		draw_polyline(points, Color(1, 1, 1, 0.35), 1.0)

	# Draw craft as a triangle pointing in its rotation direction
	var craft_screen = world_to_screen(craft_position)
	var size = 8.0
	var tip  = craft_screen + Vector2(0, -size * 2).rotated(craft_rotation)
	var bl   = craft_screen + Vector2(-size, size).rotated(craft_rotation)
	var br   = craft_screen + Vector2(size,  size).rotated(craft_rotation)
	draw_colored_polygon(PackedVector2Array([tip, bl, br]), Color.WHITE)

	# Draw engine flame
	if engine_on and fuel > 0:
		var flame_tip = craft_screen + Vector2(0, size * 3 + randf() * 5).rotated(craft_rotation)
		var fl = craft_screen + Vector2(-size * 0.6, size * 1.2).rotated(craft_rotation)
		var fr = craft_screen + Vector2(size * 0.6,  size * 1.2).rotated(craft_rotation)
		draw_colored_polygon(PackedVector2Array([fl, fr, flame_tip]), Color(1.0, 0.5, 0.1, 0.9))

# ─── HUD ──────────────────────────────────────────────────────────────────────

func _update_hud() -> void:
	var body_pos = SolarSystem.get_position(gravity_parent)
	var altitude = craft_position.distance_to(body_pos) - Constants.BODIES[gravity_parent]["radius"]

	hud_body.text     = "SOI: " + gravity_parent
	hud_altitude.text = "Alt: " + _format_distance(altitude)
	hud_velocity.text = "Vel: " + str(snapped(craft_velocity.length(), 0.1)) + " m/s"
	hud_throttle.text = "Thr: " + str(int(throttle * 100)) + "%  Fuel: " + str(snapped(fuel, 0.1)) + " kg"

	var warp = SolarSystem.time_scale
	if warp >= 1000:
		hud_warp.text = "Warp: " + str(int(warp / 1000)) + "Kx"
	else:
		hud_warp.text = "Warp: " + str(int(warp)) + "x"

	hud_time.text = "T+ Day %d %02d:%02d:%02d" % [
		int(SolarSystem.sim_time / 86400),
		int(SolarSystem.sim_time / 3600) % 24,
		int(SolarSystem.sim_time / 60) % 60,
		int(SolarSystem.sim_time) % 60
	]

func _format_distance(meters: float) -> String:
	if meters >= 1e9:
		return str(snapped(meters / 1e9, 0.01)) + " Gm"
	elif meters >= 1e6:
		return str(snapped(meters / 1e6, 0.01)) + " Mm"
	elif meters >= 1e3:
		return str(snapped(meters / 1e3, 0.01)) + " km"
	return str(snapped(meters, 0.1)) + " m"
