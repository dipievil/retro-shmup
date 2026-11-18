#!/usr/bin/env python3
"""Reproducible, dependency-free audio generator for the Retro SHMUP MVP.

Context (docs/plan.md, "Dynamic Audio Design"):
    Suno/Udio (base track) -> UVR (stem isolation) -> Audacity (loop cleanup).

None of those applications -- nor Sonic Pi, sox or ffmpeg -- are installed in
this build environment, and AGENTS.md forbids installing new runtimes/apps
here. This script is the deterministic *fallback* generator: it synthesizes
every required MVP audio slot using only the Python 3 standard library.

Fixed noise seeds make re-runs byte-identical. See README.md next to this
file for the pipeline steps that remain deferred and how to reproduce them.

Usage:
    python3 assets/audio/generate_audio.py          # (re)generate all WAVs
    python3 assets/audio/generate_audio.py --check  # validate all WAVs
"""

from __future__ import annotations

import argparse
import math
import random
import sys
import wave
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MUSIC_DIR = ROOT / "music"
SFX_DIR = ROOT / "sfx"

# 140 BPM is the tempo declared by scripts/autoload/audio_manager.gd, so the
# loop stays phase-aligned with the engine's beat/bar counters.
RATE = 44100
BPM = 140
BEAT_FRAMES = RATE * 60 // BPM          # 18900 frames == 3/7 s (exact)
LOOP_BEATS = 16                         # 4 bars of 4/4
BAR_FRAMES = BEAT_FRAMES * 4
LOOP_FRAMES = BEAT_FRAMES * LOOP_BEATS  # 302400 frames == 6.857142... s
TAU = math.tau

MUSIC_FILES = ("base_beat.wav", "drums.wav", "vocals.wav")
SFX_FILES = (
    "laser.wav",
    "missile.wav",
    "bomb.wav",
    "enemy_hit.wav",
    "enemy_destroyed.wav",
    "explosion.wav",
)

# Am - F - C - G, one chord per bar: (bass root, chord tones), Hz.
CHORDS = (
    (110.00, (220.00, 261.63, 329.63)),  # Am
    (87.31, (174.61, 220.00, 261.63)),   # F
    (130.81, (261.63, 329.63, 392.00)),  # C
    (98.00, (196.00, 246.94, 293.66)),   # G
)
BASS_PATTERN = (1.0, 1.0, 1.5, 1.0, 2.0, 1.0, 1.5, 1.0)  # root/fifth/octave, per 8th


def _buffer(frames: int) -> list[float]:
    return [0.0] * frames


def _osc(phase: float, kind: str) -> float:
    p = phase % 1.0
    if kind == "sine":
        return math.sin(TAU * p)
    if kind == "saw":
        return 2.0 * p - 1.0
    if kind == "square":
        return 1.0 if p < 0.5 else -1.0
    if kind == "tri":
        return 1.0 - 4.0 * abs(p - 0.5)
    raise ValueError(f"unknown waveform: {kind}")


def add_tone(
    buf: list[float],
    start: int,
    dur: float,
    f0: float,
    f1: float | None = None,
    amp: float = 0.2,
    kind: str = "sine",
    attack: float = 0.004,
    decay: float = 4.0,
    phase: float = 0.0,
    vib_rate: float = 0.0,
    vib_depth: float = 0.0,
) -> None:
    """Add a pitched note with an exponential decay envelope and pitch sweep."""
    f1 = f0 if f1 is None else f1
    n = int(round(dur * RATE))
    end = min(start + n, len(buf))
    cyc = phase
    for i in range(max(0, start), end):
        t = (i - start) / RATE
        f = f0 + (f1 - f0) * (t / dur if dur > 0 else 0.0)
        if vib_rate:
            f *= 1.0 + vib_depth * math.sin(TAU * vib_rate * t)
        cyc += f / RATE
        env = (min(1.0, t / attack) if attack > 0 else 1.0) * math.exp(-decay * t)
        tail = min(1.0, (dur - t) / 0.012) if dur - t < 0.012 else 1.0
        buf[i] += amp * env * tail * _osc(cyc, kind)


def add_noise(
    buf: list[float],
    start: int,
    dur: float,
    amp: float = 0.2,
    attack: float = 0.002,
    decay: float = 20.0,
    cutoff0: float = 5000.0,
    cutoff1: float = 1500.0,
    mode: str = "lowpass",
    seed: int = 1,
) -> None:
    """Add seeded white noise shaped by a one-pole low/high-pass and envelope."""
    rng = random.Random(seed)
    n = int(round(dur * RATE))
    end = min(start + n, len(buf))
    lp = 0.0
    for i in range(max(0, start), end):
        t = (i - start) / RATE
        cutoff = max(40.0, cutoff0 + (cutoff1 - cutoff0) * (t / dur if dur > 0 else 0.0))
        a = 1.0 - math.exp(-TAU * cutoff / RATE)
        x = rng.uniform(-1.0, 1.0)
        lp += a * (x - lp)
        sample = lp if mode == "lowpass" else x - lp
        env = (min(1.0, t / attack) if attack > 0 else 1.0) * math.exp(-decay * t)
        tail = min(1.0, (dur - t) / 0.012) if dur - t < 0.012 else 1.0
        buf[i] += amp * env * tail * sample


def build_drums() -> list[float]:
    """Isolated drum stem: four-on-the-floor kick, backbeat snare, eighth hats."""
    buf = _buffer(LOOP_FRAMES)
    for beat in range(LOOP_BEATS):
        s = beat * BEAT_FRAMES
        add_tone(buf, s, 0.22, 150.0, 48.0, 0.95, "sine", attack=0.001, decay=17.0)
        add_noise(buf, s, 0.012, 0.22, 0.0005, 120.0, 7000.0, 7000.0,
                  "highpass", seed=100 + beat)
        if beat % 4 in (1, 3):
            add_noise(buf, s, 0.18, 0.42, 0.002, 22.0, 4200.0, 1100.0,
                      "lowpass", seed=200 + beat)
            add_tone(buf, s, 0.09, 210.0, 150.0, 0.16, "tri", attack=0.001, decay=28.0)
        for eighth in range(2):
            hs = s + eighth * (BEAT_FRAMES // 2)
            accent = eighth == 0
            add_noise(buf, hs, 0.05, 0.20 if accent else 0.12, 0.001, 55.0,
                      7000.0, 7000.0, "highpass", seed=300 + beat * 2 + eighth)
    return buf


def build_bass() -> list[float]:
    buf = _buffer(LOOP_FRAMES)
    step = BEAT_FRAMES // 2
    for bar in range(4):
        root = CHORDS[bar][0]
        for i in range(8):
            s = bar * BAR_FRAMES + i * step
            f = root * BASS_PATTERN[i]
            add_tone(buf, s, 0.19, f, amp=0.24, kind="sine", decay=8.0)
            add_tone(buf, s, 0.19, f, amp=0.16, kind="saw", decay=9.0)
    return buf


def build_pad() -> list[float]:
    buf = _buffer(LOOP_FRAMES)
    for bar in range(4):
        s = bar * BAR_FRAMES
        for note in CHORDS[bar][1]:
            add_tone(buf, s, BAR_FRAMES * 0.98, note, amp=0.085, attack=0.22,
                     decay=0.30, vib_rate=4.5, vib_depth=0.003)
            add_tone(buf, s, BAR_FRAMES * 0.98, note * 1.005, amp=0.06,
                     kind="tri", attack=0.25, decay=0.35)
            add_tone(buf, s, BAR_FRAMES * 0.98, note / 2.0, amp=0.05,
                     attack=0.25, decay=0.35)
    return buf


def build_arp() -> list[float]:
    buf = _buffer(LOOP_FRAMES)
    step = BEAT_FRAMES // 4
    for bar in range(4):
        tones = CHORDS[bar][1]
        for i in range(16):
            s = bar * BAR_FRAMES + i * step
            note = tones[i % 3] * 2.0
            add_tone(buf, s, 0.11, note, amp=0.075, kind="tri",
                     attack=0.002, decay=14.0)
    return buf


def build_vocals() -> list[float]:
    """Synthesized vowel-like GUIDE track, not real/AI vocals (no lyrics)."""
    buf = _buffer(LOOP_FRAMES)
    for bar in range(4):
        s = bar * BAR_FRAMES
        tones = CHORDS[bar][1]
        for phrase in (0, 1):
            ps = s + phrase * 2 * BEAT_FRAMES
            f = tones[phrase + 1]
            for harmonic, amp in ((1, 0.22), (2, 0.10), (3, 0.07), (4, 0.03)):
                add_tone(buf, ps, 2 * BEAT_FRAMES * 0.97, f * harmonic,
                         amp=amp, attack=0.14, decay=0.75,
                         vib_rate=5.2, vib_depth=0.004)
    return buf


def sfx_laser() -> list[float]:
    buf = _buffer(int(0.16 * RATE))
    add_tone(buf, 0, 0.15, 1800.0, 320.0, 0.85, "saw", attack=0.001, decay=22.0)
    add_tone(buf, 0, 0.13, 900.0, 160.0, 0.35, "square", attack=0.001, decay=26.0)
    add_noise(buf, 0, 0.02, 0.18, 0.0005, 150.0, 8000.0, 8000.0, "highpass", seed=11)
    return buf


def sfx_missile() -> list[float]:
    buf = _buffer(int(0.42 * RATE))
    add_noise(buf, 0, 0.40, 0.55, 0.01, 4.0, 500.0, 3500.0, "lowpass", seed=22)
    add_tone(buf, 0, 0.35, 110.0, 230.0, 0.45, "saw", attack=0.01, decay=3.5)
    add_tone(buf, int(0.32 * RATE), 0.09, 240.0, 80.0, 0.30,
             "sine", attack=0.001, decay=12.0)
    return buf


def sfx_bomb() -> list[float]:
    buf = _buffer(int(1.0 * RATE))
    add_tone(buf, 0, 0.85, 160.0, 42.0, 0.90, "sine", attack=0.002, decay=3.2)
    add_noise(buf, 0, 0.75, 0.70, 0.004, 4.0, 2200.0, 260.0, "lowpass", seed=33)
    add_noise(buf, int(0.06 * RATE), 0.20, 0.25, 0.002, 10.0,
              7000.0, 7000.0, "highpass", seed=34)
    return buf


def sfx_enemy_hit() -> list[float]:
    buf = _buffer(int(0.12 * RATE))
    add_noise(buf, 0, 0.075, 0.55, 0.0005, 42.0, 6000.0, 2000.0, "lowpass", seed=44)
    add_tone(buf, 0, 0.09, 1320.0, 760.0, 0.35, "square", attack=0.001, decay=34.0)
    return buf


def sfx_enemy_destroyed() -> list[float]:
    buf = _buffer(int(0.38 * RATE))
    add_noise(buf, 0, 0.34, 0.65, 0.002, 7.0, 4200.0, 500.0, "lowpass", seed=55)
    add_tone(buf, 0, 0.30, 520.0, 110.0, 0.40, "saw", attack=0.002, decay=9.0)
    add_noise(buf, int(0.12 * RATE), 0.12, 0.20, 0.001, 25.0,
              7000.0, 7000.0, "highpass", seed=56)
    return buf


def sfx_explosion() -> list[float]:
    buf = _buffer(int(1.2 * RATE))
    add_tone(buf, 0, 1.0, 95.0, 32.0, 0.95, "sine", attack=0.003, decay=2.6)
    add_noise(buf, 0, 1.05, 0.75, 0.003, 2.8, 3000.0, 220.0, "lowpass", seed=66)
    add_noise(buf, 0, 0.18, 0.30, 0.001, 16.0, 6500.0, 6500.0, "highpass", seed=67)
    for k, offset in enumerate((0.13, 0.31, 0.52)):
        add_noise(buf, int(offset * RATE), 0.14, 0.22, 0.001, 20.0,
                  5500.0, 5500.0, "highpass", seed=70 + k)
    return buf


def write_wav(path: Path, buf: list[float], peak: float = 0.88,
              edge_fade: float = 0.005) -> None:
    """Normalize and write 16-bit mono PCM WAV with a short seam de-click fade."""
    path.parent.mkdir(parents=True, exist_ok=True)
    found = max(abs(x) for x in buf)
    if found <= 1e-9:
        raise ValueError(f"{path.name}: buffer is silent")
    scale = peak / found
    n = len(buf)
    fade_n = max(1, int(edge_fade * RATE)) if edge_fade else 0
    pcm = array("h")
    for i, x in enumerate(buf):
        v = x * scale
        if fade_n:
            edge = min(i, n - 1 - i)
            if edge < fade_n:
                v *= edge / fade_n
        pcm.append(int(max(-1.0, min(1.0, v)) * 32767.0))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def check() -> bool:
    expected = [(MUSIC_DIR / name, True) for name in MUSIC_FILES]
    expected += [(SFX_DIR / name, False) for name in SFX_FILES]
    print(f"{'file':<22} {'bytes':>9} {'dur(s)':>8} {'rate':>6} {'ch':>3} {'peak':>6}  result")
    ok = True
    for path, is_loop in expected:
        try:
            if not path.is_file():
                raise FileNotFoundError(str(path))
            size = path.stat().st_size
            if size < 1000:
                raise ValueError("file too small")
            with wave.open(str(path), "rb") as w:
                ch, width, rate, frames = (
                    w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
                )
                raw = w.readframes(frames)
            if (ch, width, rate) != (1, 2, RATE) or frames <= 0:
                raise ValueError(f"bad header: {ch}ch/{width * 8}bit/{rate}Hz/{frames}f")
            samples = array("h")
            samples.frombytes(raw)
            if sys.byteorder != "little":
                samples.byteswap()
            peak = max(abs(s) for s in samples)
            if not 0 < peak <= 32767:
                raise ValueError(f"bad peak: {peak}")
            if is_loop and frames != LOOP_FRAMES:
                raise ValueError(f"loop length {frames} != {LOOP_FRAMES} frames")
            print(f"{str(path.relative_to(ROOT)):<22} {size:>9} {frames / RATE:>8.3f} "
                  f"{rate:>6} {ch:>3} {peak:>6}  PASS")
        except Exception as exc:  # noqa: BLE001 - report every asset, then fail
            ok = False
            print(f"{str(path.relative_to(ROOT)):<22} {'-':>9} {'-':>8} {'-':>6} "
                  f"{'-':>3} {'-':>6}  FAIL: {exc}")
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="validate all expected WAVs instead of generating them")
    args = parser.parse_args()
    if args.check:
        return 0 if check() else 1

    drums, bass, pad, arp = build_drums(), build_bass(), build_pad(), build_arp()
    base = [
        0.80 * drums[i] + bass[i] + pad[i] + arp[i]
        for i in range(LOOP_FRAMES)
    ]
    write_wav(MUSIC_DIR / "base_beat.wav", base)
    write_wav(MUSIC_DIR / "drums.wav", drums)
    write_wav(MUSIC_DIR / "vocals.wav", build_vocals())

    sfx = {
        "laser.wav": sfx_laser(),
        "missile.wav": sfx_missile(),
        "bomb.wav": sfx_bomb(),
        "enemy_hit.wav": sfx_enemy_hit(),
        "enemy_destroyed.wav": sfx_enemy_destroyed(),
        "explosion.wav": sfx_explosion(),
    }
    for name, buf in sfx.items():
        write_wav(SFX_DIR / name, buf, edge_fade=0.001)

    return 0 if check() else 1


if __name__ == "__main__":
    sys.exit(main())
