# Tiny Demons

![Tiny Demons — gameplay](docs/readme/hero.gif)

**A bite-sized isometric action dungeon crawler about being a small, elemental
demon.** Clear tight, readable rooms of slimes and skeletons, attune to flames
to change your element mid-run, fuse elements into new classes, and carry your
gear and mastery back to the Demon Hub for the next dive.

A full run takes minutes. The chase lasts a lot longer.

*Version 0.3.75 — in active development.*

---

## The loop

```
Choose a flame  ->  dive the dungeon  ->  fight, route, and discover
      ^                                            |
      |                                            v
Demon Hub: equip, fuse, allocate, bind  <-  settle rewards, keep your gear
```

- **In the run:** pick a route, fight, find flames, gear, gold, and Chroma, then
  beat the boss or extract.
- **Between runs:** level up, allocate six stats, buy and fuse gear, and commit
  to a permanent element at the Cloaked Demon.

It is a **soft roguelite**: death ends the run, never your progress.

## What makes it tick

### Combat with weight
Directional attacks, combos, a running attack, a **spin attack**, and a held
**charge attack that releases a sword beam**. Roll, backflip, guard with a
perfect-block window, target-lock with a FOCUS bonus, hitstop, knockback, and
screen shake make every hit land. Skill beats stats.

### Elements are the identity
Eight elements — Fire, Water, Electric, plus the fusion-born Shadow, Ground,
Grass, and Ice. Collect Chroma, attune at flames, **swap** your element for a
fast run, or **fuse** two into a new class. Then pay Souls to **bind** an
element permanently, so it survives even at zero Chroma.

### A dungeon that keeps asking new questions
Authored teaching runs and a deterministic generated dungeon beyond them. Combat
rooms, elemental flame rooms, Orb vaults, color-gated puzzles, treasure, a
scaled boss with a jump-slam phase, and an optional risk/reward fork on
generated routes.

### Gear, and a reason to return
Six equipment slots, five rarities, fusion enhancement, and a Demon Hub with
STATS, SHOP, FUSION, and BIND. Drops are readable the moment they hit the floor.

### Play anywhere
Desktop, browser, and touch. Keyboard, mouse, controller, and on-screen
controls, with device-aware prompts.

## Screenshots

| Title | Demon Hub |
| --- | --- |
| ![Title screen](docs/readme/screenshot-title.png) | ![Demon Hub](docs/readme/screenshot-hub.png) |

| Elements and binding | Dungeon map |
| --- | --- |
| ![Element binding](docs/readme/screenshot-bound.png) | ![Dungeon map](docs/readme/screenshot-map.png) |

## Gameplay clips

| Charged attack & sword beam | Spin attack |
| --- | --- |
| ![Charged attack](docs/readme/gameplay-beam.gif) | ![Spin attack](docs/readme/gameplay-spin.gif) |

| Elemental casting | Boss encounter |
| --- | --- |
| ![Elemental casting](docs/readme/gameplay-chroma.gif) | ![Boss encounter](docs/readme/gameplay-boss.gif) |

## Play in your browser

Published from `main` to GitHub Pages:
**[Play Tiny Demons](https://whynchu.github.io/TinyDemons/) · [Design Wiki](https://whynchu.github.io/TinyDemons/wiki/)**

Current web build: `0.3.75`.

## Controls

Keyboard and controller bindings live in the **Input Map** and are remappable.
Defaults:

| Action | Keyboard / Mouse | Controller |
| --- | --- | --- |
| Move | Arrow keys / WASD | Left stick / D-pad |
| Attack | Left click / `J` / Space | X |
| Magic | Middle click / `U` | Y |
| Roll / Run | Right click / `K` | A (hold to run) |
| Target lock | `Q` / Tab | Right shoulder / trigger |
| Guard | `L` / Shift | Left shoulder / trigger |
| Interact / confirm | `E` / Enter | B |
| Cancel / back | `X` / Escape | A |
| Pause | Escape | Start |
| Map | `M` | Share / Options |

Mouse aims facing while movement controls travel. A quick click on an enemy
selects it; holding starts an attack; holding an attack charges it. Clicking
open ground attacks.

## Where it is headed

Tiny Demons is being built toward a **1.0** where:

- the three starter elements play like genuinely distinct **classes**, each with
  its own ability kit learned and equipped at the Demon Hub;
- elemental **mastery** lets abilities travel between elements;
- a small, readable enemy roster (melee, ranged, support, airborne) makes every
  room ask a different question;
- multiple biomes give the dungeon distinct spatial and emotional identities;
- the browser build and low-end mobile devices hit real, measured frame budgets.

This is a long road. See [`docs/ROADMAP.md`](docs/ROADMAP.md) and
[`docs/project_direction.md`](docs/project_direction.md) for the live plan.

## Tech

Built in **Godot 4.7.1** (GDScript), rendered at a 240×160 pixel-art base with
nearest-neighbor scaling, and exported for desktop and web.

## Contributing

Engineering workflows, verification commands, architecture rules, and the
"build clean" contract are in
[`docs/CONTRIBUTOR_README.md`](docs/CONTRIBUTOR_README.md). Start with
[`docs/DOCUMENTATION_MAP.md`](docs/DOCUMENTATION_MAP.md) for document authority,
or visit the [Tiny Demons Design Wiki](docs/wiki/README.md) for the quick design
and systems guide.

---

Version `0.3.75`. Every push to `main` increments the patch version by at least
`0.0.01`; the in-game title version and this README change in the same commit.
