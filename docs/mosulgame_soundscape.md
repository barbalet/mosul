# MosulGame Soundscape Technical Plan

This document defines the intended audio design and implementation path for
MosulGame. The soundscape should make the battle map easier to read, not just
more atmospheric. Every important sound cue must have a visual or textual
equivalent so the game remains playable with sound muted.

## Design Goals

- Support tactical understanding: movement, contact, fire, civilian risk, and
  time passing should become easier to follow.
- Keep the city present without turning ambient Iraqi voices into a hostile
  signal. Civilian speech is human context, not an enemy detector.
- Use U.S. radio voice sparingly as command feedback, not a constant narrator.
- Make silence immediate from the main window. A visible mute button is a
  release requirement, not a settings nice-to-have.
- Keep the portable C engine authoritative for game state. Swift can own audio
  presentation, but it should consume structured events rather than infer
  meaning from display strings.
- Keep all runtime audio assets under the curated `modernerKrieg` runtime
  payload so release packaging, license checks, and app-bundle validation stay
  deterministic.

## Player-Facing Audio Model

The soundscape has five buses:

| Bus | Purpose | Examples | Muted By Master |
| --- | --- | --- | --- |
| Master | User-facing final output and mute state | All game sound | Yes |
| Ambience | Continuous city and terrain bed | street wash, generators, distant vehicles, room tone | Yes |
| Tactical | Short game-state cues | contact reveal, route set, blocked path, civilian risk, casualties | Yes |
| Radio | U.S. procedural callouts | move acknowledged, contact reported, no line of sight, civilians close | Yes |
| UI | Interface-only feedback | button confirm, invalid command, snapshot saved | Yes |

Initial release should expose one main-window mute toggle and one master volume
control. Category sliders can come later if real playtesting shows they are
needed.

## Critical Mute Requirement

The main window must always provide a speaker icon control:

- Location: command header near `Step`, `Opponent Tick`, and `Reset`.
- Icons: `speaker.wave.2.fill` when audible, `speaker.slash.fill` when muted.
- Shortcut: `Command-Shift-M`.
- Persistence: `@AppStorage("mosul.sound.muted")` and
  `@AppStorage("mosul.sound.masterVolume")`.
- Behavior: mute must silence all buses immediately without waiting for loops
  to finish.
- First-run overlays: if ambience begins before side selection, the same mute
  affordance must also be visible in the onboarding/side-selection overlay.
- Automation: evidence, runtime checks, and performance checks should pass a
  launch argument such as `--disable-audio` so CI never depends on audio output.
- Accessibility: the control needs VoiceOver label, hint, and current value:
  "Sound muted" or "Sound on, 55 percent volume".

Implementation should prefer setting the master mixer output to zero while
keeping the engine graph alive. Stopping and rebuilding the audio graph on every
mute creates more failure modes and can clip ongoing samples.

## Technical Architecture

### Swift App Layer

Add `Mac/Mosul/App/MosulAudioController.swift`.

Responsibilities:

- Own the `AVAudioEngine`, bus mixers, loop players, and one-shot players.
- Observe `MosulAudioSettings`.
- Load the audio manifest from the same runtime resolver used by map and sprite
  assets.
- Maintain deterministic event cooldowns so repeated contact or risk updates do
  not spam the player.
- Provide no-op behavior when audio is disabled by launch argument or missing
  assets.
- Report load/runtime issues as diagnostics, but never block the playable map.

Suggested public API:

```swift
final class MosulAudioController: ObservableObject {
    @Published var isMuted: Bool
    @Published var masterVolume: Double
    @Published private(set) var status: MosulAudioStatus

    func configure(runtimeRoot: URL, launchArguments: [String])
    func setMuted(_ muted: Bool)
    func setMasterVolume(_ volume: Double)
    func updateContext(_ context: MosulAudioContext)
    func play(_ event: MosulAudioEvent)
    func stopAll()
}
```

`ContentView` should create the controller as a `@StateObject`, add the header
mute control, and forward high-level events from `MosulGameModel`. The map view
should not play sounds directly.

### Model/Event Layer

Add a structured audio event stream rather than parsing `playerNotice`.

Candidate types:

```swift
struct MosulAudioContext: Equatable {
    var tick: UInt32
    var selectedSide: MosulPlayableSide?
    var selectedUnitID: UInt32?
    var mapZoom: Double
    var visibleContactCount: Int
    var unresolvedCivilianRiskCount: Int
    var activeTargetingMode: MosulMapMode?
    var tension: Double
}

enum MosulAudioEvent: Equatable {
    case battleStarted(side: MosulPlayableSide)
    case unitSelected(id: UInt32, side: MosulPlayableSide)
    case orderArmed(kind: MosulOrderKind)
    case orderPlaced(kind: MosulOrderKind)
    case tickResolved(tick: UInt32)
    case contactRevealed(contactID: UInt32)
    case fireResolved(attackerID: UInt32, targetID: UInt32, outcome: MosulFireAudioOutcome)
    case lineOfSightBlocked
    case civilianRiskChanged(level: MosulCivilianRiskAudioLevel)
    case objectiveResolved(id: UInt32)
    case afterAction(outcome: MosulOutcomeBand)
}
```

The first implementation can emit events from Swift model methods. A later pass
should expose the C engine tick event log through `MosulEngineBridge` so contact,
fire, casualty, suppression, route-block, and objective events are driven by
gameplay facts rather than UI-side comparisons.

### Asset Manifest

Add runtime audio under:

`modernerKrieg/assets/mosul/audio/`

Add a manifest:

`modernerKrieg/assets/mosul/audio/mosul_audio_manifest.json`

Draft schema:

```json
{
  "version": 1,
  "assets": [
    {
      "id": "ambient.city.market.low.loop",
      "file": "loops/ambient_city_market_low.wav",
      "bus": "ambience",
      "kind": "loop",
      "license": "CC0-1.0",
      "attribution": "",
      "source_url": "",
      "locale": "",
      "transcript": "",
      "duration_seconds": 42.0,
      "loop_points_seconds": [0.0, 42.0],
      "lufs": -24.0,
      "tags": ["city", "distant", "low_tension"]
    }
  ]
}
```

The runtime resource checker should validate:

- referenced files exist in the app bundle
- release-approved licenses only: CC0, CC BY with attribution, original
  commissioned work, or audited U.S. Government public-domain material
- no CC BY-NC, unclear YouTube rips, unlicensed broadcast audio, or unattributed
  sample-pack fragments
- sample rate is 44.1 kHz or 48 kHz
- files are mono or stereo PCM WAV, AIFF, CAF, or AAC/M4A
- loops have duration and loop-point metadata
- speech assets have locale and transcript fields where intelligible
- every non-CC0 asset appears in an audio credits document

## Soundscape Layers

### Ambient City Bed

The base bed should be quiet, wide, and layered:

- distant road wash
- generators and HVAC
- intermittent far engines
- room tone / air
- distant street voices
- occasional far metallic movement or door impacts

The bed should respond to tactical context:

- zoomed out: wider, flatter, less positional detail
- zoomed in: more local texture, softer global wash
- selected unit near road or vehicle: slightly more engine presence
- high tension: ambience ducks slightly so tactical cues are clearer

### Engines And Movement

Engine sound should be mostly environmental. It should not imply precise vehicle
positions unless the UI also shows that information.

Useful cues:

- move order placed: short confirmation click plus low radio acknowledgment
- tick with moving unit: subtle gear/foot movement transient
- blocked route: dry stop cue plus "route blocked" radio callout
- unit arrives: soft arrival cue, no celebratory sting

### Iraqi Civilian Speech

Civilian speech should be treated as human presence:

- low intelligibility unless the scenario explicitly translates it
- mixed below tactical cues
- never used as a threat proximity detector
- dialect and content should be reviewed by native speakers if possible
- avoid fake Arabic, generic shouting, or politicized/religious clips unless
  there is a specific licensed and contextual reason

For a first release, commissioned or original recordings are preferable to
trying to force a public corpus into a natural Mosul street bed. Open corpora
can help prototype texture, but the release asset should be reviewed and
credited.

### U.S. Radio Voice

Radio should be sparse, procedural, and player-helpful:

- "Move set."
- "Crossing."
- "Contact reported."
- "No line of sight."
- "Civilians close."
- "Task complete."
- "Hold position."

Radio should have cooldowns. The same line should not repeat every tick. Any
important radio line should be mirrored in the existing player notice area or a
small caption line so muted play remains complete.

### Weapons And Contact

Weapon sound should communicate consequence without making the small demo feel
like an arcade shooter:

- fire order accepted: short radio/weapon-ready cue
- fire resolved: one controlled burst or shot layer, panned by target relation
- no line of sight: negative cue and radio line
- suppression or casualty: lower, serious transient
- civilian risk spike: distinct warning cue, never a weapon-like sound

The sound should respect fog of war. Hidden units should not get positional
audio before they are visible to the chosen side.

## Dynamic Mix Rules

`MosulAudioContext.tension` should be derived from visible tactical state:

- visible hostile contacts
- civilian risk count and severity
- recent fire
- friendly casualties/suppression
- unresolved objectives
- tick pressure near outcome thresholds

Tension should alter mix subtly:

- ambience ducks under tactical events
- radio becomes slightly more filtered or compressed
- civilian murmur does not become "scary"; it may thin out or duck
- UI feedback remains stable so controls feel reliable

## Development Cycles

Estimate: 8 focused development cycles from no-audio baseline to a release-safe
first sound pass.

Current soundscape cycle: S7, speech and radio.
Completed soundscape cycles: S1-S6 on 2026-06-14.

| Cycle | Status | Theme | Technical Work | Exit Criteria |
| --- | --- | --- | --- | --- |
| S1 | completed 2026-06-14 | Mute-first audio foundation | Added `MosulAudioController`, `MosulAudioSettings`, a header/overlay speaker toggle, persisted mute/master volume, `Command-Shift-M`, and `--disable-audio`. Playback remains silent/no-op until the mixer cycle adds a graph. | Main-window mute is always reachable, persists across relaunch, silences immediately, and smoke/evidence/performance/runtime-check launches can disable audio. |
| S2 | completed 2026-06-14 | Runtime audio manifest | Added `modernerKrieg/assets/mosul/audio/`, `mosul_audio_manifest.json`, an audio credits document, and audio manifest/license/path/format validation in the runtime-resource script. | Missing audio files, unapproved licenses, absent attribution, unsafe paths, unsupported extensions, and invalid WAV sample properties fail validation before release packaging. |
| S3 | completed 2026-06-14 | Mixer and loop engine | Built the `AVAudioEngine` graph with master, ambience, tactical, radio, and UI mixers; load loops from the manifest; added safe configure/start/stop, mute/unmute, volume, and ambience-ducking behavior. | The bundled app audio smoke can configure, mute, unmute, report context, and quit without requiring speaker output. |
| S4 | completed 2026-06-14 | Structured audio events | Added `MosulAudioEvent` and `MosulAudioContext`; emit events for side start, selection, order arm/place, tick, contact reveal, fire, blocked LOS, civilian risk, objective, and after-action. | Snapshot and accessibility smoke reports verify expected audio events textually without requiring speakers. |
| S5 | completed 2026-06-14 | Tactical feedback pass | Mapped structured gameplay events to restrained generated one-shots for order arm/confirm, invalid command, tick, movement, contact reveal, route/LOS blocked, fire resolved, objective, and civilian-risk warning. | Audio smoke probes representative event families, snapshot evidence keeps visual/text parity through player notices and reports, and invalid/blocked actions now produce structured feedback events. |
| S6 | completed 2026-06-14 | Ambient city and engines | Added original low/high city, generator, and distant-engine loops; connected zoom, tension, visible movement, and traffic movement into bus and loop mixing; added movement/transit accents. | The bundled app loads 14 manifest assets, starts 4 low-volume ambience loops in playable context, changes mix from zoom/tension/movement context, and avoids hidden hostile positional audio. |
| S7 | next | Speech and radio | Add reviewed Iraqi civilian murmur beds and sparse U.S. radio callouts with transcripts, captions for gameplay-critical lines, cooldowns, and license metadata. | Speech improves place and command clarity without becoming repetitive, stereotyped, or necessary for play. |
| S8 | pending | Audio QA and release hardening | Add audio evidence report, accessibility checks, clean-machine bundle checks, size budget, credits review, and release documentation. | Release DMGs include validated audio assets and credits; muted mode, no-audio launch, and normal playback all pass QA. |

## Open-Source Audio Policy

Useful sources can include Freesound, OpenGameArt, Wikimedia Commons, Common
Voice prototypes, and carefully audited DVIDS/U.S. Government material. The
release build should only ship assets with clear rights and complete
attribution. BBC Sound Effects and similar libraries can be useful references,
but should not be treated as open-source release assets unless a compatible
license has been obtained.

Recommended release preference:

1. Original or commissioned short radio lines and Iraqi civilian beds.
2. CC0/CC BY engine, city, UI, and weapon layers with documented attribution.
3. Audited U.S. Government material only when privacy, publicity, trademark,
   and non-endorsement caveats are acceptable.
4. No noncommercial, unsourced, or platform-ripped audio.

## Verification Checklist

- Mute button visible in main window at all playable sizes.
- `Command-Shift-M` toggles mute and updates VoiceOver state.
- `--disable-audio` creates no audio engine and is used by CI/evidence scripts.
- Missing audio assets degrade to silent mode with diagnostics, not launch
  failure.
- Audio manifest and credits are bundled under `Contents/Resources`.
- Release resource checker validates every referenced audio file.
- No sound cue reveals information hidden by fog of war.
- Every gameplay-critical cue has a visual/text equivalent.
- Speech assets have transcripts, locale notes, source URLs, and review status.
- Audio output is absent from snapshot/performance modes unless explicitly
  enabled for manual QA.
