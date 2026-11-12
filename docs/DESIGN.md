# Regulars: design notes

Working title. A restaurant survival game: PlateUp's round-by-round kitchen, the Sims'
building and people, RollerCoaster Tycoon's obsessive guest tracking.

This file records everything that is **not** in the current vertical slice, so nothing is
lost while the core loop is polished. Sections are ordered roughly by when to build them.

## 1. The vertical slice (what is in the game now)

An endless run. Each day guests arrive, you cook meat, serve it, and get paid. Survive as
many days as you can; three walkouts in one day ends the run.

- Direct control of one chef (WASD, E/Space).
- One dish: a burger. Fridge > stove > plate > table. Dirty plates go to the sink.
- Meat has doneness. A radial dial over the stove has a green "perfect" window; pull it late
  and it is dry (worse tips), leave it and it burns. The patty changes look as it goes.
- Guests are named townsfolk with patience, disgust, joy and savour. These set the tip.
- Each day is busier and guests are less patient. Money carries across days but there is
  nothing to spend it on yet.
- End-of-day summary, game-over screen, best run saved to `user://regulars_best.json`.

Code map: `sim/` is pure logic with no scene dependencies (unit-tested with GUT).
`game/` is the scene layer. `tools/make_sfx.py` regenerates the placeholder sounds.

## 2. Parked systems that already have code

These were built in the first prototype and then unhooked from the game to keep the slice
focused. The logic and tests still exist.

| System | Where | State |
| --- | --- | --- |
| Blueprint catalog, nightly crate, shelf upgrades | `sim/catalog.gd` | Logic + tests kept. No UI. |
| Walls on cell edges, line of sight, placement pathing | `sim/grid.gd` | In use for the front wall; player-built walls unhooked. |
| Word of mouth between friends | `sim/town.gd` | Still running quietly; no UI shows it. |
| Kindness / discounts | `Town.record_kindness` | Logic kept; the "half price" action was removed. |
| Flyers (ad boost) | `Town.roll_guests(day, boost)` | Parameter kept; no way to buy it. |

The first prototype's build phase (pick a crate blueprint, place with the mouse, R to
rotate walls, catalog buttons) was removed from `game/main.gd` and `game/hud.gd`. It can
be recovered from the description in section 4.

## 3. Guests (RollerCoaster Tycoon layer)

- **Four meters** per guest: patience, disgust, joy, savour. Final satisfaction =
  `0.35 savour + 0.3 joy + 0.2 patience - 0.5 disgust`. Tip = bill x satisfaction x 0.6.
- **Thoughts**: short lines triggered by what they experience ("I just watched the chef
  carry rubbish past me"). Later: a click-to-inspect guest panel with full thought history.
- **Sightlines**: disgust is line-of-sight. Sources: the bin (parked until walls return,
  because the player cannot hide it yet), uncleared tables, the chef carrying rubbish.
  A clean open kitchen should eventually *raise* joy.
- **Word of mouth**: each guest has an affinity (-1..1) that sets their chance to visit.
  A visit moves it; 40% of the change spreads to their friends.
- **To add**: stay length and order size driven by mood (dessert, second drink), groups
  arriving together, favourite dishes, regulars with a visit streak, grudges, reviews.
- **Discounts and comps**: give a guest half price to buy goodwill.

## 4. Building (Sims layer)

- **Nightly crate**: after each day, pick one of two blueprints. Place it, or shelve it
  for two days and it returns one tier higher (max tier 3). Tier effects so far: faster
  stove, stronger fern, nicer table.
- **Catalog**: buy furniture with money, gated by XP level. Starting list: partition wall
  $10, counter $15, fern $20, table for two $40 (level 2), stove $80 (level 3).
- **Walls, floors, ceilings**: free-form placement. Walls sit on cell edges and block
  sight and movement. Placement is refused if it cuts a seat or the chef off from the door.
- **Two currencies**: money (earned per day) and XP (10 per meal plus the tip; 100 per level).
- **To add**: expanding the lot, floor and wall finishes that affect joy, moving and
  selling furniture, rotating furniture, themes that change the catalog.

## 5. Characters (Sims layer)

- **Character creator**: very simple. Name, skin, shirt, hat. Peg-person style.
- **Roster**: created characters can be played by other players or assigned as staff NPCs.
- **Staff jobs**: cook, server, dishwasher, host. Simple task queues.
- **Relationships** between your characters: friends hand off faster, rivals fumble.
- **No needs** for now.

## 6. Money (Tycoon layer)

- **Ledger screen**: income, tips, wages, spending, day-by-day history chart.
- **Investments**: flyers (more guests tomorrow), loans, supplier stakes (cheaper or
  better ingredients), equipment leases.
- **Costs**: ingredient cost per dish, wages, rent that rises with the location.

## 7. Run structure

- **Theme and location** chosen at the start of a run (seaside diner first). Location sets
  the town's size and tastes; theme sets the menu and starting furniture.
- **Menu growth**: new dishes add stations and steps (chopping, frying, drinks).
- **Local co-op**: the game is structured so a second directly-controlled chef can be added.
- **Lose condition** today is three walkouts in a day. Alternatives to test: reputation
  stars, rent you must make each week.

## 8. Art and audio

- **Art direction is settled.** See `docs/STYLE_GUIDE.md` (rules, resolved conflicts,
  palette) and the 27 images in `docs/art/`. Toy diorama: legless peg-people with floating
  mitten hands, bevelled painted-wood props, soft warm shadows, paper-and-wood interface.
- **The game now follows it.** The first art pass is done, all of it built in code:
  1. Palette roles, plum-warm soft shadows and 3 cm bevels on every box (`game/build.gd`).
  2. Peg-people: one shared body, the eight faces, mitten hands with poses, and the kit
     (5 skins, 8 hair shapes, 6 hats, glasses, beard, 10 outfit colours, 4 patterns). All
     fourteen townsfolk have a look; the chef has the toque and player trim (`game/peg.gd`).
  3. Radial doneness dial, five patty looks, pan, tall burger, bitten burger, dirty plate.
  4. Every station rebuilt (sheets 8 and 10); room kit with full far walls, the 0.55 m
     cutaway, windows, wall art, sconces and table lamps (`game/scenery.gd`).
  5. Thought bubbles and four-frame cut-out effects (`game/icons.gd`, `game/fx.gd`).
  6. Paper-and-wood HUD: day plaque with sun dial, money tag, walkout punch-card, keycap
     prompt, end-of-day receipt on a clipboard, game-over menu card, icon tokens.
  7. Floating slab, plot, paved street with kerb furniture; the seaside pier theme as a
     re-skin (`REGULARS_THEME=seaside`).
- **Where it departs from the sheets** is listed in the style guide under "As built".
- **Still to do**
  - A Blender-built kit. Everything is generated in GDScript (bevelled boxes, lathed
    shapes, flat cut-out cards). `concept/concept_scene.py` shows the Blender toolchain
    works; swap pieces in where a sculpted model would beat the generated one (hair, hats,
    the fridge, the tree are the best candidates).
  - A theme picker in the game (themes are an environment variable for now).
  - Station states with no gameplay behind them yet: sink full of suds, overflowing bin.
  - Hired staff (server, dishwasher, host), co-op chefs 2 to 4 (trim colours exist),
    future dishes, the four-seat table and booth, floor lamp, awning and photo view.
  - A bundled hand-lettered font (the HUD uses a rounded system font).
  - The open items: title screen, colour-blind support, the "Town Diner" subtitle.
- Sounds are synthesised placeholders (`tools/make_sfx.py`). Later: real foley, music per theme.

## 9. Open questions

- The name stays "Regulars" for now. Logo direction is decided; see "Decisions and open items" in `docs/STYLE_GUIDE.md`.
- Should order-taking be a step (walk to the table first), as in PlateUp?
- How much of the building happens between days versus live during service?
