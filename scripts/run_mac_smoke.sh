#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$ROOT_DIR/build/mac-smoke}"
DESTINATION="${DESTINATION:-platform=macOS}"
SKIP_AIBATTLE=0

usage() {
  cat <<'USAGE'
Usage: scripts/run_mac_smoke.sh [options]

Builds the native MOSUL Mac app bundles through Xcode and verifies that the
expected app executables were produced.

Options:
  --configuration NAME      Xcode configuration to build. Defaults to Debug.
  --derived-data-root PATH  Build output root. Defaults to build/mac-smoke.
  --destination VALUE       Xcode destination. Defaults to platform=macOS.
  --skip-aibattle           Build only the player-facing Mosul app.
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

  echo "ok: $product app bundle built at $app_path"
}

mkdir -p "$DERIVED_DATA_ROOT"

build_app "Mosul.xcodeproj" "Mosul" "$DERIVED_DATA_ROOT/MosulDerivedData" "Mosul"

if [[ "$SKIP_AIBATTLE" -eq 0 ]]; then
  build_app "AIBattle.xcodeproj" "AIBattle" "$DERIVED_DATA_ROOT/AIBattleDerivedData" "AIBattle"
fi

echo "Mac app smoke passed."
