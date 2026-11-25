#!/usr/bin/env python3
"""Structural checks for task-17 (kamikaze enemy wiring and asset reuse).

Behavioural assertions live in tests/test_kamikaze_enemy.gd and run with Godot.
This validator covers the serialized scene/script wiring so a broken reference
fails loudly even without an engine:
    python3 tests/validate_kamikaze.py
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILURES: list[str] = []


def check(ok: bool, label: str) -> None:
    print(("  PASS  " if ok else "  FAIL  ") + label)
    if not ok:
        FAILURES.append(label)


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        check(False, f"{relative} exists")
        return ""
    return path.read_text(encoding="utf-8")


print("[task-17] Kamikaze scene")
scene = read("scenes/enemies/kamikaze_enemy.tscn")
check('name="KamikazeEnemy" type="Area2D"' in scene, "scene root is Area2D")
check("res://scripts/enemies/kamikaze_enemy.gd" in scene, "scene attaches its controller")
check('type="AnimatedSprite2D"' in scene, "scene has an animated visual")
check('type="CollisionShape2D"' in scene, "scene has a collision shape")

print("[task-17] Kamikaze controller")
enemy = read("scripts/enemies/kamikaze_enemy.gd")
check("class_name KamikazeEnemy" in enemy, "global class name declared")
check("extends BaseEnemy" in enemy, "reuses the existing enemy base class")
check("DIVE_ANGLE_DEG: float = 15.0" in enemy, "15-degree angle is an explicit constant")
check("SPAWN_Y_OFFSET" in enemy and "DESPAWN_MARGIN" in enemy, "spawn/despawn bounds defined")
check("player.explode()" in enemy, "player contact uses the shared death path")
check("died.emit(0)" in enemy, "ramming frees the stage spawn slot without scoring")
check("stage_1" not in enemy and "parallax" not in enemy.lower(),
      "no dependency on the unmerged parallax branch")

print("[task-17] Player death API")
player = read("scripts/player/player_ship.gd")
check("func explode() -> void:" in player, "PlayerShip.explode() exists")
check("if is_queued_for_deletion():" in player, "death is guarded against double triggers")

print("[task-17] Explosion effect")
effect_scene = read("scenes/effects/player_explosion.tscn")
check('name="PlayerExplosion" type="Node2D"' in effect_scene, "effect scene root is Node2D")
check('type="AnimatedSprite2D"' in effect_scene, "effect scene has an animated sprite")
effect = read("scripts/effects/player_explosion.gd")
check("class_name PlayerExplosion" in effect, "effect class name declared")
check("res://assets/sprites/effects/explosion_sheet.png" in effect,
      "reuses the existing explosion sheet")
check("res://assets/sprites/effects/explosion_sheet.json" in effect,
      "reuses the existing frame metadata")
check("res://assets/audio/sfx/explosion.wav" in effect, "reuses the existing explosion SFX")

print("[task-17] Active scene wiring")
main = read("scripts/main.gd")
check("res://scenes/enemies/kamikaze_enemy.tscn" in main, "main scene preloads the kamikaze")
check("KamikazeEnemy.spawn_position" in main, "main scene uses the top-edge spawn slots")

print("[task-17] Headless suite")
test = read("tests/test_kamikaze_enemy.gd")
check("res://tests/test_kamikaze_enemy.gd" in read("tests/test_kamikaze_enemy.tscn"),
      "test scene attaches its script")
check("EXPECTED_ANGLE_DEG" in test and "atan2" in test, "suite asserts the movement angle")
check("is_queued_for_deletion()" in test, "suite asserts spawn/despawn and collision cleanup")
check("frame_count == 8" in test, "suite asserts the explosion frames play")
result = read("tools/run_all.sh")
check("test_*.gd" in result, "run_all.sh discovers the new test suite")

if FAILURES:
    print(f"\n{len(FAILURES)} CHECK(S) FAILED")
    sys.exit(1)
print("\nALL STRUCTURAL CHECKS PASSED")
