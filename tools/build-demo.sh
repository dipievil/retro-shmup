#!/usr/bin/env bash
# Build a local demo export for Linux or Windows.
# Output: bin/<tag-version>-demo-<commit>/<target>/
# Example: bin/v0.0.2-demo-1a2b3c4/linux/retro-shmup.x86_64
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tools/build-demo.sh <linux|windows>

Exports the demo with the pinned Godot 4.3 preset and writes the result to:
  bin/<tag-version>-demo-<commit>/<target>/

The version comes from the nearest vX.Y.Z-demo tag on HEAD; the commit is the
current short SHA. Override the engine binary with GODOT_BIN if needed.
EOF
}

if [ "$#" -ne 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  [ "$#" -eq 1 ] && exit 0 || exit 1
fi

target="$1"
case "$target" in
  linux)
    preset="Linux"
    binary="retro-shmup.x86_64"
    ;;
  windows)
    preset="Windows"
    binary="retro-shmup.exe"
    ;;
  *)
    echo "error: unknown target '$target' (expected linux or windows)" >&2
    usage >&2
    exit 1
    ;;
esac

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

tag="$(git describe --tags --match 'v[0-9]*-demo' --abbrev=0 HEAD 2>/dev/null || true)"
if [ -z "$tag" ]; then
  echo "error: no vX.Y.Z-demo tag found on HEAD; tag the commit before building" >&2
  exit 1
fi

version="${tag%-demo}"
if ! printf '%s' "$version" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "error: unexpected demo tag '$tag'" >&2
  exit 1
fi

commit="$(git rev-parse --short=7 HEAD)"
name="${version}-demo-${commit}"
out_dir="${project_root}/bin/${name}/${target}"
mkdir -p "$out_dir"

export_log="$(mktemp)"
trap 'rm -f "$export_log"' EXIT

echo "Exporting $preset demo as ${name}/${target}"
if ! "${GODOT_BIN:-godot}" --headless --export-release "$preset" \
  "${out_dir}/${binary}" >"$export_log" 2>&1; then
  cat "$export_log" >&2
  echo "error: Godot export failed" >&2
  exit 1
fi
cat "$export_log"

if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$export_log"; then
  echo "error: Godot export logged a script error" >&2
  exit 1
fi

pck="${out_dir}/retro-shmup.pck"
for file in "${out_dir}/${binary}" "$pck"; do
  if [ ! -s "$file" ]; then
    echo "error: missing or empty export file: $file" >&2
    exit 1
  fi
done

(cd "$out_dir" && sha256sum "$binary" retro-shmup.pck > SHA256SUMS)
echo "Created $out_dir"
cat "$out_dir/SHA256SUMS"
