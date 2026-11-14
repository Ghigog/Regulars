# Product requirement docs

One file per piece of remaining work. Each is written so an agent with no history of the
project can build it. Read `CLAUDE.md` first, then the PRD, then only the code it points to.

| # | PRD | Size | Needs | Status |
| --- | --- | --- | --- | --- |
| 1 | [Recipes, ingredients and the menu](01-recipes-and-menu.md) | Very large, seven milestones | nothing | Ready; a few defaults to confirm (its "Open" list) |
| 2 | [The critic](02-critic.md) | Medium | 1 (quality and variety ratings) | Ready after 1 |
| 3 | [Mood drives pay and stay](03-mood-pay-and-stay.md) | Small | nothing | Ready |
| 4 | [Local co-op, chef 2](04-coop-chef-2.md) | Large | best after 1 | Ready |
| 5 | [Night cleaning](05-night-cleaning.md) | Small | nothing | Ready |
| 6 | [Reach display for finishes and rugs](06-reach-display.md) | Small | nothing | Ready |
| 7 | [More catalog pieces and themed shops](07-catalog-and-themes.md) | Medium | piece list signed off | Ready once the list is agreed |

## Suggested order

3, 5 and 6 first (small, independent). Then 1. Then 7, 2 and 4.

Co-op goes after the menu system on purpose: PRD 1 rewrites most of the cooking code in
`game/main.gd`, and PRD 4 moves per-chef state out of that same file. Doing 4 first means
doing that move twice.

**Almost every PRD edits `game/main.gd` and `game/hud.gd`.** Do not run two of them at the
same time in one checkout. Use a worktree each and merge one at a time, or build them in
sequence.

## Rules for every PRD

- `sim/` stays pure: no scene or node dependencies, every rule unit-tested there. `game/`
  only draws and wires it up.
- All existing tests pass before and after (139 on 13 November 2026; update the count in
  `CLAUDE.md` when it changes). Each PRD lists the new tests it needs.
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
