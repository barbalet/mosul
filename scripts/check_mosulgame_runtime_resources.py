#!/usr/bin/env python3
"""Validate the MosulGame standalone runtime-resource inventory."""

from __future__ import annotations

import argparse
import json
import sys
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INVENTORY_PATH = ROOT / "release" / "mosulgame_runtime_resources.json"


def load_key_value(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def repo_path(relative_path: str) -> Path:
    return ROOT / relative_path


def moderner_krieg_path(relative_path: str) -> Path:
    if relative_path.startswith("modernerKrieg/"):
        return repo_path(relative_path)
    return repo_path(f"modernerKrieg/{relative_path}")


def add_required(required: set[Path], relative_path: str) -> None:
    required.add(repo_path(relative_path))


def add_moderner_krieg_required(required: set[Path], relative_path: str) -> None:
    required.add(moderner_krieg_path(relative_path))


def relative_child(parent: str, child: str) -> str | None:
    child_path = Path(child)
    if child_path.is_absolute() or ".." in child_path.parts:
        return None
    return (Path(parent).parent / child_path).as_posix()


def is_under(relative_path: str, directory: str) -> bool:
    normalized = directory.rstrip("/")
    return relative_path == normalized or relative_path.startswith(f"{normalized}/")


def validate_release_scope(scope: dict[str, object], errors: list[str]) -> None:
    project_text = repo_path("MosulGame.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    release_text = repo_path("RELEASE.md").read_text(encoding="utf-8")

    expected_snippets = [
        f"name = {scope['product_target']};",
        f"productName = {scope['product_target']};",
        f"path = {scope['app_bundle']};",
        f"PRODUCT_BUNDLE_IDENTIFIER = {scope['bundle_identifier']};",
        f"INFOPLIST_KEY_CFBundleDisplayName = {scope['display_name']};",
        f"MACOSX_DEPLOYMENT_TARGET = {scope['minimum_macos']};",
    ]

    for snippet in expected_snippets:
        if snippet not in project_text:
            errors.append(f"project scope mismatch: missing {snippet!r}")

    release_snippets = [
        f"built from `{scope['product_target']}.xcodeproj`",
        f"-project {scope['product_target']}.xcodeproj",
        f"-scheme {scope['scheme']}",
        f"The Xcode target, scheme, app bundle, and executable are all named `{scope['executable']}`.",
    ]

    for architecture in scope["architectures"]:
        release_snippets.append(f"ARCHS={architecture}")

    for snippet in release_snippets:
        if snippet not in release_text:
            errors.append(f"release scope mismatch: missing {snippet!r}")


def collect_resources(inventory: dict[str, object], errors: list[str]) -> set[Path]:
    required: set[Path] = set()

    for relative_path in inventory["required_files"]:
        add_required(required, relative_path)

    scope = inventory["release_scope"]
    scenario_path = repo_path(scope["default_scenario"])
    scenario_values = load_key_value(scenario_path)
    derived = inventory["derived_runtime_inputs"]

    for key in derived["scenario_asset_keys"]:
        value = scenario_values.get(key)
        if not value:
            errors.append(f"scenario missing required key {key}")
            continue
        add_moderner_krieg_required(required, value)

    map_manifest_value = scenario_values.get("asset.map_manifest")
    if map_manifest_value:
        map_values = load_key_value(moderner_krieg_path(map_manifest_value))
        for key in derived["map_manifest_runtime_keys"]:
            value = map_values.get(key)
            if not value:
                errors.append(f"map manifest missing required key {key}")
                continue
            add_moderner_krieg_required(required, value)

    building_manifest_value = scenario_values.get("asset.building_level_manifest")
    if building_manifest_value:
        building_manifest_path = moderner_krieg_path(building_manifest_value)
        building_manifest = json.loads(building_manifest_path.read_text(encoding="utf-8"))
        png_key = derived["building_level_png_key"]
        for level in building_manifest.get("levels", []):
            value = level.get(png_key)
            if not value:
                errors.append(f"building level {level.get('id', '<unknown>')} missing {png_key}")
                continue
            add_moderner_krieg_required(required, value)

    sprite_manifest_value = scenario_values.get("asset.sprite_manifest")
    if sprite_manifest_value:
        sprite_values = load_key_value(moderner_krieg_path(sprite_manifest_value))
        for key in derived["sprite_manifest_runtime_keys"]:
            value = sprite_values.get(key)
            if not value:
                errors.append(f"sprite manifest missing required key {key}")
                continue
            add_moderner_krieg_required(required, value)

        render_manifest_value = sprite_values.get("runtime_render_manifest")
        if render_manifest_value:
            render_manifest_path = moderner_krieg_path(render_manifest_value)
            render_manifest = json.loads(render_manifest_path.read_text(encoding="utf-8"))
            rendered = render_manifest.get(derived["sprite_render_manifest_array"], [])
            expected_count = int(sprite_values.get("runtime_rendered_count", "0"))
            if expected_count and expected_count != len(rendered):
                errors.append(
                    f"sprite render count mismatch: manifest says {expected_count}, "
                    f"render manifest lists {len(rendered)}"
                )

            path_key = derived["sprite_render_manifest_path_key"]
            for entry in rendered:
                value = entry.get(path_key)
                if not value:
                    errors.append("sprite render manifest entry missing path")
                    continue
                add_moderner_krieg_required(required, value)

    collect_audio_resources(inventory, required, errors)
    return required


def collect_audio_resources(
    inventory: dict[str, object],
    required: set[Path],
    errors: list[str]
) -> None:
    audio = inventory.get("audio_runtime", {})
    if not isinstance(audio, dict):
        errors.append("audio_runtime must be an object")
        return

    manifest_relative = audio.get("manifest")
    credits_relative = audio.get("credits")
    if not isinstance(manifest_relative, str) or not manifest_relative:
        errors.append("audio_runtime.manifest is required")
        return
    if not isinstance(credits_relative, str) or not credits_relative:
        errors.append("audio_runtime.credits is required")
        return

    add_required(required, manifest_relative)
    add_required(required, credits_relative)

    manifest_path = repo_path(manifest_relative)
    if not manifest_path.exists():
        return

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        errors.append(f"audio manifest is not valid JSON: {error}")
        return

    if manifest.get("schema_version") != 1:
        errors.append("audio manifest schema_version must be 1")

    assets = manifest.get("assets")
    if not isinstance(assets, list):
        errors.append("audio manifest assets must be an array")
        return

    allowed_buses = set(str(value) for value in audio.get("allowed_buses", []))
    allowed_kinds = set(str(value) for value in audio.get("allowed_kinds", []))
    allowed_licenses = set(str(value) for value in audio.get("allowed_licenses", []))
    allowed_extensions = set(str(value).lower() for value in audio.get("allowed_extensions", []))
    allowed_sample_rates = set(int(value) for value in audio.get("allowed_sample_rates", []))
    allowed_channels = set(int(value) for value in audio.get("allowed_channels", []))
    asset_ids: set[str] = set()

    for index, entry in enumerate(assets):
        if not isinstance(entry, dict):
            errors.append(f"audio asset #{index + 1} must be an object")
            continue

        asset_id = entry.get("id")
        prefix = f"audio asset {asset_id!r}" if isinstance(asset_id, str) and asset_id else f"audio asset #{index + 1}"
        if not isinstance(asset_id, str) or not asset_id:
            errors.append(f"{prefix} missing id")
        elif asset_id in asset_ids:
            errors.append(f"duplicate audio asset id: {asset_id}")
        else:
            asset_ids.add(asset_id)

        file_value = entry.get("file")
        if not isinstance(file_value, str) or not file_value:
            errors.append(f"{prefix} missing file")
            continue

        asset_relative = relative_child(manifest_relative, file_value)
        if asset_relative is None:
            errors.append(f"{prefix} file must be relative to the audio manifest and stay inside that tree")
            continue

        extension = Path(asset_relative).suffix.lower()
        if extension not in allowed_extensions:
            errors.append(f"{prefix} has unsupported extension: {extension or '<none>'}")

        add_required(required, asset_relative)
        asset_path = repo_path(asset_relative)

        bus = entry.get("bus")
        if bus not in allowed_buses:
            errors.append(f"{prefix} bus must be one of {sorted(allowed_buses)}")

        kind = entry.get("kind")
        if kind not in allowed_kinds:
            errors.append(f"{prefix} kind must be one of {sorted(allowed_kinds)}")

        license_id = entry.get("license")
        if license_id not in allowed_licenses:
            errors.append(f"{prefix} license is not release-approved: {license_id!r}")

        attribution = str(entry.get("attribution", "")).strip()
        source_url = str(entry.get("source_url", "")).strip()
        if license_id in {"CC-BY-3.0", "CC-BY-4.0", "US-GOV-PD"} and (not attribution or not source_url):
            errors.append(f"{prefix} requires attribution and source_url for license {license_id}")
        if license_id in {"Original", "Commissioned"} and not attribution:
            errors.append(f"{prefix} requires attribution for {license_id} audio")

        if kind == "loop":
            loop_points = entry.get("loop_points_seconds")
            if not (
                isinstance(loop_points, list)
                and len(loop_points) == 2
                and all(isinstance(value, (int, float)) for value in loop_points)
                and loop_points[0] < loop_points[1]
            ):
                errors.append(f"{prefix} loop audio requires two increasing loop_points_seconds values")

        if kind == "voice":
            locale = str(entry.get("locale", "")).strip()
            transcript = str(entry.get("transcript", "")).strip()
            if not locale or not transcript:
                errors.append(f"{prefix} voice audio requires locale and transcript")

        for numeric_key in ("duration_seconds", "lufs"):
            if numeric_key in entry and not isinstance(entry[numeric_key], (int, float)):
                errors.append(f"{prefix} {numeric_key} must be numeric")

        if asset_path.exists() and extension == ".wav":
            validate_wave_asset(prefix, asset_path, allowed_sample_rates, allowed_channels, errors)


def validate_wave_asset(
    prefix: str,
    asset_path: Path,
    allowed_sample_rates: set[int],
    allowed_channels: set[int],
    errors: list[str]
) -> None:
    try:
        with wave.open(str(asset_path), "rb") as wav:
            sample_rate = wav.getframerate()
            channels = wav.getnchannels()
    except wave.Error as error:
        errors.append(f"{prefix} is not a readable WAV file: {error}")
        return

    if sample_rate not in allowed_sample_rates:
        errors.append(f"{prefix} WAV sample rate {sample_rate} is not in {sorted(allowed_sample_rates)}")
    if channels not in allowed_channels:
        errors.append(f"{prefix} WAV channel count {channels} is not in {sorted(allowed_channels)}")


def bundled_runtime_relative_paths(inventory: dict[str, object], errors: list[str]) -> set[str]:
    required = collect_resources(inventory, errors)
    excluded = list(inventory["excluded_from_standalone_bundle"])
    bundled: set[str] = set()

    for path in required:
        relative_path = path.relative_to(ROOT).as_posix()
        if not relative_path.startswith("modernerKrieg/"):
            continue
        if any(is_under(relative_path, directory) for directory in excluded):
            errors.append(f"runtime payload includes excluded source-only path: {relative_path}")
            continue
        bundled.add(relative_path)

    return bundled


def validate_source_inventory(inventory: dict[str, object], errors: list[str]) -> int:
    validate_release_scope(inventory["release_scope"], errors)
    required = collect_resources(inventory, errors)

    for relative_path in inventory["required_directories"]:
        path = repo_path(relative_path)
        if not path.is_dir():
            errors.append(f"missing directory: {relative_path}")

    missing = [path for path in sorted(required) if not path.exists()]
    for path in missing:
        errors.append(f"missing file: {path.relative_to(ROOT)}")

    return len(required)


def validate_app_bundle(app_path: Path, inventory: dict[str, object], errors: list[str]) -> int:
    scope = inventory["release_scope"]
    runtime_root = app_path / scope["runtime_bundle_root"]
    bundled = bundled_runtime_relative_paths(inventory, errors)

    if not app_path.is_dir():
        errors.append(f"missing app bundle: {app_path}")
        return 0

    if app_path.name != scope["app_bundle"]:
        errors.append(f"app bundle name mismatch: expected {scope['app_bundle']}, found {app_path.name}")

    executable = app_path / "Contents" / "MacOS" / scope["executable"]
    if not executable.is_file():
        errors.append(f"missing app executable: {executable}")

    if not runtime_root.is_dir():
        errors.append(f"missing app runtime root: {runtime_root}")
        return len(bundled)

    stamp = runtime_root / ".mosul-runtime-resources.stamp"
    if not stamp.is_file():
        errors.append(f"missing runtime resource stamp: {stamp}")

    missing = [relative_path for relative_path in sorted(bundled) if not (runtime_root / relative_path).is_file()]
    for relative_path in missing:
        errors.append(f"missing bundled runtime file: {relative_path}")

    for relative_path in inventory["required_directories"]:
        if relative_path.startswith("modernerKrieg/") and not (runtime_root / relative_path).is_dir():
            errors.append(f"missing bundled runtime directory: {relative_path}")

    for excluded in inventory["excluded_from_standalone_bundle"]:
        if excluded.startswith("modernerKrieg/") and (runtime_root / excluded).exists():
            errors.append(f"bundled runtime includes excluded path: {excluded}")

    return len(bundled)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate MosulGame runtime resources.")
    parser.add_argument(
        "--app",
        metavar="PATH",
        type=Path,
        help="validate a built MosulGame.app bundle in addition to the source inventory",
    )
    return parser.parse_args(argv)


def main() -> int:
    args = parse_args(sys.argv[1:])
    errors: list[str] = []
    inventory = json.loads(INVENTORY_PATH.read_text(encoding="utf-8"))

    source_count = validate_source_inventory(inventory, errors)
    app_count = validate_app_bundle(args.app, inventory, errors) if args.app is not None else 0

    if errors:
        print("MosulGame runtime resource inventory failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    if args.app is not None:
        print(f"MosulGame app runtime resources ok: {app_count} bundled files checked in {args.app}")
    else:
        print(f"MosulGame runtime resource inventory ok: {source_count} files checked")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
