# Retro SHMUP

A retro-style shoot-em-up game built with Godot Engine 4.3+.
16-bit pixel art, dynamic layered audio, anime cutscenes, and multi-layer depth combat.

## Quick Start

1. Open Godot 4.3+ (GL Compatibility renderer)
2. Import the `project.godot` file
3. Press F5 to run the greybox prototype

## Controls

| Action | Key |
|--------|-----|
| Move | WASD / Arrow Keys |
| Zoom In (closer layer) | E |
| Zoom Out (farther layer) | Q |
| Fire Laser | J / Space |
| Fire Missile | K |
| Fire Bomb | L |
| Pause | Escape |

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
└── assets/                 # Art, audio, fonts, shaders
    ├── sprites/
    ├── audio/
    ├── fonts/
    └── shaders/
```

## Architecture

### Autoloads (Singletons)

- **GameManager**: Game state, stage progression, score, ship data, signal bus
- **AudioManager**: Layered audio via AudioServer buses (base beat, drums, instruments, vocals, SFX)

### Core Systems

- **Player Ship** (`player_ship.gd`): Movement, depth/zoom layers, damage control (hull + front/back shields), weapon management
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

## Development

See `/docs/` in the parent repository for game design, story, script, and plan documents.
