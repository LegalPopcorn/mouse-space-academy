# space_camera.gd
# Floating origin camera for a 2D space sim.
# Does NOT use Godot's built-in Camera2D — we control rendering manually.
extends Node2D

# ─── State ────────────────────────────────────────────────────────────────────

var focus: Vector2 = Vector2.ZERO      # World position the camera is centered on (meters)
var meters_per_pixel: float = 1.0e9   # Zoom level — starts at 1 million km/pixel

# Zoom limits
const ZOOM_MIN := 1.0e-1              # 1 km/pixel  — very close surface view
const ZOOM_MAX := 1.0e12             # 1 billion km/pixel — whole solar system

# Panning
var _panning := false
var _pan_start_mouse: Vector2
var _pan_start_focus: Vector2

# Optional: body to track (name string, "" = free camera)
var tracking: String = "Earth"

# ─── Public API ───────────────────────────────────────────────────────────────

# Convert a world position (meters) to screen position (pixels)
func world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport_center = get_viewport_rect().size / 2.0
	return (world_pos - focus) / meters_per_pixel + viewport_center

# Convert a screen position (pixels) to world position (meters)
func screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport_center = get_viewport_rect().size / 2.0
	return (screen_pos - viewport_center) * meters_per_pixel + focus

# World-space radius to pixel radius
func world_to_pixel_radius(radius_m: float) -> float:
	return radius_m / meters_per_pixel

# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Scroll wheel zoom — zooms toward mouse cursor
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_toward(event.position, 0.8)   # zoom in
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_toward(event.position, 1.25)  # zoom out
		# Left click to select body
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_select_at(event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_panning = true
				_pan_start_mouse = event.position
				_pan_start_focus = focus
				tracking = ""          # detach from body when panning
			else:
				_panning = false
	# Time warp controls
	# Switching controls
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_PERIOD:
			SolarSystem.time_scale = min(SolarSystem.time_scale * 10.0, 1.0e19)
			print("Time warp: ", SolarSystem.time_scale, "x")
		elif event.keycode == KEY_COMMA:
			SolarSystem.time_scale = max(SolarSystem.time_scale / 10.0, 1.0)
			print("Time warp: ", SolarSystem.time_scale, "x")
		elif event.keycode == KEY_SPACE:
			SolarSystem.time_scale = 1.0
			print("Time warp: 1x")
		elif event.keycode == KEY_TAB:          # Tab = cycle forward
			var sel = Selection.next()
			tracking = sel.get("name", "")
			print("Tracking: ", tracking)
		elif event.keycode == KEY_Q:            # Q = cycle backward
			var sel = Selection.previous()
			tracking = sel.get("name", "")
			print("Tracking: ", tracking)
		# Middle mouse pan
		

	# Pan drag
	if event is InputEventMouseMotion and _panning:
		var delta = event.position - _pan_start_mouse
		focus = _pan_start_focus - delta * meters_per_pixel

# ─── Zoom ─────────────────────────────────────────────────────────────────────

func _zoom_toward(screen_pos: Vector2, factor: float) -> void:
	# Keep the world point under the cursor fixed while zooming
	var world_before = screen_to_world(screen_pos)
	meters_per_pixel = clamp(meters_per_pixel * factor, ZOOM_MIN, ZOOM_MAX)
	var world_after = screen_to_world(screen_pos)
	focus += world_before - world_after   # compensate drift

# ─── Tracking ─────────────────────────────────────────────────────────────────

# Temporary: flat 2D position from orbit_radius (no simulation yet)
func _draw() -> void:
	for body_name in Constants.BODIES:
		var world_pos = SolarSystem.get_position(body_name)
		var screen_pos = world_to_screen(world_pos)
		var pixel_radius = max(world_to_pixel_radius(Constants.BODIES[body_name]["radius"]), 3.0)
		draw_circle(screen_pos, pixel_radius, Constants.BODIES[body_name]["color"])
		if pixel_radius > 2.0:
			draw_string(
				ThemeDB.fallback_font, screen_pos + Vector2(pixel_radius + 4, 4),
				body_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	var craft = get_tree().get_first_node_in_group("crafts")
	if craft:
		var screen_pos = world_to_screen(craft.craft_position)
		draw_circle(screen_pos, 4.0, Color.WHITE)
	# Draw orbit prediction line
	if craft:
		var parent_name = craft.gravity_parent
		var parent_world_pos = SolarSystem.get_position(parent_name)
		var parent_screen_pos = world_to_screen(parent_world_pos)

		# Position and velocity relative to parent body
		var rel_pos = craft.craft_position - parent_world_pos
		var rel_vel = craft.craft_velocity  # velocity is already relative

		var mu = Constants.G * Constants.BODIES[parent_name]["mass"]
		var elements = OrbitSolver.state_to_elements(rel_pos, rel_vel, mu)
		var points = OrbitSolver.orbit_points(elements, parent_screen_pos, meters_per_pixel)

		# draw_polyline draws a line through all the points
		if points.size() > 2:
			draw_polyline(points, Color(1.0, 1.0, 1.0, 0.4), 1.0)



func _process(_delta: float) -> void:
	if tracking != "" and Constants.BODIES.has(tracking):
		focus = SolarSystem.get_position(tracking)
	queue_redraw()
# ─── Click Selection ──────────────────────────────────────────────────────────


# ─── Click Selection ──────────────────────────────────────────────────────────

func _try_select_at(screen_pos: Vector2) -> void:
	# Convert the click from screen space (pixels) to world space (meters)
	var world_click = screen_to_world(screen_pos)

	# Minimum Selection radius: 10 pixels worth of world space
	# This means small bodies are still clickable when zoomed out
	var min_hit_radius = 10.0 * meters_per_pixel

	var closest_name := ""
	var closest_dist := INF  # Start with infinity so any real distance beats it

	for body_name in Constants.BODIES:
		var body_pos = SolarSystem.get_position(body_name)

		# How far is the click from this body's center in world space?
		var dist = world_click.distance_to(body_pos)

		# Hit radius is whichever is larger: real radius or minimum 10-pixel radius
		var hit_radius = max(Constants.BODIES[body_name]["radius"], min_hit_radius)

		# Is the click within this body's hit radius?
		if dist < hit_radius:
			# Is this the closest body we've found so far?
			# (handles overlapping bodies at high zoom-out)
			if dist < closest_dist:
				closest_dist = dist
				closest_name = body_name

	# If we found something, select and track it
	if closest_name != "":
		tracking = closest_name
		Selection.select_by_name(closest_name)
		print("Selected: ", closest_name)
