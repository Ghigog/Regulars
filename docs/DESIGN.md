# Regulars: design notes

Working title. A restaurant survival game: PlateUp's round-by-round kitchen, the Sims'
building and people, RollerCoaster Tycoon's obsessive guest tracking.

This file records everything that is **not** in the current vertical slice, so nothing is
lost while the core loop is polished. Sections are ordered roughly by when to build them.

## 1. The vertical slice (what is in the game now)

An endless run. Each night you build the kitchen and write the menu; each day guests
arrive, read the menu, order, and you prep, assemble and serve their trays and get paid.
Survive as many days as you can; three walkouts in one day ends the run.

- Direct control of one chef (WASD, E/Space).
- **Ingredients** (PRD 1, `sim/pantry.gd`). Two themes of nine each. Diner: bun,
  patty, lettuce, tomato, onion, cheese, fries, corn cob, soda. Seaside: bread roll,
  fish fillet, calamari, lemon, courgette, pepper, new potatoes, green beans, white
  wine. Each has a tool, tags (meat, vegetable, bread, fish, fried, drink...), a worth
  (what it adds to a price) and a fee (what stocking it costs a night).
- **Stations.** Every ingredient comes from its own station in the room (a crate,
  sack, fridge, icebox, basket, barrel or the soda fountain, $15 to $45 in the shop's
  Kitchen tab), so a bigger menu needs a bigger kitchen. Each prep tool is its own
  station too: stove (grill, $50), fryer ($50), stock pot (boil, $35), chopping board
  ($25), slicer ($30). Pour happens at the drink's own station. Chopped ingredients
  and cheese can be bought ready-made (a steel tub of the prepped food, always plain,
  1.5x the fee: `READY_FEE`). Every station can be sold, the last stove included.
- **Tickets and trays** (`sim/tray.gd`). Taking a table's order puts a ticket for each
  guest who ordered on the rail along the top of the screen (oldest on the left, five
  shown, more counted on a last tab; each in the guest's shirt colour). The chef takes
  an empty tray from the tray stack and puts it on a counter or the pass: it takes the
  oldest ticket with no tray. Turning to it moves it to the next ticket (a tray with
  something on it only to a ticket for the same items). Ingredients go on in any order;
  the tray refuses one its ticket does not need, or a raw one that needs prep ("Grill
  it first"), and says what is missing ("Needs fries"). A finished tray is picked up
  and served at the guest's table; the bill is the sum of the item prices. After the
  meal the dirty tray goes to the sink and soaks until washed, one press each, back
  onto the stack. A guest who leaves tears their ticket off; a tray made for it keeps
  what is on it.
- **Prep minigames** (`sim/prep.gd`, gauges in `game/prep_widget.gd`). One per tool,
  each ending good, plain or bad: *grill* (the doneness dial: take it off in the green
  window), *fry* (the same, then two seconds draining on the rack before it can be
  picked up), *boil* (start it and leave it; done after five seconds, it waits and
  never burns, always plain), *chop* (a marker sweeps a bar three times: press in the
  notch; three hits good, two plain), *slice* (mash to six presses in 2.6 s and stop:
  exact is good, one to three over plain), *pour* (hold to fill, let go between 85%
  and full; overflowing is bad). Good, plain and bad give the ingredient a quality of
  1.0, 0.75 and 0.45; a pop over the tool says which by shape (star, dot, cross). A
  good result gives the chef a one-second burst of speed (1.5x, speed lines and a
  spinning star), a bad one a one-second penalty (half speed, a sweat drop and a
  wobble). Boil and no-prep ingredients give neither.
- **Quality.** A tray's quality is the average of its ingredients'; the guest's
  savour is that, raised by 0.1 for each ingredient they like, up to +0.3
  (`Menu.savour`). It sets the tip as before.
- **The menu screen** (`game/menu_screen.gd`, `sim/menu.gd`; at night, N, Back on a
  pad, or a click on the board by the door). A tent card with three columns: mains, sides and drinks.
  Each item is a named list of up to six ingredients (stacked in the order given; that
  only changes the look), with a live picture of the stack, a made-up name the player
  can replace (keys, the touch keyboard or a letter grid on a pad), a price level
  (cheap 0.8x, fair, dear 1.25x the summed worth; cheap is ordered more often), an
  "off tonight" switch and delete. A drink holds only drink ingredients. An item
  missing a stocked station or a tool is greyed with the reason ("No fryer", "Onion
  not stocked"). Below, tomorrow's stock: a switch per kind of ingredient station and
  the night's cost.
- **Stocking.** Each stocked ingredient station costs its fee every night, paid when
  the door card flips; an unstocked one costs nothing and gives nothing. A taped
  restock note on the build slip lists tomorrow's cost by station. The door will not
  flip with no makeable main or when the stock cannot be paid. Tonight's item names are
  chalked on the A-frame board by the door (`game/menu_board.gd`).
- **The empty start.** A run opens on night zero with $150 and a kitchen holding only
  the sink, the bin, the tray stack and the counters. Three hints lead the way, one at
  a time ("Buy an ingredient and a tool in the shop.", "Write a menu.", "Flip the door
  card to open."). Tests and most demos start from `test_kitchen()`: the theme's fixed
  main (diner Burger: bun and patty; seaside Fish roll: roll and fish) with its stations.
- **Seaside food.** Its own stations (a sea-blue icebox for fish and calamari, a
  wicker bread basket, a wine barrel, crates and sacks) and food models (salmon
  fillet, calamari rings, lemon wheels, courgette rounds, pepper strips, new potatoes,
  green beans, a stemmed wine glass). A dish in a bread roll shows as a side-on roll
  with its filling, a fish as a fish, so it never reads as a burger.
- **A dirty kitchen.** Three or more plates soaking pile up in suds. Every patty thrown
  away or burger scraped off goes in the bin; at four it overflows (it still takes more).
  "Empty bin" hands the chef a bag, which goes out of the front door ("Take out rubbish");
  carried, it counts as rubbish. Both are disgust sources (table below).
- **Night cleaning.** Mess carries over: plates on tables, the sink and the bin open the
  next day as they closed, and so does how old the mess is, so guests notice it at once.
  Mess does not age at night. In the build phase, with empty hands, E at a messy piece
  cleans it with the service actions ("Clear table", "Put in sink", "Wash up", "Take
  the bag out"); cleaning comes before "Pick up". A messy piece cannot be picked up to
  move or sell ("Clean it first."); the mouse cannot clean ("Walk over and press Use").
  While a dirty plate or the bag is carried, the shop stays shut and nothing is picked
  up; whatever is carried when the door card flips goes into service. A taped note over
  the build slip, with a stink cloud, lists what is left ("Still dirty: 2 tables, the
  sink, the bin."). Rules and tunables in `sim/cleaning.gd`.
- **Taking orders.** A seated guest first waits to order (a notepad in their thought
  bubble, "Waiting to order" on their card). With empty hands, E at the table takes
  the order ("Take order", or "Take 2 orders" for a group: one press takes the whole
  table). Only then do they wait for food, and their bubble shows what they ordered.
  Patience drains while they wait to order, 1.25x as fast as while waiting for food
  (`ORDER_PATIENCE_SCALE` 0.8 in `game/main.gd`); taking the order gives back 0.1
  (`ORDER_RELIEF`). Holding a tray at a table that has not ordered shows "Take order
  first" and E only says why (`ORDER_HANDS_FREE`; set it false to let the chef take
  orders with full hands). Taking an order comes before half price and the free meal at
  the same table. An order is data on the guest (`Guest.order`: `{main, side, drink,
  ticket}`, each an item or empty), chosen at the door by `Menu.group_order` (or by
  `order_for` in `game/main.gd` for a guest who came in another way), and serving
  matches the tray against its ticket. `REGULARS_DEMO=order`.
- **What guests order.** Each townsperson has hidden tastes: liked and disliked
  ingredient tags. A guest orders a main with nothing they dislike, plus a side and a
  drink only when one has something they like, all on one tray. Items with liked
  ingredients and cheap ones are picked more often. In a group, someone with no main
  orders a drink they do not mind, or nothing; the group walks on only if nobody finds
  a main. A guest who walks on stops at the board, thinks "Nothing I liked on the menu"
  and leaves: no strike, a small drop in opinion that friends hear about; the receipt
  counts them. Tastes are never listed: the guest card shows how often they ordered
  each item ("Orders:"), a guest reading a menu with three or more items of a kind they
  like says so ("So many things with vegetables. I love vegetables!"), a liked
  ingredient on the tray gives "Just how I like it", and gossip names what they
  praised. `REGULARS_DEMO=walkon`, `orders_card`.
- Grilled and fried food has doneness: the stove's radial dial has a green "perfect"
  window; pull it late and it is dry (plain, falling toward bad), leave it and it burns
  (thrown away). The patty and the fish change look as they go.
- Guests are named townsfolk with patience, disgust, joy and savour. These set the tip.
- Each day is busier and guests are less patient. Money carries across days.
- **Word of mouth is visible.** A visit that moves a guest's opinion says who they will
  tell or warn. The end-of-day clipboard has a town book (T): every townsperson's standing
  (five pips, from "Staying away" to "Loves you") and whether today moved it.
- **Half price.** With empty hands at the table of a guest whose patience is under half,
  E offers half price, once per visit: +0.35 patience, a little joy, +0.2 affinity, and
  they pay half the bill (the tip is worked out on the halved bill).
- **Free meal (comp).** The bigger apology, for a guest who is very unhappy: patience
  under 0.25 (`GuestMood.COMP_BELOW`) or Disgusted. The same E at their table offers it
  once half price is used up or not on offer, so a fed-up guest gets half price first and
  the free meal if they sink again; a disgusted but patient guest gets it straight away.
  +0.6 patience, +0.25 joy, -0.2 disgust (often enough to drop a stage, so they do not tell
  friends how dirty it was), +0.4 affinity, and each friend gets half that. They pay
  nothing, so no tip either. `REGULARS_DEMO=comp`.
- **Expecting a deal.** `Town` counts deals per person (`deals`: +1 half price, +2 free
  meal). At 3 they expect one: their card says "Expects a deal", they walk in thinking
  "They usually knock something off", a deal earns them only half the goodwill, and a
  full-price meal costs them 0.15 joy ("Full price this time? Hm"). Each full-price visit
  takes one off the count, so the habit wears off. Constants are at the top of
  `sim/town.gd`.
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
  - *Decor* (`sim/decor.gd`, `cheer_with_decor` in `game/main.gd`) works like
    RollerCoaster Tycoon scenery: a flat joy bonus when a guest sits down, not joy per
    second. Each piece's "joy" in `Catalog.ITEMS` is scaled by how close it is to the
    seat: on it (the floor or rug under the seat) 100%, beside it (within a cell) 50%,
    in view (further, in sight, within 3 cells; a fern 2 + tier) 20%. Nobody sits on a
    wall or a fern, so a finish or fern gives at most half. Each kind counts once, at
    its best; kinds add up to a cap of 0.35. Values: parquet 0.1, marble 0.2, rug 0.15,
    paint 0.08, striped 0.14, rose 0.2, fern 0.2 (+0.1 a tier). A table on a rug on
    parquet with a fern beside it gets 0.35, about what a fern gave over a sitting
    before (0.015 a second). The guest thinks of the piece that gave most ("Such a cosy
    rug"). If the room changes while they sit they get the difference; building is only
    between days, so that cannot happen yet.
  - *More pieces and themed shops* (PRD 7, 13 November 2026): every catalog entry may
    carry a `"theme"` (`diner` or `seaside`; none: sold in both), and the shop and
    `pick_catalog` only offer the run's theme (`Catalog.sold_in`, `Catalog.search`).
    Twelve one-cell pieces: floor lamp ($30, level 2, joy 0.12, reach 1, lit at night),
    flower stand ($15, 0.1, reach 1), coat stand ($20, 0.06, reach 1, "Somewhere for my
    coat"), and for the diner a jukebox ($120, level 4, 0.25, reach 4, three tiers) and a
    gumball machine ($45, level 2, 0.15, reach 2); for the seaside an aquarium (as the
    jukebox), a potted palm (the seaside's fern; the fern is now diner only, and each
    theme's room starts with its own) and a ship's lantern (as the gumball machine). A
    decor piece's reach is data (`"reach"` in `Catalog.ITEMS`, one more a tier) read by
    `Decor.reach`; the fern is no longer a special case (3 + tier - 1). Each has a thought
    line and shows reach marks while carried. Dining: a counter stool ($25, three tiers),
    a little round table with one stool, so only a guest alone sits there (the smallest
    free table that fits is chosen, so a single takes a stool first). Kitchen: a bin
    ($30, level 2) and a sink ($70, level 3), which are now catalog pieces like any other
    (the last of each cannot be sold), and a dish rack ($50, level 3): a sink with one
    beside it piles at 5 trays, not 3. Each sink and bin has its own mess and sightline,
    and the "still dirty" note counts them ("2 sinks").
- **Keyboard, controller or touch** (`game/controls.gd`, `game/player_input.gd`). Each
  device is a source ("keys" for keyboard and mouse, "pad:<id>" per controller, "touch")
  seated to a player; with one chef every source is player one's. Whichever device a
  player used last is their mode, so they can switch at any moment; every hint (the corner line, the
  prompt's keycap, the build slip, the shop's key line, the receipt buttons) is reworded
  for it. Controller: left stick or d-pad walk, A use (and confirm the receipt and the end
  screen), B back, X sell or remove, Y shop (town book on the receipt), LB/RB turn,
  Start options; in the shop the stick and d-pad browse. Touch: a joystick bottom left;
  down the right a big Use button that names the action, and above it, by night, Shop,
  Drop or Done, Turn, Sell, or Erase (with a build tool, Erase makes drags take things
  away); a small Menu button for options. Taps on the room work as clicks (pick a guest,
  place a piece, drag floors), and a touch on a control never reaches the room. Keys,
  pad buttons and touch buttons all become the same actions (use, back, turn, sell,
  shop, town, options, confirm, search, mute and the four browse directions), sent to the
  game as `act(player, action)`, so there is one set of rules; held actions (hold Use to
  keep laying floor) and movement are read per player. The options screen works from the keys and the pad: up and down (d-pad,
  arrows or the stick) choose a row (the tabs, each slider, the switch, Done), left and
  right turn a slider a tenth or switch tabs, A, E or Enter presses, B, Esc or Start
  closes. The chosen row gets an ink frame with a coral pointer, for keys and pad only.
  On touch the frame and key line go, buttons and slider grabbers grow to thumb size, and
  only the Menu button stays over the card. The chef cannot walk while it is open.
- **Reach marks.** While a piece with a reach is carried (a decor piece: its own reach, a fern 2 + tier cells; the bin:
  5; a fine floor, paint, wallpaper or a rug: `Decor.VIEW_RANGE`, 3), every seat gets a
  mark for the share of the piece's joy it would get, worked out by the same sight rule
  the decor bonus uses (`Decor.nearest` and `Decor.share`), so the marks are always true:
  a white-rimmed green square on it (all its joy: the seat is on this floor or rug), a
  big green disc beside it (half), a small pale green disc in view (a fifth), red if not
  reached (out of range or behind a partition). A seat whose decor joy is already at
  `Decor.CAP` gets a white "full" tick: more decor adds nothing there. The fern and the
  bin wash the floor with a pale square for their reach and a brighter 3 x 3 for the
  cells beside; a rug washes `VIEW_RANGE` round its six cells. Floors and finishes have
  no square, only the seat marks. A floor drag marks the whole rectangle; a paint or
  paper drag the whole wall run, each face cheering only its own side. Green means
  "reached", so for the bin green is the bad news. One gap: a floor dragged out past the
  room's edge takes that outer wall down once laid, but the marks are worked out with the
  wall still up, so a seat that would then see the new floor shows red.
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
- **Tier effects:** faster stove, a fern that gives more and is seen from further, a tier 2+ table gives seated guests
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
- **The line at the door.** Guests walk down the street from beyond the end of the
  line and wait in single file along the wall, 0.8 m apart, starting a step up from
  the doorway so people leaving can pass; a long line runs on up the street. Each has
  their own place and the line steps up as the front goes in. Friends arrive in single
  file. Walkers stay on the grid but stop for someone just ahead going their way (for a
  second at most) and step round anyone else, so nobody walks through anybody. Guests
  walking out of the line go one after another, onto the outer half of the pavement.
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
- **Mood drives pay and stay.** When the food reaches the table the guest's comfort is
  read once and kept: `0.6 joy + 0.4 patience - felt disgust`, 0 to 1 (savour is left
  out: comfort is about the room and the service). It scales the bill from x0.90 to
  x1.25 ("they ordered extras"), rounded, at least $1, and the eating time from x0.80 to
  x1.50 (5 s base). So a cosy room earns more per guest but turns tables slower. Order on
  the bill: base price, mood scale, then half price or a free meal; the tip is on the
  final bill, XP is unchanged. A guest who expects a deal is let down whenever they had
  no deal, whatever the scaled bill. At 0.75 and up they think "I could stay here all
  day" (or a variant); at 0.3 and under, "Let's eat and go". The guest card shows
  "Paying $N" once served, with "ordered extras" or "in a hurry". All in `GuestMood`
  (`comfort`, `bill_scale`, `stay_scale`, `pay_for`). `REGULARS_DEMO=mood`. Comfort does
  not change how much mess a guest leaves.
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
| Kindness / discounts | `GuestMood.offer_discount` / `offer_comp`, `Town.record_kindness` / `paid_full_price` | **Built**, see section 1: half price, free meals, and guests who come to expect them. |
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
  bin), with night cleaning: mess stays overnight and is cleaned in the build phase
  (section 1).
- **Word of mouth**: each guest has an affinity (-1..1) that sets their chance to visit.
  A visit moves it; 40% of the change spreads to their friends.
- **Built**: regulars with a visit streak, grudges (section 1).
- **Built**: groups arriving together (section 1).
- **Built**: stay length and bill driven by mood (section 1). Parked: a second round
  (dessert, second drink). **Built** (PRD 1, section 1): tastes (liked and disliked
  ingredients, never shown), ordering from the player's menu, walking on when nothing
  suits, order counts on the guest card and taste hints in thoughts and gossip.
  **To add**: reviews (PRD 2, the critic).
- **Discounts and comps** (built, section 1): half price, a free meal, and guests who
  come to expect a deal.

## 4. Building (Sims layer)

- **Nightly crate** (parked by decision): after each day, pick one of two blueprints.
  Place it, or shelve it for two days and it returns one tier higher (max tier 3).
- **Catalog** (built): buy furniture with money, gated by XP level. Starting list:
  partition wall $10, counter $15, fern $20, table for two $40 (level 2), booth $60
  (level 2), stove $80 (level 3), table for four $90 (level 3). Each piece fits one cell
  and keeps its seats on the cells beside it: the booth has a bench either side (seats two;
  guests get a small joy bump, "A booth! How cosy"), the table for four a chair on every
  side, so a group of four can come once one is placed. Booth and table for four come in
  three tiers like the table for two. *Built* (PRD 7): twelve more one-cell pieces and a
  shop that sells by theme (section 1, *More pieces and themed shops*). To add: more
  pieces after playtesting (a booth seating four over two cells needs multi-cell
  footprints), wall-mounted pieces, pictures on the cards.
- **Floors, walls, doors, archways** (built, section 1): `sim/floorplan.gd` holds the
  plan; `Scenery.build_room` draws it. Ceilings are not planned (the camera looks down).
- **Two currencies**: money (earned per day) and XP (10 per meal plus the tip; 100 per level).
- **Built**: moving, selling and rotating furniture (section 1).
- **Built**: floor and wall finishes that cheer seated guests, and movable rugs (section 1).
- **Built** (PRD 7): themes that change the catalog. **To add**: buying more lot.

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
- **Costs**: *built* (PRD 1): a nightly stock fee per stocked ingredient station
  (ready-made at 1.5x), on the restock note and the receipt's STOCK line; prices come
  from ingredient worth and a cheap/fair/dear level. **To add**: wages, rent that rises
  with the location.
- **Starting money**: $150 on night zero, enough for one simple main with change
  (`Ledger.money`).

## 7. Run structure

- **Theme** chosen at the start of a run: *built* (PRD 7). After Play, a card offers the
  diner ("Burgers, fries and soda") and the seaside ("Fish, vegetables and white wine"),
  each with a swatch of its room; keys and pad move the title's ink frame, touch taps,
  Back returns. The choice holds for the run (a different theme reloads the scene so the
  room is built for it), the last one is remembered (`user://regulars_theme.cfg`) and
  chosen to start with, and starting over after a game over shows the card again (the
  title is still skipped). `REGULARS_THEME` stays as a developer switch that skips it.
  **Location** (the town's size and tastes) is not chosen: Dylan decided the picker
  chooses the theme only.
- **Menu growth**: *built* (PRD 1): the player writes the menu each night from the
  stations they own; new dishes need new ingredient and tool stations (grill, fry,
  boil, chop, slice, pour). Two themes have their content (diner, seaside); the theme
  is picked on the theme card at the start of a run (PRD 7).
- **Night zero**: *built*: the run opens on an empty kitchen and $150; the first
  ingredient, tool and menu are the player's.
- **Local co-op**: input is already per player (see section 9); a second chef is the next step.
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
  - *Built* (PRD 7): a theme picker in the game, after Play on the title.
  - Hired staff (server, dishwasher, host), co-op chefs 2 to 4 (trim colours exist),
    future dishes, awning and photo view (the floor lamp is built, PRD 7).
  - A bundled hand-lettered font (the HUD uses a rounded system font).
  - The open items: the real title screen composition, colour-blind support, the "Town
    Diner" subtitle.
- Sound effects are synthesised placeholders (`tools/make_sfx.py`). Later: real foley.
- Music is real: `Daytime` during service, `Nighttime` on the receipt and in the build
  phase, `Closed` once at game over, cross-faded. `Intro` loops on the title screen. The old synthesised `assets/sfx/music.wav` is no longer played. Later: music per theme.

## 9. Decisions (13 November 2026)

Not built yet, except where marked; this is the agreed direction for future sessions.

- **Order-taking is a step.** *Built (section 1)*, now with the menu. The chef walks to
  the table to take the order before cooking. For the menu below, `order_for(guest)` in
  `game/main.gd` is the one place that picks a dish from the player's menu; the guest
  stores it (`Guest.order`), the bubble draws its icon and serving checks the dish in
  hand against it. A guest whose order is a dish not yet cooked just keeps waiting.
- **Recipes, ingredients and a menu the player designs.** Every dish is data: a recipe
  is a list of ingredients (burger: bun, patty, salad, cheese; salad: lettuce, tomato,
  onion). Each ingredient comes from a station in the room dedicated to it, so a
  bigger menu needs a bigger kitchen. Some ingredients can be bought ready-made
  (prefab salad) as shop upgrades that save prep. The player picks which ingredient
  stations to stock and writes their own menu from what they can make (only
  cheeseburgers, say), and guests order from it. Every restaurant type has mains, a
  sides system and a drinks system: the diner is burgers, fries and soda; the seaside
  is fish, vegetables and white wine. This replaces the hard-coded burger flow
  (fridge, stove, plates). *Built (section 1, PRD 1)*: tickets and trays, a station
  per ingredient and per tool, prep minigames with a burst and a penalty, the menu
  screen, nightly stock, tastes and walking on. Agreed details:
  - *Ingredients are restocked each night* and cost money. The build phase shows a
    note with what tomorrow's restock will cost, so the player can plan, or take a
    dish off the menu for a night to save on it.
  - *The menu is set each night.* The player may change the menu or the ingredients
    they stock, or just carry on with what they had.
  - *The player names each dish*, and guests order it by that name ("Stupid Burger").
  - *No limit on menu size* for now (a dish that is one slice of cheese is allowed).
  - *Ingredient order only sets how a dish looks stacked*; it never refuses one.
  - *At most one prep step per ingredient*, and some need none (used as they are).
  - *Each townsperson likes and dislikes ingredients*, so a varied menu pays off.
  - *Decided while building (13 November 2026)*: each tool is its own station; the
    ready-made ingredients are the chopped ones plus cheese; an empty tray put down
    takes the oldest ticket without one; boiling never gives the burst; a group walks
    on only if nobody has a main; every station can be sold, the last stove included.
- **The critic.** One critic per run, always the same townsperson in that run and
  unknown to the player unless they work it out. They come every fifth day (each day
  is a working day, so day 5 is Friday; there are no weekends), are served like anyone, and rate service time,
  cleanliness, food quality and variety, then give stars out of 5. The review confirms
  or contradicts the rumours going round, and resets townspeople's opinions on what it
  rated (cleanliness, speed, quality, variety), and only that: someone put off by dirt
  forgets it if the critic found the place clean. A good
  review brings more guests (which can backfire on a kitchen that is not ready); a bad
  one keeps them away.
- **Co-op: local, same screen first;** online later. Input is now per player (done
  13 November 2026): `Controls` seats each device to a player index, keeps a
  `PlayerInput` per player (device in use, stick, held actions, touch erase) and calls
  `game.act(player, action)`. Adding chef 2 means `controls.seat("pad:1", 1)`, a second
  `Player` in `chefs`, and moving the per-chef state below out of `main.gd`.
  - *Per player*: the chef (position, facing, what they carry), the build hand (the
    piece or tool held, its facing, the moving flag), the drag, the ghost and its
    no-go cross, the reach marks, the station cursor and prompt bubble, the paint-held
    spot, mouse aim (the mouse and keyboard player only), touch erase, the hint wording
    (each player's device). Already split: device mode, stick, held actions, erase.
    Still in `main.gd` as one: `hand`, `_drag`, `_aim_mouse`, `_mouse_point`,
    `_last_paint`, the ghost, the cursor and prompt (they read `player`).
  - *Shared*: the phase and the day, money and the ledger, the shop (one open at a time;
    whoever opens it browses), the options screen (pauses everyone), the receipt and
    town book, the door, the plan and the room, guests, music and camera.
  - *Open*: who may open the shop or confirm the receipt (anyone, today); hints on one
    screen for players on different devices (today they follow player one); how a pad
    joins (press Start?).
- **Title screen: a placeholder** with Play, Settings and Quit. Accessibility comes
  later; meanwhile new interface should say things by shape as well as colour.
  *Built* (`game/title.gd`): shown once a launch, before the night before day 1 (starting
  over after a game over skips it). The peg-doll logo over the room, dimmed; Play,
  Settings (the options screen) and Quit on a paper card. Keys and pad move an ink frame
  with a pointer tab (shape, not only colour); touch taps the buttons, which grow. Quit
  is left off on phones and the web.
- **Decor works like RollerCoaster Tycoon scenery:** a flat bonus by proximity, not
  joy per second. A guest seated on a rug or a fine floor gets the most, one seated
  beside nice walls or a fern less, and one who can only see them least. Built: see
  *Decor* in section 1.
- **Free meals** (built): the proposed numbers are accepted.
- **Selling the last table for two** stays refused even when the room has a booth or
  a table for four, for now.
- **No language model for townspeople** (dropped): a small local model is too heavy for
  phones. Thoughts, gossip and reviews stay written lines chosen by the simulation.
- **Banked:** the size of the lot is for the metagame (between runs); staff waits
  until after co-op; the name ("Regulars" is a working title) and the "Town Diner"
  subtitle are still open.
- Building happens between days only. Live building during service is not planned.
