# Retro SHMUP

A retro-style shoot-em-up game built with Godot Engine 4.3+.
16-bit pixel art, dynamic layered audio, anime cutscenes, and multi-layer depth combat.

> This repository is the game submodule (`src/retro-shmup` in the parent repo).
> `docs/game_design.md` and `docs/plan.md` in the parent repository are the
> source of truth for requirements; this README describes the Godot project.

## Quick Start

1. Open Godot 4.3+ (GL Compatibility renderer)
2. Import the `project.godot` file
3. Press F5 to run the greybox prototype

## Controls

| Action | Key |
|--------|-----|
| Move | WASD / Arrow Keys |
| Move (gamepad) | D-pad / left stick |
| Zoom In (closer layer) | E |
| Zoom Out (farther layer) | Q |
| Zoom In (gamepad) | R1 |
| Zoom Out (gamepad) | L1 |
| Fire Laser | J / Space |
| Fire Missile | K |
| Fire Bomb | L |
| Pause | Escape |

## Foundation configuration (Phase 1)

| Area | Setting | Value / rationale |
|------|---------|-------------------|
| Renderer | `rendering/renderer/rendering_method` | `gl_compatibility` — runs on low-end hardware and headless CI |
| Base viewport | `display/window/size/viewport_*` | 480x270 (16:9), matching the retro base resolution |
| Scaling | `window/stretch/{mode,aspect,scale_mode}` | `viewport` / `keep` / `integer` — whole-number scaling, no blurry or uneven pixels |
| Textures | `textures/canvas_textures/default_texture_filter` | `0` = Nearest (nearest-neighbour sampling for pixel art) |
| Pixel snap | `rendering/2d/snap/snap_2d_transforms_to_pixel` | enabled; vertex snapping is deliberately left off per Godot's recommendation |
| Audio | `audio/buses/default_bus_layout` | empty — the stem buses (`Music`, `BaseBeat`, `Drums`, `Instruments`, `Vocals`, `SFX`) are created at runtime by `AudioManager` through `AudioServer`, keeping the dynamic mix in one place |

Input Map already defines movement (`move_up/down/left/right`), zoom (`zoom_in`/`zoom_out`),
fire (`fire`, `fire_missile`, `fire_bomb`), `start` and `pause`, with both WASD and arrow keys.
Gamepad R1/L1 (shoulder buttons) bindings for zoom are intentionally left to the
player-movement task so the control work stays in one place.

The `ui/` folder from the plan is represented by `scenes/ui/` (HUD scene) and
`scripts/ui/` (HUD script), following Godot's parallel scenes/scripts convention.

## Project Structure

```
retro-shmup/
├── project.godot          # Godot project config (autoloads, input map, layers)
├── icon.svg
├── scenes/                # Godot scene files (.tscn)
│   ├── main.tscn          # Entry point - orchestrates stage, player, HUD
│   ├── player/            # Player ship scene
│   ├── enemies/            # Base enemy scene
│   ├── stages/             # Stage scenes (base + stage_1)
│   ├── weapons/            # Projectile scene
│   ├── ui/                 # HUD scene
│   └── cutscenes/          # Cutscene manager scene
├── scripts/               # GDScript files (.gd)
│   ├── main.gd             # Main scene controller
│   ├── autoload/           # Singletons (GameManager, AudioManager)
│   ├── player/             # Player ship controller
│   ├── enemies/            # Base enemy + AI interface
│   ├── stages/             # Stage base + stage scripts
│   ├── weapons/            # Weapon, Laser, Projectile
│   ├── ui/                 # HUD
│   └── cutscenes/          # Cutscene system
├── tools/                  # Dev-only validation helpers (not game code)
│   └── validate_project.py
└── assets/                 # Art, audio, fonts, shaders
    ├── sprites/            # player/, enemies/, effects/, props/
    ├── audio/              # music/, sfx/
    ├── fonts/
    └── shaders/
```

## Architecture

### Autoloads (Singletons)

- **GameManager**: Game state, stage progression, score, ship data, signal bus
- **AudioManager**: Layered audio via AudioServer buses (base beat, drums, instruments, vocals, SFX)

### Core Systems

- **Player Ship** (`player_ship.gd`): Movement, depth/zoom layers, damage control (hull + front/back shields), weapon management
- **Damage Control** (`damage_control.gd`): HUD-independent model with three pools (GDAS-1: hull 3, front shield 3, back shield 3). `apply_damage(amount, direction)` drains the shield facing the hit (`"front"`/`"back"`, `Direction`, bool or incoming `Vector2`); overflow reaches the hull. Signals: `shield_changed(side, value)`, `hull_changed(value)`, `ship_destroyed`. `PlayerShip.apply_damage()` exposes the model; `take_damage(amount, from_front)` stays for collisions. Shield regeneration is off by default (`shield_regen_enabled` on the ship).
- **Weapon System** (`weapon.gd`, `laser.gd`, `projectile.gd`): Base weapon class with fire rate, cooldown, upgrade levels
- **Enemy System** (`base_enemy.gd`): Virtual AI interface, health, depth/layer support
- **Stage System** (`stage_base.gd`): Parallax scrolling, enemy spawning queue, layer scaling
- **HUD** (`hud.gd`): Hull/shield bars, score, stage, weapon display
- **Cutscene Manager** (`cutscene_manager.gd`): Phantasy Star-style dialogue panels, typewriter effect, bar-synced animations

### Ships (from game_design.md)

| Ship | Hull | Front Shield | Back Shield | Speed Levels | Weapons |
|------|------|-------------|-------------|--------------|---------|
| Space Quantum | 1 | 1 | 1 | 1 | Laser |
| GDAS-1 | 3 | 3 | 3 | 3 | Laser, Missile, Bomb |

### Physics Layers

| Layer | Name |
|-------|------|
| 1 | player |
| 2 | player_projectiles |
| 3 | enemies |
| 4 | enemy_projectiles |
| 5 | pickups |
| 6 | environment |

## Validation

Run the dependency-free structural checks from the repository root:

```sh
python3 tools/validate_project.py
```

It checks the required folder layout, `project.godot` settings, scene/script
resource references, unique GDScript class names, block indentation and obvious
secrets. If a Godot binary is on `PATH`, it also runs a headless parse; otherwise
it reports that validation was structural only. Exit code is 0 when all checks pass.

## Development

See `/docs/` in the parent repository for game design, story, script, and plan documents.

## Build and Test

Requires Godot 4.3+ (the headless build is enough) and Python 3.

```bash
tools/run_all.sh                     # import, asset validators, GDScript suites
tools/run_all.sh --lint              # also gdlint / gdformat --check (gdtoolkit)
GODOT_BIN=godot-4.7 tools/run_all.sh # run the same suites against another engine

mkdir -p build/linux
godot --headless --export-release "Linux" build/linux/retro-shmup.x86_64
```

`tools/run_all.sh` fails on GDScript parse errors, on any `tools/validate_*.py` or
`tests/validate_*.py` failure, on audio asset validation failures and on any
`tests/*_test.gd` suite that exits non-zero.

CI (`.github/workflows/ci.yml`) runs the script on Godot 4.3 and 4.7.2 and exports
Linux, Windows and macOS builds with `export_presets.cfg`. Artifacts are named
`retro-shmup-<version>-<short-sha>-<target>`, where `<version>` is the `v` tag on
tag pushes and `dev` otherwise; retention is 14 days. Windows/macOS executables
cannot run on the Linux runner, so those jobs smoke-test the exported `.pck`
with the Linux engine rather than claiming a native smoke. The macOS CLI export
writes `build/macos/retro-shmup.zip`; CI unpacks it into `build/macos/` (keeping
the executable bit), validates the bundle and game data, then removes the ZIP
before tarring. The uploaded tarball contains only the `.app` bundle and any
external `.pck`.

## Demo builds

The Phase 1 demo is released as **0.0.1-demo** when the `v0.0.1-demo` tag is
pushed; the `Release` workflow (`.github/workflows/release.yml`) gates on
`tools/run_all.sh`, exports the Linux x86_64 build and publishes it to the
[GitHub Releases page](https://github.com/dipievil/retro-shmup/releases/tag/v0.0.1-demo).

Download `retro-shmup.x86_64` and `retro-shmup.pck` from that release, keep them
in the same directory and run the binary. `SHA256SUMS` is attached alongside
them — verify with `sha256sum -c SHA256SUMS` before running. The Phase 1 demo
covers GDAS-1 movement/zoom and the laser, missile and bomb weapons. The release
path packages the tagged source as-is: it adds no gameplay, HUD or audio assets.

