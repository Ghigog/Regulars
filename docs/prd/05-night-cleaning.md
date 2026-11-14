# PRD 5: Night cleaning

**Size:** small. **Needs:** nothing. **Touches:** `game/main.gd` (build-phase actions,
prompts), `game/hud.gd` (a build-phase note), tests.

## Goal

Mess carries over from one day to the next, and the night is when the player can deal
with it. A player who ends the day with a piled sink, an overflowing bin and uncleared
tables opens tomorrow with them, unless they clean up at night.

## How it works today

- Mess already persists: nothing resets `Station.dirty`, `count` or `dirty_age` between
  days (`start_day` in `game/main.gd` does not touch them). Tables, the sink and the bin
  all open the next day exactly as they closed.
- But the player **cannot clean at night**. In the build phase, Use is `build_interact`
  (pick up, place, build); the service actions (clear a table, wash up, take the bag
  out) live in the service branch of the use code, about lines 2225 to 2300.
- `dirty_age` only grows while the game ticks stations in service (line 2336).

> **Reading of the request.** The task list says "a dirty sink and bin stay dirty
> overnight, like tables do now". The code already does that for all three, so this PRD
> takes the missing part to be *cleaning during the night*. If the intent was only to
> confirm persistence, requirements 1 and 5 are all that is left.

## Requirements

1. **Persistence is a rule, with a test.** Dirty plates on tables, plates in the sink
   and scraps in the bin are unchanged by ending a day and starting the next. So is
   `dirty_age`: yesterday's mess is already old when the door opens, so guests notice it
   at once.
2. **Cleaning works in the build phase**, with the same actions, timings, sounds and
   carried items as in service: pick up a dirty plate from a table, put it in the sink,
   wash up, carry the bin bag out.
3. **Use decides by what the chef faces and holds:**
   - Empty build hand, facing a messy table, sink or bin: Use cleans. The prompt bubble
     says what it will do ("Clear table", "Wash up", "Take the bag out").
   - A messy piece cannot be picked up to move, or sold, until it is clean. Trying shows
     the usual no-go feedback and the line "Clean it first."
   - A clean piece is picked up to move, as now.
   - While the chef carries a dirty plate or the bin bag, the shop does not open and no
     piece can be picked up. Back does nothing to a carried plate (it is not a build
     hand).
4. **The mouse.** A click on a messy piece at night walks nothing and cleans nothing; it
   shows the prompt "Walk over and press Use". Cleaning is a chef action, as in service.
5. **A note in the build phase** when anything is dirty, in the same place and style as
   the other build notes: "Still dirty: 2 tables, the sink, the bin." It updates as
   things are cleaned and goes away when nothing is left. Use an icon as well as the
   text.
6. **Starting the day while carrying:** if the chef holds a dirty plate or the bag when
   the door card is flipped, they keep holding it into service.
7. **Mess does not age at night.** `dirty_age` stands still in the build phase.

## Out of scope

- Any new kind of mess, or mess that gets worse overnight (smell, pests).
- A hired cleaner or dishwasher (staff is banked until after co-op).
- Changing what guests think of mess during service.

## Tests

- End a day with one dirty table, a sink at `SINK_PILED` and a bin at `BIN_HOLDS`; start
  the next day; all three are unchanged and still count in the gross list (`_gross`).
- In the build phase, Use at a dirty table with an empty hand gives the chef a dirty
  plate and lowers `dirty` by one; Use at the sink then washes it.
- A messy table cannot be moved or sold; the same table can once cleared.
- The shop does not open while a dirty plate is held.
- `dirty_age` does not grow during the build phase.

## Demo and done

- `REGULARS_DEMO=night_clean`: build phase after a messy day, the note showing, the chef
  mid-way with a plate in hand. Shoot once at the note and once at a prompt bubble.
- `docs/DESIGN.md`: update the "To add: night cleaning" line in section 3 and add the
  rule to section 1.
