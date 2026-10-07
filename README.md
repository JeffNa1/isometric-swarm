# Isometric Swarm

A fast, absurdly outnumbered swarm-survival game built with **Godot 4.3** (GL Compatibility renderer, so it runs on desktop, mobile and the web).

You pilot a single hover-drone. Your weapons fire on their own; you steer, dash, and choose upgrades. Survive ten minutes, kill the Hive Queen.

## Play

- **Phone / browser:** every push to `master` builds a web version and publishes it to GitHub Pages (see [Web build](#web-build)).
- **Desktop:** open `project.godot` in Godot 4.3 and press <kbd>F5</kbd>.

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | WASD / arrows | Left stick | Drag anywhere |
| Dash (brief invulnerability) | Space / Shift | A / RB | DASH button |
| Pause | Esc / P | Start | ❚❚ button |
| Pick upgrade | 1 / 2 / 3 or click | – | Tap a card |
| FPS overlay | F3 | – | – |

## The run

| Time | What happens |
| --- | --- |
| 0:00 | Mites everywhere. Level up fast and pick your first weapons. |
| 0:40, then every 50s | **Swarm surge**: a full ring of enemies closes in. |
| 0:45 | Darts join: fast flankers that overshoot. |
| 1:30 / 3:30 / 6:30 / 8:30 | **Champion**: a gold elite that drops a supply cache (free upgrade + heal). |
| 2:00 | Brutes: slow, tanky, shrug off knockback. |
| 2:50 | Spitters: keep their distance and lob slow, readable shots. |
| 4:20 | Bombers: rush in, fuse, explode. They hurt their friends too. |
| 5:00 | **Broodmother** mid-boss. |
| 10:00 | **Hive Queen**. Kill her to win. |

The director keeps the population climbing from about 50 to 1,500 live enemies. On weaker devices the cap trims itself automatically to hold the frame rate.

## Arsenal

Hold up to **4 weapons** and **4 systems**, each up to level 5. Once everything is maxed, level-ups offer repairs and permanent damage boosts.

**Weapons:** Pulse Cannon (starter, auto-aimed bolts) · Halo Blades (orbiting) · Arc Coil (chain lightning) · Nova Pulse (knockback blast) · Rail Lance (piercing beam into the densest crowd) · Cluster Mortar (shells on distant packs)

**Systems:** Overcharge (damage) · Coolant (fire rate) · Amplifier (area) · Servos (speed and dash) · Nanoplating (HP and regen) · Tractor Field (pickup range and XP)

Field drops: ❤ repair, 🧲 vacuum all XP, 💣 clear the screen.

## Code tour

Everything is built in code; scenes are just entry points.

```
scripts/
  data.gd         Autoload. Palette, every balance number, theme, save data, input map
  sfx.gd          Autoload. Procedurally synthesised, rate-limited sound effects
  game.gd         Run controller: spawn director, events, XP/levels, camera, end of run
  swarm.gd        Struct-of-arrays enemy sim, spatial grid, crowd pressure, one draw call
  weapons.gd      Loadout, derived stats, all weapon logic and melee/area visuals
  projectiles.gd  Player bolts and enemy shots
  pickups.gd      XP crystals (auto-merging) and field items
  fx.gd           Particles, rings, ground residue, damage numbers (all budgeted)
  boss.gd         Broodmother / Hive Queen with telegraphed attack patterns
  player.gd       Movement, dash, i-frames, procedural drone art
  batch.gd        MultiMesh helper: thousands of sprites, one draw call
  ui/             HUD + touch controls, level-up cards, overlays, menu, vector icons
shaders/
  floor.gdshader  Calm isometric deck tiles
  swarm.gdshader  Every enemy type drawn with signed distance fields
  glow / gem / screen
```

**Tuning:** almost all balance lives at the top of `scripts/data.gd` (`ENEMIES`, `SPAWN_TABLE`, `target_population`, `hp_scale`, `xp_to_next`). Weapon level curves are in `weapons.gd` (`_fire_*` functions and `_cooldown`).

## Web build

`.github/workflows/web.yml` exports the **Web** preset with threads disabled, so it runs on GitHub Pages without special headers, and deploys it.

One-time setup: **Settings → Pages → Build and deployment → Source: GitHub Actions**. After the next push to `master` (or a manual run from the Actions tab), the game is live at `https://<user>.github.io/isometric-swarm/`.

## License

MIT. Font: [Chakra Petch](https://fonts.google.com/specimen/Chakra+Petch) (SIL Open Font License, see `assets/fonts/OFL.txt`).
