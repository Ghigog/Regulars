# PRD 6: Reach display for floors, wall finishes and rugs

**Size:** small. **Needs:** nothing. **Touches:** `game/main.gd` (reach marks),
possibly `sim/decor.gd`, `docs/STYLE_GUIDE.md`, tests.

## Goal

While the player holds a fine floor, a paint or wallpaper, or a rug, the room shows
which seats it would cheer and how much, the same way a carried fern does. Today the
effect of these pieces only shows up later, in guests' thoughts.

## How it works today

- **Decor rules** (`sim/decor.gd`): a guest gets a flat joy bonus on sitting down. The
  share depends on distance: `ON` (1.0, the floor or rug under the seat), `BESIDE` (0.5,
  within a cell, or the wall the seat is against), `IN_VIEW` (0.2, up to `VIEW_RANGE` = 3
  cells, in sight). Total decor joy is capped at `CAP` (0.35). Partitions block it.
- **What a seat really gets** is worked out by `decor_near(cell)` and `decor_bonus(cell)`
  in `game/main.gd` (about line 1884).
- **Reach marks exist for the fern and the bin only:** `range_of(id, tier)`,
  `seats_reached(cell, reach)` and the mark drawing just below them (about line 1915).
  A pale square shows the area; each seat gets a mark: strong green for beside, small
  pale green for in view, red for not reached.
- Catalog entries with a `joy` value that have no display: `floor_parquet`,
  `floor_marble`, `paint`, `paper_stripe`, `paper_rose`, `rug`.

## Requirements

1. **Marks appear while any piece with joy is in the build hand**, at the spot it would
   be placed: the six entries above, whether newly bought or (the rug) being moved.
   Plain tile, planks, walls, doors and archways have no joy and show nothing.
2. **The marks tell the truth.** The share shown for a seat must be the share that seat
   would get from this piece once placed, by the same rules `decor_near` uses, including
   line of sight. Share the code, do not copy it: the simplest way is one function that
   answers "what band does this seat get from this piece at this spot", used both by
   `decor_near` and by the display.
3. **Three levels now, not two,** each different in shape as well as colour:
   - *On* (full joy): the seat is on this floor tile or this rug. New mark. Suggested: the
     strong green mark with a ring round it, or a filled square instead of a dot.
   - *Beside* (half): the existing strong green mark.
   - *In view* (a fifth): the existing small pale green mark.
   - *Not reached*: the existing red mark.
4. **Floors laid by dragging.** While a floor drag is in progress, the marks show the
   effect of the whole rectangle being laid, not only the tile under the cursor.
5. **Wall finishes.** A finish goes on a wall length, not a cell. A seat against that
   length is *beside*; seats that can see it within `VIEW_RANGE` are *in view*. A wall
   has two faces: only seats on the painted side count, as in `decor_near`.
6. **Seats already at the cap.** A seat whose decor joy is already at `Decor.CAP`
   gains nothing from more. Show these with a small "full" tick on the mark, so the
   player does not pay for nothing. The tick is a shape, not a colour change.
7. **No pale area square for floors and finishes.** The fern's square shows a radius
   from one point; a floor or a wall has no single centre. Show seat marks only. The rug
   keeps a square, sized to `VIEW_RANGE`.
8. **Works with every input.** Mouse aim, the chef's facing cell (keys and pad) and
   touch all place the same marks. In co-op (PRD 4) the marks belong to the player
   holding the piece; write the code so it takes the hand and spot as arguments instead
   of reading the single `hand`.

## Out of scope

- Showing the reach of finishes and rugs that are already placed, when nothing is held.
- Changing any decor number.
- Pictures on the shop cards.

## Tests

- For each of floor, rug and finish: for a small room with seats on, beside, in view,
  out of range and behind a partition, the band the display reports equals the band
  `decor_near` gives after the piece is really placed.
- A floor drag over a rectangle marks every seat on it as *on*.
- A seat at the cap is flagged full.
- A finish on one face of a wall does not mark seats on the other side.

## Demo and done

- Three hooks beside the existing `build_range`: `build_range_floor` (a marble drag in
  progress), `build_range_rug`, `build_range_paint`. One screenshot each.
- `docs/STYLE_GUIDE.md`: describe the new *on* mark and the *full* tick under "As built".
- `docs/DESIGN.md`: update the "Reach marks" entry in section 1 and remove the "not
  built" line in section 4.
