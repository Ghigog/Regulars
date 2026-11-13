# Regulars: design notes

Working title. A restaurant survival game: PlateUp's round-by-round kitchen, the Sims'
building and people, RollerCoaster Tycoon's obsessive guest tracking.

This file records everything that is **not** in the current vertical slice, so nothing is
lost while the core loop is polished. Sections are ordered roughly by when to build them.

## 1. The vertical slice (what is in the game now)

An endless run. Each day guests arrive, you cook meat, serve it, and get paid. Survive as
many days as you can; three walkouts in one day ends the run.

- Direct control of one chef (WASD, E/Space).
- One dish: a burger. Fridge > stove > plate > table. Dirty plates go into the sink and
  soak there until washed, one press each, back onto the stack.
- **A dirty kitchen.** Three or more plates soaking pile up in suds. Every patty thrown
  away or burger scraped off goes in the bin; at four it overflows (it still takes more).
  "Empty bin" hands the chef a bag, which goes out of the front door ("Take out rubbish");
  carried, it counts as rubbish. Both are disgust sources (table below).
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
- **Night 0.** The game opens in the build phase, on the night before day 1, with the door
  card on CLOSED and the starting $50 to spend. Tests and `REGULARS_DEMO` shots skip it
  (`first_night` in `game/main.gd`).
- **Build phase, between days only, played from the keyboard.** Receipt, then Enter. The
  chef walks the room (WASD or arrows). E picks up the piece in front (a partition on the
  edge ahead first, else the next cell) and puts it down again in front; R turns it, X
  sells it, Esc puts it back. Tab opens the shop: a tray along the bottom holds one row of
  every piece in the category. The row slides so the selected piece is always in the
  middle, much bigger than the small ones either side (about five show each way), on a
  soft white disc, lifted, tipped and spinning slowly, with its price underneath and its
  name and a few words on what it does on the line below. Left and right browse (wrapping), up and down change
  category (Kitchen, Dining, Decor, Build, Extras, centred under the row; there is no
  "All"), E buys, F or / types in the search box at the bottom left. A search looks
  through every category, and picking a category ends it. A bought piece goes into the chef's hands
  and is paid for when it is put down; it stays in hand for another while there is money.
  The mouse works too: moving it over the room aims the piece in hand at the floor
  under the pointer (walking hands aim back to the chef), a left click puts it down or
  picks a piece up, and a right click drops it.
- **Building the room** (Build tab). Tiled floor and plank floor ($5 a tile), wall ($5 a
  length), door ($20) and archway ($15) are tools: they stay in hand while there is money.
  - *Floors* grow the room. New floor must touch floor already laid (a dragged
    rectangle is laid outward from the room) and stay on the lot, which reaches 5 cells
    left and 2 back (`LOT`): the street is on the right and the near edge stays put.
    Laying one kind over the other swaps it. The outer walls are never placed: any
    edge with floor on one side is a wall, so they move out as the floor grows, and
    the wall between the old room and the new floor comes down.
  - *Walls* divide the room: they go on an edge between two floors and are refused if
    they would cut a seat, a station or the chef off from the door.
  - *Doors and archways* go in any wall, outer ones included, so a door can be cut
    before the room behind it is floored. A door lets people through but blocks sight;
    an archway lets both through. One that nobody can use (bare ground or a piece of
    furniture on a side, or not reachable from the front door) is drawn grey under a
    yellow warning sign. Laying floor past a door in an outer wall merges the rooms and
    pays the door back.
  - *Placing:* E builds at the spot in front of the chef; holding E with a floor tool
    and walking keeps laying, so the chef can pave their way out. With the mouse, a left
    drag lays a rectangle of floor or a straight row of wall (the prompt shows the count
    and the cost), and a click adds a door or archway. Removing: X at the spot in front,
    or a right drag. Everything taken away is paid back in full. The floor inside the
    front door, floor under furniture or seats, and floor that would strand someone
    cannot be lifted.
  - The first room's fixtures (hood, wall cabinets, jar shelf, kitchen sconce)
    stay only while the wall or floor they hang on does.
  - *Finishes:* two nicer floors (parquet $10 a tile, level 2; marble $20, level 3) and
    three wall finishes laid with the same drag as walls (sage paint $5 a length,
    level 1; striped paper $10, level 2; rose paper $20, level 3). One finish per wall
    edge, showing on both faces of a knee-high wall; papering over paint, laying floor
    that takes a wall down, or cutting a door through it pays the old finish back.
    Doorways cannot be papered. Plank, parquet and marble rooms all count as dining
    rooms (wainscot, windows, sconces).
  - *Rugs:* a woven rug ($25, Decor) covers 3 x 2 cells and is placed, turned, moved and
    sold like a fern. It lies flat, so anyone walks over it and a table can stand on
    it; picking up on a cell takes what stands there first, then the rug. Floor under a
    rug cannot be lifted. The first room starts with one under the middle table.
  - *Joy from surroundings* (per second while seated, in `apply_surroundings`): the
    floor under the seat (parquet 0.005, marble 0.01), a rug under the seat (0.005), and
    the best finish on a wall within 2 cells that the seat can see (paint 0.003, striped
    0.006, rose 0.01). All of them together (0.025) are less than a fern ++ (0.03). The
    values live in `Catalog.ITEMS` ("joy"), so they are easy to retune.
- **Keyboard, controller or touch** (`game/controls.gd`). Whichever device was used last
  is the mode, so a player can switch at any moment; every hint (the corner line, the
  prompt's keycap, the build slip, the shop's key line, the receipt buttons) is reworded
  for it. Controller: left stick or d-pad walk, A use (and confirm the receipt and the end
  screen), B back, X sell or remove, Y shop (town book on the receipt), LB/RB turn,
  Start options; in the shop the stick and d-pad browse. Touch: a joystick bottom left;
  down the right a big Use button that names the action, and above it, by night, Shop,
  Drop or Done, Turn, Sell, or Erase (with a build tool, Erase makes drags take things
  away); a small Menu button for options. Taps on the room work as clicks (pick a guest,
  place a piece, drag floors), and a touch on a control never reaches the room. The
  buttons and the controller send the same key presses as the keyboard, so there is one
  set of rules. Not yet: moving the options sliders with a controller.
- **Reach marks.** While a piece with a reach is carried (a fern: 2 + tier cells; the bin:
  5), a pale square on the floor shows how far it goes from the spot in front, and every
  seat has a disc: green if the piece would reach it from there, red if not (out of range
  or behind a partition). Green means "reached", so for the bin green is the bad news.
  Stoves (seen from 7 cells) are not marked.
- **The door card.** An OPEN / CLOSED card hangs on a string in the doorway. In the build
  phase, E at the doorway flips it to OPEN and starts the day (there is no button). From
  halfway through the day (`CLOSE_EARLY_FROM`), E at the doorway flips it to CLOSED: no
  more arrivals, and guests already here (queue included) are served as usual. The halfway
  rule stops a day being skipped outright; it is a guess and easy to change.
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
  | Overflowing bin (any distance) | 0.008 | 8 s | 0.06 | when it overflowed (replaces the line above) |
  | Sink piled with 3+ plates | 0.003 | 10 s | 0.04 | when it piled up |
  | Chef carrying rubbish | 0.05 | 1.5 s | 0.4 | when this guest first saw it |

  Below 0.005 a second a guest has not noticed: no thought, and it does not spoil the
  view. A guest who can see a working stove and nothing they have noticed gains joy
  (0.01 a second).
- **Groups.** Guests arrive in groups of friends, never with strangers. The biggest
  group is the most seats any one table has (2, or 4 once a table for four is placed). A group queues together, takes
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
- **Flyers.** In the shop's Extras tab, $15 buys +25% visit chance for everyone tomorrow. One
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
placed. (Floors, walls and doors are built; ceilings are not planned.)

## 3. Guests (RollerCoaster Tycoon layer)

- **Four meters** per guest: patience, disgust, joy, savour. Final satisfaction =
  `0.35 savour + 0.3 joy + 0.2 patience - 0.5 disgust`. Tip = bill x satisfaction x 0.6.
- **Disgust stages** (built): disgust builds unseen and does nothing until a stage is
  reached. Ick (0.2): they wince, enjoy the visit less and tip less. Disgusted (0.45): they
  also tell their friends and think less of the place. Revolted (0.75): they also never
  come back. Each stage has its own icon over the head.
- **Thoughts**: short lines triggered by what they experience ("I just watched the chef
  carry rubbish past me"). The click-to-inspect guest card is built (section 1); it shows
  the last six thoughts, not the full history.
- **Sightlines**: built (section 1), including a dirty kitchen (piled sink, overflowing
  bin). To add: night cleaning; the sink and bin stay as they are overnight, like tables.
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
  partition wall $10, counter $15, fern $20, table for two $40 (level 2), booth $60
  (level 2), stove $80 (level 3), table for four $90 (level 3). Each piece fits one cell
  and keeps its seats on the cells beside it: the booth has a bench either side (seats two;
  guests get a small joy bump, "A booth! How cosy"), the table for four a chair on every
  side, so a group of four can come once one is placed. Booth and table for four come in
  three tiers like the table for two. To add: more pieces to make browsing worth it
  (a booth seating four over two cells needs multi-cell footprints), pictures on the cards.
- **Floors, walls, doors, archways** (built, section 1): `sim/floorplan.gd` holds the
  plan; `Scenery.build_room` draws it. Ceilings are not planned (the camera looks down).
- **Two currencies**: money (earned per day) and XP (10 per meal plus the tip; 100 per level).
- **Built**: moving, selling and rotating furniture (section 1).
- **Built**: floor and wall finishes that cheer seated guests, and movable rugs (section 1).
- **To add**: buying more lot, themes that change the catalog. A reach display for
  finishes and rugs, like the fern's, is not built: their effect only shows in guests'
  thoughts.

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
  - Hired staff (server, dishwasher, host), co-op chefs 2 to 4 (trim colours exist),
    future dishes, floor lamp, awning and photo view.
  - A bundled hand-lettered font (the HUD uses a rounded system font).
  - The open items: title screen, colour-blind support, the "Town Diner" subtitle.
- Sound effects are synthesised placeholders (`tools/make_sfx.py`). Later: real foley.
- Music is real: `Daytime` during service, `Nighttime` on the receipt and in the build
  phase, `Closed` once at game over, cross-faded. `Intro` is unused until there is a title
  screen. The old synthesised `assets/sfx/music.wav` is no longer played. Later: music per theme.

## 9. Decisions (13 November 2026)

Not built yet; this is the agreed direction for future sessions.

- **Order-taking is a step.** The chef walks to the table to take the order before
  cooking. Build it together with the menu below, since the guest orders from the menu.
- **Recipes, ingredients and a menu the player designs.** Every dish is data: a recipe
  is a list of ingredients (burger: bun, patty, salad, cheese; salad: lettuce, tomato,
  onion). Each ingredient comes from a station in the room dedicated to it, so a
  bigger menu needs a bigger kitchen. Some ingredients can be bought ready-made
  (prefab salad) as shop upgrades that save prep. The player picks which ingredient
  stations to stock and writes their own menu from what they can make (only
  cheeseburgers, say), and guests order from it. Every restaurant type has mains, a
  sides system and a drinks system: the diner is burgers, fries and soda; the seaside
  is fish, vegetables and white wine. Proposed, not yet agreed: ingredient order only
  sets how a dish looks stacked, never refuses it; at most one prep step per
  ingredient; townspeople like and dislike ingredients, so variety pays. Still to
  answer: ingredient costs (per serving or restocked nightly), when the menu is set
  (nightly?), who names dishes, and whether menu size has a cap. This replaces the
  hard-coded burger flow (fridge, stove, plates).
- **Mood drives pay and stay.** Happy guests pay more and stay longer: secure income,
  but the table turns over slower, so a fast-food player may keep guests a little
  less comfortable on purpose.
- **The critic.** One critic per run, always the same townsperson in that run and
  unknown to the player unless they work it out. They come every fifth day (Friday;
  to confirm: days, not levels), are served like anyone, and rate service time,
  cleanliness, food quality and variety, then give stars out of 5. The review confirms
  or contradicts the rumours going round, and resets townspeople's opinions on what it
  rated: someone put off by dirt forgets it if the critic found the place clean. A good
  review brings more guests (which can backfire on a kitchen that is not ready); a bad
  one keeps them away.
- **Co-op: local, same screen first;** online later. Controller input today goes into
  the game as shared key presses (`game/controls.gd`), so co-op needs input per
  player: refactor that first.
- **Title screen: a placeholder** with Play, Settings and Quit. Accessibility comes
  later; meanwhile new interface should say things by shape as well as colour.
- **Banked:** the size of the lot is for the metagame (between runs); staff waits
  until after co-op; the name ("Regulars" is a working title) and the "Town Diner"
  subtitle are still open.
- Building happens between days only. Live building during service is not planned.
