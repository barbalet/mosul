#!/usr/bin/env python3
"""Verify deterministic MOSUL outcome-band playthrough evidence."""

from __future__ import annotations

import argparse
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MODERNER_KRIEG_DIR = ROOT_DIR / "modernerKrieg"


@dataclass(frozen=True)
class OutcomeCase:
    name: str
    scenario: str
    ticks: int
    expected_outcome: str


@dataclass(frozen=True)
class OutcomeResult:
    case: OutcomeCase
    score: int
    success_threshold: int
    partial_threshold: int
    objectives: int
    contested: int
    interaction: int
    civilian_risk: int
    ticks: int
    narrative: str
    transcript: Path
    replay: Path


OUTCOME_CASES = [
    OutcomeCase(
        name="success",
        scenario="game/mosul/scenarios/market_control_smoke_2003.mkscenario",
        ticks=1,
        expected_outcome="success",
    ),
    OutcomeCase(
        name="partial",
        scenario="game/mosul/scenarios/market_control_smoke_2003.mkscenario",
        ticks=80,
        expected_outcome="partial",
    ),
    OutcomeCase(
        name="failure",
        scenario="game/mosul/scenarios/market_contested_risk_smoke_2003.mkscenario",
        ticks=80,
        expected_outcome="failure",
    ),
]

AFTER_ACTION_RE = re.compile(
    r"after_action: outcome=(?P<outcome>\w+) "
    r"score=(?P<score>-?\d+) "
    r"thresholds\(success=(?P<success>-?\d+),partial=(?P<partial>-?\d+)\) "
    r"objectives=(?P<objectives>\d+) contested=(?P<contested>\d+) "
    r"interaction=(?P<interaction>-?\d+) civilian_risk=(?P<civilian_risk>-?\d+) "
    r"casualties\(player=(?P<player_casualties>\d+),opfor=(?P<opfor_casualties>\d+),civilian=(?P<civilian_casualties>\d+)\) "
    r"ticks=(?P<ticks>\d+)"
)
END_RE = re.compile(
    r"event tick=(?P<tick>\d+) kind=end result=(?P<result>\w+) "
    r"score=(?P<score>-?\d+) outcome=(?P<outcome>\w+)"
)


def run(command: list[str], cwd: Path, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )


def build_headless(preset: str) -> None:
    run(["cmake", "--preset", preset], cwd=MODERNER_KRIEG_DIR)
    run(["cmake", "--build", "--preset", preset], cwd=MODERNER_KRIEG_DIR)


def parse_result(case: OutcomeCase, transcript: Path, replay: Path) -> OutcomeResult:
    transcript_text = transcript.read_text(encoding="utf-8")
    replay_text = replay.read_text(encoding="utf-8")

    after_action = AFTER_ACTION_RE.search(transcript_text)
    if after_action is None:
        raise ValueError(f"{case.name}: missing after_action summary in {transcript}")

    narrative_match = re.search(r"^after_action_text: (?P<narrative>.+)$", transcript_text, re.MULTILINE)
    if narrative_match is None or not narrative_match.group("narrative").strip():
        raise ValueError(f"{case.name}: missing after_action_text narrative in {transcript}")

    end_matches = list(END_RE.finditer(replay_text))
    if not end_matches:
        raise ValueError(f"{case.name}: missing replay end event in {replay}")
    end_event = end_matches[-1]

    outcome = after_action.group("outcome")
    replay_outcome = end_event.group("outcome")
    if outcome != case.expected_outcome or replay_outcome != case.expected_outcome:
        raise ValueError(
            f"{case.name}: expected {case.expected_outcome}, "
            f"transcript has {outcome}, replay has {replay_outcome}"
        )

    if end_event.group("result") != "MK_OK":
        raise ValueError(f"{case.name}: replay ended with {end_event.group('result')}")

    return OutcomeResult(
        case=case,
        score=int(after_action.group("score")),
        success_threshold=int(after_action.group("success")),
        partial_threshold=int(after_action.group("partial")),
        objectives=int(after_action.group("objectives")),
        contested=int(after_action.group("contested")),
        interaction=int(after_action.group("interaction")),
        civilian_risk=int(after_action.group("civilian_risk")),
        ticks=int(after_action.group("ticks")),
        narrative=narrative_match.group("narrative").strip(),
        transcript=transcript,
        replay=replay,
    )


def run_case(headless: Path, output_dir: Path, case: OutcomeCase) -> OutcomeResult:
    transcript = output_dir / f"{case.name}.txt"
    replay = output_dir / f"{case.name}.mkreplay"
    transcript.unlink(missing_ok=True)
    replay.unlink(missing_ok=True)

    run(
        [
            str(headless),
            "--project-root",
            ".",
            "--scenario",
            case.scenario,
            "--ai-only",
            "--max-ticks",
            str(case.ticks),
            "--quiet",
            "--aar",
            "--debug-log",
            "--transcript",
            str(transcript),
            "--replay",
            str(replay),
            "--expect-outcome",
            case.expected_outcome,
        ],
        cwd=MODERNER_KRIEG_DIR,
    )

    if not transcript.exists() or not replay.exists():
        raise ValueError(f"{case.name}: expected transcript and replay output")

    return parse_result(case, transcript, replay)


def write_report(report: Path, results: list[OutcomeResult]) -> None:
    lines = [
        "ok=true",
        "check=mosulgame_outcome_bands",
        f"cases={len(results)}",
    ]

    for result in results:
        prefix = result.case.name
        lines.extend(
            [
                f"{prefix}.scenario={result.case.scenario}",
                f"{prefix}.ticks={result.ticks}",
                f"{prefix}.outcome={result.case.expected_outcome}",
                f"{prefix}.score={result.score}",
                f"{prefix}.thresholds=success:{result.success_threshold},partial:{result.partial_threshold}",
                f"{prefix}.objectives={result.objectives}",
                f"{prefix}.contested={result.contested}",
                f"{prefix}.interaction={result.interaction}",
                f"{prefix}.civilian_risk={result.civilian_risk}",
                f"{prefix}.after_action_text={result.narrative}",
                f"{prefix}.transcript={result.transcript}",
                f"{prefix}.replay={result.replay}",
            ]
        )

    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-build", action="store_true", help="reuse an existing headless CMake build")
    parser.add_argument("--preset", default="headless", help="CMake preset to configure/build")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=ROOT_DIR / "snapshots/evidence/mosul-outcome-bands",
        help="directory for per-case transcripts and replays",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=ROOT_DIR / "snapshots/evidence/mosul-outcome-bands.txt",
        help="combined text report path",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.skip_build:
        build_headless(args.preset)

    headless = MODERNER_KRIEG_DIR / "build" / args.preset / "bin" / "mk_headless_run"
    if not headless.exists():
        raise FileNotFoundError(f"missing headless runner: {headless}")

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    results = [run_case(headless, output_dir, case) for case in OUTCOME_CASES]
    write_report(args.report.resolve(), results)
    print(f"MosulGame outcome-band evidence ok: {args.report.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
