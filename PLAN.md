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
- Completed: Step 11 - Keep edge labels and dense contact stacks inside the shared tactical-map frame.
- Completed: Step 12 - Tune AIBattle pacing and result criteria using the repeatable evidence report.
- Completed: Step 13 - Expose and render `modernerKrieg` building-level alpha overlays in the shared tactical map.
- Completed: Step 14 - Add level-aware unit, contact, and interaction context to the Mac UI.
- Completed: Step 15 - Add player-facing fog-of-war and side-perspective outcome context to MosulGame.
- Completed: Step 16 - Add scripted outcome-band and AI balance-sweep evidence for the playable release loop.
- Completed: Step 17 - Establish the standalone performance budget for launch, first render, memory, and map/sprite loading.
- Completed: Step 18 - Add release-quality missing-runtime and diagnostic error handling for broken standalone app bundles.
- Completed: Step 19 - Review accessibility, UI polish, and minimum-window behavior for the playable standalone app.
- Completed: Step 20 - Add release-candidate Apple Silicon and Intel app bundle builds with architecture verification.
- Active: Step 21 - Automate DMG packaging for the verified release-candidate app bundles.
- Active detail: Start cycle 19 with stable DMG volume names, app bundle placement, checksums, and overwrite-safe `dist/` behavior.
- Last advanced: 2026-06-13

## Standalone Release Build Plan

Estimate: 24 development cycles from the current repo-playable MosulGame state
to a polished standalone macOS release build. A rough release candidate can
exist after cycle 18 if the bundled app launches, plays the full scenario, and
passes automated smoke checks outside the source checkout. Cycles 19-24 are the
polish, signing, distribution, and release-hardening pass that make it feel
safe to hand to external testers.

A cycle here means one focused implementation-and-verification loop that leaves
the repository buildable. Some cycles can overlap, but each should land with
tests, scripts, or release artifacts updated in the same change.

Current standalone release cycle: cycle 19, DMG packaging.
Completed standalone release cycles: cycles 1-18 on 2026-06-13.

### Standalone Release Definition

The standalone build is done when:

- `MosulGame.app` launches from Finder, `/Applications`, and a mounted DMG
  without a `mosul` source checkout beside it.
- All runtime scenario files, manifests, map PNGs, sprite PNGs, marker data,
  and required `modernerKrieg` metadata are inside the app bundle under
  `Contents/Resources`.
- The app resolves resources through `Bundle.main.resourceURL` first, and uses
  the repo checkout only as a development fallback.
- A fresh user can choose a side, select units, issue orders, run opponent AI,
  resolve breach/search/rooftop/cache interactions, and reach an after-action
  result without using developer scripts.
- Snapshot/evidence capture works in scripted evidence mode and cannot hang
  CI indefinitely.
- macOS release builds exist for Apple Silicon and Intel, are signed
  ad-hoc for local testing, and have a documented Developer ID/notarization
  path for public distribution.
- CI validates portable C tests, native Mac builds, bundled-resource integrity,
  launch smoke, snapshot evidence, and release packaging scripts.
- `RELEASE.md` can be followed from a clean checkout to produce verified DMGs
  and a populated source archive.

### Release Cycles

| Cycle | Status | Theme | Technical Work | Exit Criteria |
| --- | --- | --- | --- | --- |
| 1 | completed 2026-06-12 | Release scope lock | Define the exact public-demo scenario, supported macOS versions, target architectures, and whether the first public name remains `MosulGame` or ships as display-name `MOSUL`. | `PLAN.md` and `RELEASE.md` agree on product name, versioning, scope, and supported platforms. |
| 2 | completed 2026-06-12 | Resource inventory | Generate an explicit list of runtime assets needed by MosulGame: scenario files, map manifests, building-level/topology manifests, map PNGs, sprite manifests, rendered sprites, marker manifests, and any README/evidence assets used at runtime. | `release/mosulgame_runtime_resources.json` and `scripts/check_mosulgame_runtime_resources.py` validate the current runtime payload. |
| 3 | completed 2026-06-12 | Bundle layout | Add a deterministic app-resource layout under `Contents/Resources/mosul-runtime/` without copying source art into `Mac/`. Prefer an Xcode build phase or script that copies from `modernerKrieg` at build time. | `scripts/copy_mosulgame_runtime_resources.py` and the `MosulGame` Xcode build phase copy 1,101 runtime files into `Contents/Resources/mosul-runtime/modernerKrieg` while excluding source art, build outputs, snapshots, and candidate/provenance folders. |
| 4 | completed 2026-06-12 | Runtime root resolver | Change `MosulGameModel.findModernerKriegRoot` and `MosulSpriteManifest` usage into a resource resolver that checks the bundled runtime first, then falls back to the source checkout for development. | `MosulRuntimeResources` resolves bundled runtime data first; a copied Release app under `/private/tmp` exits cleanly through `--check-runtime-resources`, and the headless runner loads the bundled scenario from that copied app root. |
| 5 | completed 2026-06-12 | Bridge path contract | Update `MosulEngineCreate`/bridge naming if needed so the C bridge accepts a runtime asset root, not necessarily a `modernerKrieg` repository root. | `MosulEngineCreate` now accepts a `runtime_asset_root`, the bridge stores `runtime_asset_root`, validates the scenario/map/marker runtime contract directly, and the Swift model passes `runtimeAssetRoot` from `MosulRuntimeResources`. |
| 6 | completed 2026-06-12 | Bundled-resource tests | Add a script or C/Swift smoke that validates the built `.app` contains every resource referenced by the scenario, manifests, and sprite render manifest. | `scripts/check_mosulgame_runtime_resources.py --app <MosulGame.app>` verifies the built bundle's `mosul-runtime` payload, and `scripts/run_mac_smoke.sh` runs that check in CI after building MosulGame. |
| 7 | completed 2026-06-12 | Launch smoke outside repo | Add a Mac smoke step that copies `MosulGame.app` to a temporary directory, launches it or its evidence mode from there, and verifies no source-checkout path is required. | `scripts/run_mac_smoke.sh` copies `MosulGame.app` with `ditto`, validates the copied app payload, launches it through `open -W -n` with `--check-runtime-resources --require-bundled-runtime`, and verifies the copied app wrote a bundled-runtime check stamp. |
| 8 | completed 2026-06-12 | Snapshot hang fix | Fix the current snapshot evidence hang by making command-line capture complete deterministically, report errors, and exit under a watchdog. | `scripts/capture_snapshot_evidence.sh` validates the built app payload, removes stale output before capture, launches snapshot evidence through `open -W -n`, requires bundled runtime resources, writes a PNG, and returns nonzero on timeout or renderer failure. |
| 9 | completed 2026-06-12 | Evidence parity | Extend snapshot evidence to cover side selection, one selected unit, one move/investigate order, visible upper-floor overlay state, and after-action text presence. | `scripts/capture_snapshot_evidence.sh` now stages a player path through side selection, selected command unit, configurable move/investigate order, visible upper-floor overlays, player-state evidence rendering, and a `.txt` report that must include `ok=true`. |
| 10 | completed 2026-06-12 | Player onboarding | Replace developer-first launch state with a compact first-run flow: scenario title, side choice, objective summary, and clear start controls. | The first-run overlay now presents `MOSUL`, the scenario name, location/year, objective counts, scenario objectives, U.S. scoring context, and clear icon-backed `Start U.S. Patrol` / `Start Opposing Cell` controls. |
| 11 | completed 2026-06-12 | Command ergonomics | Polish selection, move/investigate mode, disabled command states, interaction buttons, and feedback notices so commands feel intentional and recoverable. | Segmented map-mode changes now route through command validation, icon-backed order/task controls expose disabled states, player notices report select/move/investigate/hold/overwatch/rally/breach/search/reset feedback, and `docs/mosulgame_manual_smoke.md` covers the manual smoke path. |
| 12 | completed 2026-06-12 | Fog of war and side context | Finish Step 15: hide or soften enemy state based on chosen side and label U.S.-perspective scoring separately from chosen-side command context. | MosulGame now renders player-visible units and contact reports by chosen side, hides unconfirmed opposing units, redacts opposing order/strength/suppression/route details, and labels score/after-action panels as U.S.-perspective context separate from the command side. |
| 13 | completed 2026-06-13 | Scenario completion loop | Ensure a full manual-vs-AI playthrough can produce win/partial/failure outcomes with understandable after-action narratives. | `scripts/check_mosulgame_outcome_bands.py` builds the headless tools, runs deterministic scripted success/partial/failure playthroughs, verifies after-action narratives and replay end events, and writes `snapshots/evidence/mosul-outcome-bands.txt`. |
| 14 | completed 2026-06-13 | Balance and pacing pass | Use AIBattle and headless seed sweeps to tune tick pacing, contact pressure, civilian-risk penalties, and partial-result thresholds for a short public demo. | `scripts/check_mosulgame_balance_sweep.py` runs a five-seed public-demo AI sweep, fails on stalls, weak score floor, weak contact/risk pressure, or early trivial settlement, and writes `snapshots/evidence/mosul-balance-sweep.txt`. |
| 15 | completed 2026-06-13 | Performance budget | Measure app launch time, first map render time, memory footprint, sprite loading, and large PNG behavior. Add lazy loading or image caching only where measurements require it. | `scripts/check_mosulgame_performance_budget.sh` builds the Release app, launches the bundled-runtime performance mode, verifies launch/model/sprite/first-render/total/memory/map-PNG budgets, uses the shared tactical-map image cache for repeated PNG access, and writes `snapshots/evidence/mosul-performance-budget.txt`. |
| 16 | completed 2026-06-13 | Error handling | Replace source-tree/developer error messages with release-quality missing-resource, unsupported-platform, and scenario-load messages. | `scripts/check_mosulgame_release_errors.sh` verifies an intact Release app runtime check, breaks a copied app bundle by removing the bundled scenario, requires a structured `ok=false` report with player-facing title/message/recovery plus diagnostics, and writes `snapshots/evidence/mosul-release-errors.txt`. |
| 17 | completed 2026-06-13 | Accessibility and UI polish | Review labels, contrast, keyboard focus, button naming, scrolling panels, resizable window behavior, and map controls. | MosulGame now uses a responsive wide/compact layout with a `980x680` minimum window, keyboard shortcuts for core commands, VoiceOver labels/hints for the command bar, side selection, inspector, map controls, units, contacts, and tasks, and `scripts/check_mosulgame_accessibility_ui.sh` captures minimum-window evidence plus accessibility/shortcut guardrails. |
| 18 | completed 2026-06-13 | Release candidate build script | Add or update a release script that builds Apple Silicon and Intel app bundles from a clean checkout with bundled resources and ad-hoc signing. | `scripts/build_mosulgame_release_candidate.sh` builds Release `arm64` and `x86_64` app bundles under `dist/release-candidate/<arch>/MosulGame.app`, validates bundled resources, ad-hoc signs by default, verifies signatures, and records `lipo` architecture checks in `snapshots/evidence/mosul-release-candidate.txt`. |
| 19 | next | DMG packaging | Automate DMG creation with stable volume names, app bundle placement, checksum output, and overwrite-safe `dist/` behavior. | `dist/` contains reproducible Apple Silicon and Intel DMGs plus SHA-256 sums. |
| 20 | pending | Developer ID and notarization | Keep ad-hoc signing available, but document and optionally script Developer ID signing, notary submission, stapling, and verification. | `RELEASE.md` can be followed for both local unsigned testing and public notarized release. |
| 21 | pending | CI release dry run | Add a non-secret CI dry run that builds release configuration, validates bundled resources, and packages unsigned artifacts without notarization. | Pull requests prove release packaging stays healthy. |
| 22 | pending | Clean-machine QA | Test the app from a fresh checkout, from outside the checkout, from a DMG, and after moving to `/Applications`; include at least one Intel or Rosetta check if hardware is unavailable. | QA notes record exact OS, architecture, app path, and pass/fail evidence. |
| 23 | pending | Release docs and support | Update README, Mac README, RELEASE, troubleshooting, known limitations, source archive instructions, and tester handoff notes. | External testers know how to install, launch, report issues, and understand current demo limitations. |
| 24 | pending | Final release freeze | Tag the source, lock the `modernerKrieg` submodule revision, regenerate artifacts, verify checksums, write release notes, and archive evidence. | A GitHub release can be published with DMGs, source zip, checksums, release notes, and known-limitations list. |

### Technical Risk List

- The bundle-first runtime resolver, copy phase, and strict runtime check are in
  place; later release cycles still need Finder, `/Applications`, and DMG QA.
- `MosulGame.xcodeproj` now has a runtime-copy build phase, bundle-resource
  validation, and copied-app LaunchServices smoke coverage in the Mac smoke path.
- Snapshot evidence now uses a watchdog, strict bundled-runtime validation,
  player-state evidence rendering, and a report that validates player-facing
  state.
- Scripted outcome-band and balance-sweep checks now cover current result
  narratives and AI pacing pressure.
- The Release app now has first-render performance, broken-bundle error,
  accessibility/minimum-window, and architecture-specific release-candidate
  checks; later cycles still need DMG packaging, Developer ID signing,
  notarization, and clean-machine QA.
- Release packaging currently assumes the submodule source archive is attached,
  but the app bundle itself still needs its own curated runtime payload.

## Soundscape Development Plan

Estimate: 8 additional development cycles for a release-safe first audio pass.
This is a playability and atmosphere track that can run after, or in parallel
with, the remaining standalone release cycles once packaging stays stable. The
technical specification lives in `docs/mosulgame_soundscape.md`.

The first sound task is deliberately mute-first: MosulGame must expose an
always-reachable main-window speaker control before ambience, radio, speech, or
weapon layers become release defaults.

Current soundscape cycle: complete; all planned first-pass soundscape cycles are done.
Completed soundscape cycles: S1-S8 on 2026-06-14.

### Soundscape Definition

The first public soundscape is done when:

- The command header exposes a speaker icon that immediately mutes every audio
  bus, persists across relaunch, has `Command-Shift-M`, and reports clear
  VoiceOver state.
- Evidence, runtime-resource, performance, and release-check modes can launch
  with audio disabled so CI is deterministic and silent.
- Runtime audio assets live under the curated `modernerKrieg` runtime payload
  and are copied into `Contents/Resources/mosul-runtime/` with the maps,
  manifests, sprites, and markers.
- An audio manifest records every sound id, bus, file path, license,
  attribution, source URL, transcript/locale where relevant, duration, loop
  metadata, and loudness target.
- The app has a small `AVAudioEngine` layer with master, ambience, tactical,
  radio, and UI buses.
- Gameplay-critical audio is driven by structured state/events, not by parsing
  player-facing strings.
- Ambient city, engine, Iraqi civilian murmur, U.S. radio, contact, fire,
  objective, and civilian-risk cues all have visual or textual equivalents.
- Fog of war is respected: sound never reveals hidden units or precise hostile
  locations that the selected side cannot see.
- The shipped asset set uses release-compatible rights only: original work,
  commissioned work, CC0, CC BY with attribution, or audited public-domain U.S.
  Government material.

### Soundscape Cycles

| Cycle | Status | Theme | Technical Work | Exit Criteria |
| --- | --- | --- | --- | --- |
| S1 | completed 2026-06-14 | Mute-first audio foundation | Added `MosulAudioController`, `MosulAudioSettings`, a header/overlay speaker toggle, persisted mute/master volume, `Command-Shift-M`, and `--disable-audio`. Playback remains silent/no-op until the mixer cycle adds a graph. | Main-window mute is always reachable, persists across relaunch, silences immediately, and smoke/evidence/performance/runtime-check launches can disable audio. |
| S2 | completed 2026-06-14 | Runtime audio manifest | Added `modernerKrieg/assets/mosul/audio/`, `mosul_audio_manifest.json`, an audio credits document, and audio manifest/license/path/format validation in the runtime-resource script. | Missing audio files, unapproved licenses, absent attribution, unsafe paths, unsupported extensions, and invalid WAV sample properties fail validation before release packaging. |
| S3 | completed 2026-06-14 | Mixer and loop engine | Built the `AVAudioEngine` graph with master, ambience, tactical, radio, and UI mixers; load loops from the manifest; added safe configure/start/stop, mute/unmute, volume, and ambience-ducking behavior. | The bundled app audio smoke can configure, mute, unmute, report context, and quit without requiring speaker output. |
| S4 | completed 2026-06-14 | Structured audio events | Added `MosulAudioEvent` and `MosulAudioContext`; emit events for side start, selection, order arm/place, tick, contact reveal, fire, blocked LOS, civilian risk, objective, and after-action. | Snapshot and accessibility smoke reports verify expected audio events textually without requiring speakers. |
| S5 | completed 2026-06-14 | Tactical feedback pass | Mapped structured gameplay events to restrained generated one-shots for order arm/confirm, invalid command, tick, movement, contact reveal, route/LOS blocked, fire resolved, objective, and civilian-risk warning. | Audio smoke probes representative event families, snapshot evidence keeps visual/text parity through player notices and reports, and invalid/blocked actions now produce structured feedback events. |
| S6 | completed 2026-06-14 | Ambient city and engines | Added original low/high city, generator, and distant-engine loops; connected zoom, tension, visible movement, and traffic movement into bus and loop mixing; added movement/transit accents. | The bundled app loads 14 manifest assets, starts 4 low-volume ambience loops in playable context, changes mix from zoom/tension/movement context, and avoids hidden hostile positional audio. |
| S7 | completed 2026-06-14 | Speech and radio | Added original non-lexical civilian murmur beds and sparse U.S. radio cue assets with transcripts, visible captions, cooldowns, review metadata, and credits. | Speech/radio improves place and command clarity without fake Arabic, unreviewed language, repetition spam, or sound-only gameplay requirements. |
| S8 | completed 2026-06-14 | Audio QA and release hardening | Added audio release evidence reporting, stricter manifest validation for transcripts/captions/review status/credits/size budget, release checklist entries, and app-bundle audio smoke assertions. | Source and built-app audio reports pass; muted mode, disabled-audio launch, bundled-runtime playback, radio captions, and accessibility evidence are covered by repeatable checks. |

## Current Public Baseline

- The public README describes the 2003 Market / Commercial Streets demo direction and the Mac/frontend split.
- `MosulGame.xcodeproj` builds the player-facing Mac game shell with an opening choice to command either the U.S. patrol or the opposing armed cell.
- `AIBattle.xcodeproj` builds a standalone Mac AI-vs-AI autoplay shell that reuses the Mosul model, tactical view, bridge, and C core sources.
- `Mac/Mosul/App/` contains the SwiftUI presentation, map view, controls, and inspector.
- `Mac/Mosul/Bridge/` contains a small C bridge over the `modernerKrieg` headers.
- Public presentation art exists under `assets/readme/`.
- The `modernerKrieg` engine submodule builds as a portable C/CMake project and remains the owner of gameplay, data loading, AI, runtime PNG assets, and validation tools.
- The engine has deterministic coverage for core rules, board projection, scenario loading, asset manifests, AI/autoplay, replay validation, balance checks, and the core/frontend boundary.
- Source art and generated runtime art for the 2003 demo exist under `modernerKrieg/assets/mosul/`.
- `modernerKrieg` now carries runtime building-level PNGs, alpha overlays, and multistorey mask metadata for the Market / Commercial Streets map.
- The SDL path is retired; new launchable interfaces should be platform-native shells over the portable C core.
- The codenamed `snapshot` Mac test path can write timestamped local PNG captures of the current tactical-map render under ignored `snapshots/` output.
- `scripts/run_mac_smoke.sh` and `.github/workflows/mac-app-smoke.yml` provide a repeatable native Mac smoke path that builds the MosulGame and AIBattle app bundles through Xcode.
- `MosulGame.xcodeproj` now copies a curated runtime payload into `Contents/Resources/mosul-runtime/modernerKrieg` during app builds.
- MosulGame resolves bundled runtime resources before falling back to the source checkout, and has a `--check-runtime-resources` app argument for LaunchServices-based bundle checks.
- MosulGame has a mute-first soundscape foundation with an `AVAudioEngine` master/ambience/tactical/radio/UI mixer graph, continuous true-loop ambience from app launch, source-level ambience loudness guards, persisted mute/volume state, a command-key mute shortcut, and a `--disable-audio` deterministic launch path.
- `scripts/check_mosulgame_audio_smoke.sh` verifies the bundled app audio controller can configure, mute, unmute, report context, play representative cues, expose radio captions, and quit; snapshot/accessibility evidence now records structured audio events.
- The soundscape runtime now includes 23 original generated/procedural WAV assets: 10 tactical/UI one-shots, 6 ambience/murmur loops, and 7 sparse radio voice cues, all listed in the bundled audio manifest and credits.
- Gameplay events now trigger restrained cue playback for orders, invalid commands, route/LOS blocks, ticks, movement, contacts, fire, objectives, civilian risk, and sparse radio acknowledgements; ambience mix responds to zoom, tension, visible unit movement, and traffic movement without revealing hidden enemies.
- `scripts/write_mosulgame_audio_report.py` produces release evidence for manifest counts, speech transcripts/captions, review metadata, credits coverage, missing files, and the configured audio byte budget from either source assets or a built app bundle.
- MosulGame can require bundled runtime resources with `--require-bundled-runtime` and write a `--runtime-check-output` stamp for deterministic launch-smoke verification.
- The Mosul C bridge now treats its creation argument as a runtime asset root and validates required scenario/map/marker runtime files before loading the game.
- `scripts/check_mosulgame_runtime_resources.py --app <MosulGame.app>` validates the built MosulGame app bundle's runtime payload, and the Mac smoke script runs that check in CI for both the built app and a copied app outside the checkout.
- MosulGame now has a mute-first audio foundation with a main-window speaker
  control, persisted master volume, `Command-Shift-M`, and `--disable-audio`
  support for silent automation.
- `modernerKrieg/assets/mosul/audio/` now contains a bundled audio manifest and
  credits file, and the runtime-resource validator checks future audio assets
  for release-approved licenses, safe paths, supported formats, and WAV sample
  properties before packaging.
- MosulGame gates manual orders to the selected human side and can run deterministic opponent-only AI ticks through the shared C bridge.
- MosulGame now validates map-mode changes against the selected command unit,
  reports concise command feedback notices, and has a manual smoke checklist in
  `docs/mosulgame_manual_smoke.md`.
- MosulGame now filters map and inspector state through the chosen side:
  unconfirmed opposing units are hidden, visible opposing elements are shown as
  intel contacts, and U.S.-perspective scoring is labeled separately from
  command context.
- `scripts/check_mosulgame_outcome_bands.py` verifies success, partial, and
  failure after-action bands with transcript and replay evidence under
  ignored `snapshots/evidence/` output.
- `scripts/check_mosulgame_balance_sweep.py` runs the five-seed public-demo AI
  pacing sweep with stall, score-floor, contact-pressure, risk-pressure, and
  early-settlement guards.
- `scripts/check_mosulgame_performance_budget.sh` builds the Release
  MosulGame app, requires bundled runtime resources, measures first tactical-map
  render performance and memory, and writes ignored budget evidence.
- `scripts/check_mosulgame_release_errors.sh` verifies that a deliberately
  broken copied app bundle reports player-facing recovery text and
  diagnostic report evidence.
- `scripts/check_mosulgame_accessibility_ui.sh` builds MosulGame, captures
  `980x680` minimum-window evidence, and enforces keyboard/VoiceOver modifier
  guardrails in the SwiftUI shell.
- `scripts/build_mosulgame_release_candidate.sh` builds ad-hoc signed Release
  candidates for Apple Silicon and Intel under
  `dist/release-candidate/<arch>/MosulGame.app`, validates bundled resources,
  and verifies each executable architecture with `lipo`.
- `scripts/capture_snapshot_evidence.sh` builds MosulGame, validates the app bundle payload, runs a deterministic player-path LaunchServices app launch under a timeout watchdog, and writes ignored PNG plus text-report evidence under `snapshots/evidence/`.
- MosulGame's first-run overlay now frames the Market / Commercial Streets scenario with side choice, objective summary, U.S.-perspective scoring context, and clear start controls before enabling the tactical map.
- `scripts/capture_aibattle_evidence.sh` builds AIBattle, runs a deterministic evidence-only app launch, and writes ignored pacing/readability evidence plus a tuning report under `snapshots/evidence/`.
- `scripts/capture_aibattle_movie.sh` builds AIBattle, runs a deterministic movie-only app launch, and writes ignored full-battle MOV captures plus a final tuning report under `snapshots/evidence/`.
- The shared Mac tactical map now resolves unit glyphs through `modernerKrieg`'s runtime sprite manifest and draws runtime PNG sprites in both Mosul and AIBattle.
- The shared Mac tactical map now shows order, selection, route destination, suppression, casualty, objective, civilian-risk, hidden/contact, and breach/search/cache/rooftop interaction markers over the runtime sprites.
- The shared Mac tactical map now draws civilian-risk as a dedicated underlay with stronger high-risk emphasis so civilians stay visible during contact/objective overlap.
- The shared Mac tactical map now uses edge-aware objective/unit labels and clustered contact offsets so dense markers stay inside the rendered map frame.
- The shared Mac tactical map now renders `modernerKrieg`'s runtime ground-level PNG plus upper-floor and roof-access alpha overlays with compact per-level toggles.
- The shared Mac tactical map now labels selected-unit, contact, and interaction levels, distinguishes vertical interaction routes from same-level tasks, and auto-shows tactical map overlays referenced by selected units, vertical routes, unresolved contacts, or actionable interactions.
- The C bridge now exposes the sprite and marker manifest ids the Mac map needs, unit/civilian sprite ids, unit/contact/interaction gameplay level IDs, validated tactical marker ids, breach/search/cache/rooftop interaction summaries, and selected-unit interaction commands.
- The Mosul inspector now shows a player-facing after-action panel backed by the C core's score, outcome, summary, narrative, and score-component data, plus selected-unit interaction controls.
- AIBattle now shows a compact tuning panel for pacing, risk, result criteria, contacts, interactions, and the first evidence-driven readability target.
- AIBattle now delays raw partial outcomes until the configured settling tick, labels high-pressure partials separately, and writes result-pressure plus partial-settlement fields into its evidence report.

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
- Keep `MosulGame.xcodeproj` buildable from the repository root.
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
11. Done 2026-06-08: Keep edge labels and dense contact stacks inside the shared tactical-map frame.
   - Active detail 2026-06-08: Use the latest AIBattle evidence to clamp right-edge marker labels and reduce dense contact stack clipping before broader AI/play tuning.
12. Done 2026-06-08: Tune AIBattle pacing and result criteria using the repeatable evidence report.
   - Active detail 2026-06-08: Use the latest AIBattle report to adjust autoplay pacing, unresolved-contact pressure, and partial-win criteria now that map readability blockers are reduced.
13. Done 2026-06-08: Expose and render `modernerKrieg` building-level alpha overlays in the shared tactical map.
   - Active detail 2026-06-08: Use the updated `modernerKrieg` runtime level PNGs and multistorey mask metadata to add level-aware map overlays/toggles through the bridge without copying assets into the Mac tree.
14. Done 2026-06-08: Add level-aware unit, contact, and interaction context to the Mac UI.
   - Active detail 2026-06-08: Use the C-core gameplay level IDs to label selected units, emphasize same-level versus vertical interactions, and tie the new upper-floor overlays to tactical state instead of visual toggles only.
15. Done 2026-06-13: Add player-facing fog-of-war and side-perspective outcome context to MosulGame.
   - Done detail 2026-06-13: Hide or soften information the selected side should not know, separate commandable units from observed enemy state, and clarify whether the after-action result is being scored from the U.S. stabilization perspective or the chosen side's perspective.
16. Done 2026-06-13: Add scripted outcome-band and AI balance-sweep evidence for the playable release loop.
17. Done 2026-06-13: Establish the standalone performance budget for launch, first render, memory, and map/sprite loading.
18. Done 2026-06-13: Add release-quality missing-runtime and diagnostic error handling for broken standalone app bundles.
19. Done 2026-06-13: Review accessibility, UI polish, and minimum-window behavior for the playable standalone app.
20. Done 2026-06-13: Add release-candidate Apple Silicon and Intel app bundle builds with architecture verification.
21. Active: Automate DMG packaging for the verified release-candidate app bundles.
   - Active detail 2026-06-13: Add stable DMG volume names, app bundle placement, checksum output, and overwrite-safe `dist/` behavior.
