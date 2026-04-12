# game_state.gd
# Autoload — persists all critical state across scene switches.
# Think of this as the save file that's always in memory.
extends Node

# ─── Craft physics state ──────────────────────────────────────────────────────
# These are written by the flight scene every frame and read when returning to it

var craft_position: Vector2 = Vector2.ZERO
var craft_velocity: Vector2 = Vector2.ZERO
var craft_rotation: float = 0.0          # radians
var gravity_parent: String = "Earth"
var craft_exists: bool = false           # false = not yet launched, use launch site

# ─── Rocket definition ────────────────────────────────────────────────────────
# Written by the builder, read by the flight scene to construct the rocket
# Each entry: { "type": "capsule"/"fuselage"/"engine", 
#               "position": Vector2,     ← local position within rocket
#               "rotation": float,       ← local rotation
#               "fuel": float }          ← only meaningful for fuselage

var rocket_parts: Array = []

# ─── Launch site ──────────────────────────────────────────────────────────────

var launch_site_name: String = "Kennedy Space Center"

# ─── Scene management ─────────────────────────────────────────────────────────

enum Scene { FLIGHT, MAP, BUILD }
var current_scene: Scene = Scene.BUILD

func go_to(scene: Scene) -> void:
	current_scene = scene
	match scene:
		Scene.FLIGHT:
			get_tree().change_scene_to_file("res://scenes/flight/flight.tscn")
		Scene.MAP:
			get_tree().change_scene_to_file("res://scenes/map/map.tscn")
		Scene.BUILD:
			get_tree().change_scene_to_file("res://scenes/build/build.tscn")

# ─── Default rocket ───────────────────────────────────────────────────────────
# Called by builder on first run — gives player something to start with

func load_default_rocket() -> void:
	rocket_parts = [
		{"type": "capsule",  "position": Vector2(0, -70), "rotation": 0.0, "fuel": 0.0},
		{"type": "fuselage", "position": Vector2(0, 0),   "rotation": 0.0, "fuel": 5000.0},
		{"type": "engine",   "position": Vector2(0, 70),  "rotation": 0.0, "fuel": 0.0}
	]
