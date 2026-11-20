#!/usr/bin/env bash
################################################################################
# Run every check the project has:
#   1. Godot headless import (fails on GDScript parse errors)
#   2. Python validators (tools/validate_*.py and tests/validate_*.py)
#   3. Audio asset validation (assets/audio/generate_audio.py --check)
#   4. GDScript test suites (tests/test_*.gd and tests/*_test.gd, run with --script)
#   5. Optional gdtoolkit lint/format check (--lint)
#
# Usage:
#   tools/run_all.sh            # import, validators, test suites
#   tools/run_all.sh --lint     # also run gdlint and gdformat --check
#
# Env:
#   GODOT_BIN    Godot binary to use (default: godot)
#   PYTHON_BIN   Python interpreter (default: python3)
#   SUITE_TIMEOUT  seconds per GDScript suite (default: 120)
################################################################################

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR" || exit 1

GODOT_BIN="${GODOT_BIN:-godot}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
SUITE_TIMEOUT="${SUITE_TIMEOUT:-120}"
RUN_LINT=0

for arg in "$@"; do
    case "$arg" in
        --lint) RUN_LINT=1 ;;
        -h | --help)
            sed -n '1,20p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            echo "unknown argument: $arg" >&2
            exit 2
            ;;
    esac
done

# Godot warns when started as root (CI containers and the builder LXC both do).
export GODOT_SILENCE_ROOT_WARNING=1

FAILED=0
STEP=0
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

pass() { echo "  PASS  $1"; }
fail() {
    echo "  FAIL  $1" >&2
    FAILED=$((FAILED + 1))
}
skip() { echo "  SKIP  $1"; }
section() {
    STEP=$((STEP + 1))
    echo
    echo "== ${STEP}. ${1} =="
}

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    echo "error: Godot binary '${GODOT_BIN}' not found (set GODOT_BIN)" >&2
    exit 2
fi

# --------------------------------------------------------------------------
section "Godot import ($("$GODOT_BIN" --headless --version | head -1))"
# --------------------------------------------------------------------------
if "$GODOT_BIN" --headless --import >"$LOG" 2>&1; then
    if grep -qE 'Parse Error|SCRIPT ERROR|Failed to load script' "$LOG"; then
        fail "GDScript parse errors during import"
        grep -nE 'Parse Error|SCRIPT ERROR|Failed to load script' "$LOG" | head -20 | sed 's/^/        /'
    else
        pass "project imported without parse errors"
    fi
else
    fail "godot --import exited non-zero"
    tail -20 "$LOG" | sed 's/^/        /'
fi

# --------------------------------------------------------------------------
section "Asset validators"
# --------------------------------------------------------------------------
VALIDATOR_COUNT=0
# Discovery runs on fd 3 so child processes keep their own stdin.
while IFS= read -r -u 3 file; do
    VALIDATOR_COUNT=$((VALIDATOR_COUNT + 1))
    if "$PYTHON_BIN" "$file" >"$LOG" 2>&1; then
        pass "$file"
    else
        fail "$file"
        tail -25 "$LOG" | sed 's/^/        /'
    fi
done 3< <(find tools tests -maxdepth 1 -name 'validate_*.py' 2>/dev/null | sort)

if [ "$VALIDATOR_COUNT" -eq 0 ]; then
    skip "no validate_*.py found"
fi

# --------------------------------------------------------------------------
section "Audio assets"
# --------------------------------------------------------------------------
if [ -f assets/audio/generate_audio.py ]; then
    if "$PYTHON_BIN" assets/audio/generate_audio.py --check >"$LOG" 2>&1; then
        pass "assets/audio/generate_audio.py --check"
    else
        fail "assets/audio/generate_audio.py --check"
        tail -25 "$LOG" | sed 's/^/        /'
    fi
else
    skip "no assets/audio/generate_audio.py"
fi

# --------------------------------------------------------------------------
section "GDScript test suites"
# --------------------------------------------------------------------------
# Avoid expanding an empty array under `set -u`: Bash < 4.4 treats that as an
# unbound variable, so keep the optional timeout in a scalar and branch on it.
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN="$(command -v timeout)"
fi

run_suite() {
    if [ -n "$TIMEOUT_BIN" ]; then
        "$TIMEOUT_BIN" "$SUITE_TIMEOUT" "$@"
    else
        "$@"
    fi
}

SUITE_COUNT=0
while IFS= read -r -u 3 file; do
    SUITE_COUNT=$((SUITE_COUNT + 1))
    # A suite with a companion .tscn is scene-based: it needs the project's
    # autoloads and global class_name registrations, which Godot does not set
    # up in --script mode. Run it through the scene instead.
    suite_args=(--script "res://${file}")
    suite_label="$file"
    if [ -f "${file%.gd}.tscn" ]; then
        suite_args=(--path . "res://${file%.gd}.tscn")
        suite_label="${file%.gd}.tscn"
    fi
    if run_suite "$GODOT_BIN" --headless "${suite_args[@]}" >"$LOG" 2>&1; then
        pass "$suite_label"
    else
        fail "$suite_label"
        tail -30 "$LOG" | sed 's/^/        /'
    fi
done 3< <(find tests -maxdepth 1 \( -name '*_test.gd' -o -name 'test_*.gd' \) 2>/dev/null | sort)

if [ "$SUITE_COUNT" -eq 0 ]; then
    skip "no tests/*_test.gd found"
fi

# --------------------------------------------------------------------------
if [ "$RUN_LINT" = "1" ]; then
    section "Lint (gdtoolkit)"
    if ! command -v gdlint >/dev/null 2>&1; then
        skip "gdlint not installed"
    else
        LINT_PATHS=(scripts)
        if [ -d tests ]; then
            LINT_PATHS+=(tests)
        fi
        if gdlint "${LINT_PATHS[@]}" >"$LOG" 2>&1; then
            pass "gdlint"
        else
            fail "gdlint"
            tail -25 "$LOG" | sed 's/^/        /'
        fi
        if command -v gdformat >/dev/null 2>&1; then
            if gdformat --check scripts >"$LOG" 2>&1; then
                pass "gdformat --check"
            else
                fail "gdformat --check"
                tail -10 "$LOG" | sed 's/^/        /'
            fi
        fi
    fi
fi

echo
if [ "$FAILED" -gt 0 ]; then
    echo "${FAILED} check(s) failed" >&2
    exit 1
fi
echo "All checks passed"
