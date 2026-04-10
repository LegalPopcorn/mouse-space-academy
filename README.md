# mouse-space-academy
Open-source 2D space flight simulator built in Godot 4
```
mouse-space-academy/
│
├── ✅ 1. Project structure
│       GitHub, folders, constants autoload
│
├── ✅ 2. Solar system data
│       Real planetary data, circular orbits
│
├── ✅ 3. Camera system
│       Floating origin, zoom, pan, body tracking
│
├── ✅ 4. Gravity + integrator
│       Velocity Verlet, time warp, SOI framework
│
├── ✅ 5. Selection system
│       Tab/Q cycling, extensible to rockets
│
├── 🔲 6. Click to select
│       Click directly on a body to focus it
│
├── 🔲 7. HUD overlay
│       Body name, time warp level, simulated date
│
├── 🔲 8. Test craft
│       Point mass placed in stable orbit around Earth
│
├── 🔲 9. Orbit prediction line
│       Draw the ellipse the craft will follow
│
├── 🔲 10. SOI transitions
│        Craft switches gravity parent when leaving SOI
│
├── 🔲 11. Basic rocket
│        Single stage, engine thrust, fuel depletion
│
├── 🔲 12. Flight scene
│        Launch, reach orbit, basic controls
│
├── 🔲 13. Map view
│        Proper orbital map, maneuver nodes
│
└── 🔲 14. Rocket builder
         Part stacking, assembly scene
```
```
mouse-space-academy/
│
├── .github/
│   └── ISSUE_TEMPLATE/         ← Bug report / feature request templates
│
├── assets/
│   ├── fonts/
│   ├── textures/
│   │   ├── bodies/             ← Planet/moon sprites
│   │   ├── parts/              ← Rocket part sprites
│   │   └── ui/                 ← HUD icons, buttons
│   └── sounds/
│
├── scenes/
│   ├── main.tscn               ← Root scene, boots the game
│   ├── flight/                 ← The actual spaceflight scene
│   │   ├── flight.tscn
│   │   └── flight.gd
│   ├── map/                    ← Orbital map view (like SFS map mode)
│   │   ├── map.tscn
│   │   └── map.gd
│   ├── build/                  ← Rocket assembly scene
│   │   ├── build.tscn
│   │   └── build.gd
│   └── ui/                     ← Menus, HUD overlays
│       ├── hud.tscn
│       └── main_menu.tscn
│
├── scripts/
│   ├── physics/
│   │   ├── gravity.gd          ← Newtonian gravity calculation
│   │   ├── orbit_solver.gd     ← Kepler orbit math (conic sections)
│   │   └── integrator.gd       ← Verlet / RK4 integrator
│   ├── bodies/
│   │   ├── celestial_body.gd   ← Base class: mass, radius, SOI
│   │   └── solar_system.gd     ← Loads and manages all bodies
│   ├── rocket/
│   │   ├── rocket.gd           ← Rocket root: manages parts, staging
│   │   └── part.gd             ← Individual part: engine, tank, etc.
│   ├── camera/
│   │   └── space_camera.gd     ← Zoom, pan, body-relative tracking
│   └── utils/
│       ├── constants.gd        ← G, AU, real body data — autoload this
│       └── math_utils.gd       ← Vector helpers, unit conversions
│
├── data/
│   └── solar_system.json       ← Real planetary data (mass, radius, orbit)
│
├── docs/
│   ├── CONTRIBUTING.md
│   └── design/                 ← Your design notes, diagrams
│
├── addons/                     ← Future mod support / Godot plugins
│
├── .gitignore
├── LICENSE
├── README.md
└── project.godot
```
