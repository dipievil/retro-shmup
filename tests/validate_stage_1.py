#!/usr/bin/env python3
"""Structural checks for task-19 (stage 1 playable training stage).

Complements tests/test_stage_1.gd: catches missing scene wiring, parallax
layers, wave table or cutscene hook without needing a Godot binary.
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


print("[task-19] stage wiring")
main = read("scenes/main.tscn")
check('path="res://scenes/stages/stage_1.tscn"' in main, "main scene instances stage_1.tscn")
check('name="Stage1" parent="." instance=' in main, "main scene names the stage node Stage1")
main_script = read("scripts/main.gd")
check("stage_completed.connect(_on_stage_completed)" in main_script,
      "main connects the stage_completed hook")
check("res://scenes/cutscenes/stage_1_end.tscn" in main_script,
      "main references the stage 1 end cutscene")

print("[task-19] parallax and waves")
stage_scene = read("scenes/stages/stage_1.tscn")
for node in (
    'node name="ParallaxBackground" type="ParallaxBackground"',
    'node name="FarLayer" type="ParallaxLayer"',
    'node name="MidLayer" type="ParallaxLayer"',
    'node name="NearLayer" type="ParallaxLayer"',
):
    check(node in stage_scene, f"stage 1 reuses {node.split(chr(34))[1]}")

stage_script = read("scripts/stages/stage_1.gd")
check("extends StageBase" in stage_script, "stage 1 extends the existing StageBase")
check("signal stage_completed" in stage_script, "stage_completed signal declared")
check("signal wave_started" in stage_script, "wave_started signal declared")
for wave in ("01_first_contact", "02_formation", "03_flank", "04_surge"):
    check(wave in stage_script, f"wave table includes {wave}")
for enemy_scene in ("stage1_scout.tscn", "stage1_interceptor.tscn"):
    check((ROOT / "scenes" / "enemies" / enemy_scene).is_file(),
          f"stage 1 enemy scene exists: {enemy_scene}")
    enemy_script = read(f"scripts/enemies/{enemy_scene.replace('.tscn', '.gd')}")
    check("extends BaseEnemy" in enemy_script, f"{enemy_scene} reuses BaseEnemy")

print("[task-19] cutscene hook")
cutscene = read("scenes/cutscenes/stage_1_end.tscn")
check('node name="Stage1EndCutscene" type="Control"' in cutscene, "cutscene root is a Control")
check('node name="AnimationPlayer" type="AnimationPlayer"' in cutscene,
      "cutscene has an AnimationPlayer")
check("anims/play = SubResource(" in cutscene, "cutscene has a play animation")
check('node name="DialogueText" type="RichTextLabel"' in cutscene, "cutscene has a text panel")
check("Alex Mercer" in read("scripts/cutscenes/stage_1_end_cutscene.gd"),
      "cutscene carries the stage 1 story beat")
check((ROOT / "tests" / "test_stage_1.gd").is_file(), "headless stage 1 test suite present")
check((ROOT / "tests" / "test_stage_1.tscn").is_file(), "headless stage 1 test scene present")

if FAILURES:
    print(f"\n{len(FAILURES)} CHECK(S) FAILED")
    sys.exit(1)
print("\nALL STAGE 1 STRUCTURAL CHECKS PASSED")
