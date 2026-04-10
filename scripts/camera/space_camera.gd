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
var tracking: String = "Moon"

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
	# Time warp controls
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_PERIOD:        # . = speed up
			solarsystem.time_scale = min(solarsystem.time_scale * 10.0, 1.0e18)
			print("Time warp: ", solarsystem.time_scale, "x")
		elif event.keycode == KEY_COMMA:       # , = slow down
			solarsystem.time_scale = max(solarsystem.time_scale / 10.0, 1.0)
			print("Time warp: ", solarsystem.time_scale, "x")
		elif event.keycode == KEY_SPACE:       # space = reset to 1x
			solarsystem.time_scale = 1.0
			print("Time warp: 1x")
	# Switching controls
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_PERIOD:
			solarsystem.time_scale = min(solarsystem.time_scale * 10.0, 1.0e8)
			print("Time warp: ", solarsystem.time_scale, "x")
		elif event.keycode == KEY_COMMA:
			solarsystem.time_scale = max(solarsystem.time_scale / 10.0, 1.0)
			print("Time warp: ", solarsystem.time_scale, "x")
		elif event.keycode == KEY_SPACE:
			solarsystem.time_scale = 1.0
			print("Time warp: 1x")
		elif event.keycode == KEY_TAB:          # Tab = cycle forward
			var sel = selection.next()
			tracking = sel.get("name", "")
			print("Tracking: ", tracking)
		elif event.keycode == KEY_Q:            # Q = cycle backward
			var sel = selection.previous()
			tracking = sel.get("name", "")
			print("Tracking: ", tracking)

		# Middle mouse pan
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_panning = true
				_pan_start_mouse = event.position
				_pan_start_focus = focus
				tracking = ""          # detach from body when panning
			else:
				_panning = false

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
	for body_name in constants.BODIES:
		var world_pos = solarsystem.get_position(body_name)
		var screen_pos = world_to_screen(world_pos)
		var pixel_radius = max(world_to_pixel_radius(constants.BODIES[body_name]["radius"]), 3.0)
		draw_circle(screen_pos, pixel_radius, constants.BODIES[body_name]["color"])
		if pixel_radius > 2.0:
			draw_string(
				ThemeDB.fallback_font,
				screen_pos + Vector2(pixel_radius + 4, 4),
				body_name,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1, 12, Color.WHITE
			)

func _process(_delta: float) -> void:
	if tracking != "" and constants.BODIES.has(tracking):
		focus = solarsystem.get_position(tracking)
	queue_redraw()
# ─── Debug draw ───────────────────────────────────────────────────────────────
