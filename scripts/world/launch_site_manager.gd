# launch_site_manager.gd
# Autoload — loads launch site data from JSON and computes world positions.
extends Node

var sites: Array = []

func _ready() -> void:
	_load_sites()

func _load_sites() -> void:
	# Open the JSON file
	var file = FileAccess.open("res://data/launch_sites.json", FileAccess.READ)
	if not file:
		push_error("Could not open launch_sites.json")
		return

	# Parse the JSON text into a GDScript Dictionary
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("Failed to parse launch_sites.json: " + json.get_error_message())
		return

	sites = json.data["launch_sites"]
	print("Loaded ", sites.size(), " launch sites")

# Get a site dictionary by name
func get_site(name: String) -> Dictionary:
	for site in sites:
		if site["name"] == name:
			return site
	return {}

# Compute the world position of a launch site
# Returns { "position": Vector2, "normal": Vector2 }
# normal = direction pointing away from planet center (rocket's "up")
func get_world_position(site_name: String) -> Dictionary:
	var site = get_site(site_name)
	if site.is_empty():
		return {}

	var body_name = site["body"]
	var angle = deg_to_rad(site["angle_deg"])
	var body_pos = SolarSystem.get_position(body_name)
	var radius = Constants.BODIES[body_name]["radius"]

	# Surface point
	var normal = Vector2(cos(angle), sin(angle))
	var surface_pos = body_pos + normal * radius

	return {
		"position": surface_pos,
		"normal": normal,
		"angle": angle
	}
