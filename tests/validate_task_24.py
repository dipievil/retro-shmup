#!/usr/bin/env python3
"""Regression check for card [0.8]: GDAS-1 must face right.

The animated engine flame is the only difference between the early frames
(frames 0-3); the weapon muzzle flash starts later.  A right-facing ship has
that flame on the LEFT half of each frame.  A whole-sprite horizontal flip
would move it to the RIGHT half and leave the cockpit/muzzle pointing left.
"""

import json
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHEET = ROOT / "assets/sprites/player/gdas1_sheet.png"
META = SHEET.with_suffix(".json")

FRAME_COUNT = 8
FRAME_SIZE = 32
DURATION = 90


def fail(message):
    print(f"FAIL {message}", file=sys.stderr)
    sys.exit(1)


def read_rgba_png(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail("sheet is not a PNG")
    pos = 8
    compressed = bytearray()
    header = None
    while pos < len(data):
        size = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + size]
        pos += 12 + size
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            compressed.extend(body)
        elif kind == b"IEND":
            break
    if header is None:
        fail("PNG has no IHDR")
    width, height, depth, color, _, _, interlace = header
    if (depth, color, interlace) != (8, 6, 0):
        fail("sheet must be 8-bit RGBA, non-interlaced")
    raw = zlib.decompress(compressed)
    stride = width * 4
    rows = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        line = bytearray(raw[offset + 1 : offset + 1 + stride])
        offset += 1 + stride
        for i in range(stride):
            a = line[i - 4] if i >= 4 else 0
            b = previous[i]
            c = previous[i - 4] if i >= 4 else 0
            if filter_type == 1:
                prediction = a
            elif filter_type == 2:
                prediction = b
            elif filter_type == 3:
                prediction = (a + b) // 2
            elif filter_type == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                prediction = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
            elif filter_type == 0:
                prediction = 0
            else:
                fail(f"unsupported PNG filter {filter_type}")
            line[i] = (line[i] + prediction) & 0xFF
        rows.append(bytes(line))
        previous = line
    return width, height, rows


def pixel(rows, x, y):
    return rows[y][x * 4 : x * 4 + 4]


def main():
    metadata = json.loads(META.read_text())
    frames = metadata["frames"]
    if len(frames) != FRAME_COUNT:
        fail(f"expected {FRAME_COUNT} frames, got {len(frames)}")
    for index, frame in enumerate(frames):
        box = frame["frame"]
        if box["w"] != FRAME_SIZE or box["h"] != FRAME_SIZE:
            fail(f"frame {index} is not {FRAME_SIZE}x{FRAME_SIZE}")
        if box["x"] != index * FRAME_SIZE or box["y"] != 0:
            fail(f"frame {index} is not in a horizontal sheet at x={index * FRAME_SIZE}")
        if frame["rotated"] or frame["trimmed"]:
            fail(f"frame {index} must not be rotated or trimmed")
        if frame["duration"] != DURATION:
            fail(f"frame {index} duration must be {DURATION}")
    size = metadata["meta"]["size"]
    if size["w"] != FRAME_COUNT * FRAME_SIZE or size["h"] != FRAME_SIZE:
        fail("sheet metadata is not 256x32")

    width, height, rows = read_rgba_png(SHEET)
    if (width, height) != (FRAME_COUNT * FRAME_SIZE, FRAME_SIZE):
        fail("sheet PNG is not 256x32")

    # Frames 0-3 only animate the engine flame; the muzzle flash appears later.
    changed = []
    for frame in (1, 2, 3):
        for y in range(FRAME_SIZE):
            for x in range(FRAME_SIZE):
                if pixel(rows, x, y) != pixel(rows, frame * FRAME_SIZE + x, y):
                    changed.append(x)
    if not changed:
        fail("engine flame is not animated in frames 0-3")
    wrong_side = [x for x in changed if x >= FRAME_SIZE // 2]
    if wrong_side:
        fail(f"engine flame animation reaches right half at x={sorted(set(wrong_side))}")

    print(
        f"OK: {FRAME_COUNT} frames of {FRAME_SIZE}x{FRAME_SIZE}, "
        f"engine flame confined to x<{FRAME_SIZE // 2} (ship faces right)"
    )


if __name__ == "__main__":
    main()
