# Product requirement docs

One file per piece of remaining work. Each is written so an agent with no history of the
project can build it. Read `CLAUDE.md` first, then the PRD, then only the code it points to.

| # | PRD | Size | Needs | Status |
| --- | --- | --- | --- | --- |
| 1 | [Recipes, ingredients and the menu](01-recipes-and-menu.md) | Very large, seven milestones | nothing | Built (13 November 2026, all seven milestones) |
| 2 | [The critic](02-critic.md) | Medium | 1 (quality and variety ratings) | Built (13 November 2026) |
| 3 | [Mood drives pay and stay](03-mood-pay-and-stay.md) | Small | nothing | Built (merged) |
| 4 | [Local co-op, chef 2](04-coop-chef-2.md) | Large | best after 1 | Built (13 November 2026) |
| 5 | [Night cleaning](05-night-cleaning.md) | Small | nothing | Built (merged) |
| 6 | [Reach display for finishes and rugs](06-reach-display.md) | Small | nothing | Built (merged) |
| 7 | [More catalog pieces and themed shops](07-catalog-and-themes.md) | Medium | piece list signed off | Built (13 November 2026) |
| 8 | [Counters, storage and the tool tree](08-counters-storage-tools.md) | Very large, seven milestones | nothing | Built (16 November 2026, all seven milestones) |
| 9 | [Floor mess and cleaning](09-floor-mess.md) | Large, six milestones | 8, from 9.4 on | Built (16 November 2026, all six milestones) |
| 10 | [Staff](10-staff.md) | Very large, eight milestones | 8, 9 (per milestone) | Built (16 November 2026, all eight milestones) |
| 11 | [Paying the bill](11-paying.md) | Large, four milestones | 10 for 11.4 | Built (17 November 2026, all four milestones) |

## Suggested order

3, 5 and 6 first (small, independent). Then 1. Then 7, 2 and 4.

Co-op goes after the menu system on purpose: PRD 1 rewrites most of the cooking code in
`game/main.gd`, and PRD 4 moves per-chef state out of that same file. Doing 4 first means
doing that move twice.

**Almost every PRD edits `game/main.gd` and `game/hud.gd`.** Do not run two of them at the
same time in one checkout. Use a worktree each and merge one at a time, or build them in
sequence.

## Build order for PRDs 8 to 10

Written 16 November 2026, after all three were agreed. Each milestone has an id (8.1,
9.4, 10.6 and so on) and a *Needs* line in its PRD. Start a session per track below.

| Wave | Track A: PRD 8 spine | Track B: floor mess | Track C: staff | Can start when |
| --- | --- | --- | --- | --- |
| 1 | 8.1 kitchen sim | 9.1 floor-mess sim | 10.1 tolerances, then 10.2 staff sim | now |
| 2 | 8.2 counters and tops | 9.2 dirt in the room | | 8.1 / 9.1 merged |
| 3 | 8.3 upgrade trees | 9.3 slipping | 10.3 desk and CVs | 8.2 merged (for 10.3) |
| 4 | 8.4 storage | | 10.4 staff list | |
| 5 | 8.5 wall layer | | | |
| 6 | 8.6 new jobs and ingredients | 9.4 mops, hook, robot; then 9.5 treatments and trees | | 8.5 merged |
| 7 | 8.7 art and docs | 9.6 docs | 10.5 task board | 8.4 and 9.4 merged |
| 8 | | | 10.6 helpers in the room | 10.4 and 10.5 merged |
| 9 | | | 10.7 all-staff run, 10.8 docs | 8.6 merged |

**The critical path** is 8.1 > 8.2 > 8.3 > 8.4 > 8.5 > 9.4 > 10.5 > 10.6 > 10.7. Keep a
session on track A at all times; tracks B and C fill in around it.

**Why this order**
- Wave 1 is all pure `sim/` code in four new files (`kitchen.gd`, `floor_mess.gd`,
  `staff.gd`) plus 10.1 in `town.gd` and `guest_mood.gd`, so up to four sessions can run
  at once (10.1 and 10.2 split into two) with almost no overlap.
- PRD 8's milestones were reordered so the upgrade screen (8.3) comes before storage
  (8.4): chilled food has to live in a fridge, and a fridge is reached by upgrading a
  counter. Removing the crates before fridges exist would strand patties and fish.
- Dirt (9.2, 9.3) needs nothing from PRD 8: tool `mess` factors and the hood read as 1.0
  and absent until 8.3 and 8.5 merge. Mops need PRD 8's wall layer (the hook, the closet).
- The desk screen (10.3, 10.4) only needs tools on counters to list duties, so it runs
  beside PRD 8. The desk stays out of the shop until helpers can work (10.6).
- The task board (10.5) needs every kind of task to exist: fetching from storage (8.4),
  dirt, fallen people and mops (9.2 to 9.4). The all-staff run (10.7) needs every tool
  (8.6), since it is the check that no task is left without a duty.

**Working in tandem**
- One worktree per track, branched from the latest `main`. Merge one at a time, always
  track A first when two are ready, then rebase the others on `main` before they merge.
- Waves 2 to 7 all edit `game/main.gd` and `game/hud.gd`. That is why there are at most
  three tracks; do not split a track further.
- Each PRD's tests go in its own file (`test_kitchen.gd`, `test_floor_mess.gd`,
  `test_staff.gd`), not `test_sim.gd`, so merges do not collide there. Update the test
  count in `CLAUDE.md` after each merge, on `main`.
- Run `--headless --import` in every new worktree before anything else (`CLAUDE.md`).

## Rules for every PRD

- `sim/` stays pure: no scene or node dependencies, every rule unit-tested there. `game/`
  only draws and wires it up.
- All existing tests pass before and after (the count is in `CLAUDE.md`; update it there
  when it changes). Each PRD lists the new tests it needs.
- Every visible feature gets a `REGULARS_DEMO` hook in `_apply_demo` (`game/main.gd`), is
  listed in `CLAUDE.md`, and is checked with a screenshot at the times given.
- New interface follows `docs/STYLE_GUIDE.md` (paper and wood, toy diorama), reads at
  60 px for characters and 20 px for food and icons, and says things **by shape as well as
  colour**. Note any departure in the style guide's "As built" section.
- When done, move the item in `docs/DESIGN.md` from section 9 (decisions) or the "To add"
  lines into section 1 (what is in the game), written as built.
- Numbers marked *tunable* are starting values. Keep each as a named constant with a
  comment, in `sim/`.
- Text for thoughts, gossip and reviews is written lines picked by the simulation. No
  language model.
- Do not change a gameplay rule that a PRD does not name. If the build needs one, stop and
  ask.

## Decisions taken while writing these (13 November 2026)

| Topic | Decision |
| --- | --- |
| Ingredient stock | A flat fee per stocked ingredient per night. Stock never runs out. |
| What a guest orders | A main, plus a side and a drink when the menu has ones they like, all carried on one tray. |
| Menu entries | Single named items in three courses (mains, sides, drinks). No player-built combos. |
| Dish price | Automatic from ingredient cost, with a three-level setting per item: cheap, fair, dear. |
| First content | Both themes: diner (burgers, fries, soda) and seaside (fish, vegetables, white wine). |
| Starting kitchen | Empty, with a budget. The player builds the first kitchen and menu on night zero. |
| Tastes | Always hidden. Guests only eat what they like. The guest card shows how often they ordered each item; thoughts and gossip hint at tastes. |
| Nothing they like | They read the menu at the door and walk on. No strike; a small drop in opinion that friends hear about. |
| Prep steps | One minigame per tool: grill (timer), fry (timer, then a rest to cool), boil (start and leave), chop (hit the middle of a sweeping bar), slice (mash to a count), pour (hold, do not overfill), none. |
| Prep reward | Done well: a one-second burst of movement speed. Done badly: a one-second penalty. |
| Critic's review | A newspaper clipping with that night's receipt. Unsigned the first time; the first review names the critic, so later visits are a known table. |
| Mood and pay | Mood scales the bill itself (about -10% to +25%) and the eating time (about -20% to +50%). |
| Co-op: shared screens | Anyone opens the shop or options. The receipt and starting the day need both players to confirm. |
| Co-op: hints | One corner hint line per player, in their trim colour, worded for their own device. |
| Co-op: joining | Press Start on an unseated controller, at any time. |
| Catalog and themes | New one-cell pieces, a theme tag on catalog entries, and a theme picker at the start of a run. Multi-cell pieces are not included. |
