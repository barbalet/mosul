#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$ROOT_DIR/build/mac-smoke}"
DESTINATION="${DESTINATION:-platform=macOS}"
SKIP_AIBATTLE=0
SKIP_OUTSIDE_REPO_LAUNCH=0
TEMP_ROOT=""

cleanup() {
  if [[ -n "$TEMP_ROOT" && -d "$TEMP_ROOT" ]]; then
    rm -rf "$TEMP_ROOT"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Usage: scripts/run_mac_smoke.sh [options]

Builds the native MOSUL Mac app bundles through Xcode, verifies that the
expected MosulGame and AIBattle app executables were produced, and checks the
MosulGame bundled runtime payload.

Options:
  --configuration NAME      Xcode configuration to build. Defaults to Debug.
  --derived-data-root PATH  Build output root. Defaults to build/mac-smoke.
  --destination VALUE       Xcode destination. Defaults to platform=macOS.
  --skip-aibattle           Build only the player-facing Mosul app.
  --skip-outside-launch     Skip copying and launching MosulGame outside the checkout.
  -h, --help                Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --skip-aibattle)
      SKIP_AIBATTLE=1
      shift
      ;;
    --skip-outside-launch)
      SKIP_OUTSIDE_REPO_LAUNCH=1
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

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is required for the Mac app smoke path" >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR/modernerKrieg/engine" ]]; then
  echo "error: expected modernerKrieg submodule at $ROOT_DIR/modernerKrieg" >&2
  echo "hint: run 'git submodule update --init --recursive'" >&2
  exit 1
fi

build_app() {
  local project="$1"
  local scheme="$2"
  local derived_data_path="$3"
  local product="$4"
  local app_path="$derived_data_path/Build/Products/$CONFIGURATION/$product.app"
  local executable_path="$app_path/Contents/MacOS/$product"
  local info_plist_path="$app_path/Contents/Info.plist"

  echo "==> Building $scheme ($CONFIGURATION)"
  xcodebuild \
    -project "$ROOT_DIR/$project" \
    -scheme "$scheme" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$derived_data_path" \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO \
    build

  if [[ ! -x "$executable_path" ]]; then
    echo "error: expected executable was not produced: $executable_path" >&2
    exit 1
  fi

  if [[ ! -f "$info_plist_path" ]]; then
    echo "error: expected app Info.plist was not produced: $info_plist_path" >&2
    exit 1
  fi

  if [[ "$product" == "MosulGame" ]]; then
    python3 "$ROOT_DIR/scripts/check_mosulgame_runtime_resources.py" --app "$app_path"

    if [[ "$SKIP_OUTSIDE_REPO_LAUNCH" -eq 0 ]]; then
      smoke_mosulgame_outside_repo "$app_path"
    fi
  fi

  echo "ok: $product app bundle built at $app_path"
}

smoke_mosulgame_outside_repo() {
  local app_path="$1"
  local copied_app_path
  local runtime_check_output

  if ! command -v open >/dev/null 2>&1; then
    echo "error: open is required for the outside-repo MosulGame launch smoke" >&2
    exit 1
  fi

  if [[ -z "$TEMP_ROOT" ]]; then
    TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mosulgame-smoke.XXXXXX")"
  fi

  copied_app_path="$TEMP_ROOT/MosulGame.app"
  ditto "$app_path" "$copied_app_path"

  python3 "$ROOT_DIR/scripts/check_mosulgame_runtime_resources.py" --app "$copied_app_path"
  runtime_check_output="$TEMP_ROOT/runtime-check.txt"
  rm -f "$runtime_check_output"

  open -W -n "$copied_app_path" --args \
    --check-runtime-resources \
    --disable-audio \
    --require-bundled-runtime \
    --runtime-check-output "$runtime_check_output"

  if [[ ! -s "$runtime_check_output" ]]; then
    echo "error: copied MosulGame app did not write runtime-check output" >&2
    exit 1
  fi

  if ! grep -q "bundled app resources" "$runtime_check_output"; then
    echo "error: copied MosulGame app did not load bundled runtime resources" >&2
    cat "$runtime_check_output" >&2
    exit 1
  fi

  echo "ok: MosulGame copied app launched with bundled runtime at $copied_app_path"
}

mkdir -p "$DERIVED_DATA_ROOT"

build_app "MosulGame.xcodeproj" "MosulGame" "$DERIVED_DATA_ROOT/MosulGameDerivedData" "MosulGame"

if [[ "$SKIP_AIBATTLE" -eq 0 ]]; then
  build_app "AIBattle.xcodeproj" "AIBattle" "$DERIVED_DATA_ROOT/AIBattleDerivedData" "AIBattle"
fi

echo "Mac app smoke passed."
