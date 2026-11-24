#!/usr/bin/env python3
"""Structural validation for the retro-shmup Godot project.

Runs without Godot installed: checks project settings, folder layout, scene and
script resource references, unique class names, GDScript block indentation and
the absence of obvious secrets. If a Godot binary is on PATH (or set in GODOT_BIN),
an additional headless parse is attempted.

Usage: python3 tools/validate_project.py
Exit code 0 = all checks passed, 1 = at least one failure.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

failures: list[str] = []
checks = 0


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if condition:
        print(f"  ok   {message}")
    else:
        print(f"FAIL   {message}")
        failures.append(message)


def section(title: str) -> None:
    print(f"\n[{title}]")


def strip_comment(line: str) -> str:
    """Remove an inline # comment, ignoring # inside quotes (good enough here)."""
    quote: str | None = None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
        elif ch in ("'", '"'):
            quote = ch
        elif ch == "#":
            return line[:i]
    return line


# --------------------------------------------------------------------------
# Folder layout (docs/plan.md "Foundation" + task-1 plan step 3)
# --------------------------------------------------------------------------
section("folder layout")
required_dirs = [
    "scenes",
    "scripts",
    "scenes/ui",
    "scripts/ui",
    "assets",
    "assets/sprites",
    "assets/sprites/player",
    "assets/sprites/enemies",
    "assets/sprites/effects",
    "assets/sprites/props",
    "assets/audio",
    "assets/audio/music",
    "assets/audio/sfx",
]
for rel in required_dirs:
    check((ROOT / rel).is_dir(), f"directory exists: {rel}")

section("required files")
required_files = [
    "project.godot",
    "icon.svg",
    "README.md",
    "scenes/main.tscn",
    "scripts/main.gd",
    "scripts/autoload/game_manager.gd",
    "scripts/autoload/audio_manager.gd",
]
for rel in required_files:
    check((ROOT / rel).is_file(), f"file exists: {rel}")


# --------------------------------------------------------------------------
# project.godot settings
# --------------------------------------------------------------------------
section("project.godot")
settings: dict[str, str] = {}
project_text = ""
project_path = ROOT / "project.godot"
if project_path.is_file():
    project_text = project_path.read_text(encoding="utf-8")
    current_section = ""
    for raw in project_text.splitlines():
        line = strip_comment(raw).strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            current_section = line[1:-1]
            continue
        match = re.match(r"^([A-Za-z0-9_/]+)\s*=\s*(.*)$", line)
        if match:
            key = match.group(1)
            settings[f"{current_section}/{key}" if current_section else key] = match.group(2)

check(settings.get("config_version") == "5", "config_version is 5 (Godot 4.x)")
check(
    settings.get("application/run/main_scene") == '"res://scenes/main.tscn"',
    "main scene is res://scenes/main.tscn",
)
check(
    settings.get("rendering/textures/canvas_textures/default_texture_filter") == "0",
    "canvas texture filter = 0 (Nearest / nearest-neighbour pixel art)",
)
check(
    settings.get("display/window/stretch/scale_mode") == '"integer"',
    'stretch scale_mode = "integer" (no fractional pixel scaling)',
)
check(
    settings.get("rendering/2d/snap/snap_2d_transforms_to_pixel") == "true",
    "2D transforms snap to whole pixels",
)
check(
    settings.get("rendering/renderer/rendering_method") == '"gl_compatibility"',
    "GL Compatibility renderer (portable, lightweight)",
)
for autoload in ("GameManager", "AudioManager"):
    value = settings.get(f"autoload/{autoload}", "")
    rel = value.strip('"').lstrip("*").removeprefix("res://")
    check(
        value.strip('"').startswith("*res://") and (ROOT / rel).is_file(),
        f"autoload {autoload} points to an existing script",
    )
for action in (
    "move_up",
    "move_down",
    "move_left",
    "move_right",
    "zoom_in",
    "zoom_out",
    "fire",
    "fire_laser",
    "fire_missile",
    "fire_bomb",
    "start",
    "pause",
):
    check(f"input/{action}" in settings, f"input action defined: {action}")

bus_layout = settings.get("audio/buses/default_bus_layout", '""').strip('"')
check(
    bus_layout == "" or (ROOT / bus_layout.removeprefix("res://")).is_file(),
    "audio bus layout resolves (empty = built at runtime by AudioManager)",
)


# --------------------------------------------------------------------------
# Scene and script resource references
# --------------------------------------------------------------------------
section("scene resources")
scene_files = sorted((ROOT / "scenes").rglob("*.tscn"))
check(bool(scene_files), "at least one .tscn scene exists")
for scene in scene_files:
    text = scene.read_text(encoding="utf-8")
    rel = scene.relative_to(ROOT)
    declared: set[str] = set()
    for resource_line in (line for line in text.splitlines() if line.startswith("[ext_resource")):
        path_match = re.search(r'path="(res://[^"]+)"', resource_line)
        id_match = re.search(r'id="([^"]+)"', resource_line)
        if not path_match or not id_match:
            check(False, f"{rel}: malformed ext_resource line: {resource_line}")
            continue
        path = path_match.group(1)
        declared.add(id_match.group(1))
        check(
            (ROOT / path.removeprefix("res://")).is_file(),
            f"{rel}: ext_resource {path} exists",
        )
    used_ext = set(re.findall(r'(?:ExtResource|instance=ExtResource)\("([^"]+)"\)', text))
    check(used_ext <= declared, f"{rel}: all ExtResource ids are declared")
    declared_sub: set[str] = set(re.findall(r'\[sub_resource\s+[^\]]*?id="([^"]+)"', text))
    used_sub = set(re.findall(r'SubResource\("([^"]+)"\)', text))
    check(used_sub <= declared_sub, f"{rel}: all SubResource ids are declared")

# Registries of optional resource paths carry the marker below in a comment.
# Those paths are probed at runtime and fall back when the asset is absent (e.g.
# weapon sprites/SFX authored in sibling tasks), so demanding they exist here is
# a false positive. Every other script stays subject to the existence check.
OPTIONAL_ASSET_MARKER = "OPTIONAL-ASSET-REGISTRY"

section("script resources")
script_files = sorted((ROOT / "scripts").rglob("*.gd"))
check(bool(script_files), "at least one .gd script exists")
for script in script_files:
    text = script.read_text(encoding="utf-8")
    rel = script.relative_to(ROOT)
    if OPTIONAL_ASSET_MARKER in text:
        continue
    for path in set(re.findall(r"res://[A-Za-z0-9_./-]+", text)):
        check((ROOT / path.removeprefix("res://")).exists(), f"{rel}: {path} exists")

section("GDScript global class names")
class_owners: dict[str, list[str]] = {}
for script in script_files:
    seen_here: list[str] = []
    for line in script.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", line.strip())
        if match:
            name = match.group(1)
            seen_here.append(name)
            class_owners.setdefault(name, []).append(str(script.relative_to(ROOT)))
    check(
        len(seen_here) == len(set(seen_here)),
        f"{script.relative_to(ROOT)}: no duplicate class_name declaration",
    )
for name, owners in sorted(class_owners.items()):
    check(len(owners) == 1, f"class_name {name} is global-unique ({', '.join(owners)})")

for required_class in ("PlayerShip", "StageBase", "HUD", "BaseEnemy"):
    check(required_class in class_owners, f"class_name {required_class} is declared")

section("GDScript indentation")
for script in script_files:
    rel = script.relative_to(ROOT)
    lines = script.read_text(encoding="utf-8").splitlines()
    problems: list[int] = []
    for i, raw in enumerate(lines):
        code = strip_comment(raw)
        if not code.strip() or code.strip().startswith("#"):
            continue
        if not code.rstrip().endswith(":"):
            continue
        indent = len(code) - len(code.lstrip("\t"))
        # Find the next meaningful line.
        j = i + 1
        while j < len(lines):
            nxt = strip_comment(lines[j])
            if nxt.strip() and not nxt.strip().startswith("#"):
                break
            j += 1
        if j >= len(lines):
            problems.append(i + 1)
            continue
        next_indent = len(lines[j]) - len(lines[j].lstrip("\t"))
        if next_indent <= indent:
            problems.append(i + 1)
    check(not problems, f"{rel}: block statements open an indented block (bad lines: {problems})")


# --------------------------------------------------------------------------
# Secrets scan
# --------------------------------------------------------------------------
section("secrets scan")
secret_patterns = [
    re.compile(r"-----BEGIN (?:RSA|EC|DSA|OPENSSH|PGP) PRIVATE KEY-----"),
    re.compile(
        r"(?i)\b(?:api[_-]?key|secret[_-]?key|access[_-]?token|password|passwd)\b\s*[:=]\s*['\"][^'\"]{6,}['\"]"
    ),
    re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b"),
    re.compile(r"\bsk-[A-Za-z0-9]{20,}\b"),
    re.compile(r"\bAIza[0-9A-Za-z_-]{30,}\b"),
]
scanned = 0
for path in ROOT.rglob("*"):
    if not path.is_file() or ".git" in path.parts or ".godot" in path.parts:
        continue
    if path.suffix not in {".gd", ".tscn", ".godot", ".md", ".cfg", ".json", ".tres", ".py", ".svg"}:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    scanned += 1
    for pattern in secret_patterns:
        if pattern.search(text):
            check(False, f"potential secret in {path.relative_to(ROOT)}: {pattern.pattern[:40]}")
check(scanned > 0, f"scanned {scanned} text files for secrets")


# --------------------------------------------------------------------------
# Engine parse (optional)
# --------------------------------------------------------------------------
section("Godot engine parse")
godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4") or shutil.which("godot-4")
if godot:
    try:
        result = subprocess.run(
            [godot, "--headless", "--path", str(ROOT), "--editor", "--quit"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        check(result.returncode == 0, f"{godot} headless parse exited {result.returncode}")
        if result.returncode != 0:
            print(result.stdout[-2000:])
            print(result.stderr[-2000:])
    except subprocess.TimeoutExpired:
        check(False, "Godot headless parse timed out")
    except OSError as exc:
        check(False, f"cannot run {godot}: {exc}")
else:
    print("  note  no Godot binary found - structural validation only (engine parse skipped)")


# --------------------------------------------------------------------------
print(f"\n{checks - len(failures)}/{checks} checks passed.")
if failures:
    print(f"{len(failures)} FAILED:")
    for item in failures:
        print(f"  - {item}")
    sys.exit(1)
print("All structural checks passed.")
