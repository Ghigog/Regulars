# PRD 9: Floor mess and cleaning

**Status:** agreed, not built (16 November 2026). Build after PRD 8.
**Size:** large; six milestones (9.1 to 9.6). **Needs:** only from 9.4 on: PRD 8
milestones 8.3 to 8.5 (tree screen, storage, wall layer). 9.1 to 9.3 can start now. **Touches:** a new `sim/floor_mess.gd`, `sim/cleaning.gd`, `sim/guest_mood.gd`,
`sim/critic.gd`, `sim/catalog.gd`, `sim/town.gd` (a messy trait), `game/main.gd`,
`game/guest.gd`, `game/player.gd`, `game/build.gd`, `game/fx.gd`, tests, docs.

## Goal

Dirt on the floor, made by cooking and by guests, that spreads, gets tracked around,
slows everyone and puts guests off. Cleaning it is a job a chef can take on full time in
co-op, and the tools for it have their own upgrade trees.

This is separate from the existing mess (dirty plates on tables, the sink pile, the bin,
`sim/cleaning.gd`), which stays as it is.

## Decided (from the user, 16 November 2026)

| Topic | Decision |
| --- | --- |
| Levels | Each floor cell holds dirt from 0 to 4. New dirt on a dirty cell grows it by one. At 4 the cell is fully covered. |
| Overflow | Dirt landing on a level 4 cell goes to a random cell around it (the eight neighbours) instead, under furniture included. |
| Under furniture | Dirt only gets under furniture by overflow. It cannot be cleaned until the restaurant closes and the furniture is moved. So furniture placement can shield cells, and a neglected puddle can spread where you cannot reach it until night. |
| Tracking | Anyone (guest or chef) who walks from a dirty cell to the next carries one level with them: the cell left loses one, the cell entered gains one. |
| Slowing | Everyone, guests included, is slowed by the level of the cell they stand on. |
| Slipping | At level 4 a guest can slip and stays down on that cell until helped up. A chef helps up fast; a nearby guest helps up, much more slowly. Very bad for the fallen guest, bad for witnesses within one cell. |
| Disgust | A puddle adds disgust to anyone who can see it (as sightlines do now). From level 3 it also smells: disgust within a set radius, seen or not. |
| Kitchen sources | Tools and processes drop grease, by common sense (frying most). A badly played prep drops more. Upgrades change it: some specialists are messier, some efficient steps are cleaner. The hood cuts a stove's grease. |
| Guest sources | Random at first; more likely when the guest is annoyed, for certain townsfolk, and for greasy food. Lands anywhere within a radius of the guest, except under furniture. |
| When to clean | During service (a chef can be the cleaner in co-op) and at night in the build phase, where moving furniture uncovers what is under it. |
| Tools | Mops to clear dirt; cleaners; a primer that may stop spills landing; a floor finish that adds speed and beauty, offsetting dirt on top of it. |
| Order | After PRD 8. |
| Chefs slip | Yes, at level 4, the same as guests. The other chef (or a guest, slowly) helps them up. |
| Treatments | Last one day of service. Laid at night; re-laid each night for their cost while switched on, like stocking an ingredient, until the player turns them off. |
| After a slip | The chance the guest walks out comes from how they already felt: low for one who loves the place, very high for one who already did not. |
| Chemicals and food | Never in the same cell, never in a fridge. It gives the player a reason to build a back room for cleaning supplies. |
| Robot sweeper | In. Like a real robot vacuum it drifts slowly towards mess and cleans it slowly. Manual cleaning, with a tool picked up (mop, sponge), stays the fast way. |

## Agreed design

### The numbers (all *tunable*, in `sim/floor_mess.gd`)

| Level | Looks like | Speed | Seen (disgust/s in sight) | Smell |
| --- | --- | --- | --- | --- |
| 1 | a few drops | 0.9x | small | none |
| 2 | a puddle | 0.8x | more | none |
| 3 | a big puddle | 0.65x | more | radius 2 |
| 4 | the whole cell | 0.5x | most | radius 2, stronger; slipping |

- **Slip:** each time anyone steps onto a level 4 cell, `SLIP_CHANCE := 0.25` (a chef
  0.15, *tunable*). The fallen guest's mood drops a lot (about a walkout's worth
  of strikes, *tunable*); each witness within one cell gets a smaller hit and a thought
  ("Did they just fall?"). Helping up: a chef presses E beside them, 1 second; a guest
  within one cell who is not seated walks over and takes 6 seconds. A fallen guest who is
  never helped gets up alone after 20 seconds, angrier. A fallen chef is helped up by the
  other chef, or gets up alone after 4 seconds. On getting up, a guest walks out with
  chance `lerp(0.9, 0.1, opinion)` (*tunable*): their opinion of the restaurant (town
  affinity and current mood, 0 to 1) decides it.
- **Tracking:** one level moves per step off a dirty cell. A fallen guest tracks nothing.
  Guests and chefs leave footprints on the cells they gain dirt on, for the look.
- **Grease (per prep done):** fry 0.5, grill 0.3, boil 0.15, chop and slice 0.1 (scraps),
  pour 0.1 (spills): the chance a level drops on the chef's cell or one beside the station.
  A bad prep doubles it, a good one halves it. A hood over a stove: x0.3. Each tool node's
  `mess` factor multiplies it (char grill 1.5, twin fryer with splash guard 0.7, auto slicer
  0.5, and so on, set in PRD 8's trees).
- **Guests (once per meal, when they finish eating):** base 0.15, x(1 + annoyance), x2 for
  a messy townsperson, x1.5 for a fried or meat dish. Lands on a random free floor cell
  within 2 of their seat.
- **The critic** reads floor dirt into the Cleanliness rating with the rest of disgust.

### Mopping

The mop lives in a **mop bucket** (a one-cell kitchen piece, sellable). E at the bucket
takes the mop; hands are full while holding it, so the cleaner is a role. E on a dirty
cell in front clears one level (0.6 s, held E repeats). The mop gets dirty: after 4
levels it spreads instead of clearing until it is rinsed at the bucket or a sink. At night
the same mop works, and furniture can be moved to reach the cells under it.

### Floor treatments

Laid with the floor drag at night, a price per cell, one treatment per cell, shown as a
sheen. Each lasts one day of service. A laid treatment stays switched on and is re-laid
every night for its price (the restock note lists it with the ingredients), until the
player lifts it or switches it off; then that cell is bare the next day.

- **Cleaner:** dirt on it mops off in one press regardless of level.
- **Primer** (specialist): a chance a level that would land here does not (40%). It still
  tracks in from other cells.
- **Finish** (specialist): +10% speed on it and a little joy as decor (like parquet), which
  offsets the slowing and disgust of dirt on top. Dirt shows more on it.

### Where cleaning supplies live

Cleaning things use PRD 8's storage, with one rule: **chemicals never share a cell with
food.** A cell that holds a cleaning kind cannot hold an ingredient in any of its slots, top
or high, and no cleaning kind goes in a fridge.

- **Treatments** (cleaner, primer, finish) are boxes, bought from the Pantry tab like
  ingredients and placed in a storage slot. A treatment cannot be laid or re-laid unless
  its box is stored somewhere. A low and a high shelf together (the closet) is the natural
  cleaning cupboard.
- **Hand tools** (mop, sponge, scraper, spill kit) each have a home they are taken from
  and put back in with E: the **mop bucket** (a one-cell floor piece, also where a mop is
  rinsed) holds a mop; a **wall hook** (a cheap high-layer piece, a wall cell only) holds
  one small tool (sponge, scraper, spill kit); a closet holds either. A tool put down
  anywhere else lies on the floor and is in the way.
- **The robot sweeper** has a **dock** (a one-cell floor piece). It goes back to charge
  when its run is done and when the day ends.

### The cleaning trees (from the shop with the piece in hand, as PRD 8)

```
Mop bucket + mop $20  clears 1 level a press, dirty after 4
├─E Sponge-head mop $35  clears 1 level, dirty after 6
│   └─E Flat mop $60  clears a whole cell a press, dirty after 8
│       └─E Floor scrubber $180  push along: clears every cell it passes, never dirty, slow to walk
├─S Wringer bucket $45  rinses itself: never dirty, clears 1 level
│   └─S Robot sweeper $300  a dock; the robot drifts slowly to the nearest dirt and clears a
│                           level every few seconds, during service and at night; anyone
│                           can trip on it (it counts as level 2 where it is)

Sponge $15  (lives on a wall hook) clears 1 level fast, dirty after 2; quick spot cleaning
├─E Scourer $25  clears 1 level fast, dirty after 4
├─S Grease scraper $40  kitchen grease only, whole cell a press, never dirty; no use on guest mess
└─S Spill kit $30  a level 4 cell becomes level 2 at once, three uses a day; helps a fallen guest up faster

Floor cleaner $3 a cell  (one-press mopping)
├─E Strong cleaner $5  also stops dirt tracking off the cell
├─S Primer $6  40% of dirt does not land  ─E Sealing primer $10  60%
└─S Floor finish $8  +10% speed, a little joy  ─S High gloss $15  +20% speed, more joy, dirt shows more
```

Hood (PRD 8) gets its own short tree: Hood $40 (grease x0.3) ─E Extractor $90 (x0.15, and
cuts the smell radius of kitchen dirt by one).

## Milestones

Build order and tandem work: `docs/prd/README.md`, "Build order for PRDs 8 to 10". Tests
for this PRD go in a new `test/unit/test_floor_mess.gd`. Until PRD 8 lands, a tool's
`mess` factor and the hood are 1.0 and absent: read them through one function so they
light up when 8.3 and 8.5 merge.

1. **9.1** `sim/floor_mess.gd`: levels, overflow, tracking, speed, slip, disgust by sight
   and smell, sources. Tests only. *Needs nothing.*
2. **9.2** Dirt in the room: drawn by level, footprints, slowing for chefs and guests,
   sources from prep and meals, disgust and the critic. *Needs 9.1.*
3. **9.3** Slipping: down, helped up, witnesses, the walkout chance. *Needs 9.2.*
4. **9.4** Mop bucket, wall hook, sponge and mop, in service and at night, uncovering
   cells by moving furniture; the robot sweeper and its dock. *Needs 9.3 and 8.5* (the
   wall hook is a high-layer piece; the closet is PRD 8 storage).
5. **9.5** Treatments (boxes in storage, the no-chemicals-with-food rule, re-laid
   nightly on the restock note) and the cleaning and hood trees. *Needs 9.4, 8.3 (tree
   screen) and 8.4 (Pantry tab and slots).*
6. **9.6** Demos, style guide "As built", `DESIGN.md`. *Needs 9.5.*

## Open questions

None (16 November 2026).
