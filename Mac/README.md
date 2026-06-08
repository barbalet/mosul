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

It renders the runtime map overview from `modernerKrieg/assets/mosul/runtime/`, overlays C-core units/objectives/civilians/contact reports, and can step the simulation or run the deterministic AI loop.

The codenamed `snapshot` test path writes the current tactical-map render to timestamped PNG files under `snapshots/` at the repository root. The directory is ignored by git so local visual samples can be captured freely while checking battle states, civilian risk, contact reports, and future sprite rendering.
