# MOSUL Plan

`mosul` is the public project home for the MOSUL playable demo. The first public target is the 2003 Market / Commercial Streets scenario, with `modernerKrieg` providing the portable tactical engine.

The project is ready to move from art/import work into playable-demo development. The next job is to turn the existing source art, scenario concept, and engine core into a small playable vertical slice.

## Current Public Baseline

- The public README describes the 2003 Market / Commercial Streets demo direction.
- Public presentation art exists under `assets/readme/`.
- The `modernerKrieg` engine submodule builds as a portable C/CMake project.
- The engine already has deterministic core tests for game state, board view, selection, movement, line of sight, fire, suppression, and scenario state.
- Source art for the 2003 demo exists under `modernerKrieg/assets/mosul/source/`.
- The current SDL3 app shell is still experimental and should be judged against a possible SwiftUI frontend contingency.

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

- Add runtime PNG loading and texture ownership to the SDL3 app layer or chosen frontend.
- Add asset manifests for infantry, weapons, vehicles, markers, and map layers.
- Render real map art before colored terrain blocks.
- Render real unit sprites before colored unit rectangles.
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

- Keep headless tests runnable without SDL3.
- Verify the SDL3 app if SDL3 is available locally.
- If SDL3 feels wrong for the desired user experience, keep the C core and build a SwiftUI frontend around it.
- Package one macOS-first demo before broadening to Windows/Linux.

## Additional Art Needed

The imported art is enough to start development. The likely missing public-demo assets are narrow and can be planned while implementation begins:

- civilian/non-combatant top-down sprites
- selection, order, route, objective, suppression, casualty, and hidden-contact markers
- rooftop, stair, breach, search/cache, checkpoint, and suspected-danger markers
- engine-ready map tiles at the chosen demo zoom levels
- collision/pathfinding masks for roads, interiors, rooftops, rubble, blocked routes, and upper-floor access
- small UI icons for orders and unit states

Do not pause engine development for a large new art pass. Add these assets only when a playable slice needs them.

## Immediate Next Steps

1. Update `modernerKrieg` to load and render PNG textures from a manifest.
2. Create the first 2003 scenario data file and load it into the core.
3. Render the Market / Commercial Streets map overview or first tile set in the app.
4. Render real unit sprites for at least one U.S. squad and one opposing cell.
5. Add visible order/selection/state markers.
6. Add a minimal after-action result screen or log.
7. Run headless tests and one local app smoke test before sharing the public demo.
