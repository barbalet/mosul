#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$ROOT_DIR/build/mosulgame-release-errors}"
DESTINATION="${DESTINATION:-platform=macOS}"
REPORT_PATH="${REPORT_PATH:-$ROOT_DIR/snapshots/evidence/mosul-release-errors.txt}"
SKIP_BUILD=0
TIMEOUT_SECONDS="${RELEASE_ERROR_TIMEOUT_SECONDS:-60}"
TEMP_ROOT=""
MISSING_SCENARIO_RELATIVE="Contents/Resources/mosul-runtime/modernerKrieg/game/mosul/scenarios/market_commercial_streets_2003.mkscenario"

cleanup() {
  if [[ -n "$TEMP_ROOT" && -d "$TEMP_ROOT" ]]; then
    rm -rf "$TEMP_ROOT"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Usage: scripts/check_mosulgame_release_errors.sh [options]

Builds MosulGame.app in Release configuration, verifies an intact bundled
runtime check, then breaks a copied app bundle and verifies the app writes a
release-quality runtime failure report.

Options:
  --report PATH             Text report path. Defaults to snapshots/evidence/mosul-release-errors.txt.
  --configuration NAME      Xcode configuration. Defaults to Release.
  --derived-data-root PATH  Build output root. Defaults to build/mosulgame-release-errors.
  --destination VALUE       Xcode destination. Defaults to platform=macOS.
  --skip-build              Reuse an existing MosulGame app under the derived-data root.
  --timeout SECONDS         Fail if an app runtime check does not exit in time. Defaults to 60.
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
  local executable_path="$1"
  local escaped_app_path
  local pids

  escaped_app_path="$(printf '%s\n' "$executable_path" | sed 's/[][\.*^$()+?{}|/]/\\&/g')"
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
  local executable_path="$2"
  shift 2
  local watchdog_pid
  local status

  (
    sleep "$timeout_seconds"
    if [[ ! -s "$CURRENT_RUNTIME_CHECK_REPORT" ]]; then
      echo "error: runtime error check timed out after ${timeout_seconds}s" >&2
      terminate_app "$executable_path"
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

kv() {
  local key="$1"
  local path="$2"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$path"
}

runtime_check() {
  local app_path="$1"
  local executable_path="$app_path/Contents/MacOS/MosulGame"
  local output_path="$2"

  rm -f "$output_path"
  CURRENT_RUNTIME_CHECK_REPORT="$output_path"
  run_with_watchdog "$TIMEOUT_SECONDS" "$executable_path" \
    open -W -n "$app_path" --args \
    --check-runtime-resources \
    --require-bundled-runtime \
    --runtime-check-output "$output_path"
}

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mosul-release-errors.XXXXXX")"
INTACT_REPORT="$TEMP_ROOT/intact-runtime-check.txt"
BROKEN_APP_PATH="$TEMP_ROOT/MosulGame-broken.app"
BROKEN_REPORT="$TEMP_ROOT/broken-runtime-check.txt"

runtime_check "$APP_PATH" "$INTACT_REPORT"

if [[ ! -s "$INTACT_REPORT" ]] || ! grep -q '^ok=true$' "$INTACT_REPORT"; then
  echo "error: intact MosulGame app did not pass runtime check" >&2
  [[ -f "$INTACT_REPORT" ]] && cat "$INTACT_REPORT" >&2
  exit 1
fi

ditto "$APP_PATH" "$BROKEN_APP_PATH"
BROKEN_EXECUTABLE_PATH="$BROKEN_APP_PATH/Contents/MacOS/MosulGame"
REMOVED_FILE="$BROKEN_APP_PATH/$MISSING_SCENARIO_RELATIVE"

if [[ ! -f "$REMOVED_FILE" ]]; then
  echo "error: expected bundled scenario was not found: $REMOVED_FILE" >&2
  exit 1
fi

rm -f "$REMOVED_FILE"

set +e
runtime_check "$BROKEN_APP_PATH" "$BROKEN_REPORT"
BROKEN_STATUS=$?
set -e

if [[ ! -s "$BROKEN_REPORT" ]]; then
  echo "error: broken MosulGame bundle did not write a failure report" >&2
  exit 1
fi

if ! grep -q '^ok=false$' "$BROKEN_REPORT"; then
  echo "error: broken runtime report did not record ok=false" >&2
  cat "$BROKEN_REPORT" >&2
  exit 1
fi

if ! grep -q '^title=MOSUL bundled runtime is missing$' "$BROKEN_REPORT"; then
  echo "error: broken runtime report did not include the expected player-facing title" >&2
  cat "$BROKEN_REPORT" >&2
  exit 1
fi

for required_key in message recovery diagnostic; do
  if [[ -z "$(kv "$required_key" "$BROKEN_REPORT")" ]]; then
    echo "error: broken runtime report missing $required_key" >&2
    cat "$BROKEN_REPORT" >&2
    exit 1
  fi
done

mkdir -p "$(dirname "$REPORT_PATH")"
{
  echo "ok=true"
  echo "check=mosulgame_release_errors"
  echo "intact_runtime_ok=true"
  echo "broken_bundle_failed=true"
  echo "broken_launch_returncode=$BROKEN_STATUS"
  echo "broken_report_ok=false"
  echo "removed_file=$MISSING_SCENARIO_RELATIVE"
  echo "intact_runtime_source=$(kv runtime_source "$INTACT_REPORT")"
  echo "broken_title=$(kv title "$BROKEN_REPORT")"
  echo "broken_message=$(kv message "$BROKEN_REPORT")"
  echo "broken_recovery=$(kv recovery "$BROKEN_REPORT")"
  echo "broken_diagnostic=$(kv diagnostic "$BROKEN_REPORT")"
} > "$REPORT_PATH"

echo "MosulGame release error checks ok: $REPORT_PATH"
cat "$REPORT_PATH"
