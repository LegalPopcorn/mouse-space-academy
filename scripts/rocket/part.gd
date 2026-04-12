# part.gd
# Base class for all rocket parts.
# Each part knows its own mass and can draw itself.
extends Node2D

# ─── Part properties ──────────────────────────────────────────────────────────

@export var part_name: String = "Part"
@export var dry_mass: float = 100.0      # kg, mass when empty of fuel

# Override in subclasses for parts with fuel
func current_mass() -> float:
	return dry_mass

# Part height in meters — used for stacking
@export var height: float = 2.0
@export var width: float = 2.0
