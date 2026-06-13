# MosulGame Playthrough And Balance Checks

These checks use the portable `modernerKrieg` headless tools from the Mosul
repository root. They build the `headless` CMake preset by default and write
ignored evidence under `snapshots/evidence/`.

## Outcome Bands

```sh
scripts/check_mosulgame_outcome_bands.py
```

This script runs three deterministic scripted playthroughs and fails unless the
expected after-action band is reached and the transcript includes narrative
after-action text:

- `success`: `market_control_smoke_2003.mkscenario`, 1 tick.
- `partial`: `market_control_smoke_2003.mkscenario`, 80 ticks.
- `failure`: `market_contested_risk_smoke_2003.mkscenario`, 80 ticks.

The combined report is written to:

```text
snapshots/evidence/mosul-outcome-bands.txt
```

Per-band transcripts and replays are written under:

```text
snapshots/evidence/mosul-outcome-bands/
```

## Balance Sweep

```sh
scripts/check_mosulgame_balance_sweep.py
```

This script runs a five-seed AI-vs-AI sweep on the public
`market_commercial_streets_2003.mkscenario` demo. It fails on stalled battles,
failed runner exits, score floors below the configured threshold, weak contact
pressure, weak resolved-contact pressure, weak civilian-risk pressure, or a
success/partial settlement before the configured minimum settle tick.

The combined report is written to:

```text
snapshots/evidence/mosul-balance-sweep.txt
```

The current baseline is intentionally pressure-heavy: the five-seed public-demo
sweep reaches failure outcomes, produces dense contact and civilian-risk
pressure, does not stall, and does not settle trivially. Later balance cycles
can raise the score floor or settlement expectations once the player completion
loop and AI tuning improve.
