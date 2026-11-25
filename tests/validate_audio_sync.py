#!/usr/bin/env python3
"""Structural checks for task-18 (dynamic audio sync).

The behavioural checks live in tests/test_audio_manager.gd and run headless.
This validator guards the wiring that cannot be observed without starting real
audio playback (which leaves AudioStreamPlayback objects alive under the
headless driver at engine shutdown).

    python3 tests/validate_audio_sync.py
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


def body(source: str, signature: str) -> str:
    match = re.search(re.escape(signature) + r"[^\n]*\n(.*?)(?=\nfunc |\Z)", source, re.S)
    return match.group(1) if match else ""


manager = read("scripts/autoload/audio_manager.gd")
print("[task-18] AudioManager implementation")
check("AudioServer" in manager, "AudioServer manages the stem buses")
check("AudioStreamPlayer.new()" in manager, "one AudioStreamPlayer is created per stem")
check("func load_stems()" in manager, "stems are loaded through load_stems()")
check("ResourceLoader.exists" in manager, "missing stem files are detected before load")
check("if not is_layer_available(layer)" in manager, "events skip unavailable layers")
check("func set_layer(" in manager and "tween_method" in manager,
      "layer volume changes are tweened")
check("func on_event(" in manager and "MIXES" in manager,
      "named events map to mix presets")
check("player.get_playback_position()" in manager,
      "beat/bar timing follows engine playback, not wall clock")
check("Time.get_ticks_msec" not in manager, "no wall-clock beat tracking")

start_body = body(manager, "func play_default_music()")
check("player.play()" in start_body, "play_default_music() starts the looped players")
check("on_event(" in start_body, "play_default_music() applies the initial mix")

print("[task-18] Event wiring")
main = read("scripts/main.gd")
check("AudioManager.play_default_music()" in main, "main scene starts the music")
stage = read("scripts/stages/stage_base.gd")
for event in ("EVENT_STAGE_START", "EVENT_ENEMY_SPAWNED",
              "EVENT_ENEMY_DESTROYED", "EVENT_STAGE_CLEAR"):
    check(f"AudioManager.{event}" in stage, f"stage_base emits {event}")
cutscene = read("scripts/cutscenes/cutscene_manager.gd")
for event in ("EVENT_CUTSCENE_START", "EVENT_CUTSCENE_END"):
    check(f"AudioManager.{event}" in cutscene, f"cutscene_manager emits {event}")
check("AudioManager.hull_changed" not in manager and "GameManager.hull_changed" in manager,
      "player damage is wired from GameManager signals")
check("GameManager.game_state_changed" in manager, "state changes drive cutscene mixes")

print("[task-18] Assets and docs")
for stem in ("base_beat.wav", "drums.wav", "vocals.wav"):
    path = ROOT / "assets" / "audio" / "music" / stem
    valid = path.is_file() and path.stat().st_size > 44
    if valid:
        with path.open("rb") as handle:
            header = handle.read(12)
        valid = header[:4] == b"RIFF" and header[8:12] == b"WAVE"
    check(valid, f"task-3 stem present as WAV: {stem}")
check("Dynamic audio API" in read("README.md"), "audio API is documented in README.md")
check((ROOT / "tests" / "test_audio_manager.gd").is_file(), "headless GDScript suite present")
check((ROOT / "tests" / "test_audio_manager.tscn").is_file(), "headless test scene present")

if FAILURES:
    print(f"\n{len(FAILURES)} CHECK(S) FAILED")
    sys.exit(1)
print("\nALL AUDIO SYNC STRUCTURAL CHECKS PASSED")
