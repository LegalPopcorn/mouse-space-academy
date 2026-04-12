# map.gd
# Orbital map view. Press M to return to flight.
# Reuses floating origin camera logic, draws orbits for all bodies + craft.
extends Node2D

var cam_focus: Vector2 = Vector2.ZERO
var meters_per_pixel: float = 1.0e9
const ZOOM_MIN := 1.0e5
const ZOOM_MAX := 1.0e12

var _panning := false
var _pan_start_mouse: Vector2
var _pan_start_focus: Vector2

var tracking: String = "Craft"

@onready var label_focus := $CanvasLayer/Control/label_focus
@onready var label_hint  := $CanvasLayer/Control/label_hint

func _ready() -> void:
	# Start focused on the craft
	cam_focus = GameState.craft_position
	label_hint.text = "M = back to flight   Tab = cycle bodies   Scroll = zoom   MMB = pan"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			GameState.go_to(GameState.Scene.FLIGHT)
			return
		elif event.keycode == KEY_TAB:
			var sel = Selection.next()
			tracking = sel.get("name", "")
		elif event.keycode == KEY_Q:
			var sel = Selection.previous()
			tracking = sel.get("name", "")

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
				tracking = ""
			else:
				_panning = false

	if event is InputEventMouseMotion and _panning:
		cam_focus = _pan_start_focus - (event.position - _pan_start_mouse) * meters_per_pixel

func _process(_delta: float) -> void:
	# Update focus
	if tracking == "Craft":
		cam_focus = GameState.craft_position
	elif tracking != "" and Constants.BODIES.has(tracking):
		cam_focus = SolarSystem.get_position(tracking)

	label_focus.text = "Focus: " + (tracking if tracking != "" else "Free")
	queue_redraw()

func _draw() -> void:
	# Draw all bodies
	for body_name in Constants.BODIES:
		var world_pos = SolarSystem.get_position(body_name)
		var screen_pos = world_to_screen(world_pos)
		var pixel_radius = max(Constants.BODIES[body_name]["radius"] / meters_per_pixel, 3.0)
		draw_circle(screen_pos, pixel_radius, Constants.BODIES[body_name]["color"])
		draw_string(ThemeDB.fallback_font, screen_pos + Vector2(pixel_radius + 4, 4),
			body_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

	# Draw craft
	if GameState.craft_exists:
		var craft_screen = world_to_screen(GameState.craft_position)
		draw_circle(craft_screen, 4.0, Color.WHITE)
		draw_string(ThemeDB.fallback_font, craft_screen + Vector2(6, 4),
			"Craft", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)

		# Draw orbit prediction from saved state
		var parent_world = SolarSystem.get_position(GameState.gravity_parent)
		var rel_pos = GameState.craft_position - parent_world
		var mu = Constants.G * Constants.BODIES[GameState.gravity_parent]["mass"]
		var elements = OrbitSolver.state_to_elements(rel_pos, GameState.craft_velocity, mu)
		var points = OrbitSolver.orbit_points(elements, world_to_screen(parent_world), meters_per_pixel)
		if points.size() > 2:
			draw_polyline(points, Color(1, 1, 0, 0.5), 1.5)

func world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos - cam_focus) / meters_per_pixel + get_viewport_rect().size / 2.0

func screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - get_viewport_rect().size / 2.0) * meters_per_pixel + cam_focus

func _zoom_toward(screen_pos: Vector2, factor: float) -> void:
	var w = screen_to_world(screen_pos)
	meters_per_pixel = clamp(meters_per_pixel * factor, ZOOM_MIN, ZOOM_MAX)
	cam_focus += w - screen_to_world(screen_pos)
