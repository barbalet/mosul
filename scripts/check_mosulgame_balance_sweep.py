#!/usr/bin/env python3
"""Run a deterministic MOSUL AI balance and pacing sweep."""

from __future__ import annotations

import argparse
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MODERNER_KRIEG_DIR = ROOT_DIR / "modernerKrieg"
DEFAULT_SCENARIO = "game/mosul/scenarios/market_commercial_streets_2003.mkscenario"

SUMMARY_RE = re.compile(
    r"battle=(?P<battle>\d+) tick=(?P<tick>\d+) score=(?P<score>-?\d+) "
    r"outcome=(?P<outcome>\w+) "
    r"objectives\(player=(?P<player>\d+),opfor=(?P<opfor>\d+),neutral=(?P<neutral>\d+),contested=(?P<contested>\d+)\) "
    r"contacts=(?P<contacts>\d+) resolved=(?P<resolved>\d+) "
    r"interaction=(?P<interaction>-?\d+) risk=(?P<risk>-?\d+)"
)
SETTLED_RE = re.compile(
    r"battle=(?P<battle>\d+) settled tick=(?P<tick>\d+) "
    r"score=(?P<score>-?\d+) outcome=(?P<outcome>\w+)"
)
TOTALS_RE = re.compile(
    r"ai_battle_totals battles=(?P<battles>\d+) failed=(?P<failed>\d+) "
    r"settled=(?P<settled>\d+) stalled=(?P<stalled>\d+) "
    r"best_score=(?P<best>-?\d+) worst_score=(?P<worst>-?\d+) "
    r"seed_step=(?P<seed_step>\d+)"
)


@dataclass(frozen=True)
class SweepSummary:
    battles: int
    failed: int
    settled: int
    stalled: int
    best_score: int
    worst_score: int
    max_contacts: int
    max_resolved_contacts: int
    max_civilian_risk: int
    earliest_settle_tick: int | None
    outcomes: tuple[str, ...]


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


def parse_sweep(output: str) -> SweepSummary:
    summaries = list(SUMMARY_RE.finditer(output))
    totals_match = TOTALS_RE.search(output)
    if not summaries:
        raise ValueError("mk_ai_battle output did not include battle summaries")
    if totals_match is None:
        raise ValueError("mk_ai_battle output did not include ai_battle_totals")

    settled = list(SETTLED_RE.finditer(output))
    earliest_settle_tick = min((int(match.group("tick")) for match in settled), default=None)
    outcomes = tuple(sorted({match.group("outcome") for match in summaries}))

    return SweepSummary(
        battles=int(totals_match.group("battles")),
        failed=int(totals_match.group("failed")),
        settled=int(totals_match.group("settled")),
        stalled=int(totals_match.group("stalled")),
        best_score=int(totals_match.group("best")),
        worst_score=int(totals_match.group("worst")),
        max_contacts=max(int(match.group("contacts")) for match in summaries),
        max_resolved_contacts=max(int(match.group("resolved")) for match in summaries),
        max_civilian_risk=max(int(match.group("risk")) for match in summaries),
        earliest_settle_tick=earliest_settle_tick,
        outcomes=outcomes,
    )


def validate_summary(
    summary: SweepSummary,
    expected_battles: int,
    min_worst_score: int,
    min_contacts: int,
    min_resolved_contacts: int,
    min_civilian_risk: int,
    min_settle_tick: int,
) -> None:
    failures: list[str] = []

    if summary.battles != expected_battles:
        failures.append(f"expected {expected_battles} battles, saw {summary.battles}")
    if summary.failed != 0:
        failures.append(f"failed battles: {summary.failed}")
    if summary.stalled != 0:
        failures.append(f"stalled battles: {summary.stalled}")
    if summary.worst_score < min_worst_score:
        failures.append(f"worst score {summary.worst_score} below floor {min_worst_score}")
    if summary.max_contacts < min_contacts:
        failures.append(f"max contacts {summary.max_contacts} below floor {min_contacts}")
    if summary.max_resolved_contacts < min_resolved_contacts:
        failures.append(
            f"max resolved contacts {summary.max_resolved_contacts} below floor {min_resolved_contacts}"
        )
    if summary.max_civilian_risk < min_civilian_risk:
        failures.append(f"max civilian risk {summary.max_civilian_risk} below floor {min_civilian_risk}")
    if summary.earliest_settle_tick is not None and summary.earliest_settle_tick < min_settle_tick:
        failures.append(
            f"earliest settled tick {summary.earliest_settle_tick} before floor {min_settle_tick}"
        )

    if failures:
        raise ValueError("; ".join(failures))


def write_report(
    report: Path,
    command: list[str],
    output: str,
    summary: SweepSummary,
    scenario: str,
    seed: int,
    seed_step: int,
    ticks: int,
) -> None:
    lines = [
        "ok=true",
        "check=mosulgame_balance_sweep",
        f"scenario={scenario}",
        f"seed={seed}",
        f"seed_step={seed_step}",
        f"ticks={ticks}",
        f"battles={summary.battles}",
        f"failed={summary.failed}",
        f"settled={summary.settled}",
        f"stalled={summary.stalled}",
        f"best_score={summary.best_score}",
        f"worst_score={summary.worst_score}",
        f"max_contacts={summary.max_contacts}",
        f"max_resolved_contacts={summary.max_resolved_contacts}",
        f"max_civilian_risk={summary.max_civilian_risk}",
        f"earliest_settle_tick={summary.earliest_settle_tick if summary.earliest_settle_tick is not None else 'none'}",
        f"outcomes={','.join(summary.outcomes)}",
        f"command={' '.join(command)}",
        "",
        output.rstrip(),
    ]
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-build", action="store_true", help="reuse an existing headless CMake build")
    parser.add_argument("--preset", default="headless", help="CMake preset to configure/build")
    parser.add_argument("--scenario", default=DEFAULT_SCENARIO, help="scenario path relative to modernerKrieg")
    parser.add_argument("--battles", type=int, default=5, help="number of seed-sweep battles")
    parser.add_argument("--ticks", type=int, default=160, help="maximum ticks per battle")
    parser.add_argument("--seed", type=int, default=84985359904819, help="first deterministic seed")
    parser.add_argument("--seed-step", type=int, default=101, help="deterministic seed step")
    parser.add_argument("--watchdog", type=int, default=40, help="stall watchdog ticks")
    parser.add_argument("--summary-every", type=int, default=20, help="battle summary cadence")
    parser.add_argument("--min-worst-score", type=int, default=-1500, help="lowest accepted final score")
    parser.add_argument("--min-contacts", type=int, default=20, help="minimum contact pressure across the sweep")
    parser.add_argument(
        "--min-resolved-contacts",
        type=int,
        default=20,
        help="minimum resolved contact pressure across the sweep",
    )
    parser.add_argument("--min-civilian-risk", type=int, default=20, help="minimum risk pressure across the sweep")
    parser.add_argument(
        "--min-settle-tick",
        type=int,
        default=30,
        help="if a success/partial settlement occurs, it must not happen before this tick",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=ROOT_DIR / "snapshots/evidence/mosul-balance-sweep.txt",
        help="text report path",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.skip_build:
        build_headless(args.preset)

    ai_battle = MODERNER_KRIEG_DIR / "build" / args.preset / "bin" / "mk_ai_battle"
    if not ai_battle.exists():
        raise FileNotFoundError(f"missing AI battle runner: {ai_battle}")

    command = [
        str(ai_battle),
        "--project-root",
        ".",
        "--scenario",
        args.scenario,
        "--battles",
        str(args.battles),
        "--ticks",
        str(args.ticks),
        "--seed",
        str(args.seed),
        "--seed-step",
        str(args.seed_step),
        "--summary-every",
        str(args.summary_every),
        "--watchdog",
        str(args.watchdog),
        "--fail-on-stall",
        "--expect-max-stalled",
        "0",
        "--expect-min-worst-score",
        str(args.min_worst_score),
    ]
    completed = run(command, cwd=MODERNER_KRIEG_DIR, capture=True)
    summary = parse_sweep(completed.stdout)
    validate_summary(
        summary,
        expected_battles=args.battles,
        min_worst_score=args.min_worst_score,
        min_contacts=args.min_contacts,
        min_resolved_contacts=args.min_resolved_contacts,
        min_civilian_risk=args.min_civilian_risk,
        min_settle_tick=args.min_settle_tick,
    )
    write_report(
        args.report.resolve(),
        command,
        completed.stdout,
        summary,
        args.scenario,
        args.seed,
        args.seed_step,
        args.ticks,
    )
    print(f"MosulGame balance sweep ok: {args.report.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
