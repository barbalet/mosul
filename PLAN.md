# MOSUL Plan

`mosul` is the public Mac SwiftUI interface and project home for the MOSUL playable demo. The first public target is the 2003 Market / Commercial Streets scenario, with `modernerKrieg` providing the portable tactical engine, scenario data, asset manifests, runtime PNGs, AI, replay, and headless validation tools.

The project is ready to move from art/import work into playable-demo development. The next job is to turn the existing source art, scenario concept, and engine core into a small playable vertical slice.

## Active Development Step

- Completed: Step 1 - Replace the first SwiftUI unit markers with sprite-manifest driven runtime PNG drawing.
- Completed: Step 2 - Add visible order, selection, route, suppression, casualty, objective, and hidden-contact markers in the Mac app.
- Completed: Step 3 - Expose sprite/marker manifest ids through the bridge only where the Mac app needs them.
- Completed: Step 4 - Add player-facing after-action results from the existing C score/outcome data.
- Completed: Step 5 - Deepen breach/search/cache/rooftop interactions in the C core, then surface only their controls and overlays in SwiftUI.
- Completed: Step 6 - Add a repeatable Mac app smoke path in addition to the existing headless CTest coverage.
- Completed: Step 7 - Keep README, `PLAN.md`, and `Mac/README.md` aligned whenever the frontend/core boundary changes.
- Completed: Step 8 - Use `snapshot` captures as visual regression evidence when sprite-driven unit rendering and civilian state art replace the current symbolic overlays.
- Completed: Step 9 - Use AIBattle to tune AI pacing, result criteria, civilian-risk visibility, and battle-state readability before moving the same visualization improvements into the player-facing Mosul app.
- Completed: Step 10 - Improve civilian-risk readability where risk rings overlap contact, objective, and unit markers in the shared tactical map.
- Active: Step 11 - Keep edge labels and dense contact stacks inside the shared tactical-map frame.
- Active detail: Use the latest AIBattle evidence to clamp right-edge marker labels and reduce dense contact stack clipping before broader AI/play tuning.
- Last advanced: 2026-06-08

## Current Public Baseline

- The public README describes the 2003 Market / Commercial Streets demo direction and the Mac/frontend split.
- `Mosul.xcodeproj` now builds a native Mac SwiftUI shell from this repository.
- `AIBattle.xcodeproj` builds a standalone Mac AI-vs-AI autoplay shell that reuses the Mosul model, tactical view, bridge, and C core sources.
- `Mac/Mosul/App/` contains the SwiftUI presentation, map view, controls, and inspector.
- `Mac/Mosul/Bridge/` contains a small C bridge over the `modernerKrieg` headers.
- Public presentation art exists under `assets/readme/`.
- The `modernerKrieg` engine submodule builds as a portable C/CMake project and remains the owner of gameplay, data loading, AI, runtime PNG assets, and validation tools.
- The engine has deterministic coverage for core rules, board projection, scenario loading, asset manifests, AI/autoplay, replay validation, balance checks, and the core/frontend boundary.
- Source art and generated runtime art for the 2003 demo exist under `modernerKrieg/assets/mosul/`.
- The SDL path is retired; new launchable interfaces should be platform-native shells over the portable C core.
- The codenamed `snapshot` Mac test path can write timestamped local PNG captures of the current tactical-map render under ignored `snapshots/` output.
- `scripts/run_mac_smoke.sh` and `.github/workflows/mac-app-smoke.yml` provide a repeatable native Mac smoke path that builds the Mosul and AIBattle app bundles through Xcode.
- `scripts/capture_snapshot_evidence.sh` builds Mosul, runs a deterministic snapshot-only app launch, and writes ignored visual evidence under `snapshots/evidence/`.
- `scripts/capture_aibattle_evidence.sh` builds AIBattle, runs a deterministic evidence-only app launch, and writes ignored pacing/readability evidence plus a tuning report under `snapshots/evidence/`.
- The shared Mac tactical map now resolves unit glyphs through `modernerKrieg`'s runtime sprite manifest and draws runtime PNG sprites in both Mosul and AIBattle.
- The shared Mac tactical map now shows order, selection, route destination, suppression, casualty, objective, civilian-risk, hidden/contact, and breach/search/cache/rooftop interaction markers over the runtime sprites.
- The shared Mac tactical map now draws civilian-risk as a dedicated underlay with stronger high-risk emphasis so civilians stay visible during contact/objective overlap.
- The C bridge now exposes the sprite and marker manifest ids the Mac map needs, unit/civilian sprite ids, validated tactical marker ids, breach/search/cache/rooftop interaction summaries, and selected-unit interaction commands.
- The Mosul inspector now shows a player-facing after-action panel backed by the C core's score, outcome, summary, narrative, and score-component data, plus selected-unit interaction controls.
- AIBattle now shows a compact tuning panel for pacing, risk, result criteria, contacts, interactions, and the first evidence-driven readability target.

## Playable Demo Target

The first demo should be a compact tactical slice, not the whole city.

- Setting: Mosul, Iraq, 2003, after the city fell during Operation Iraqi Freedom.
- Location: a 500 m x 500 m Market / Commercial Streets cluster.
- Player force: U.S. Army patrol / security element with squad-level control.
- Opposing forces: regime remnants, irregular fighters, looters, early insurgent cells, and hidden armed threats.
- Non-combatants: civilians and civilian movement/risk must affect player decisions.
- Terrain: streets, shopfronts, courtyards, rooftops, upper floors, checkpoints, rubble, cache/search areas, and breach points.

The demo is playable when a user can launch one scenario, inspect the map, select units, issue orders, resolve contact, see casualties/suppression/civilian risk, and reach a clear after-action outcome.

## Product Tracks

### Scenario And Design

- Define one short scenario briefing, starting forces, hidden threat layout, victory conditions, and failure conditions.
- Keep the first scenario focused on patrol, contact, civilian safety, search/cache handling, and withdrawal or stabilization.
- Write scenario data outside hard-coded C constants once the first data format is chosen.
- Decide what information the player knows at start, what is uncertain, and what can be revealed.

### Art And Asset Pipeline

- Keep source PNGs unmodified in `modernerKrieg/assets/mosul/source/`.
- Generate runtime sprites, atlases, map tiles, collision masks, and metadata outside the source folder.
- Use the 128 px sprite sheets and source-angle weapon sprites as the first tactical art source.
- Use the Market / Commercial Streets overview and map layers as the first map source.
- Document pivot points, facing names, tile size, map scale, and allowed generated outputs.

### Engine Integration

- Keep runtime PNG loading, manifests, and metadata ownership in `modernerKrieg`.
- Use the `mosul` C bridge to expose scenario state, map paths, score, units, civilians, objectives, contacts, selection, and order commands to Swift.
- Render the real runtime map overview before investing in tiled streaming.
- Render real unit sprites after the bridge exposes sprite manifest/runtime ids cleanly enough for SwiftUI.
- Keep tactical rules in the portable C core, with rendering as a view over game state.
- Add deterministic tests for any new scenario-data parser and combat rule.

### Gameplay Systems

- Finish a small order set: move, hold, fire, suppress, overwatch, breach/search, rally, and withdraw.
- Add civilian-risk scoring before heavy weapons become useful.
- Add hidden contact/reveal logic.
- Add rooftop/upper-floor access as a simple but visible tactical difference.
- Add casualty, wounded, dead, and suppression state display.
- Add a basic opposing AI for defend, ambush, displace, and flee.

### Build And Release

- Keep `modernerKrieg` headless tests runnable without any native app dependency.
- Keep `Mosul.xcodeproj` buildable from the repository root.
- Package one macOS-first SwiftUI demo before broadening to Windows.
- Keep all PNG assets and loaders in `modernerKrieg`; do not copy runtime art into the Mac app tree unless packaging explicitly requires a generated bundle step.

## Additional Art Needed

The imported art is enough to start development. The likely missing public-demo assets are narrow and can be planned while implementation begins:

- civilian/non-combatant top-down sprites
- custom PNG marker art for selection, order, route, objective, suppression, casualty, and hidden-contact states if the current SwiftUI markers are not enough
- rooftop, stair, breach, search/cache, checkpoint, and suspected-danger markers
- engine-ready map tiles at the chosen demo zoom levels
- collision/pathfinding masks for roads, interiors, rooftops, rubble, blocked routes, and upper-floor access
- small UI icons for orders and unit states

Do not pause engine development for a large new art pass. Add these assets only when a playable slice needs them.

## Immediate Next Steps

1. Done 2026-06-08: Replace the first SwiftUI unit markers with sprite-manifest driven runtime PNG drawing.
2. Done 2026-06-08: Add visible order, selection, route, suppression, casualty, objective, and hidden-contact markers in the Mac app.
3. Done 2026-06-08: Expose sprite/marker manifest ids through the bridge only where the Mac app needs them.
4. Done 2026-06-08: Add player-facing after-action results from the existing C score/outcome data.
5. Done 2026-06-08: Deepen breach/search/cache/rooftop interactions in the C core, then surface only their controls and overlays in SwiftUI.
   - Active detail 2026-06-08: Expose C-core breach/search/cache/rooftop interaction points through the bridge as map overlays and selected-unit controls.
6. Done 2026-06-08: Add a repeatable Mac app smoke path in addition to the existing headless CTest coverage.
   - Active detail 2026-06-08: Add a root Mac smoke script and CI workflow that build the native Mosul and AIBattle app bundles through Xcode.
7. Done 2026-06-08: Keep README, `PLAN.md`, and `Mac/README.md` aligned whenever the frontend/core boundary changes.
   - Active detail 2026-06-08: Keep the documented frontend/core boundary current after the Mac smoke path and interaction-control changes.
8. Done 2026-06-08: Use `snapshot` captures as visual regression evidence when sprite-driven unit rendering and civilian state art replace the current symbolic overlays.
   - Active detail 2026-06-08: Capture repeatable tactical-map PNG evidence for the current sprite/interaction/civilian overlay state and document how to use it in visual checks.
9. Done 2026-06-08: Use AIBattle to tune AI pacing, result criteria, civilian-risk visibility, and battle-state readability before moving the same visualization improvements into the player-facing Mosul app.
   - Active detail 2026-06-08: Run and inspect repeatable AIBattle evidence to identify the first readability and pacing tuning target.
10. Done 2026-06-08: Improve civilian-risk readability where risk rings overlap contact, objective, and unit markers in the shared tactical map.
   - Active detail 2026-06-08: Apply the first AIBattle evidence target by making civilian risk easier to scan during active contact without hiding tactical markers.
11. Active: Keep edge labels and dense contact stacks inside the shared tactical-map frame.
   - Active detail 2026-06-08: Use the latest AIBattle evidence to clamp right-edge marker labels and reduce dense contact stack clipping before broader AI/play tuning.
