#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$ROOT_DIR/build/mosulgame-accessibility-ui}"
DESTINATION="${DESTINATION:-platform=macOS}"
OUTPUT_PATH="${OUTPUT_PATH:-$ROOT_DIR/snapshots/evidence/mosul-accessibility-ui.png}"
REPORT_PATH="${REPORT_PATH:-$ROOT_DIR/snapshots/evidence/mosul-accessibility-ui.txt}"
WIDTH=980
HEIGHT=680
MIN_ACCESSIBILITY_MODIFIERS="${MIN_ACCESSIBILITY_MODIFIERS:-18}"
MIN_KEYBOARD_SHORTCUTS="${MIN_KEYBOARD_SHORTCUTS:-8}"
SKIP_BUILD=0
TIMEOUT_SECONDS="${ACCESSIBILITY_UI_TIMEOUT_SECONDS:-120}"

usage() {
  cat <<'USAGE'
Usage: scripts/check_mosulgame_accessibility_ui.sh [options]

Builds MosulGame.app, captures minimum-window evidence, and checks that the
SwiftUI shell keeps a baseline set of accessibility labels and keyboard
shortcuts.

Options:
  --output PATH             PNG output path. Defaults to snapshots/evidence/mosul-accessibility-ui.png.
  --report PATH             Text report path. Defaults to snapshots/evidence/mosul-accessibility-ui.txt.
  --width POINTS            Minimum evidence width. Defaults to 980.
  --height POINTS           Minimum evidence height. Defaults to 680.
  --configuration NAME      Xcode configuration. Defaults to Debug.
  --derived-data-root PATH  Build output root. Defaults to build/mosulgame-accessibility-ui.
  --destination VALUE       Xcode destination. Defaults to platform=macOS.
  --min-accessibility N     Minimum accessibility modifier count. Defaults to 18.
  --min-shortcuts N         Minimum keyboard shortcut count. Defaults to 8.
  --skip-build              Reuse an existing MosulGame app under the derived-data root.
  --timeout SECONDS         Fail if snapshot capture does not exit in time. Defaults to 120.
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
    --min-accessibility)
      if [[ $# -lt 2 ]]; then
        echo "error: --min-accessibility requires a value" >&2
        exit 2
      fi
      MIN_ACCESSIBILITY_MODIFIERS="$2"
      shift 2
      ;;
    --min-shortcuts)
      if [[ $# -lt 2 ]]; then
        echo "error: --min-shortcuts requires a value" >&2
        exit 2
      fi
      MIN_KEYBOARD_SHORTCUTS="$2"
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

for numeric_value in "$WIDTH" "$HEIGHT" "$MIN_ACCESSIBILITY_MODIFIERS" "$MIN_KEYBOARD_SHORTCUTS" "$TIMEOUT_SECONDS"; do
  case "$numeric_value" in
    ''|*[!0-9]*|0)
      echo "error: numeric options require positive integers" >&2
      exit 2
      ;;
  esac
done

if [[ "$OUTPUT_PATH" != /* ]]; then
  OUTPUT_PATH="$ROOT_DIR/$OUTPUT_PATH"
fi

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

"$ROOT_DIR/scripts/capture_snapshot_evidence.sh" \
  --skip-build \
  --configuration "$CONFIGURATION" \
  --derived-data-root "$DERIVED_DATA_ROOT" \
  --destination "$DESTINATION" \
  --output "$OUTPUT_PATH" \
  --report "$REPORT_PATH" \
  --width "$WIDTH" \
  --height "$HEIGHT" \
  --timeout "$TIMEOUT_SECONDS"

ACCESSIBILITY_MODIFIERS="$(
  python3 - "$ROOT_DIR/Mac/Mosul/App" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
pattern = re.compile(r"\.accessibility(?:Element|Hidden|Hint|Label|SortPriority|Value)\b")
print(sum(len(pattern.findall(path.read_text(encoding="utf-8"))) for path in root.glob("*.swift")))
PY
)"
KEYBOARD_SHORTCUTS="$(
  python3 - "$ROOT_DIR/Mac/Mosul/App" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
pattern = re.compile(r"\.keyboardShortcut\b")
print(sum(len(pattern.findall(path.read_text(encoding="utf-8"))) for path in root.glob("*.swift")))
PY
)"

{
  echo "check=mosulgame_accessibility_ui"
  echo "minimum_window_width=$WIDTH"
  echo "minimum_window_height=$HEIGHT"
  echo "minimum_window_png=$OUTPUT_PATH"
  echo "accessibility_modifiers=$ACCESSIBILITY_MODIFIERS"
  echo "minimum_accessibility_modifiers=$MIN_ACCESSIBILITY_MODIFIERS"
  echo "keyboard_shortcuts=$KEYBOARD_SHORTCUTS"
  echo "minimum_keyboard_shortcuts=$MIN_KEYBOARD_SHORTCUTS"
} >> "$REPORT_PATH"

if [[ "$ACCESSIBILITY_MODIFIERS" -lt "$MIN_ACCESSIBILITY_MODIFIERS" ]]; then
  echo "error: expected at least $MIN_ACCESSIBILITY_MODIFIERS accessibility modifiers, found $ACCESSIBILITY_MODIFIERS" >&2
  cat "$REPORT_PATH" >&2
  exit 1
fi

if [[ "$KEYBOARD_SHORTCUTS" -lt "$MIN_KEYBOARD_SHORTCUTS" ]]; then
  echo "error: expected at least $MIN_KEYBOARD_SHORTCUTS keyboard shortcuts, found $KEYBOARD_SHORTCUTS" >&2
  cat "$REPORT_PATH" >&2
  exit 1
fi

echo "MosulGame accessibility and minimum-window UI ok: $REPORT_PATH"
cat "$REPORT_PATH"
