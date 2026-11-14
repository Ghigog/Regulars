# PRD 7: More catalog pieces, and themes that change the shop

**Size:** medium (mostly art). **Needs:** the piece list below signed off by Dylan
before any art is built. **Touches:** `sim/catalog.gd`, `sim/decor.gd`, `game/build.gd`,
`game/scenery.gd`, `game/hud.gd` (shop, theme picker), `game/title.gd`, `game/main.gd`,
`docs/STYLE_GUIDE.md`, tests.

## Goal

Make browsing the shop worth it, and make the two themes feel like different
restaurants: the diner and the seaside sell different things, and the player picks a
theme at the start of a run.

## Decided

- New pieces fit **one cell**. Multi-cell footprints (a booth for four over two cells)
  are not in this PRD.
- Catalog entries get a **theme tag**; the shop only lists what the run's theme sells.
- A **theme picker** at the start of a run replaces the `REGULARS_THEME` environment
  variable as the normal way to choose.

## How it works today

- `Catalog.ITEMS` (`sim/catalog.gd` line 17): about 20 entries with `name`, `price`,
  `level`, `category` (Kitchen, Dining, Decor, Build), `tiers`, optional `joy`, `tool`,
  `finish`, `blurb`, `up`. `Catalog.search(query, category)` feeds the shop.
- Themes are a re-skin of one kit: `Scenery.THEMES`, `Scenery.theme_id` (`diner` or
  `seaside`), set from `REGULARS_THEME` at `game/main.gd` line 484.
- Decor joy and reach: `sim/decor.gd`. Only the fern has a reach by tier.
- The title screen (`game/title.gd`) has Play, Settings and Quit; Play goes to the night
  before day 1.

## Requirements

### 1. Theme tag

1. An entry may carry `"themes": ["diner"]` (or `["seaside"]`). No tag means sold in
   every theme. Add `Catalog.sold_in(id, theme)` and a `theme` argument to `search`.
2. The shop lists only what the current theme sells. Level and money gates are
   unchanged.
3. Catalog stays pure: the theme id is passed in, never read from `Scenery`.
4. PRD 1 uses the same tag for ingredient stations (burger stations in the diner, fish
   stations at the seaside). Whichever PRD lands first adds the tag; the other reuses it.

### 2. New pieces

**Proposed list. Dylan to confirm, cut or add before art starts.** Prices and levels
are *tunable*. Every piece needs a model in `game/build.gd` that reads at about 60 px,
follows the palette roles, and is noted in the style guide.

| Piece | Category | Theme | Price | Level | What it does |
| --- | --- | --- | --- | --- | --- |
| Floor lamp | Decor | both | 30 | 2 | Joy 0.12 beside; a warm light at night. |
| Flower stand | Decor | both | 15 | 1 | Joy 0.10, short reach (1). The cheap starter decor. |
| Coat stand | Decor | both | 20 | 1 | Joy 0.06; guests at the nearest table think "Somewhere for my coat". |
| Jukebox | Decor | diner | 120 | 4 | Joy 0.25, reach 4. Three tiers. The diner's showpiece. |
| Gumball machine | Decor | diner | 45 | 2 | Joy 0.15, reach 2. |
| Aquarium | Decor | seaside | 120 | 4 | Joy 0.25, reach 4. Three tiers. The seaside showpiece. |
| Potted palm | Decor | seaside | 20 | 1 | The seaside's fern: same numbers and tiers, and the fern is tagged diner. |
| Ship's lantern | Decor | seaside | 45 | 2 | Joy 0.15, reach 2. |
| Counter stool | Dining | both | 25 | 1 | One seat at a small high table, for guests who come alone. Three tiers. |
| Second bin | Kitchen | both | 30 | 2 | Another bin (the first is a fixture and cannot be sold). |
| Dish rack | Kitchen | both | 50 | 3 | The sink takes two more plates before it looks piled. |
| Second sink | Kitchen | both | 70 | 3 | Another place to wash up. |

5. Decor pieces use the existing rules: flat joy by distance (`Decor.band`), the cap,
   line of sight. A piece's reach comes from data (`"reach"` on the entry) through
   `Decor.reach`, so the fern stops being a special case. Each new decor piece shows the
   reach marks while carried, like the fern.
6. Each new decor piece gets one or two thought lines in `Decor.THOUGHTS`.
7. The counter stool needs seating for one: check `Town.make_groups` and the seating
   code hand a single guest to a one-seat table, and never a pair.
8. Second bin and second sink: the nearest one is used; each has its own mess, its own
   sightline and its own entry in the "still dirty" note (PRD 5).
9. Every piece can be moved, turned and sold for half, like existing ones.

### 3. Theme picker

10. After Play on the title screen, a card offers the themes: a name, a short line
    ("Burgers, fries and soda" / "Fish, vegetables and white wine") and a small picture
    or swatch of the room. Keys and pad move the same ink frame with a pointer tab used
    on the title screen; touch taps. Back returns to the title.
11. The choice sets `Scenery.theme_id` before the room is built and holds for the run.
12. Starting over after a game over shows the picker again (the title is still skipped).
13. `REGULARS_THEME` stays as a developer override: when set, the picker is skipped.
    Screenshot demos keep working without change.
14. The last theme chosen is remembered and preselected next time.

## Out of scope

- Multi-cell pieces, wall-mounted pieces (pictures, neon signs), pictures on shop cards.
- New themes beyond diner and seaside.
- Buying more lot, music per theme.
- Menus and ingredient stations per theme: that is PRD 1.

## Tests

- `Catalog.search` with a theme returns untagged entries and that theme's entries, and
  none of the other theme's.
- `Decor.reach` reads the entry's reach; the fern's reach by tier is unchanged.
- Every new entry has a name, price, level, category and blurb, and a model that builds
  without error (a loop over `ITEMS` calling the station builder).
- A single guest can be seated at a counter stool; a pair cannot.
- With a dish rack, the sink is piled at `SINK_PILED + 2`.
- The picker sets the theme; with `REGULARS_THEME` set it is skipped.

## Demo and done

- `REGULARS_DEMO=picker` (the theme card), `build_new` (a room with every new piece
  placed, once per theme), and the existing `build` to check the shop lists by theme.
- `docs/STYLE_GUIDE.md`: each new model under "As built", checked against the nearest
  concept sheet in spirit.
- `docs/DESIGN.md`: update section 4 ("more pieces", "themes that change the catalog")
  and section 8 ("a theme picker in the game").

## Open

- **The piece list above** is a proposal, not a decision.
- **Should the theme picker also choose a location** (town size and tastes, as section 7
  of the design notes describes)? Default: no, theme only.
