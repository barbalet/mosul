# MosulGame Release Budget And Error Evidence

This note records the cycle 15 and 16 release checks for the standalone
MosulGame app. Both checks run against a built `.app` bundle and write ignored
evidence under `snapshots/evidence/`.

## Performance Budget

Run:

```sh
scripts/check_mosulgame_performance_budget.sh
```

The script builds `MosulGame.app` in Release configuration, launches the app
with `--performance-budget --require-bundled-runtime`, and writes:

```text
snapshots/evidence/mosul-performance-budget.txt
```

The app-side probe measures:

- app-side startup-to-probe time, plus wrapper-measured external launch/probe
  wall time
- model/runtime load time
- sprite manifest resolution time
- first tactical-map render time
- total probe time
- resident memory
- runtime map PNG count, total encoded size, and largest encoded PNG
- tactical-map image-cache load count and missing-image count

Current budget ceilings are intentionally generous release gates rather than
final optimization targets:

```text
launch_to_probe_ms <= 5000
external_launch_probe_ms <= 9000
model_load_ms <= 2500
sprite_resolve_ms <= 1500
first_map_render_ms <= 5000
total_probe_ms <= 9000
resident_memory_mb <= 768
map_png_total_mb <= 64
largest_map_png_mb <= 32
```

The tactical map now uses a shared path-based `NSImage` cache so repeated
SwiftUI view updates do not reopen the same map or sprite PNGs. The first-render
probe resets that cache immediately before rendering, which keeps the report
tied to a cold tactical-map frame.

## Release Error Handling

Run:

```sh
scripts/check_mosulgame_release_errors.sh
```

The script builds `MosulGame.app` in Release configuration, verifies an intact
runtime check, copies the app to a temporary location, removes the bundled
scenario file from the copy, then launches the broken copy with
`--check-runtime-resources --require-bundled-runtime`.

The broken app must write a structured failure report with:

- `ok=false`
- a player-facing title
- a player-facing message
- a recovery action
- a diagnostic string for developer/support logs

The consolidated evidence report is:

```text
snapshots/evidence/mosul-release-errors.txt
```

The player-facing app window uses the same release issue model, so missing
runtime data now blocks play with a concise error panel instead of leaving the
app in a half-loaded tactical shell.
