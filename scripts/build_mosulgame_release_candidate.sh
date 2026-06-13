#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$ROOT_DIR/build/release-candidate}"
DIST_ROOT="${DIST_ROOT:-$ROOT_DIR/dist/release-candidate}"
DESTINATION="${DESTINATION:-generic/platform=macOS}"
REPORT_PATH="${REPORT_PATH:-$ROOT_DIR/snapshots/evidence/mosul-release-candidate.txt}"
VERSION="${VERSION:-}"
ARCHS=()
SKIP_SIGN=0
REPLACE=0

usage() {
  cat <<'USAGE'
Usage: scripts/build_mosulgame_release_candidate.sh [options]

Builds MosulGame.app release-candidate bundles for Apple Silicon and Intel,
copies them into architecture-specific dist/release-candidate folders,
validates bundled runtime resources, ad-hoc signs by default, and verifies each
executable architecture with lipo.

Options:
  --arch ARCH               Build one architecture. Repeat for multiple values.
                            Defaults to arm64 and x86_64.
  --configuration NAME      Xcode configuration. Defaults to Release.
  --derived-data-root PATH  Build output root. Defaults to build/release-candidate.
  --dist-root PATH          Candidate output root. Defaults to dist/release-candidate.
  --destination VALUE       Xcode destination. Defaults to generic/platform=macOS.
  --report PATH             Text report path. Defaults to snapshots/evidence/mosul-release-candidate.txt.
  --version VERSION         Artifact version. Defaults to MosulGame MARKETING_VERSION.
  --skip-sign               Leave copied app bundles unsigned.
  --replace                 Replace existing candidate app bundles for requested architectures.
  -h, --help                Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      if [[ $# -lt 2 ]]; then
        echo "error: --arch requires a value" >&2
        exit 2
      fi
      ARCHS+=("$2")
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
    --dist-root)
      if [[ $# -lt 2 ]]; then
        echo "error: --dist-root requires a value" >&2
        exit 2
      fi
      DIST_ROOT="$2"
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
    --report)
      if [[ $# -lt 2 ]]; then
        echo "error: --report requires a value" >&2
        exit 2
      fi
      REPORT_PATH="$2"
      shift 2
      ;;
    --version)
      if [[ $# -lt 2 ]]; then
        echo "error: --version requires a value" >&2
        exit 2
      fi
      VERSION="$2"
      shift 2
      ;;
    --skip-sign)
      SKIP_SIGN=1
      shift
      ;;
    --replace)
      REPLACE=1
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

if [[ "${#ARCHS[@]}" -eq 0 ]]; then
  ARCHS=(arm64 x86_64)
fi

for arch in "${ARCHS[@]}"; do
  case "$arch" in
    arm64|x86_64)
      ;;
    *)
      echo "error: unsupported architecture: $arch" >&2
      exit 2
      ;;
  esac
done

for path_var in DERIVED_DATA_ROOT DIST_ROOT REPORT_PATH; do
  path_value="${!path_var}"
  if [[ "$path_value" != /* ]]; then
    printf -v "$path_var" '%s/%s' "$ROOT_DIR" "$path_value"
  fi
done

if [[ -z "$VERSION" ]]; then
  VERSION="$(
    awk -F' = |;' '/MARKETING_VERSION =/ { print $2; exit }' "$ROOT_DIR/MosulGame.xcodeproj/project.pbxproj"
  )"
fi

if [[ -z "$VERSION" ]]; then
  echo "error: could not determine MosulGame MARKETING_VERSION" >&2
  exit 1
fi

for tool in xcodebuild ditto lipo python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool is required for release-candidate builds" >&2
    exit 1
  fi
done

if [[ "$SKIP_SIGN" -eq 0 ]] && ! command -v codesign >/dev/null 2>&1; then
  echo "error: codesign is required unless --skip-sign is used" >&2
  exit 1
fi

mkdir -p "$DIST_ROOT"
mkdir -p "$(dirname "$REPORT_PATH")"
rm -f "$REPORT_PATH"

{
  echo "check=mosulgame_release_candidate"
  echo "version=$VERSION"
  echo "configuration=$CONFIGURATION"
  echo "destination=$DESTINATION"
  echo "signed=$([[ "$SKIP_SIGN" -eq 0 ]] && echo "ad-hoc" || echo "false")"
  echo "archs=$(IFS=,; echo "${ARCHS[*]}")"
  echo "dist_root=$DIST_ROOT"
} >> "$REPORT_PATH"

build_arch() {
  local arch="$1"
  local derived_data_path="$DERIVED_DATA_ROOT/$arch"
  local built_app="$derived_data_path/Build/Products/$CONFIGURATION/MosulGame.app"
  local output_dir="$DIST_ROOT/$arch"
  local output_app="$output_dir/MosulGame.app"
  local output_executable="$output_app/Contents/MacOS/MosulGame"
  local lipo_archs

  if [[ -e "$output_app" ]]; then
    if [[ "$REPLACE" -eq 0 ]]; then
      echo "error: candidate output already exists: $output_app" >&2
      echo "hint: pass --replace to replace generated candidate app bundles" >&2
      exit 1
    fi
    rm -rf "$output_app"
  fi
  mkdir -p "$output_dir"

  echo "==> Building MosulGame $arch ($CONFIGURATION)"
  xcodebuild \
    -project "$ROOT_DIR/MosulGame.xcodeproj" \
    -scheme MosulGame \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$derived_data_path" \
    ARCHS="$arch" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

  if [[ ! -x "$built_app/Contents/MacOS/MosulGame" ]]; then
    echo "error: expected built app executable was not produced: $built_app" >&2
    exit 1
  fi

  python3 "$ROOT_DIR/scripts/check_mosulgame_runtime_resources.py" --app "$built_app"
  ditto "$built_app" "$output_app"
  python3 "$ROOT_DIR/scripts/check_mosulgame_runtime_resources.py" --app "$output_app"

  if [[ "$SKIP_SIGN" -eq 0 ]]; then
    codesign --force --deep --sign - "$output_app"
    codesign --verify --deep --strict "$output_app"
  fi

  lipo_archs="$(lipo -archs "$output_executable")"
  if [[ "$lipo_archs" != "$arch" ]]; then
    echo "error: expected $output_executable to contain only $arch, found: $lipo_archs" >&2
    exit 1
  fi

  {
    echo "${arch}_app=$output_app"
    echo "${arch}_lipo_archs=$lipo_archs"
  } >> "$REPORT_PATH"
  echo "ok: MosulGame $arch candidate at $output_app"
}

for arch in "${ARCHS[@]}"; do
  build_arch "$arch"
done

echo "ok=true" >> "$REPORT_PATH"

echo "MosulGame release candidate ok: $REPORT_PATH"
cat "$REPORT_PATH"
