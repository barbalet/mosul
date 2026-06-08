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

It renders the runtime map overview from `modernerKrieg/assets/mosul/runtime/`, resolves C-core unit glyphs through `modernerKrieg/assets/mosul/runtime/sprites/manifest.json`, draws the matching runtime PNG sprites, overlays tactical markers for objectives, orders, routes, suppression, casualties, civilians, and contact reports, and can step the simulation or run the deterministic AI loop.

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
