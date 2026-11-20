#!/usr/bin/env python3
"""Structural validation for the task-5 weapon systems.

Godot is not always installed in CI/homelab contexts, so this checks the parts
that can be verified without the engine: scene wiring, resource paths, GDScript
delimiter balance/unique class names, and the presence of the behaviours the
game design requires (cadence, homing, bomb ammo, weapon switching, cleanup).

Run from anywhere:  python3 tests/validate_weapons.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []

REQUIRED_FILES = [
    "scripts/weapons/weapon.gd",
    "scripts/weapons/weapon_resources.gd",
    "scripts/weapons/projectile.gd",
    "scripts/weapons/laser.gd",
    "scripts/weapons/missile.gd",
    "scripts/weapons/missile_projectile.gd",
    "scripts/weapons/bomb.gd",
    "scripts/weapons/bomb_projectile.gd",
    "scenes/weapons/laser_projectile.tscn",
    "scenes/weapons/missile_projectile.tscn",
    "scenes/weapons/bomb_projectile.tscn",
]

PROJECTILE_SCENES = {
    "scenes/weapons/laser_projectile.tscn": ("projectile.gd", "laser"),
    "scenes/weapons/missile_projectile.tscn": ("missile_projectile.gd", "missile"),
    "scenes/weapons/bomb_projectile.tscn": ("bomb_projectile.gd", "bomb"),
}

BEHAVIOUR_CHECKS = [
    ("scripts/weapons/weapon.gd", r"func can_fire\(\)", "weapon cooldown gate"),
    ("scripts/weapons/weapon.gd", r"func fire\(", "weapon fire entry point"),
    ("scripts/weapons/weapon.gd", r"_cooldown = fire_rate", "per-weapon cadence"),
    ("scripts/weapons/weapon.gd", r"func _play_sfx\(\)", "optional SFX hook"),
    ("scripts/weapons/weapon.gd", r"_configure_projectile\(proj\)", "projectile config hook"),
    ("scripts/weapons/projectile.gd", r"extends Area2D", "Area2D projectile"),
    ("scripts/weapons/projectile.gd", r"var depth: float = 0.5", "projectile carries launch depth"),
    ("scripts/weapons/weapon.gd", r"proj\.depth = launch_depth", "launch depth copied to projectile"),
    ("scripts/weapons/projectile.gd", r"func _is_off_screen\(\)", "off-screen cleanup"),
    ("scripts/weapons/projectile.gd", r"queue_free\(\)", "free on hit/expiry"),
    ("scripts/weapons/projectile.gd", r"func _apply_visual\(\)", "optional sprite fallback"),
    ("scripts/weapons/missile.gd", r"homing_radius", "missile homing config"),
    ("scripts/weapons/missile_projectile.gd", r'get_nodes_in_group\("enemy"\)', "enemy tracking"),
    ("scripts/weapons/missile_projectile.gd", r"angle_to\(desired\)", "limited turn rate"),
    ("scripts/weapons/missile_projectile.gd", r"absf\(float\(mine\) - float\(theirs\)\) <= depth_tolerance", "same-layer depth comparison"),
    ("scripts/weapons/bomb.gd", r"max_ammo", "bomb limit"),
    ("scripts/weapons/bomb.gd", r"recharge_time", "bomb cooldown"),
    ("scripts/weapons/bomb.gd", r"func can_fire\(\)", "bomb ammo gate"),
    ("scripts/weapons/bomb_projectile.gd", r"explosion_radius", "bomb blast radius"),
    ("scripts/weapons/bomb_projectile.gd", r'call\("take_damage"', "bomb damages enemies"),
    ("scripts/player/player_ship.gd", r"func switch_weapon\(", "weapon selection"),
    ("scripts/player/player_ship.gd", r"func cycle_weapon\(", "weapon cycling"),
    ("scripts/player/player_ship.gd", r"Laser\.new\(\)", "laser instantiation"),
    ("scripts/player/player_ship.gd", r"Missile\.new\(\)", "missile instantiation"),
    ("scripts/player/player_ship.gd", r"Bomb\.new\(\)", "bomb instantiation"),
    ("scripts/player/player_ship.gd", r'\bweapon_changed\.emit\(', "HUD weapon signal"),
    ("project.godot", r"^next_weapon=\{", "next weapon input"),
    ("project.godot", r"^prev_weapon=\{", "previous weapon input"),
    ("project.godot", r"^select_laser=\{", "direct laser select"),
    ("project.godot", r"^select_missile=\{", "direct missile select"),
    ("project.godot", r"^select_bomb=\{", "direct bomb select"),
]

INPUT_ACTIONS_USED = [
    "move_left", "move_right", "move_up", "move_down",
    "zoom_in", "zoom_out", "fire", "fire_missile", "fire_bomb",
    "next_weapon", "prev_weapon", "select_laser", "select_missile",
    "select_bomb", "pause", "start",
]


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        ERRORS.append(f"missing required file: {rel}")
        return ""
    return path.read_text(encoding="utf-8")


def strip_gd_noncode(text: str) -> str:
    """Remove comments and string literals so delimiter counts are meaningful."""
    out: list[str] = []
    i = 0
    quote = ""
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = ""
            i += 1
            continue
        if ch in ('"', "'"):
            quote = ch
            i += 1
            continue
        if ch == "#":
            end = text.find("\n", i)
            i = len(text) if end == -1 else end
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def check_delimiters(rel: str, text: str) -> None:
    code = strip_gd_noncode(text)
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[str] = []
    for lineno, line in enumerate(code.splitlines(), start=1):
        if line.lstrip().startswith(" "):
            ERRORS.append(f"{rel}:{lineno}: space indentation in GDScript (use tabs)")
        for ch in line:
            if ch in "([{":
                stack.append(ch)
            elif ch in pairs:
                if not stack or stack[-1] != pairs[ch]:
                    ERRORS.append(f"{rel}:{lineno}: unbalanced '{ch}'")
                    return
                stack.pop()
    if stack:
        ERRORS.append(f"{rel}: unbalanced delimiters ({len(stack)} left open)")


def check_resource_paths(rel: str, text: str, optional: set[str]) -> None:
    for path in re.findall(r"res://[A-Za-z0-9_./-]+", text):
        if path in optional:
            continue
        if not (ROOT / path.removeprefix("res://")).exists():
            ERRORS.append(f"{rel}: referenced resource does not exist: {path}")


def check_scene(rel: str, script_hint: str, kind: str) -> None:
    text = read(rel)
    if not text:
        return
    if not text.startswith("[gd_scene"):
        ERRORS.append(f"{rel}: not a Godot scene header")
    if 'type="Area2D"' not in text:
        ERRORS.append(f"{rel}: root node is not Area2D")
    if "CollisionShape2D" not in text:
        ERRORS.append(f"{rel}: missing hitbox CollisionShape2D")
    if 'name="Visual" type="Sprite2D"' not in text:
        ERRORS.append(f"{rel}: missing optional sprite node")
    if f'weapon_kind = "{kind}"' not in text:
        ERRORS.append(f"{rel}: missing weapon_kind = {kind}")
    scripts = re.findall(r'path="(res://[^"]+\.gd)"', text)
    if not any(script_hint in s for s in scripts):
        ERRORS.append(f"{rel}: missing script {script_hint}")
    steps = re.search(r"load_steps=(\d+)", text)
    ext = len(re.findall(r"^\[ext_resource", text, re.M))
    sub = len(re.findall(r"^\[sub_resource", text, re.M))
    if steps and int(steps.group(1)) != ext + sub + 1:
        ERRORS.append(f"{rel}: load_steps mismatch (got {steps.group(1)}, want {ext + sub + 1})")


def function_body(rel: str, name: str) -> str:
    """Return one top-level GDScript function body (up to the next func/EOF)."""
    text = read(rel)
    match = re.search(rf"^func {re.escape(name)}\(", text, re.M)
    if not match:
        ERRORS.append(f"{rel}: missing func {name}()")
        return ""
    rest = text[match.end():]
    next_func = re.search(r"^func\s", rest, re.M)
    return rest[: next_func.start()] if next_func else rest


def check_depth_propagation() -> None:
    """Godot is unavailable here, so verify the depth data path structurally:
    owner depth -> projectile, before configuration/add_child, and that homing
    compares both depths. Without this, the same-layer filter silently no-ops.
    """
    spawn = function_body("scripts/weapons/weapon.gd", "_spawn_projectile")
    if not spawn:
        return
    assign = spawn.find("proj.depth")
    if assign < 0:
        ERRORS.append("weapon.gd: _spawn_projectile() does not set proj.depth")
        return
    for token, label in (("_configure_projectile(proj)", "configure"),
                         ("add_child(proj)", "add to tree")):
        idx = spawn.find(token)
        if idx < 0:
            ERRORS.append(f"weapon.gd: _spawn_projectile() missing {label}")
        elif assign > idx:
            ERRORS.append(f"weapon.gd: depth assigned after {label}")

    resolver = function_body("scripts/weapons/weapon.gd", "_launch_depth")
    if '"depth" in owner_node' not in resolver:
        ERRORS.append("weapon.gd: _launch_depth() does not read the owner's depth")

    homing = function_body("scripts/weapons/missile_projectile.gd", "_is_on_same_layer")
    for token in ('get("depth")', 'other.get("depth")', "depth_tolerance"):
        if token not in homing:
            ERRORS.append(f"missile_projectile.gd: layer check missing {token}")


def main() -> int:
    for rel in REQUIRED_FILES:
        read(rel)

    # Optional assets are declared centrally and are allowed to be absent
    # until the sprite (task-2) and SFX (task-3) worktrees are merged.
    resources_text = read("scripts/weapons/weapon_resources.gd")
    optional = set(re.findall(r"res://[A-Za-z0-9_./-]+", resources_text))
    player_text = read("scripts/player/player_ship.gd")
    project_text = read("project.godot")

    gd_files = sorted((ROOT / "scripts").rglob("*.gd"))
    class_names: dict[str, str] = {}
    for path in gd_files:
        rel = str(path.relative_to(ROOT))
        text = path.read_text(encoding="utf-8")
        check_delimiters(rel, text)
        check_resource_paths(rel, text, optional)
        for name in re.findall(r"^class_name\s+(\w+)", text, re.M):
            if name in class_names:
                ERRORS.append(f"duplicate class_name {name}: {class_names[name]} and {rel}")
            class_names[name] = rel

    for path in sorted((ROOT / "scenes").rglob("*.tscn")):
        rel = str(path.relative_to(ROOT))
        check_resource_paths(rel, path.read_text(encoding="utf-8"), optional)

    for rel, (script, kind) in PROJECTILE_SCENES.items():
        check_scene(rel, script, kind)

    for rel, pattern, label in BEHAVIOUR_CHECKS:
        text = project_text if rel == "project.godot" else read(rel)
        if not re.search(pattern, text, re.M):
            ERRORS.append(f"{rel}: missing {label} (/{pattern}/)")

    check_depth_propagation()

    # Cadence/ordering sanity: laser rapid, missile slower, bomb slowest and
    # capped. This is the closest check to a behaviour test without Godot.
    def weapon_number(prefix: str, field: str) -> float:
        match = re.search(rf"{prefix}\.{field} = ([\d.]+)", player_text)
        return float(match.group(1)) if match else -1.0

    rates = {w: weapon_number(w if w != "laser" else "weapon", "fire_rate")
             for w in ("laser", "missile", "bomb")}
    speeds = {w: weapon_number(w if w != "laser" else "weapon", "projectile_speed")
              for w in ("laser", "missile", "bomb")}
    if not (0 < rates["laser"] < rates["missile"] < rates["bomb"]):
        ERRORS.append(f"cadence order wrong: {rates}")
    if not (speeds["laser"] > speeds["missile"] > speeds["bomb"] > 0):
        ERRORS.append(f"projectile speed order wrong: {speeds}")
    bomb_ammo = weapon_number("bomb", "max_ammo")
    if not 0 < bomb_ammo < 10:
        ERRORS.append(f"bomb ammo cap out of range: {bomb_ammo}")

    after_input = project_text.split("[input]", 1)[-1]
    next_section = re.search(r"^\[[a-z_]+\]", after_input, re.M)
    input_section = after_input[: next_section.start()] if next_section else after_input
    for action in INPUT_ACTIONS_USED:
        if not re.search(rf"^{re.escape(action)}=\{{", input_section, re.M):
            ERRORS.append(f"project.godot: missing input action '{action}'")

    if ERRORS:
        print("WEAPON VALIDATION: FAIL")
        for err in ERRORS:
            print(f"  - {err}")
        return 1
    print(
        f"WEAPON VALIDATION: PASS "
        f"({len(REQUIRED_FILES)} required files, {len(gd_files)} scripts, "
        f"{len(BEHAVIOUR_CHECKS)} behaviour checks, {len(optional)} optional assets)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
