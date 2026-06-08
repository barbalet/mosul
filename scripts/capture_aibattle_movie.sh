#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$ROOT_DIR/build/aibattle-movie}"
DESTINATION="${DESTINATION:-platform=macOS}"
OUTPUT_PATH="${OUTPUT_PATH:-}"
REPORT_PATH="${REPORT_PATH:-}"
OUTPUT_PATH_SET=0
REPORT_PATH_SET=0
WIDTH=1600
HEIGHT=1000
SCALE=1
FPS=6
TAIL_SECONDS=2
BATTLE_INDEX=1
MAX_TICKS=120
WATCHDOG_TICKS=40
SKIP_BUILD=0

if [[ -n "$OUTPUT_PATH" ]]; then
  OUTPUT_PATH_SET=1
fi

if [[ -n "$REPORT_PATH" ]]; then
  REPORT_PATH_SET=1
fi

usage() {
  cat <<'USAGE'
Usage: scripts/capture_aibattle_movie.sh [options]

Builds the AIBattle Mac app, runs its command-line movie mode, and verifies
that a full-battle MOV plus final tuning report were produced.

Options:
  --output PATH             Movie output path. Defaults to snapshots/evidence/aibattle-battle-N.mov.
  --report PATH             Text report path. Defaults to the movie path with a .txt extension.
  --width POINTS            Movie frame view width. Defaults to 1600.
  --height POINTS           Movie frame view height. Defaults to 1000.
  --scale SCALE             Renderer scale. Defaults to 1.
  --fps N                   Movie frames per second. Defaults to 6.
  --tail-seconds N          Hold the final frame for N seconds. Defaults to 2.
  --battle-index N          Battle variant. Defaults to 1.
  --max-ticks N             Result limit used for the full battle. Defaults to 120.
  --watchdog-ticks N        Watchdog limit used for stalled battles. Defaults to 40.
  --configuration NAME      Xcode configuration. Defaults to Debug.
  --derived-data-root PATH  Build output root. Defaults to build/aibattle-movie.
  --destination VALUE       Xcode destination. Defaults to platform=macOS.
  --skip-build              Reuse an existing AIBattle app under the derived-data root.
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
      OUTPUT_PATH_SET=1
      shift 2
      ;;
    --report)
      if [[ $# -lt 2 ]]; then
        echo "error: --report requires a value" >&2
        exit 2
      fi
      REPORT_PATH="$2"
      REPORT_PATH_SET=1
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
    --fps)
      if [[ $# -lt 2 ]]; then
        echo "error: --fps requires a value" >&2
        exit 2
      fi
      FPS="$2"
      shift 2
      ;;
    --tail-seconds)
      if [[ $# -lt 2 ]]; then
        echo "error: --tail-seconds requires a value" >&2
        exit 2
      fi
      TAIL_SECONDS="$2"
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
    --max-ticks)
      if [[ $# -lt 2 ]]; then
        echo "error: --max-ticks requires a value" >&2
        exit 2
      fi
      MAX_TICKS="$2"
      shift 2
      ;;
    --watchdog-ticks)
      if [[ $# -lt 2 ]]; then
        echo "error: --watchdog-ticks requires a value" >&2
        exit 2
      fi
      WATCHDOG_TICKS="$2"
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

if [[ "$OUTPUT_PATH_SET" -eq 0 ]]; then
  OUTPUT_PATH="$ROOT_DIR/snapshots/evidence/aibattle-battle-$BATTLE_INDEX.mov"
fi

if [[ "$OUTPUT_PATH" != /* ]]; then
  OUTPUT_PATH="$ROOT_DIR/$OUTPUT_PATH"
fi

if [[ "$REPORT_PATH_SET" -eq 0 ]]; then
  output_name="$(basename "$OUTPUT_PATH")"
  output_dir="$(dirname "$OUTPUT_PATH")"
  if [[ "$output_name" == *.* ]]; then
    output_name="${output_name%.*}"
  fi
  REPORT_PATH="$output_dir/$output_name.txt"
fi

if [[ "$REPORT_PATH" != /* ]]; then
  REPORT_PATH="$ROOT_DIR/$REPORT_PATH"
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  xcodebuild \
    -project "$ROOT_DIR/AIBattle.xcodeproj" \
    -scheme AIBattle \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_ROOT/AIBattleDerivedData" \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

EXECUTABLE_PATH="$DERIVED_DATA_ROOT/AIBattleDerivedData/Build/Products/$CONFIGURATION/AIBattle.app/Contents/MacOS/AIBattle"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "error: expected AIBattle executable was not found: $EXECUTABLE_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
mkdir -p "$(dirname "$REPORT_PATH")"

"$EXECUTABLE_PATH" \
  --aibattle-movie \
  --aibattle-movie-output "$OUTPUT_PATH" \
  --aibattle-movie-report "$REPORT_PATH" \
  --aibattle-movie-width "$WIDTH" \
  --aibattle-movie-height "$HEIGHT" \
  --aibattle-movie-scale "$SCALE" \
  --aibattle-movie-fps "$FPS" \
  --aibattle-movie-tail-seconds "$TAIL_SECONDS" \
  --aibattle-movie-battle "$BATTLE_INDEX" \
  --aibattle-movie-max-ticks "$MAX_TICKS" \
  --aibattle-movie-watchdog-ticks "$WATCHDOG_TICKS"

if [[ ! -s "$OUTPUT_PATH" ]]; then
  echo "error: AIBattle movie was not produced: $OUTPUT_PATH" >&2
  exit 1
fi

if [[ ! -s "$REPORT_PATH" ]]; then
  echo "error: AIBattle movie report was not produced: $REPORT_PATH" >&2
  exit 1
fi

echo "AIBattle movie written to $OUTPUT_PATH"
echo "AIBattle movie report written to $REPORT_PATH"
