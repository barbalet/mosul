# MOSUL Mac

This folder contains the public MOSUL Mac interface. The Mac app is intentionally thin: SwiftUI owns presentation and input, while `modernerKrieg` owns the portable C simulation, scenario data, asset manifests, runtime PNG assets, AI, and replay/debug tooling.

Open the player-facing game project from the repository root:

```sh
open MosulGame.xcodeproj
```

Or build from Terminal:

```sh
xcodebuild -project MosulGame.xcodeproj -scheme MosulGame -configuration Debug build
```

For a local workspace-contained build directory:

```sh
xcodebuild -project MosulGame.xcodeproj \
  -scheme MosulGame \
  -configuration Debug \
  -derivedDataPath build/MosulGameDerivedData \
  build
```

The app currently loads the 2003 Market / Commercial Streets scenario from:

```text
modernerKrieg/game/mosul/scenarios/market_commercial_streets_2003.mkscenario
```

MosulGame renders the runtime ground-level PNG plus upper-floor and roof-access alpha overlays from `modernerKrieg/assets/mosul/runtime/`, receives the sprite, marker, map-level, unit-level, contact-level, and interaction-level ids it needs through the C bridge, draws the matching runtime PNG sprites from `modernerKrieg`, overlays edge-aware tactical markers for objectives, orders, routes, suppression, casualties, civilians, dedicated civilian-risk underlays, clustered contact reports, and breach/search/cache/rooftop interactions, labels selected-unit/contact/interaction level context, auto-shows tactically referenced upper-floor overlays, shows C-core after-action results in the inspector, and can toggle map levels, step the simulation, run opponent AI ticks, or issue selected-unit interaction actions.

The opening screen lets the player command either the U.S. patrol or the opposing armed cell. Manual orders are gated to the chosen side; opponent ticks run the other side through the existing deterministic tactical AI.

Run the repeatable Mac app smoke path from the repository root:

```sh
scripts/run_mac_smoke.sh
```

The smoke path builds the MosulGame and AIBattle native app bundles into `build/mac-smoke/` through Xcode and checks that the expected app executables were produced. The root `Mac App Smoke` GitHub Actions workflow runs the same script on macOS, making it the Mac-wrapper companion to the portable CTest coverage in `modernerKrieg`.

The codenamed `snapshot` test path writes the current tactical-map render to timestamped PNG files under `snapshots/` at the repository root. The directory is ignored by git so local visual samples can be captured freely while checking battle states, civilian risk, contact reports, and future sprite rendering.

For repeatable visual evidence, run:

```sh
scripts/capture_snapshot_evidence.sh
```

The evidence script builds the MosulGame app, runs a deterministic snapshot-only launch with AI ticks, and writes `snapshots/evidence/mosul-map-evidence.png` for before/after comparison.

`AIBattle.xcodeproj` is a standalone Mac autoplay app for AI-vs-AI development. It reuses the Mosul model, tactical map view, C bridge, and `modernerKrieg` core sources, runs both tactical sides through the core AI loop, visualizes the battle, then starts the next seeded battle after a clean result, pressured partial, tick limit, or watchdog stall.

Run repeatable AIBattle pacing/readability evidence from the repository root:

```sh
scripts/capture_aibattle_evidence.sh
```

The evidence script builds AIBattle, runs a deterministic evidence-only launch, and writes `snapshots/evidence/aibattle-evidence.png` plus `snapshots/evidence/aibattle-evidence.txt` with a compact tuning report that includes result pressure and partial-settlement state.

Run a full AIBattle movie capture from the repository root:

```sh
scripts/capture_aibattle_movie.sh
```

The movie script builds AIBattle, runs its deterministic movie-only launch, and writes `snapshots/evidence/aibattle-battle-1.mov` plus a matching `.txt` report. The MOV frames include the tactical map, visible overlays, score, civilian state, unit state, contacts, tuning status, and final result for external review. Use `--battle-index`, `--fps`, `--output`, and `--report` for alternate captures.

Build AIBattle from the repository root:

```sh
xcodebuild -project AIBattle.xcodeproj \
  -scheme AIBattle \
  -configuration Debug \
  -derivedDataPath build/AIBattleDerivedData \
  build
```
