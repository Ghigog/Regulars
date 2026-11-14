# PRD 3: Mood drives pay and stay

**Size:** small. **Needs:** nothing. **Touches:** `sim/guest_mood.gd`, `game/guest.gd`,
`game/main.gd` (serving and paying), `game/hud.gd` (guest card), tests.

## Goal

A happy guest pays more and stays longer. That gives the player a real choice: a cosy
room earns more per guest but turns tables slower, so a fast-food player may keep guests
a little less comfortable on purpose.

## How it works today

- Every meal costs `BILL` (12) in `game/main.gd`. `GuestMood.bill_for(price)` applies
  half price and free meals. The tip is `bill x satisfaction x 0.6` (`tip_for`).
- Every guest eats for `Guest.EAT_TIME` (5 seconds) in `game/guest.gd`.
- Satisfaction is `0.35 savour + 0.3 joy + 0.2 patience - 0.5 disgust`.

## Requirements

1. **One number drives both effects.** Add `GuestMood.comfort()`, read once, **when the
   food arrives at the table**: `clamp(0.6 joy + 0.4 patience - felt_disgust(), 0, 1)`
   (*tunable*). Savour is left out on purpose: comfort is about the room and the service,
   not the dish. Store the value on the guest so the bill and the stay agree.
2. **Bill.** `GuestMood.bill_scale(comfort)` goes in a straight line from 0.90 at
   comfort 0 to 1.25 at comfort 1 (*tunable*: `BILL_LOW`, `BILL_HIGH`). It reads in the
   fiction as "they ordered extras". The scaled price is rounded to a whole number, at
   least 1.
3. **Stay.** `GuestMood.stay_scale(comfort)` goes from 0.80 to 1.50 (*tunable*:
   `STAY_LOW`, `STAY_HIGH`) and multiplies the eating time.
4. **Order of effects on the bill:** base price, then the mood scale, then half price or
   free meal (`bill_for`). The tip is worked out on the final bill, as now.
5. **Deals still work.** `main.gd` line 2097 tests `bill == BILL` to tell whether a guest
   who expects a deal paid full price. Replace that with a test on
   `mood.discounted or mood.comped`, since the bill is no longer a constant.
6. **The player can see it.**
   - A thought when the food arrives, in the usual thought log: high comfort
     (0.75 and up) "I could stay here all day"; low (0.3 and under) "Let's eat and go".
     One line each is enough; add two or three variants if cheap.
   - The guest card (click to inspect) shows the bill they are paying once they have been
     served, so the player can connect a cosy seat to a bigger bill.
   - The coin pop on paying already shows the amount. No new effect is needed.
7. **XP is unchanged:** 10 a meal plus the tip.

## Out of scope

- A second round (dessert, a second drink). Decided against for now.
- Any change to the tip formula, to satisfaction, or to how long guests wait.
- PRD 1 replaces the single `BILL` with a tray price. This PRD must scale whatever the
  base price is, through one function, so PRD 1 only changes the input.

## Tests (in `test/unit/test_sim.gd`)

- `comfort()` is 0 to 1, rises with joy and patience, falls with felt disgust.
- `bill_scale` and `stay_scale` hit their ends at comfort 0 and 1 and are monotonic.
- A comped guest pays 0 and a half-price guest pays half of the scaled bill.
- A guest who expects a deal and pays full price is still let down when the scaled bill
  differs from the base price.

In `test_game.gd`: a guest with high comfort eats longer and pays more than one with low
comfort, same dish.

## Demo and done

- `REGULARS_DEMO=mood`: two seated guests, one content and one fed up, both served; shoot
  at the moment each pays (two times given in the `_apply_demo` comment) and once with
  the guest card open.
- `docs/DESIGN.md`: move "Mood drives pay and stay" from section 9 to section 1, and
  update the "To add: stay length and order size driven by mood" line in section 3.

## Open, with a default

- **Does comfort also change how much mess a guest leaves?** Default: no.
