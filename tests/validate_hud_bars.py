#!/usr/bin/env python3
"""Headless stderr regression for task-10 (HUD stat bars).

Instantiates hud.tscn through Godot and inspects the combined stdout/stderr.
The original double-parent bug printed "already has a parent" three times but
still exited 0, so checking the exit code alone is not enough: this validator
fails whenever that message appears, even if the scene test exits cleanly.

Run from anywhere:  python3 tests/validate_hud_bars.py
Uses GODOT_BIN when set (default: godot), matching tools/run_all.sh.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN", "godot")
SCENE = "res://tests/test_hud_bars.tscn"
MARKER = "already has a parent"


def main() -> int:
    try:
        proc = subprocess.run(
            [GODOT, "--headless", "--path", str(ROOT), SCENE],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=120,
            env={**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1"},
        )
    except FileNotFoundError:
        print(f"  FAIL  Godot binary not found: {GODOT}")
        return 1
    except subprocess.TimeoutExpired:
        print(f"  FAIL  {SCENE} timed out after 120s")
        return 1

    output = proc.stdout or ""
    errors: list[str] = []
    if MARKER in output:
        errors.append(f"Godot logged '{MARKER}' while instancing hud.tscn")
        for line in output.splitlines():
            if MARKER in line:
                print(f"  FAIL  {line.strip()}")
    if proc.returncode != 0:
        errors.append(f"{SCENE} exited {proc.returncode}")
        for line in output.splitlines()[-15:]:
            print(f"        {line}")

    if errors:
        print("HUD STDERR REGRESSION: FAIL")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(f"  PASS  no '{MARKER}' in headless HUD run; scene exited 0")
    print("HUD STDERR REGRESSION: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
