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
- Each day is busier and guests are less patient. Money carries across days.
- **Word of mouth is visible.** A visit that moves a guest's opinion says who they will
  tell or warn. The end-of-day clipboard has a town book (T): every townsperson's standing
  (five pips, from "Staying away" to "Loves you") and whether today moved it.
- **Half price.** With empty hands at the table of a guest whose patience is under half,
  E offers half price, once per visit: +0.35 patience, a little joy, +0.2 affinity, and
  they pay half the bill (the tip is worked out on the halved bill).
- **Build phase, between days only.** Receipt, then Enter opens it; Enter again opens the
  day. A tray along the bottom is the catalog, browsed like the Sims: type in the search
  box (matches name, category and what a piece does) or pick a category tab (Kitchen,
  Dining, Decor, Walls). Pick a card, then place with the mouse: a ghost follows the
  pointer, left-click places and pays, right-click or Esc cancels. The piece stays in
  hand while there is money for another. Partitions snap to the nearest cell edge (no
  rotate key). A spot is refused if it would cut the chef, any seat or any station off
  from the door.
- **Move, turn, sell.** With nothing in hand, clicking a piece in the room picks it up
  (it keeps whatever is on it). Click to put it down for free, R to turn it a quarter
  turn (a turned table seats guests above and below), right-click or Esc to put it
  back; a piece still carried when the day opens goes back too. Sell (button or X)
  refunds half the catalog price. Fixtures (fridge, sink, bin, plate stack, pass
  counters) can be moved but not sold, and the last stove and last table cannot be sold.
  Player-built partitions move and sell the same way; the entrance wall does not.
- **Upgrades are catalog entries.** Stove, fern and table are sold in three tiers; a
  tier costs 1x, 2x, 4x the base price and each tier needs one more level. Counter and
  partition have one tier. There are no free blueprints.
- **Tier effects:** faster stove, stronger fern, a tier 2+ table gives seated guests
  +0.05 joy per tier. Counters and partitions gain nothing but looks.
- **Guest card.** Click a guest during service to see their standing, visit number, the
  four meters and their last six thoughts. It follows them live and closes when they go.
- **Sightlines.** A guest is disgusted only by what they can see; a partition hides it.
  Every source follows one rule (`GuestMood.gross_rate`): it starts small, doubles on a
  fixed beat and tops out. Rates per second, in `GROSS` in `game/main.gd`:

  | Source | Starts | Doubles every | Tops out | Ages from |
  | --- | --- | --- | --- | --- |
  | Used plate on a table | 0.002 | 10 s | 0.06 | when the plate was left |
  | Burning food on a stove | 0.01 | 5 s | 0.06 | when it burnt |
  | The bin (within 5 cells) | 0.004 | 15 s | 0.02 | when this guest first saw it |
  | Chef carrying rubbish | 0.05 | 1.5 s | 0.4 | when this guest first saw it |

  Below 0.005 a second a guest has not noticed: no thought, and it does not spoil the
  view. A guest who can see a working stove and nothing they have noticed gains joy
  (0.01 a second).
- **Groups.** Guests arrive in groups of friends, never with strangers. The biggest
  group is the most seats any one table has (2 today). A group queues together, takes
  a whole empty table (the smallest that fits) and shares it with nobody, so a lone
  guest has a table to themselves. If one of a group runs out of patience, those still
  waiting leave with them and it counts as one walkout; each of them holds a grudge.
- **Reaching stations.** E uses the nearest station within 1.3 m that has something to
  do, with a small preference for the one the chef faces and for serving over putting
  down. A table also counts as near when one of its seated guests is.
- **Regulars.** Three good visits in a row (satisfaction above 0.3) make someone a
  regular: they arrive with +0.1 joy and tip 25% more. A poor visit resets the streak.
  The town book shows "Regular, N in a row".
- **Grudges.** A guest who walks out stays away for the next two days (the town book
  counts them down), then returns sore: 0.75 patience, -0.1 joy. A good visit forgives
  (+0.1 affinity on top of the usual). Each further walkout adds two more days away.
  Guests holding a grudge are not used to top up a thin crowd.
- **Flyers.** On the receipt, $15 (F) buys +25% visit chance for everyone tomorrow. One
  batch a night. 
- End-of-day summary, game-over screen, best run saved to `user://regulars_best.json`.

Code map: `sim/` is pure logic with no scene dependencies (unit-tested with GUT).
`game/` is the scene layer. `tools/make_sfx.py` regenerates the placeholder sounds.

## 2. Parked systems that already have code

These were built in the first prototype and then unhooked from the game to keep the slice
focused. The logic and tests still exist.

| System | Where | State |
| --- | --- | --- |
| Blueprint catalog | `sim/catalog.gd` | **Built**, see section 1. |
| Nightly crate, shelf upgrades | `Catalog.offer`, `shelve`, `collect_ready` | **Parked again by decision** (no blueprints from the sky, at least for now). Was hooked up briefly on this branch; logic and tests kept, nothing in the game calls them. |
| Walls on cell edges, line of sight, placement pathing | `sim/grid.gd` | **Built**, see section 1. Placement rules are `Grid.can_place_block` and `can_place_wall`. |
| Word of mouth between friends | `sim/town.gd` | **Built**, see section 1. |
| Kindness / discounts | `GuestMood.offer_discount`, `Town.record_kindness` | **Built**, see section 1. Full comps (a free meal) are not. |
| Flyers (ad boost) | `Town.roll_guests(day, boost)` | **Built**, see section 1. |

Everything else in this table is back in the game. Not built: upgrading a piece already
placed; floors and ceilings.

## 3. Guests (RollerCoaster Tycoon layer)

- **Four meters** per guest: patience, disgust, joy, savour. Final satisfaction =
  `0.35 savour + 0.3 joy + 0.2 patience - 0.5 disgust`. Tip = bill x satisfaction x 0.6.
- **Thoughts**: short lines triggered by what they experience ("I just watched the chef
  carry rubbish past me"). The click-to-inspect guest card is built (section 1); it shows
  the last six thoughts, not the full history.
- **Sightlines**: built (section 1). To add: a dirty kitchen (sink full, bin overflowing)
  as its own source, so "clean" means more than "nothing burning".
- **Word of mouth**: each guest has an affinity (-1..1) that sets their chance to visit.
  A visit moves it; 40% of the change spreads to their friends.
- **Built**: regulars with a visit streak, grudges (section 1).
- **Built**: groups arriving together (section 1).
- **To add**: stay length and order size driven by mood (dessert, second drink),
  favourite dishes (needs a second dish), reviews (needs a design).
- **Discounts and comps**: half price is built (section 1). To add: a free meal, and
  guests who come to expect a discount.

## 4. Building (Sims layer)

- **Nightly crate** (parked by decision): after each day, pick one of two blueprints.
  Place it, or shelve it for two days and it returns one tier higher (max tier 3).
- **Catalog** (built): buy furniture with money, gated by XP level. Starting list:
  partition wall $10, counter $15, fern $20, table for two $40 (level 2), stove $80
  (level 3). To add: more pieces to make browsing worth it, pictures on the cards.
- **Walls, floors, ceilings**: free-form placement. Walls sit on cell edges and block
  sight and movement. Placement is refused if it cuts a seat or the chef off from the door.
- **Two currencies**: money (earned per day) and XP (10 per meal plus the tip; 100 per level).
- **Built**: moving, selling and rotating furniture (section 1).
- **To add**: expanding the lot, floor and wall finishes that affect joy, themes that
  change the catalog. Known rough edge: the dining-room rugs are scenery and stay put
  when a table is moved off them.

## 5. Characters (Sims layer)

- **Character creator**: very simple. Name, skin, shirt, hat. Peg-person style.
- **Roster**: created characters can be played by other players or assigned as staff NPCs.
- **Staff jobs**: cook, server, dishwasher, host. Simple task queues.
- **Relationships** between your characters: friends hand off faster, rivals fumble.
- **No needs** for now.

## 6. Money (Tycoon layer)

- **Ledger screen**: income, tips, wages, spending, day-by-day history chart.
- **Investments**: flyers (built, section 1), loans, supplier stakes (cheaper or
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
- Sound effects are synthesised placeholders (`tools/make_sfx.py`). Later: real foley.
- Music is real: `Daytime` during service, `Nighttime` on the receipt and in the build
  phase, `Closed` once at game over, cross-faded. `Intro` is unused until there is a title
  screen. The old synthesised `assets/sfx/music.wav` is no longer played. Later: music per theme.

## 9. Open questions

- The name stays "Regulars" for now. Logo direction is decided; see "Decisions and open items" in `docs/STYLE_GUIDE.md`.
- Should order-taking be a step (walk to the table first), as in PlateUp?
- Building happens between days only (decided). Live building during service is not planned.
