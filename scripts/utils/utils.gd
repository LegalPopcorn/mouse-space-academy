# constants.gd
# Global autoload — access anywhere as Constants.SOMETHING
extends Node
# ─── Test fce ───────────────────────────────────────────────────



# ─── Fundamental constants ───────────────────────────────────────────────────

const G := 6.674e-11          # Gravitational constant (m³ kg⁻¹ s⁻²)
const AU := 1.496e11           # Astronomical unit in meters
const DEG2RAD := PI / 180.0
const RAD2DEG := 180.0 / PI

# ─── Solar system bodies ──────────────────────────────────────────────────────
# Each entry:
#   mass          kg
#   radius        m
#   orbit_radius  m   (semi-major axis from parent, 0 for Sun)
#   parent        name of parent body ("" for Sun)
#   color         for placeholder circle rendering

const BODIES := {
	"Sun": {
		"mass":         1.989e30,
		"radius":       6.957e8,
		"orbit_radius": 0.0,
		"parent":       "",
		"color":        Color(1.0, 0.9, 0.2)
	},
	"Mercury": {
		"mass":         3.301e23,
		"radius":       2.440e6,
		"orbit_radius": 5.791e10,
		"parent":       "Sun",
		"color":        Color(0.6, 0.6, 0.6)
	},
	"Venus": {
		"mass":         4.867e24,
		"radius":       6.052e6,
		"orbit_radius": 1.082e11,
		"parent":       "Sun",
		"color":        Color(0.9, 0.75, 0.4)
	},
	"Earth": {
		"mass":         5.972e24,
		"radius":       6.371e6,
		"orbit_radius": 1.496e11,
		"parent":       "Sun",
		"color":        Color(0.2, 0.5, 1.0)
	},
	"Moon": {
		"mass":         7.342e22,
		"radius":       1.737e6,
		"orbit_radius": 3.844e8,
		"parent":       "Earth",
		"color":        Color(0.8, 0.8, 0.8)
	},
	"Mars": {
		"mass":         6.390e23,
		"radius":       3.390e6,
		"orbit_radius": 2.279e11,
		"parent":       "Sun",
		"color":        Color(0.8, 0.3, 0.1)
	},
	"Jupiter": {
		"mass":         1.898e27,
		"radius":       6.991e7,
		"orbit_radius": 7.783e11,
		"parent":       "Sun",
		"color":        Color(0.8, 0.6, 0.4)
	},
	"Saturn": {
		"mass":         5.683e26,
		"radius":       5.823e7,
		"orbit_radius": 1.427e12,
		"parent":       "Sun",
		"color":        Color(0.9, 0.8, 0.5)
	},
	"Uranus": {
		"mass":         8.681e25,
		"radius":       2.536e7,
		"orbit_radius": 2.871e12,
		"parent":       "Sun",
		"color":        Color(0.5, 0.85, 0.95)
	},
	"Neptune": {
		"mass":         1.024e26,
		"radius":       2.462e7,
		"orbit_radius": 4.495e12,
		"parent":       "Sun",
		"color":        Color(0.2, 0.3, 1.0)
	}
}

# ─── Helper functions ─────────────────────────────────────────────────────────

# Standard gravitational parameter (μ = GM) for a body by name
func mu(body_name: String) -> float:
	return G * BODIES[body_name]["mass"]

# Sphere of influence radius for a body orbiting its parent
# SOI = orbit_radius * (mass / parent_mass) ^ (2/5)

func soi_radius(body_name: String) -> float:
	var body = BODIES[body_name]
	if body["parent"] == "":
		return INF
	var parent = BODIES[body["parent"]]
	return body["orbit_radius"] * pow(body["mass"] / parent["mass"], 0.4)

# Circular orbital velocity at a given altitude above a body
func orbital_velocity(body_name: String, altitude: float) -> float:
	var r = BODIES[body_name]["radius"] + altitude
	return sqrt(mu(body_name) / r)
