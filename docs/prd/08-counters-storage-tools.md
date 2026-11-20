# PRD 8: Counters, storage and the tool tree

**Status:** built, all seven milestones (16 November 2026). What it built is in `docs/DESIGN.md` section 1.
**Size:** very large; build it in the seven milestones at the end (8.1 to 8.7), each mergeable.
**Needs:** nothing. **Touches:** `sim/catalog.gd`, `sim/pantry.gd`, `sim/menu.gd`,
`sim/prep.gd`, a new `sim/kitchen.gd` (cells, layers, slots), `game/main.gd`,
`game/station.gd`, `game/build.gd`, `game/scenery.gd`, `game/hud.gd`, `game/menu_screen.gd`,
tests, `docs/DESIGN.md`, `docs/STYLE_GUIDE.md`.

## Goal

Nothing in the kitchen is set dressing. Every piece is bought, can be sold, and does a
job: a work surface, a tool, or storage. Ingredients no longer come from a crate of their
own; they live in storage the player builds (counters, shelves, cabinets, fridges). Tools
sit on counters, and tools that do similar jobs form an upgrade tree.

## Decided (from the user, 16 November 2026)

| Topic | Decision |
| --- | --- |
| Stock amount | Unchanged: a flat fee per stocked kind per night, never runs out. A stocked kind now needs a storage slot. |
| Counters | The base of the kitchen. A counter says "I am using this cell". Tools go on top of counters, stove and fridge included. A stove on a counter changes the counter's look and use, but still works as a surface. |
| Double counter | More storage, one cell. It comes only from the counter's upgrade tree in the shop; a counter cannot be put on a counter (it is refused: "Something's already there"). |
| Sell anything | Every kitchen piece can be bought and sold, the starting counters included. |
| Shelf | Storage only, nothing on top, so it is smaller than a counter. |
| Chilled food | Must be stored in a fridge. Fridge level 1: one kind, lower half of the wall only. Level 2: two kinds, both wall layers, so nothing goes above it. |
| Wall layers | A cell against a wall has two layers: low (floor pieces) and high (wall pieces), so storage can climb the wall into a closet. |
| Tools | An upgrade tree, not equals. Each step is efficient (a bit better at the same jobs) or specialist (much better at one niche, or a new job). Opened by opening the shop with a piece in hand. |
| Grater | In, with shredded cheese (diner) and breadcrumbs to coat fish (seaside). |
| Double counter | An upgrade of the counter, bought from its tree; still one cell. A counter cannot go onto a counter. |
| New ingredients | In this PRD, with their jobs and trees. |
| Fridges | The specialist line of the counter. They store anything, chilled or not. |
| Hood | Bought and placed over a stove. A flag only for now (see "Later: floor mess"). |

## Agreed design

### One cell, three parts

Each kitchen cell holds at most:

1. **Base** (low layer): a *counter* (has a top, has storage below), a *shelf* (storage,
   no top, half depth so it reads smaller), or a *tall* piece (tall fridge, closet) that
   also fills the high layer.
2. **Top** (on a counter only): one tool (board, slicer, grater, stove, pot, fryer, a drink
   dispenser) or nothing. Every top can still hold one carried thing (a plate, a patty),
   like a bare counter does today. Hands that are empty take the thing first.
3. **High** (wall cells only): a wall cabinet (storage), an open wall shelf (storage), or a
   hood. A shelf low plus a shelf high draws as one closet.

Fridges are not a separate floor piece: a **level 1 fridge goes into a counter** (an
under-counter fridge; the top stays free for a tool), and a **level 2 fridge replaces the
counter** as a tall piece. A level 3 fridge, if wanted: three kinds, still one cell.

### Storage slots

| Piece | Kinds held | Chilled |
| --- | --- | --- |
| Counter | 1 | no |
| Double counter (from the counter's upgrade tree) | 2 | no |
| Low or high shelf, wall cabinet | 1 | no |
| Fridge level 1 (under-counter) | 1, any kind | yes |
| Fridge level 2 (tall) | 2, any kind | yes |

Chilled kinds (`"chilled": true` in `Pantry.ITEMS`) are listed under the trees below. Ready-
made tubs keep the chill of their ingredient. A drink dispenser is its own storage: it
holds its drink and needs no slot.

### Buying and placing stock

The shop gets a **Pantry** tab: one box per kind. Buying one puts a box in hand; placing it
in a free slot (a chilled kind only in a fridge slot) stocks that kind, and its nightly fee
starts. Picking it up and selling it stops the fee. The `crate_*` pieces go; `ready_*` tubs
become a ready version of the same box. The menu screen greys an item whose kind has no
slot ("Patty: needs a fridge").

### Taking from storage

E with empty hands at a cell: take what is on the top; else take from storage. A cell with
two or more kinds: each tap of E swaps what is in hand for the next kind, so tap, tap,
walk. A small row of icons over the cell names the kinds, as the crate signs do now.

### Upgrading (decided 16 November 2026)

Nothing is upgraded by buying a piece and placing it on top. At night, pick up a piece
(E) and open the shop (the usual shop key, Y, or the Shop button). With something in hand
the shop opens its **upgrade tree** instead: a screen like the shop, on blue blueprint paper with white lines. The
held piece sits on the left; its line forks to the right, one row per branch, and keeps
forking. A branch that leaves the screen ends in an arrow and the view scrolls to it.
Each node shows the piece, its jobs as tool icons with a quality pip, and the price of the
step (the new price less the old). Buying a node turns the held piece into it, in hand;
put it back down as usual. To shop, hands must be empty. Decor
pieces with tiers (fern, jukebox) get a short tree the same way. Selling pays back the piece's whole price as now. A node can
be bought only from its parent, so skipping steps means buying each step. The three
catalog tiers on tools go: efficient steps in the tree replace them.

Every step is one of two kinds, shown by its line:

- **Efficient** (straight line, same row): the same jobs, a bit better. Quality +0.15 on
  every job it does (*tunable*, `EFFICIENT_STEP`), stand-ins included. Cheap, about 1.5x.
- **Specialist** (a fork to a new row): one job much better (1.6, *tunable*
  `SPECIALIST`), or a new job that unlocks new ingredients, and the stand-ins fall away
  (0.4 or none). Dearer, about 2 to 3x. Taking one is a real trade.

Quality is the minigame's difficulty: 0.6 (a stand-in) is narrower and faster than tier 1
was; 1.6 is easier than tier 3 was, or plays itself (auto pieces).

### A sketch of the trees

`E` efficient, `S` specialist. Prices are first guesses. **New** marks a new job or
ingredient. Each base piece is bought in the shop; everything after it only in its tree.

**Cutting** (on a counter)
```
Chopping board $25  chop 1.0  slice 0.6
├─E Sharp knife $40  chop 1.15 slice 0.75 ─E Butcher block $65  chop 1.3 slice 0.9
├─S Slicer $60  slice 1.6  chop 0.6
│   ├─E Auto slicer $120  slice plays itself, no chop
│   └─S Grater $70  NEW grate 1.6  slice 0.6  ─E Rotary grater $110  grate 1.8
└─S Bread knife $45  NEW saw 1.6  chop 0.6
    └─S Juicer $90  NEW juice 1.6  ─S Blender $150  NEW blend 1.6 (and juice 0.6)
```
**Heat** (on a counter; the stove's surface still holds a thing)
```
Stove $50  grill 1.0  boil 0.6  fry 0.6
├─E Range $80  grill 1.15 boil 0.75 fry 0.75 ─E Two-hob range $130  two pans at once
├─S Char grill $110  grill 1.6, a "smoky" tag some guests like  (no boil, no fry)
├─S Stock pot $60  boil 1.6  grill 0.4 ─S Steamer $100  NEW steam 1.6
└─S Fryer $70  fry 1.6  grill 0.4 ─E Twin fryer $120  two baskets
```
**Pour** (on a counter; a dispenser stores its own drinks)
```
Soda fountain $40 (diner)  soda          Wine barrel $45 (seaside)  white wine
├─E Two-tap fountain $70  soda + cola    ├─E Wine rack $75  white + red
└─S Coffee machine $90  NEW coffee        └─S Beer tap $90  NEW ale
```
**Storage** (a counter is the base; fridges are its specialist line)
```
Counter $15  1 kind, unchilled
├─E Double counter $25  2 kinds ─E Long counter $45  3 kinds
└─S Under-counter fridge $50  1 kind, any (chilled or not), top stays free
    └─S Tall fridge $110  2 kinds, any; fills both wall layers, no top
        ├─E Tall fridge, glass door $160  3 kinds
        └─S Freezer $150  NEW frozen kinds (ice cream), 2 kinds
Wall shelf $10  1 kind, unchilled, high or low layer ─E Wide shelf $20  2 kinds
```

### New ingredients the trees unlock

| Job | Diner | Seaside |
| --- | --- | --- |
| grate | Shredded cheese (topping, dairy) | Breadcrumbs (a crumb coat on fish: fish + crumbs is a breaded fillet) |
| saw | Sourdough (bread, a main's base instead of a bun) | Crusty loaf (bread) |
| juice | Orange juice (drink) | Lemonade (drink, uses the lemon kind) |
| blend | Milkshake (drink, needs ice cream from a freezer) | Fruit smoothie (drink) |
| steam | Steamed corn (side, better than boiled) | Mussels (main, chilled) |
| pour | Cola, coffee | Red wine, ale |

Chilled: patty, cheese, shredded cheese, fish, calamari, mussels. Frozen: ice cream.
Anything unchilled may also go in a fridge.

### Balance notes

- An efficient path never unlocks food, so a player who only wants their menu faster
  climbs cheaply. A specialist path is how the menu grows, and every new dish needs one.
- A specialist loses its stand-ins, so a small kitchen that goes all-specialist needs
  more counters. That is the space cost.
- Two of the same job on one menu (chop and slice from one board) is the early game;
  splitting them across two counters is the mid game.

### First room

The fixed fixtures in `Scenery._fixtures` (hood, wall cabinets, jar shelf) become real
pieces placed at the start, each sellable: the hood over the stove, cabinets as storage
holding the starting kinds, the jar shelf as a high shelf. The sconce becomes a wall light
in Decor, or goes.

## Later: floor mess (its own PRD)

From the user: some tools and processes drop grease puddles on the floor, guests drop
mess puddles; puddles slow the chef and raise disgust within a radius; the player buys and
upgrades cleaning tools to clear them. Specified in [PRD 9](09-floor-mess.md); here the hood
is a flag (`has_hood(cell)`) ready for it, and each tree node carries a `mess` factor
(1.0 for now).

## Milestones

Build order, cross-PRD tandem work and merge rules: `docs/prd/README.md`, "Build order
for PRDs 8 to 10". Milestone ids below (8.1 and so on) are used there. Tests for this PRD
go in a new `test/unit/test_kitchen.gd`, not `test_sim.gd`, so parallel work does not
collide.

1. **8.1** `sim/kitchen.gd`: cells with base, top, high; slot counting; chilled rules;
   the tree data (nodes, efficient or specialist, `jobs`, `mess` factor, price); stand-in
   quality. Tests only. *Needs nothing.*
2. **8.2** Counters and tops: tools move onto counters, double counters, every counter
   sellable, starting kitchen rebuilt from pieces. Crates still work. *Needs 8.1.*
3. **8.3** Upgrade trees: the shop opened with a piece in hand, on blueprint paper; trees
   for the five existing jobs and the counter line (fridge nodes included); stand-in and
   specialist quality in the minigames. *Needs 8.2.*
4. **8.4** Storage: Pantry tab, boxes into slots, chilled kinds only in fridges (the
   under-counter fridge, reached through the counter tree), crates removed, menu and
   restock read slots, E takes and cycles. *Needs 8.3* (a fridge is only reached by
   upgrading a counter).
5. **8.5** Wall layer: cabinets, shelves, closet, tall fridge and its branches, hood,
   first-room fixtures as pieces. *Needs 8.4.*
6. **8.6** New jobs and ingredients (grate, saw, juice, blend, steam), their minigames and
   their trees' nodes. *Needs 8.5.*
7. **8.7** Art pass, demos, style guide "As built", `DESIGN.md`. *Needs 8.6.*

## Open questions

None (16 November 2026). Cleaning supplies and the no-chemicals-with-food rule are in
[PRD 9](09-floor-mess.md), not here.
