#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$ROOT_DIR/build/mosulgame-performance}"
DESTINATION="${DESTINATION:-platform=macOS}"
REPORT_PATH="${REPORT_PATH:-$ROOT_DIR/snapshots/evidence/mosul-performance-budget.txt}"
SKIP_BUILD=0
TIMEOUT_SECONDS="${PERFORMANCE_TIMEOUT_SECONDS:-90}"

usage() {
  cat <<'USAGE'
Usage: scripts/check_mosulgame_performance_budget.sh [options]

Builds MosulGame.app in Release configuration, runs the app-side performance
budget probe, and verifies that the report passes.

Options:
  --report PATH             Text report path. Defaults to snapshots/evidence/mosul-performance-budget.txt.
  --configuration NAME      Xcode configuration. Defaults to Release.
  --derived-data-root PATH  Build output root. Defaults to build/mosulgame-performance.
  --destination VALUE       Xcode destination. Defaults to platform=macOS.
  --skip-build              Reuse an existing MosulGame app under the derived-data root.
  --timeout SECONDS         Fail if the app probe does not exit in time. Defaults to 90.
  -h, --help                Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)
      if [[ $# -lt 2 ]]; then
        echo "error: --report requires a value" >&2
        exit 2
      fi
      REPORT_PATH="$2"
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

case "$TIMEOUT_SECONDS" in
  ''|*[!0-9]*|0)
    echo "error: --timeout requires a positive integer" >&2
    exit 2
    ;;
esac

if [[ "$REPORT_PATH" != /* ]]; then
  REPORT_PATH="$ROOT_DIR/$REPORT_PATH"
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  "$ROOT_DIR/scripts/run_mac_smoke.sh" \
    --skip-aibattle \
    --skip-outside-launch \
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

terminate_app() {
  local escaped_app_path
  local pids

  escaped_app_path="$(printf '%s\n' "$EXECUTABLE_PATH" | sed 's/[][\.*^$()+?{}|/]/\\&/g')"
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
    if [[ ! -s "$REPORT_PATH" ]]; then
      echo "error: performance budget probe timed out after ${timeout_seconds}s" >&2
      terminate_app
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

mkdir -p "$(dirname "$REPORT_PATH")"
rm -f "$REPORT_PATH"

START_MS="$(python3 -c 'import time; print(int(time.time() * 1000))')"
run_with_watchdog "$TIMEOUT_SECONDS" \
  open -W -n "$APP_PATH" --args \
  --performance-budget \
  --require-bundled-runtime \
  --performance-report "$REPORT_PATH"
END_MS="$(python3 -c 'import time; print(int(time.time() * 1000))')"
EXTERNAL_LAUNCH_PROBE_MS=$((END_MS - START_MS))

if [[ ! -s "$REPORT_PATH" ]]; then
  echo "error: MosulGame did not write performance report: $REPORT_PATH" >&2
  exit 1
fi

{
  echo "external_launch_probe_ms=$EXTERNAL_LAUNCH_PROBE_MS"
  echo "budget_external_launch_probe_ms=9000"
} >> "$REPORT_PATH"

if ! grep -q '^ok=true$' "$REPORT_PATH"; then
  echo "error: MosulGame performance budget failed: $REPORT_PATH" >&2
  cat "$REPORT_PATH" >&2
  exit 1
fi

if [[ "$EXTERNAL_LAUNCH_PROBE_MS" -gt 9000 ]]; then
  echo "error: MosulGame external launch/probe budget failed: $REPORT_PATH" >&2
  cat "$REPORT_PATH" >&2
  exit 1
fi

echo "MosulGame performance budget ok: $REPORT_PATH"
cat "$REPORT_PATH"
