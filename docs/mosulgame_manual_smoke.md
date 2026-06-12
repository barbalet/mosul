# MosulGame Manual Smoke Checklist

Use this checklist after `scripts/run_mac_smoke.sh` passes and the built
`MosulGame.app` launches. Record the app path, macOS version, architecture, and
chosen side when filing a QA note.

## Command Ergonomics

- [ ] Start a new battle as `U.S. Patrol`.
- [ ] Select the first command unit from the map, then from the unit list.
- [ ] Select `Move`, click a nearby street location, and confirm the notice
      reports a movement target for the selected command unit.
- [ ] Select `Investigate`, click a suspected contact or terrain cue, and
      confirm the notice reports an investigation target.
- [ ] Issue `Hold`, `Overwatch`, and `Rally` to the selected command unit and
      confirm each command reports a notice.
- [ ] Select a visible opposing contact and confirm the inspector marks it as
      intel only, with order/strength/suppression redacted.
- [ ] Select an actionable breach/search/route task, then confirm disabled
      states clear when a command unit is selected.
- [ ] Use `Opponent Tick` at least once and confirm the selected command side
      still owns manual command.
- [ ] Use `Reset` and confirm the chosen side remains active and a command unit
      is selected.

## Side Context And Fog Of War

- [ ] Confirm hidden opposing units are not listed in `Units` and do not render
      as exact unit markers on the map.
- [ ] Confirm visible/revealed opposing elements render as reported contacts,
      without route targets, strength, order, or suppression values.
- [ ] Confirm `Contact Reports` use approximate positions and player-facing
      side labels.
- [ ] Confirm the score panel is labeled as the U.S. stabilization perspective
      regardless of the selected command side.
- [ ] Repeat the side-selection flow as `Opposing Cell` and confirm the same
      command-vs-intel split applies with U.S. elements treated as opposing
      contacts.
