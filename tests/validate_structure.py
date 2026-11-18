#!/usr/bin/env python3
"""Structural validation for task-4 (player movement / zoom / layers).

Runs without a Godot binary. It checks the serialized Input Map, the player
controller source, the GDAS-1 damage data and the scene wiring. The behavioural
checks live in tests/test_player_ship.gd and run with Godot headless when a
Godot binary is available.
"""

import re
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


def input_block(project: str, action: str) -> str | None:
    pattern = r"(?m)^" + re.escape(action) + r"=\{\n(.*?)^\}\n"
    match = re.search(pattern, project, re.S | re.M)
    return match.group(1) if match else None


def events(block: str) -> list[tuple[str, dict[str, str]]]:
    result = []
    for event_type, raw in re.findall(r"Object\((\w+),([^\n]*)\)", block):
        props = {k: v for k, v in re.findall(r'"(\w+)":([^,)]*)', raw)}
        result.append((event_type, props))
    return result


def prop(event: tuple[str, dict[str, str]], name: str) -> str | None:
    return event[1].get(name)


project = read("project.godot")
print("[task-4] Input Map: movement")

move = {
    "move_up": {"wasd": 87, "arrow": 4194320, "dpad": 11, "axis": 1, "axis_value": -1.0},
    "move_down": {"wasd": 83, "arrow": 4194322, "dpad": 12, "axis": 1, "axis_value": 1.0},
    "move_left": {"wasd": 65, "arrow": 4194319, "dpad": 13, "axis": 0, "axis_value": -1.0},
    "move_right": {"wasd": 68, "arrow": 4194321, "dpad": 14, "axis": 0, "axis_value": 1.0},
}
for action, expected in move.items():
    block = input_block(project, action)
    check(block is not None, f"[input] {action} exists")
    if block is None:
        continue
    evs = events(block)
    keys = [e for e in evs if e[0] == "InputEventKey"]
    check(any(prop(e, "physical_keycode") == str(expected["wasd"]) for e in keys),
          f"{action}: WASD key")
    check(any(prop(e, "physical_keycode") == str(expected["arrow"])
              or prop(e, "keycode") == str(expected["arrow"]) for e in keys),
          f"{action}: arrow key")
    buttons = [e for e in evs if e[0] == "InputEventJoypadButton"]
    check(any(prop(e, "button_index") == str(expected["dpad"]) for e in buttons),
          f"{action}: gamepad D-pad button")
    motion = [e for e in evs if e[0] == "InputEventJoypadMotion"]
    check(any(prop(e, "axis") == str(expected["axis"])
              and float(prop(e, "axis_value") or 0) == expected["axis_value"]
              for e in motion), f"{action}: gamepad left stick axis")

print("[task-4] Input Map: zoom (R1 / L1)")
zoom = {"zoom_in": 10, "zoom_out": 9}
for action, button in zoom.items():
    block = input_block(project, action)
    check(block is not None, f"[input] {action} exists")
    if block is None:
        continue
    check(any(prop(e, "button_index") == str(button)
              for e in events(block) if e[0] == "InputEventJoypadButton"),
          f"{action}: gamepad shoulder button {button}")

print("[task-4] Player controller")
ship = read("scripts/player/player_ship.gd")
check(ship.count("class_name PlayerShip") == 1, "exactly one class_name PlayerShip")
check("enum ActionLayer" in ship, "discrete action-layer enum present")
check("func change_depth" in ship, "change_depth() helper present")
check("func set_action_layer" in ship, "set_action_layer() helper present")
check("move_toward(depth, _target_depth" in ship, "depth interpolation cannot overshoot")
check(re.search(r"^\tmatch wname:", ship, re.M) is not None, "match at function body indent")
check(re.search(r"^\t\tmatch wname:", ship, re.M) is None, "no over-indented match")

print("[task-4] GDAS-1 damage control")
manager = read("scripts/autoload/game_manager.gd")
gdas = re.search(r'"gdas_1": \{(.*?)\n\t\},', manager, re.S)
check(gdas is not None, "GDAS-1 ship data present")
if gdas:
    for key, value in (("max_hull", 3), ("max_front_shield", 3), ("max_back_shield", 3)):
        check(re.search(rf'"{key}": {value}', gdas.group(1)) is not None,
              f"GDAS-1 {key} = {value}")

print("[task-4] Scene + tests")
scene = read("scenes/player/player_ship.tscn")
check('name="PlayerShip" type="Area2D"' in scene, "player scene root is Area2D")
check("res://scripts/player/player_ship.gd" in scene, "player scene attaches controller")
check((ROOT / "tests" / "test_player_ship.gd").is_file(), "headless GDScript test present")

if FAILURES:
    print(f"\n{len(FAILURES)} CHECK(S) FAILED")
    sys.exit(1)
print("\nALL STRUCTURAL CHECKS PASSED")
