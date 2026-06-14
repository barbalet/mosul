#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$ROOT_DIR/build/snapshot-evidence}"
DESTINATION="${DESTINATION:-platform=macOS}"
OUTPUT_PATH="${OUTPUT_PATH:-$ROOT_DIR/snapshots/evidence/mosul-map-evidence.png}"
REPORT_PATH="${REPORT_PATH:-}"
WIDTH=1440
HEIGHT=900
SCALE=1
AI_TICKS=10
BATTLE_INDEX=1
SIDE="us-patrol"
ORDER="investigate"
SKIP_BUILD=0
TIMEOUT_SECONDS="${SNAPSHOT_TIMEOUT_SECONDS:-60}"

usage() {
  cat <<'USAGE'
Usage: scripts/capture_snapshot_evidence.sh [options]

Builds the MosulGame Mac app, runs its command-line snapshot evidence mode, and
verifies that a PNG was produced for visual comparison.

Options:
  --output PATH             PNG output path. Defaults to snapshots/evidence/mosul-map-evidence.png.
  --report PATH             Text report path. Defaults to the PNG path with .txt extension.
  --width POINTS            Snapshot view width. Defaults to 1440.
  --height POINTS           Snapshot view height. Defaults to 900.
  --scale SCALE             Renderer scale. Defaults to 1.
  --ai-ticks N              Deterministic AI ticks before capture. Defaults to 10.
  --battle-index N          Scenario battle variant. Defaults to 1.
  --side SIDE               Evidence side: us-patrol or opposing-cell. Defaults to us-patrol.
  --order ORDER             Evidence order: move or investigate. Defaults to investigate.
  --configuration NAME      Xcode configuration. Defaults to Debug.
  --derived-data-root PATH  Build output root. Defaults to build/snapshot-evidence.
  --destination VALUE       Xcode destination. Defaults to platform=macOS.
  --skip-build              Reuse an existing MosulGame app under the derived-data root.
  --timeout SECONDS         Fail if snapshot capture does not exit in time. Defaults to 60.
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
    --report)
      if [[ $# -lt 2 ]]; then
        echo "error: --report requires a value" >&2
        exit 2
      fi
      REPORT_PATH="$2"
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
    --side)
      if [[ $# -lt 2 ]]; then
        echo "error: --side requires a value" >&2
        exit 2
      fi
      SIDE="$2"
      shift 2
      ;;
    --order)
      if [[ $# -lt 2 ]]; then
        echo "error: --order requires a value" >&2
        exit 2
      fi
      ORDER="$2"
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
    --timeout)
      if [[ $# -lt 2 ]]; then
        echo "error: --timeout requires a value" >&2
        exit 2
      fi
      TIMEOUT_SECONDS="$2"
      shift 2
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

if [[ -z "$REPORT_PATH" ]]; then
  REPORT_PATH="${OUTPUT_PATH%.*}.txt"
elif [[ "$REPORT_PATH" != /* ]]; then
  REPORT_PATH="$ROOT_DIR/$REPORT_PATH"
fi

case "$TIMEOUT_SECONDS" in
  ''|*[!0-9]*)
    echo "error: --timeout requires a positive integer" >&2
    exit 2
    ;;
  0)
    echo "error: --timeout requires a positive integer" >&2
    exit 2
    ;;
esac

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  "$ROOT_DIR/scripts/run_mac_smoke.sh" \
    --skip-aibattle \
    --configuration "$CONFIGURATION" \
    --derived-data-root "$DERIVED_DATA_ROOT" \
    --destination "$DESTINATION"
fi

APP_PATH="$DERIVED_DATA_ROOT/MosulGameDerivedData/Build/Products/$CONFIGURATION/MosulGame.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/MosulGame"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "error: expected MosulGame executable was not found: $EXECUTABLE_PATH" >&2
  exit 1
fi

if ! command -v open >/dev/null 2>&1; then
  echo "error: open is required for snapshot evidence capture" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
mkdir -p "$(dirname "$REPORT_PATH")"
rm -f "$OUTPUT_PATH"
rm -f "$REPORT_PATH"

python3 "$ROOT_DIR/scripts/check_mosulgame_runtime_resources.py" --app "$APP_PATH"

terminate_snapshot_app() {
  local escaped_app_path
  local pids

  escaped_app_path="$(printf '%s\n' "$APP_PATH/Contents/MacOS/MosulGame" | sed 's/[][\.*^$()+?{}|/]/\\&/g')"
  pids="$(pgrep -f "$escaped_app_path" || true)"
  if [[ -n "$pids" ]]; then
    echo "$pids" | xargs kill -TERM 2>/dev/null || true
    sleep 2
    pids="$(pgrep -f "$escaped_app_path" || true)"
    if [[ -n "$pids" ]]; then
      echo "$pids" | xargs kill -KILL 2>/dev/null || true
    fi
  fi
}

run_with_watchdog() {
  local timeout_seconds="$1"
  shift
  local watchdog_pid
  local status

  (
    sleep "$timeout_seconds"
    if [[ ! -s "$OUTPUT_PATH" || ! -s "$REPORT_PATH" ]]; then
      echo "error: snapshot evidence timed out after ${timeout_seconds}s" >&2
      terminate_snapshot_app
    fi
  ) &
  watchdog_pid=$!

  if "$@"; then
    status=0
  else
    status=$?
  fi

  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true
  return "$status"
}

run_with_watchdog "$TIMEOUT_SECONDS" \
  open -W -n "$APP_PATH" --args \
  --snapshot-evidence \
  --disable-audio \
  --require-bundled-runtime \
  --snapshot-output "$OUTPUT_PATH" \
  --snapshot-report "$REPORT_PATH" \
  --snapshot-width "$WIDTH" \
  --snapshot-height "$HEIGHT" \
  --snapshot-scale "$SCALE" \
  --snapshot-ai-ticks "$AI_TICKS" \
  --snapshot-battle "$BATTLE_INDEX" \
  --snapshot-side "$SIDE" \
  --snapshot-order "$ORDER"

if [[ ! -s "$OUTPUT_PATH" ]]; then
  echo "error: snapshot evidence PNG was not produced: $OUTPUT_PATH" >&2
  exit 1
fi

if [[ ! -s "$REPORT_PATH" ]]; then
  echo "error: snapshot evidence report was not produced: $REPORT_PATH" >&2
  exit 1
fi

if ! grep -q '^ok=true$' "$REPORT_PATH"; then
  echo "error: snapshot evidence report did not pass validation: $REPORT_PATH" >&2
  cat "$REPORT_PATH" >&2
  exit 1
fi

echo "Snapshot evidence written to $OUTPUT_PATH"
echo "Snapshot evidence report written to $REPORT_PATH"
