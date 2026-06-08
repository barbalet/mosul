#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$ROOT_DIR/build/snapshot-evidence}"
DESTINATION="${DESTINATION:-platform=macOS}"
OUTPUT_PATH="${OUTPUT_PATH:-$ROOT_DIR/snapshots/evidence/mosul-map-evidence.png}"
WIDTH=1440
HEIGHT=1440
SCALE=1
AI_TICKS=10
BATTLE_INDEX=1
SKIP_BUILD=0

usage() {
  cat <<'USAGE'
Usage: scripts/capture_snapshot_evidence.sh [options]

Builds the Mosul Mac app, runs its command-line snapshot evidence mode, and
verifies that a PNG was produced for visual comparison.

Options:
  --output PATH             PNG output path. Defaults to snapshots/evidence/mosul-map-evidence.png.
  --width POINTS            Snapshot view width. Defaults to 1440.
  --height POINTS           Snapshot view height. Defaults to 1440.
  --scale SCALE             Renderer scale. Defaults to 1.
  --ai-ticks N              Deterministic AI ticks before capture. Defaults to 10.
  --battle-index N          Scenario battle variant. Defaults to 1.
  --configuration NAME      Xcode configuration. Defaults to Debug.
  --derived-data-root PATH  Build output root. Defaults to build/snapshot-evidence.
  --destination VALUE       Xcode destination. Defaults to platform=macOS.
  --skip-build              Reuse an existing Mosul app under the derived-data root.
  -h, --help                Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      if [[ $# -lt 2 ]]; then
        echo "error: --output requires a value" >&2
        exit 2
      fi
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --width)
      if [[ $# -lt 2 ]]; then
        echo "error: --width requires a value" >&2
        exit 2
      fi
      WIDTH="$2"
      shift 2
      ;;
    --height)
      if [[ $# -lt 2 ]]; then
        echo "error: --height requires a value" >&2
        exit 2
      fi
      HEIGHT="$2"
      shift 2
      ;;
    --scale)
      if [[ $# -lt 2 ]]; then
        echo "error: --scale requires a value" >&2
        exit 2
      fi
      SCALE="$2"
      shift 2
      ;;
    --ai-ticks)
      if [[ $# -lt 2 ]]; then
        echo "error: --ai-ticks requires a value" >&2
        exit 2
      fi
      AI_TICKS="$2"
      shift 2
      ;;
    --battle-index)
      if [[ $# -lt 2 ]]; then
        echo "error: --battle-index requires a value" >&2
        exit 2
      fi
      BATTLE_INDEX="$2"
      shift 2
      ;;
    --configuration)
      if [[ $# -lt 2 ]]; then
        echo "error: --configuration requires a value" >&2
        exit 2
      fi
      CONFIGURATION="$2"
      shift 2
      ;;
    --derived-data-root)
      if [[ $# -lt 2 ]]; then
        echo "error: --derived-data-root requires a value" >&2
        exit 2
      fi
      DERIVED_DATA_ROOT="$2"
      shift 2
      ;;
    --destination)
      if [[ $# -lt 2 ]]; then
        echo "error: --destination requires a value" >&2
        exit 2
      fi
      DESTINATION="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$OUTPUT_PATH" != /* ]]; then
  OUTPUT_PATH="$ROOT_DIR/$OUTPUT_PATH"
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  "$ROOT_DIR/scripts/run_mac_smoke.sh" \
    --skip-aibattle \
    --configuration "$CONFIGURATION" \
    --derived-data-root "$DERIVED_DATA_ROOT" \
    --destination "$DESTINATION"
fi

EXECUTABLE_PATH="$DERIVED_DATA_ROOT/MosulDerivedData/Build/Products/$CONFIGURATION/Mosul.app/Contents/MacOS/Mosul"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "error: expected Mosul executable was not found: $EXECUTABLE_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

"$EXECUTABLE_PATH" \
  --snapshot-evidence \
  --snapshot-output "$OUTPUT_PATH" \
  --snapshot-width "$WIDTH" \
  --snapshot-height "$HEIGHT" \
  --snapshot-scale "$SCALE" \
  --snapshot-ai-ticks "$AI_TICKS" \
  --snapshot-battle "$BATTLE_INDEX"

if [[ ! -s "$OUTPUT_PATH" ]]; then
  echo "error: snapshot evidence PNG was not produced: $OUTPUT_PATH" >&2
  exit 1
fi

echo "Snapshot evidence written to $OUTPUT_PATH"
