# MosulGame Accessibility And Release Candidate Evidence

This note records the cycle 17 and 18 standalone-release checks for the
player-facing `MosulGame.app`.

## Accessibility And Minimum Window

Run:

```sh
scripts/check_mosulgame_accessibility_ui.sh
```

The script builds `MosulGame.app`, captures a deterministic player-path
evidence image at the release minimum size, and writes:

```text
snapshots/evidence/mosul-accessibility-ui.png
snapshots/evidence/mosul-accessibility-ui.txt
```

Current minimum-window evidence size:

```text
width=980
height=680
```

The script also counts SwiftUI accessibility and keyboard affordances under
`Mac/Mosul/App/` and fails below these guardrails:

```text
accessibility_modifiers >= 18
keyboard_shortcuts >= 8
```

The current app shell uses a compact map-over-inspector layout below the wide
desktop breakpoint, keeps command controls horizontally scrollable at tight
widths, exposes VoiceOver labels and hints for the command bar, side selection,
inspector panels, map controls, units, contacts, and tasks, and lowers the app
minimum window to `980x680`.

## Release Candidate Bundles

Run:

```sh
scripts/build_mosulgame_release_candidate.sh
```

The script builds Release configuration candidates for:

```text
arm64
x86_64
```

By default it writes architecture-specific app bundles while keeping the bundle
itself named `MosulGame.app`:

```text
dist/release-candidate/arm64/MosulGame.app
dist/release-candidate/x86_64/MosulGame.app
snapshots/evidence/mosul-release-candidate.txt
```

Each candidate is validated with:

- bundled runtime resource inventory checks
- ad-hoc signing, unless `--skip-sign` is passed
- `codesign --verify --deep --strict`
- `lipo -archs` against the requested architecture

Use `--arch`, `--configuration`, `--derived-data-root`, `--dist-root`,
`--report`, `--version`, `--skip-sign`, and `--replace` for local variants.
The default command is the release-candidate gate before the later DMG packaging
cycle.
