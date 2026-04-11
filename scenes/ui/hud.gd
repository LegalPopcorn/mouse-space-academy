# hud.gd
# Attached to the Control node inside CanvasLayer.
# Updates HUD labels every frame from global state.
extends CanvasLayer

# Get references to the three labels.
# $LabelName is Godot shorthand for get_node("LabelName")
@onready var body_label: Label = $body_label
@onready var warp_label: Label = $warp_label
@onready var date_label: Label = $date_label

func _process(_delta: float) -> void:
	# Current selection
	var sel = selection.current()
	if sel.is_empty():
		body_label.text = "Nothing selected"
	else:
		# Show body name and current SOI info
		body_label.text = "Focus: " + sel.get("name", "?")
	# Show which body's gravity we're in
	var craft = get_tree().get_first_node_in_group("crafts")
	if craft:
		body_label.text += "\nSOI: " + craft.gravity_parent

	# Time warp - nice metric format
	var warp = solarsystem.time_scale
	if warp >= 10e18:
		warp_label.text = "Warp: " + str(warp / 10e18) + "Ex"
	elif warp >= 10e15:
		warp_label.text = "Warp: " + str(warp / 10e15) + "Px"
	elif warp >= 10e12:
		warp_label.text = "Warp: " + str(warp / 10e12) + "Tx"
	elif warp >= 10e9:
		warp_label.text = "Warp: " + str(warp / 10e9) + "Gx"
	elif warp >= 10e6:
		warp_label.text = "Warp: " + str(warp / 10e6) + "Mx"
	elif warp >= 10e3:
		warp_label.text = "Warp: " + str(warp / 10e3) + "Kx"
	else:
		warp_label.text = "Warp: " + str(warp) + "x"

	# Simulated date — convert elapsed seconds to a readable date
	date_label.text = "T+ " + _format_time(solarsystem.sim_time)

# Convert seconds into days/hours/minutes/seconds
func _format_time(seconds: float) -> String:
	var total = int(seconds)
	var s = total % 60
	var m = (total / 60) % 60
	var h = (total / 3600) % 24
	var d = total / 86400
	return "Day %d  %02d:%02d:%02d" % [d, h, m, s]
