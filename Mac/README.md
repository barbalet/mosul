# MOSUL Mac

This folder contains the public MOSUL Mac interface. The Mac app is intentionally thin: SwiftUI owns presentation and input, while `modernerKrieg` owns the portable C simulation, scenario data, asset manifests, runtime PNG assets, AI, and replay/debug tooling.

Open the project from the repository root:

```sh
open Mosul.xcodeproj
```

Or build from Terminal:

```sh
xcodebuild -project Mosul.xcodeproj -scheme Mosul -configuration Debug build
```

For a local workspace-contained build directory:

```sh
xcodebuild -project Mosul.xcodeproj \
  -scheme Mosul \
  -configuration Debug \
  -derivedDataPath build/MosulDerivedData \
  build
```

The app currently loads the 2003 Market / Commercial Streets scenario from:

```text
modernerKrieg/game/mosul/scenarios/market_commercial_streets_2003.mkscenario
```

It renders the runtime map overview from `modernerKrieg/assets/mosul/runtime/`, receives the sprite and marker manifest ids it needs through the C bridge, draws the matching runtime PNG sprites from `modernerKrieg`, overlays tactical markers for objectives, orders, routes, suppression, casualties, civilians, contact reports, and breach/search/cache/rooftop interactions, shows C-core after-action results in the inspector, and can step the simulation, run the deterministic AI loop, or issue selected-unit interaction actions.

Run the repeatable Mac app smoke path from the repository root:

```sh
scripts/run_mac_smoke.sh
```

The smoke path builds both native app bundles into `build/mac-smoke/` through Xcode and checks that the expected app executables were produced. It is the Mac-wrapper companion to the portable CTest coverage in `modernerKrieg`.

The codenamed `snapshot` test path writes the current tactical-map render to timestamped PNG files under `snapshots/` at the repository root. The directory is ignored by git so local visual samples can be captured freely while checking battle states, civilian risk, contact reports, and future sprite rendering.

`AIBattle.xcodeproj` is a standalone Mac autoplay app for AI-vs-AI development. It reuses the Mosul model, tactical map view, C bridge, and `modernerKrieg` core sources, runs both tactical sides through the core AI loop, visualizes the battle, then starts the next seeded battle after a settled result, tick limit, or watchdog stall.

Build AIBattle from the repository root:

```sh
xcodebuild -project AIBattle.xcodeproj \
  -scheme AIBattle \
  -configuration Debug \
  -derivedDataPath build/AIBattleDerivedData \
  build
```
