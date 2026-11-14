# PRD 4: Local co-op, chef 2

**Size:** large (mostly a careful refactor). **Needs:** best built after PRD 1, which
rewrites the cooking code this PRD has to move. **Touches:** `game/main.gd`,
`game/player.gd`, `game/controls.gd`, `game/player_input.gd`, `game/hud.gd`, tests.

## Goal

A second chef can join on the same screen and do everything the first can: cook, serve,
clean, and build at night. Two players, one restaurant, one wallet.

## Decided

- Local, same screen. Online is later.
- **Two chefs** in this PRD. Trim colours exist for up to four; write nothing that
  assumes exactly two, but ship and test two.
- **Shared screens:** either player can open the shop or the options screen. **The
  receipt and starting the day need both players to confirm.**
- **Hints:** one corner hint line per player, in that player's trim colour, worded for
  that player's own device. The prompt bubble over each chef uses that chef's device.
- **Joining:** press Start on an unseated controller, at any time, day or night.

## How it works today

- Input is already per player. `Controls` (`game/controls.gd`) seats each device source
  to a player index with `seat(source, p)`, keeps a `PlayerInput` per player (device in
  use, stick, held actions, touch erase) and calls `game.act(player, action)`
  (`game/main.gd` line 2495). `act` returns early when `p >= chefs.size()`.
- `chefs: Array[Player]` exists and holds one chef; `player` is chef 1.
- **Still one of each in `main.gd`, read from `player`:** `hand` (line 82),
  `_aim_mouse`, `_mouse_point`, `_drag`, `_last_paint`, `_ghost` and `_ghost_key`,
  `_cursor`, the prompt bubble, the reach marks, and `shopping`.
- On a pad, Start is already the Options button (`controls.gd` line 37).

## Requirements

### 1. Move per-chef state out of `main.gd`

1. Everything in the "per player" list belongs to the chef, not the game: position,
   facing, what they carry; the build hand (piece or tool, facing, the moving flag); the
   drag; the ghost and its no-go cross; the reach marks; the station cursor and prompt
   bubble; the paint-held spot; mouse aim (the keyboard-and-mouse player only); touch
   erase; hint wording. Put it on `Player` or on a small per-chef object the game holds
   by index.
2. Every function that reads `player` or `hand` takes a player index or a chef instead.
   After this step there is no code path that assumes chef 1, apart from the `player`
   alias kept for tests and demos.
3. **Do this as its own commit, with one chef, before adding the second.** All existing
   tests must pass unchanged at that point. This is the bulk of the work and the place
   regressions will hide.
4. Shared, and staying in the game: phase and day, money and the ledger, the shop, the
   options screen, the receipt and town book, the door, the plan and the room, guests,
   music, camera.

### 2. Joining and leaving

5. Pressing Start on a controller that is not seated seats it as the next free player
   and drops a chef in at the door, with that player's trim colour and a short pop
   effect and sound. A line says "Chef 2 joined."
6. Start on a seated controller opens Options, as now.
7. Works on the title screen, at night and in service. A chef who joins mid-service is
   simply an extra pair of hands.
8. **Which device is player one:** whichever device is used first, as now. A second
   controller, or the keyboard when player one is on a controller, joins the same way
   (Enter on the keyboard). Touch is single-player only: no join by touch.
9. **Leaving:** hold Start for one second, or the controller is unplugged. The chef
   walks out of the door and is removed. What they carried: food or a dirty plate goes
   on the nearest free counter, or is lost if there is none; a piece being moved goes
   back where it was (`cancel_hand`); a piece just bought and not yet placed is
   refunded.
10. If player one leaves, the remaining player becomes player one.
11. The number of chefs is not saved between runs. A restart keeps whoever is seated.

### 3. Playing together

12. Each chef acts for themselves: `act(1, "use")` uses chef 2's position, facing and
    hands. Two chefs at one station: the first Use wins; the second gets the normal
    "nothing to do" feedback.
13. Each chef has their own station cursor and prompt bubble, tinted with their trim
    and marked with their number, so two bubbles on one station can be told apart by
    shape as well as colour.
14. Chefs do not block each other: they pass through, as guests used to. See "Open".
15. **Build phase:** each chef has their own build hand and ghost. Both can place at
    once. Two ghosts on one spot: the first to press Use gets it; the other's ghost
    shows the no-go cross. A chef cannot pick up a piece the other is moving.
16. **Mouse aim** stays with the keyboard-and-mouse player. A controller player aims
    with the chef's facing cell, as now.
17. **Guest card** (click to inspect), **town book** and **flyers** are shared: one
    open at a time, either player can open or close it.

### 4. Shared screens

18. **Shop:** either player opens it; whoever opened it browses and buys, and their
    chef stands still. The other chef keeps moving and building. The other player's
    Shop button does nothing while it is open, with a small "Chef 1 is shopping" tag.
    What is bought goes into the buyer's hand.
19. **Options:** either player opens it. It pauses everyone. Either player can close it.
20. **Receipt:** stays up until **both** players have pressed Confirm. Each player has
    a ready marker on the card (their trim colour and number, a tick when ready). A
    player can take their ready back with Back until the second one confirms.
21. **Starting the day:** flipping the door card needs both. The first chef to use the
    door card sets it half-turned and shows their ready marker; the second chef using it
    opens. The first can cancel by using it again.
22. **Closing early** is the same: both must agree.
23. With one chef, 20 to 22 behave exactly as today (one confirm).

### 5. Hints

24. Two corner hint lines: player one bottom-left, player two bottom-right, each with
    the player's trim colour and number tag, each worded for that player's current
    device (`PlayerInput` already tracks the mode). With one chef there is one line, as
    now.
25. On narrow screens the two lines must not overlap: shorten to icons before wrapping.

## Out of scope

- Online play, chefs 3 and 4, a character creator, per-player money or scores.
- Harder days or more guests when two chefs play. See "Open".
- Split screen or a moving camera. The room already fits the fixed camera.

## Tests

- After the state move and with one chef: the whole existing suite passes unchanged.
- `controls.seat("pad:1", 1)` plus a join adds a second `Player`; `act(1, ...)` moves
  and uses chef 2 and leaves chef 1's hand and position alone.
- Two build hands are independent; two chefs cannot both take the same spot or the same
  piece.
- The receipt stays open after one confirm and closes after two; with one chef, one is
  enough. The same for the door card.
- A chef who leaves while moving a piece returns it; while holding food, it lands on a
  free counter.
- Start on an unseated pad joins; Start on a seated pad opens Options.
- Each player's hint line uses their own device's wording.

## Demo and done

- `REGULARS_DEMO=coop` (two chefs in service, two prompt bubbles, two hint lines),
  `coop_build` (two ghosts at night), `coop_ready` (the receipt with one player ready).
  Combine with `REGULARS_INPUT=pad` for player two's hints.
- `docs/DESIGN.md`: move the co-op entry from section 9 to section 1 and record the
  three answers above.

## Open, with defaults

Built 13 November 2026 with each default below: chefs pass through each other, the
day is the same with two chefs, and the other chef keeps building while the shop is
open (the shop tray covers only the bottom of the room, so building stays usable).

- **Do chefs block each other?** Default: no.
- **Does the day get harder with two chefs?** Default: no change. Revisit after
  playtesting.
- **Can the other chef keep building while the shop is open?** Default: yes. If the
  shop card covers too much of the room for that to be usable, freeze them instead and
  say so in the hint line.
