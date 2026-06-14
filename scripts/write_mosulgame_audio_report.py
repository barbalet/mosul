#!/usr/bin/env python3
"""Write a deterministic MosulGame audio release evidence report."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INVENTORY_PATH = ROOT / "release" / "mosulgame_runtime_resources.json"
SOURCE_RUNTIME_ROOT = ROOT / "modernerKrieg"
SPEECH_TAGS = {"speech", "murmur", "radio", "voice"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, help="Optional MosulGame.app bundle to inspect.")
    parser.add_argument("--output", type=Path, help="Optional key-value report path.")
    return parser.parse_args()


def runtime_root(app: Path | None, inventory: dict[str, object]) -> tuple[Path, str]:
    if app is None:
        return SOURCE_RUNTIME_ROOT, "source checkout"

    scope = inventory["release_scope"]
    return app / scope["runtime_bundle_root"] / "modernerKrieg", "bundled app resources"


def audio_paths(root: Path) -> tuple[Path, Path]:
    audio_root = root / "assets" / "mosul" / "audio"
    return audio_root / "mosul_audio_manifest.json", audio_root / "CREDITS.md"


def relative_asset_path(manifest_path: Path, file_value: str) -> Path:
    return manifest_path.parent / file_value


def report_error(message: str, errors: list[str]) -> None:
    errors.append(message.replace("\n", " "))


def main() -> int:
    args = parse_args()
    inventory = json.loads(INVENTORY_PATH.read_text(encoding="utf-8"))
    root, source_label = runtime_root(args.app, inventory)
    manifest_path, credits_path = audio_paths(root)
    errors: list[str] = []

    if not manifest_path.exists():
        report_error(f"missing audio manifest: {manifest_path}", errors)
        manifest = {"assets": []}
    else:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    credits_text = credits_path.read_text(encoding="utf-8") if credits_path.exists() else ""
    if not credits_text:
        report_error(f"missing audio credits: {credits_path}", errors)

    audio_inventory = inventory.get("audio_runtime", {})
    size_budget = audio_inventory.get("size_budget_bytes", 0)
    assets = manifest.get("assets", [])
    bus_counts = Counter()
    kind_counts = Counter()
    review_counts = Counter()
    total_bytes = 0
    transcript_count = 0
    caption_count = 0
    speech_tagged_count = 0
    attribution_covered = 0
    missing_files: list[str] = []

    for entry in assets:
        if not isinstance(entry, dict):
            report_error("audio manifest contains a non-object asset entry", errors)
            continue

        asset_id = str(entry.get("id", "<missing>"))
        bus = str(entry.get("bus", ""))
        kind = str(entry.get("kind", ""))
        bus_counts[bus] += 1
        kind_counts[kind] += 1

        file_value = str(entry.get("file", ""))
        asset_path = relative_asset_path(manifest_path, file_value)
        if asset_path.exists():
            total_bytes += asset_path.stat().st_size
        else:
            missing_files.append(file_value)
            report_error(f"missing audio asset file: {asset_id} -> {file_value}", errors)

        transcript = str(entry.get("transcript", "")).strip()
        caption = str(entry.get("caption", "")).strip()
        review_status = str(entry.get("review_status", "")).strip()
        tags = set(entry.get("tags", [])) if isinstance(entry.get("tags", []), list) else set()

        if transcript:
            transcript_count += 1
        if caption:
            caption_count += 1
        if review_status:
            review_counts[review_status] += 1

        if kind == "voice" or tags.intersection(SPEECH_TAGS):
            speech_tagged_count += 1
            if not transcript:
                report_error(f"speech asset missing transcript: {asset_id}", errors)
            if kind == "voice" and not caption:
                report_error(f"voice asset missing caption: {asset_id}", errors)
            if not review_status:
                report_error(f"speech asset missing review_status: {asset_id}", errors)

        attribution = str(entry.get("attribution", "")).strip()
        license_id = str(entry.get("license", "")).strip()
        if license_id != "CC0-1.0" and attribution:
            if attribution in credits_text:
                attribution_covered += 1
            else:
                report_error(f"credits missing attribution for {asset_id}", errors)

    if kind_counts["voice"] <= 0:
        report_error("audio report expected at least one voice asset", errors)
    if bus_counts["radio"] <= 0:
        report_error("audio report expected at least one radio-bus asset", errors)
    if not any("murmur" in set(entry.get("tags", [])) for entry in assets if isinstance(entry, dict)):
        report_error("audio report expected at least one civilian murmur asset", errors)
    if isinstance(size_budget, int) and size_budget > 0 and total_bytes > size_budget:
        report_error(f"audio byte budget exceeded: {total_bytes} > {size_budget}", errors)

    report_lines = [
        f"ok={'false' if errors else 'true'}",
        "check=mosulgame_audio_release",
        f"runtime_source={source_label}",
        f"audio_manifest={manifest_path}",
        f"audio_credits={credits_path}",
        f"audio_asset_count={len(assets)}",
        f"audio_loop_count={kind_counts['loop']}",
        f"audio_one_shot_count={kind_counts['one_shot']}",
        f"audio_voice_count={kind_counts['voice']}",
        f"audio_radio_count={bus_counts['radio']}",
        f"audio_ambience_count={bus_counts['ambience']}",
        f"audio_speech_tagged_count={speech_tagged_count}",
        f"audio_transcript_count={transcript_count}",
        f"audio_caption_count={caption_count}",
        f"audio_review_statuses={','.join(sorted(review_counts))}",
        f"audio_attribution_covered_count={attribution_covered}",
        f"audio_total_bytes={total_bytes}",
        f"audio_size_budget_bytes={size_budget}",
        f"audio_missing_file_count={len(missing_files)}",
    ]

    if errors:
        report_lines.append(f"errors={'; '.join(errors)}")

    report = "\n".join(report_lines) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")

    sys.stdout.write(report)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
