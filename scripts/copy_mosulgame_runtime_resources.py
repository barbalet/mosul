#!/usr/bin/env python3
"""Copy MosulGame runtime resources into an app-bundle resource layout."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path


sys.dont_write_bytecode = True

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_mosulgame_runtime_resources import (  # noqa: E402
    INVENTORY_PATH,
    ROOT,
    collect_resources,
)


def is_under(relative_path: str, directory: str) -> bool:
    normalized = directory.rstrip("/")
    return relative_path == normalized or relative_path.startswith(f"{normalized}/")


def bundled_runtime_files(inventory: dict[str, object]) -> list[Path]:
    errors: list[str] = []
    required = collect_resources(inventory, errors)
    excluded = list(inventory["excluded_from_standalone_bundle"])
    bundled: list[Path] = []

    for path in sorted(required):
        relative_path = path.relative_to(ROOT).as_posix()
        if not relative_path.startswith("modernerKrieg/"):
            continue
        if any(is_under(relative_path, directory) for directory in excluded):
            errors.append(f"runtime payload includes excluded source-only path: {relative_path}")
            continue
        bundled.append(path)

    missing = [path for path in bundled if not path.exists()]
    for path in missing:
        errors.append(f"missing runtime payload file: {path.relative_to(ROOT)}")

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        raise SystemExit(1)

    return bundled


def prepare_destination(runtime_root: Path) -> Path:
    resolved = runtime_root.resolve()
    forbidden = {Path("/"), ROOT.resolve(), (ROOT / "modernerKrieg").resolve()}
    if resolved in forbidden:
        print(f"refusing unsafe runtime destination: {runtime_root}", file=sys.stderr)
        raise SystemExit(1)

    moderner_krieg_destination = runtime_root / "modernerKrieg"
    if moderner_krieg_destination.exists():
        shutil.rmtree(moderner_krieg_destination)
    moderner_krieg_destination.mkdir(parents=True, exist_ok=True)
    return moderner_krieg_destination


def copy_runtime_files(runtime_root: Path, files: list[Path]) -> None:
    prepare_destination(runtime_root)

    for source in files:
        relative_path = source.relative_to(ROOT)
        destination = runtime_root / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    stamp = runtime_root / ".mosul-runtime-resources.stamp"
    stamp.write_text(f"files={len(files)}\n", encoding="utf-8")


def default_runtime_root() -> Path | None:
    target_build_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if target_build_dir is not None:
        return target_build_dir

    return None


def main() -> int:
    runtime_root = default_runtime_root()
    if runtime_root is None:
        print(
            "usage: copy_mosulgame_runtime_resources.py "
            "<Contents/Resources/mosul-runtime destination>",
            file=sys.stderr,
        )
        return 2

    inventory = json.loads(INVENTORY_PATH.read_text(encoding="utf-8"))
    files = bundled_runtime_files(inventory)
    copy_runtime_files(runtime_root, files)
    print(f"Copied {len(files)} MosulGame runtime files to {runtime_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
