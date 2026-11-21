#!/usr/bin/env python3
"""Dry-run the semantic-release version derivation from the real workflow.

The `Compute next semantic version` and `Create per-platform archives and
SHA256SUMS` steps are extracted verbatim from
.github/workflows/semantic-release.yml and executed in throwaway directories.
Testing the workflow's own shell code (rather than a copy) prevents the test
from drifting away from the logic that actually runs in CI.

Covers: patch / minor / `type!:` major, both `BREAKING CHANGE:` and
`BREAKING-CHANGE:` footers (major), the strict-semver baseline filter that must
ignore the demo tag `v0.0.1-demo`, and macOS release packaging (inner tarball
unpacked, executable bit preserved, no nested archive, checksums valid).

Runs without Godot: python3 tools/validate_semantic_release.py
Exit code 0 = all checks passed, 1 = at least one failure.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "semantic-release.yml"

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


def extract_run_block(text: str, step_name: str = "Compute next semantic version") -> str:
    """Return the shell body of a named workflow step."""
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip() != "run: |":
            continue
        owner = ""
        for j in range(i - 1, -1, -1):
            if lines[j].lstrip().startswith("- name:"):
                owner = lines[j]
                break
        if step_name in owner:
            start = i + 1
            break
    if start is None:
        raise RuntimeError(f"could not find the '{step_name}' run block")

    indent = None
    block: list[str] = []
    for line in lines[start:]:
        if not line.strip():
            block.append("")
            continue
        current = len(line) - len(line.lstrip())
        if indent is None:
            indent = current
        if current < indent:
            break
        block.append(line[indent:])
    return "\n".join(block).rstrip() + "\n"


def build_repo(path: Path, events: list[tuple[str, ...]]) -> None:
    def git(*args: str) -> None:
        subprocess.run(
            ["git", "-C", str(path), *args],
            check=True,
            capture_output=True,
            text=True,
        )

    subprocess.run(
        ["git", "init", "-q", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    git("config", "user.email", "semantic-release-test@example.invalid")
    git("config", "user.name", "Semantic Release Test")
    for event in events:
        if event[0] == "commit":
            args = ["commit", "--allow-empty", "-q", "-m", event[1]]
            if event[2]:
                args += ["-m", event[2]]
            git(*args)
        elif event[0] == "tag":
            git("tag", event[1])
        else:
            raise ValueError(f"unknown event: {event}")


def dry_run(script: str, events: list[tuple[str, ...]]) -> tuple[dict[str, str], subprocess.CompletedProcess[str]]:
    with tempfile.TemporaryDirectory(prefix="semantic-release-test-") as tmp:
        repo = Path(tmp) / "repo"
        repo.mkdir()
        build_repo(repo, events)
        output = Path(tmp) / "github_output"
        env = dict(os.environ, GITHUB_OUTPUT=str(output))
        result = subprocess.run(
            ["bash", "-c", script],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
        )
        values: dict[str, str] = {}
        if output.exists():
            for line in output.read_text().splitlines():
                if "=" in line:
                    key, _, value = line.partition("=")
                    values[key] = value
        return values, result


def make_macos_tarball(target: Path, artifact: str, app_name: str, mode: int) -> None:
    """Build the mode-preserving inner tarball produced by the macOS CI job."""
    stage = target.parent / f"{artifact}-stage"
    binary = stage / app_name / "Contents" / "MacOS" / "Retro SHMUP"
    binary.parent.mkdir(parents=True)
    binary.write_text("#!/bin/sh\nexit 0\n")
    binary.chmod(mode)
    (stage / app_name / "Contents" / "Info.plist").write_text("<plist/>\n")
    (stage / "retro-shmup.pck").write_bytes(b"fake pck\n")
    subprocess.run(
        ["tar", "-czf", str(target / artifact), "-C", str(stage), "."],
        check=True,
    )
    shutil.rmtree(stage)


def make_unpacked_app(target: Path, app_name: str = "retro-shmup.app") -> None:
    """Build an already-unpacked artifact, which packaging must not reject."""
    binary = target / app_name / "Contents" / "MacOS" / "Retro SHMUP"
    binary.parent.mkdir(parents=True)
    binary.write_text("#!/bin/sh\nexit 0\n")
    binary.chmod(0o755)
    (target / "retro-shmup.pck").write_bytes(b"fake pck\n")


def make_linux_files(target: Path, artifact: str) -> None:
    (target / "retro-shmup.x86_64").write_bytes(b"fake binary\n")
    (target / "retro-shmup.pck").write_bytes(b"fake pck\n")


def packaging_scenario(
    script: str,
    label: str,
    artifact: str,
    prepare: Callable[[Path, str], None],
    expected_entry: str,
    expect_executable: bool,
) -> None:
    with tempfile.TemporaryDirectory(prefix="semantic-release-package-") as tmp:
        root = Path(tmp)
        target = root / "artifacts" / artifact
        target.mkdir(parents=True)
        prepare(target, artifact)
        output = root / "github_output"
        env = dict(os.environ, GITHUB_OUTPUT=str(output))
        result = subprocess.run(
            ["bash", "-c", script],
            cwd=root,
            env=env,
            capture_output=True,
            text=True,
        )
        check(result.returncode == 0, f"{label}: packaging step succeeded")
        if result.returncode != 0:
            print(f"       stderr: {result.stderr.strip()[-500:]}")
            return

        archive = root / "dist" / f"{artifact}.tar.gz"
        check(archive.is_file(), f"{label}: release archive created")
        if not archive.is_file():
            return
        listing = subprocess.run(
            ["tar", "-tzf", str(archive)], check=True, capture_output=True, text=True
        ).stdout
        check(expected_entry in listing, f"{label}: {expected_entry} at top level")
        check(".tar.gz" not in listing, f"{label}: no nested archive published")
        if expect_executable:
            verbose = subprocess.run(
                ["tar", "-tvzf", str(archive)], check=True, capture_output=True, text=True
            ).stdout
            binaries = [line for line in verbose.splitlines() if line.endswith("Retro SHMUP")]
            check(
                any(line.startswith("-rwxr-xr-x") for line in binaries),
                f"{label}: executable bit preserved on 'Retro SHMUP'",
            )
            check(".pck" in listing, f"{label}: external .pck kept alongside the app")

        sums = subprocess.run(
            ["sha256sum", "-c", "SHA256SUMS"],
            cwd=root / "dist",
            capture_output=True,
            text=True,
        )
        check(sums.returncode == 0, f"{label}: sha256sum -c SHA256SUMS passes")
        if sums.returncode != 0:
            print(f"       stderr: {sums.stderr.strip()[-300:]}")


INIT: tuple[str, ...] = ("commit", "chore: initial commit", "")
SCENARIOS: list[tuple[str, list[tuple[str, ...]], dict[str, str]]] = [
    (
        "patch for fix:",
        [INIT, ("commit", "fix: correct off-by-one", "")],
        {"changed": "true", "previous": "none", "commits": "2", "tag": "v0.0.1"},
    ),
    (
        "minor for feat:",
        [INIT, ("tag", "v1.2.3"), ("commit", "feat: add shield", "")],
        {"changed": "true", "previous": "v1.2.3", "commits": "1", "tag": "v1.3.0"},
    ),
    (
        "major for feat!:",
        [INIT, ("tag", "v1.2.3"), ("commit", "feat!: rework weapons", "")],
        {"changed": "true", "previous": "v1.2.3", "commits": "1", "tag": "v2.0.0"},
    ),
    (
        "major for scoped fix(scope)!:",
        [INIT, ("tag", "v1.2.3"), ("commit", "fix(weapons)!: rebalance bomb", "")],
        {"changed": "true", "previous": "v1.2.3", "commits": "1", "tag": "v2.0.0"},
    ),
    (
        "major for BREAKING CHANGE: footer",
        [
            INIT,
            ("tag", "v1.2.3"),
            ("commit", "feat: new parser", "BREAKING CHANGE: parser interface changed"),
        ],
        {"changed": "true", "previous": "v1.2.3", "commits": "1", "tag": "v2.0.0"},
    ),
    (
        "major for BREAKING-CHANGE: footer",
        [
            INIT,
            ("tag", "v1.2.3"),
            ("commit", "feat: new parser", "BREAKING-CHANGE: parser interface changed"),
        ],
        {"changed": "true", "previous": "v1.2.3", "commits": "1", "tag": "v2.0.0"},
    ),
    (
        "v0.0.1-demo ignored as baseline with BREAKING-CHANGE: footer",
        [
            INIT,
            ("tag", "v0.0.1-demo"),
            ("commit", "feat: new parser", "BREAKING-CHANGE: parser interface changed"),
        ],
        {"changed": "true", "previous": "none", "commits": "2", "tag": "v1.0.0"},
    ),
    (
        "v0.0.1-demo ignored as baseline with feat:",
        [INIT, ("tag", "v0.0.1-demo"), ("commit", "feat: add shield", "")],
        {"changed": "true", "previous": "none", "commits": "2", "tag": "v0.1.0"},
    ),
    (
        "no new commits since baseline",
        [INIT, ("tag", "v1.2.3")],
        {"changed": "false"},
    ),
]


def main() -> int:
    section("workflow source")
    check(WORKFLOW.is_file(), f"{WORKFLOW.relative_to(ROOT)} exists")
    if not WORKFLOW.is_file():
        return 1

    workflow_text = WORKFLOW.read_text()
    try:
        script = extract_run_block(workflow_text)
        package_script = extract_run_block(
            workflow_text, "Create per-platform archives and SHA256SUMS"
        )
    except RuntimeError as exc:
        check(False, str(exc))
        return 1
    check(
        "bump=major" in script and "bump=minor" in script and "GITHUB_OUTPUT" in script,
        "extracted the version-derivation shell block from the workflow",
    )
    check(
        'tar -xzf "$inner" -C "$dir"' in package_script
        and 'rm -f "$inner"' in package_script
        and "chmod 0755" in package_script,
        "extracted the macOS packaging shell block from the workflow",
    )

    section("version-derivation dry runs")
    for label, events, expected in SCENARIOS:
        values, result = dry_run(script, events)
        ok = result.returncode == 0 and all(
            values.get(key) == value for key, value in expected.items()
        )
        detail = ", ".join(f"{key}={values.get(key)!r}" for key in expected)
        check(ok, f"{label} -> {detail}")
        if not ok and result.stderr.strip():
            print(f"       stderr: {result.stderr.strip()[-300:]}")

    section("release packaging dry runs")
    macos_artifact = "retro-shmup-dev-1a2b3c4-macos"
    app_binary = "./retro-shmup.app/Contents/MacOS/Retro SHMUP"
    packaging_scenario(
        package_script,
        "macOS inner tarball",
        macos_artifact,
        lambda target, artifact: make_macos_tarball(target, artifact, "retro-shmup.app", 0o755),
        app_binary,
        expect_executable=True,
    )
    packaging_scenario(
        package_script,
        "macOS inner tarball with mode repair",
        macos_artifact,
        lambda target, artifact: make_macos_tarball(target, artifact, "retro-shmup.app", 0o644),
        app_binary,
        expect_executable=True,
    )
    packaging_scenario(
        package_script,
        "macOS app already unpacked",
        macos_artifact,
        lambda target, artifact: make_unpacked_app(target),
        app_binary,
        expect_executable=True,
    )
    packaging_scenario(
        package_script,
        "macOS app with a different bundle name",
        macos_artifact,
        lambda target, artifact: make_macos_tarball(target, artifact, "Retro SHMUP.app", 0o755),
        "./Retro SHMUP.app/Contents/MacOS/Retro SHMUP",
        expect_executable=True,
    )
    packaging_scenario(
        package_script,
        "Linux artifact unchanged",
        "retro-shmup-dev-1a2b3c4-linux",
        make_linux_files,
        "./retro-shmup.x86_64",
        expect_executable=False,
    )

    print(f"\n{checks - len(failures)}/{checks} checks passed.")
    if failures:
        print(f"{len(failures)} FAILED:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("All semantic-release version checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
