# PRD 11: Paying the bill

**Size:** large, four milestones. **Needs:** nothing (PRD 10 for 11.4). **Touches:**
`sim/guest_mood.gd`, a new `sim/bill.gd`, `sim/jobs.gd`, `sim/staff.gd`, `game/guest.gd`,
`game/main.gd` (finishing a meal, the till), `game/hud.gd` (the bill screen, hints),
`game/crew.gd` (the server), `game/fx.gd` (the call bubble), tests.

## Goal

Paying is half the job of a diner, and today it is skipped: a guest finishes eating, a
coin pops and they walk out. This PRD makes it a task. Guests finish, chat a moment, then
ask for the bill. The player writes the bill at the till, picking exactly what the table
ordered, carries it over and takes the money. It adds a third trip to every table (order,
serve, pay), a memory test (what did table 3 have?), and a reason to keep the room in
sight, since a guest only waves at someone they can see.

## How it works today

- `Guest.tick` "eating" counts down `eat_time`, then calls `game.finish_meal(g)`.
- `finish_meal` (`game/main.gd`) works out the bill (`mood.pay_for(bill_base)`) and the
  tip, records the sale, the visit and the gossip, leaves a dirty plate
  (`table.dirty += 1`), pops the coin and calls `_leave(g)`.
- A party that ordered nothing sits in "company" and leaves when the others leave.
- The till is drawn on the pass (`Build.register`, the station at (4, 2)) and moves with
  it. It does nothing yet.
- `Grid.sight_open(a, b)` already says whether one cell can see another.
- Helpers take tasks from the board (`JobBoard`, `sim/jobs.gd`); ordering is the
  "order" task, done by the `take_orders` duty.

## The flow

1. **Finish.** The last bite (`eat_time` runs out) no longer pays. The guest goes to a
   new state, **"chatting"**, for `CHAT_TIME` (*tunable*, 3 s), with the speech bubbles
   helpers use on their break (`helpers_break`). A guest eating alone chats to no one:
   they just sit back for the same time.
2. **Ready to pay.** When every guest in the party who ordered has finished chatting, the
   table is **ready to pay**. One bill per table (see Open). From here the party's
   patience runs again, at `PAY_PATIENCE_SCALE` (*tunable*, 1.5, slower than waiting for
   food) of the table patience.
3. **Calling.** While a chef, or a helper with the `take_payment` duty, is in sight of
   the table (`Grid.sight_open` from the table's cell to theirs), one guest raises a hand
   with a **bill bubble** (a small paper slip with a coin, by shape: a torn-edged slip, not
   a plate). The bubble shows only while someone can see them; it is the "call". A soft
   bell plays once when a call starts.
4. **Going to the till.** If the table has been ready to pay for `TILL_AFTER` (*tunable*,
   12 s) and nobody has brought the bill, one guest (the one who called, else the first
   seated) stands up and **walks to the till**, queuing in front of the pass. The rest
   stay seated. A guest at the till shows the same bill bubble at all times.
5. **Writing the bill.** A chef at the till presses E to open the **bill screen** (11.3).
   They pick which waiting table it is for, then tick the menu items the table had, with
   counts. Confirming prints the slip into the chef's hand.
6. **Handing it over.** The chef carries the slip to the table (or to the guest at the
   till) and **holds E for `HAND_TIME`** (*tunable*, 1 s), with a fill bar like helping
   someone up. When the bar fills, the bill is checked:
   - **Exactly right:** they pay. Everything `finish_meal` does today happens now: the
     bill and tip, the sale, the visit, the gossip, the coin. Then the party leaves (the
     one at the till goes straight out of the door).
   - **Wrong:** they refuse it and say what is wrong in the thought log, in written lines
     ("We never had the fries", "You forgot my soda", "That's not our table"). The slip is
     thrown away, the party loses `WRONG_BILL_JOY` (*tunable*, 0.1) joy each and keeps
     waiting. The player goes back and writes it again.
7. **Running out of patience.** A party whose patience runs out while waiting to pay
   **leaves without paying**: no money, no tip, a drop in opinion that friends hear about
   ("left without paying, nobody came"). It is **not** a strike: they ate, the kitchen did
   its job. See Open.
8. **Plates.** Dirty plates are made when a guest finishes eating, as now, not when they
   leave. Clearing a table's plates works while the party is chatting, waiting to pay or
   gone. A cleared table does not hurry them; a dirty one in front of them is the usual
   mess they see.
9. **The seat** is only free once the party has left. Paying is where tables turn.

## Requirements

### 11.1: the bill sim (`sim/bill.gd`, `sim/guest_mood.gd`)

1. `Bill` holds a table id and a count per menu item id. `Bill.for_party(orders)` builds
   the right bill from the party's `ordered_items()`. `Bill.check(written, right)` returns
   `"ok"`, or the first difference as `{kind: "missing" | "extra" | "table", item}`, so the
   game can pick the line to say.
2. `Bill.price(bill, menu)` is the sum of tonight's prices. The mood scale, half price and
   free meals stay where they are (`GuestMood.pay_for`), applied per guest when they pay.
3. `GuestMood` gets the paying wait: `wait()` runs during "ready to pay" with
   `PAY_PATIENCE_SCALE`, and `walked_out()` covers it. Leaving unpaid is
   `GuestMood.skipped_bill` (true), so the town and the receipt can tell it apart from a
   walkout.
4. `Town.left_unpaid(idx)`: the opinion drop (*tunable*, `UNPAID_OPINION`, half a
   walkout's) and a gossip line.
5. `Ledger.today.unpaid_bills` counts parties who left without paying. (The existing
   `unpaid` is staff wages; do not reuse it.)

### 11.2: guests chat, call and go to the till (`game/guest.gd`, `game/main.gd`)

1. New guest states: `chatting`, `to_pay` (seated, waiting), `to_till` (walking),
   `at_till` (queued in front of the pass). `finish_meal` is split: the eating end moves
   the guest to `chatting` and makes the plate; a new `pay_bill(table)` does the money and
   the leaving.
2. The "company" guest who ordered nothing waits with the party and leaves with them, as
   now. They are not on the bill.
3. The call: every half second, a `to_pay` table checks sight to each chef and to each
   helper with `take_payment`. The bubble is on while any of them can see it.
4. The till queue stands on the room side of the pass, one cell per guest, lined like the
   door queue. If the pass is moved at night, the line follows it.
5. The guest card shows "Waiting for the bill" and how long.

### 11.3: the bill screen and handing it over (`game/hud.gd`, `game/main.gd`)

1. The bill screen is a paper slip on the till, in the paper-and-wood style: at the top,
   the tables waiting to pay (by their table number and party size, the ones at the till
   marked), then tonight's menu in its three courses with a count beside each item
   (E or click adds one, Backspace or right click takes one off), then "Print".
2. The screen does **not** show what the table ordered. The player remembers it, or reads
   it off the guest card ("Ordered tonight", already there), or looks at the trays still
   on the table. This is the skill.
3. The printed slip is held like a tray: a chef holds one thing at a time. Dropping it
   (Q) throws it away. A slip for a table that has already gone is thrown away too.
4. Handing over is a hold of `HAND_TIME` with a fill bar over the table, cancelled by
   walking off. Hints: "Hold E give the bill" (with pad and touch variants).
5. In co-op either chef can write and hand a bill. Two chefs cannot write for the same
   table at once: a table with a slip already printed is shown greyed on the screen.
6. The receipt gets a line for parties who left without paying, beside walkouts, with
   its own stamp shape (an open purse), not a strike mark.

### 11.4: the server pays tables (`sim/jobs.gd`, `sim/staff.gd`, `game/crew.gd`)

1. A new task type, `"bill"`, one per table ready to pay, urgency `3.5` (*tunable*,
   just above taking an order), and a new duty, `take_payment` (people kind, weight like
   `take_orders`). The duty is on the server post by default.
2. A helper doing it walks to the till, writes the bill (always right, but takes
   `WRITE_TIME`, *tunable* 2 s, modified by their skill like prep), carries it and hands
   it over. A chef can take over the task as with any other.
3. The all-staff run (10.7) still works with no chef: add `take_payment` to the check
   that every task has a duty.

## Out of scope

- Splitting the bill, card or cash, change, and tips left on the table.
- Guests ordering more after the meal (decided against in PRD 3).
- A bigger till or a card machine in the shop. Later, if the till becomes a bottleneck.
- Any change to prices, the tip formula or satisfaction beyond the waiting above.

## Tests

In a new `test/unit/test_bill.gd`:
- `for_party` counts duplicate items (two burgers) and skips guests who ordered nothing.
- `check` returns ok for an exact bill, and missing, extra and wrong-table for each kind of
  mistake; order of ticking does not matter.
- `price` sums tonight's prices.
- Waiting to pay drains patience at the paying scale; running out sets `skipped_bill`.
- `left_unpaid` drops opinion less than a walkout and is not a strike.

In `test_game.gd`:
- A guest who finishes eating chats, then their table is ready to pay; no money is
  recorded until the bill is handed over.
- With a chef in sight a ready table calls; with the chef behind a wall it does not.
- After `TILL_AFTER` one guest walks to the till and the rest stay seated.
- An exact bill pays the same bill and tip `finish_meal` paid before this PRD; a wrong one
  is refused, costs joy and leaves the table waiting.
- A table can be cleared while its party waits to pay; the seat frees only when they go.
- A party left too long leaves without paying, with no strike.
- In `test_staff.gd` or `test_jobs.gd`: a server with `take_payment` takes a bill task and
  the table pays.

## Demo and done

- `pay_call`: a table ready to pay, one guest's hand up with the bill bubble, the chef in
  sight; a second table behind the wall not calling. Shoot at about 8.
- `pay_till`: two guests queued at the till, bubbles up. Shoot at about 8.
- `pay_bill`: the bill screen open, two tables waiting, three items ticked. Shoot at 3.
- `pay_hand`: the chef handing a slip over, the bar half full. Shoot at 3.
- `pay_wrong`: a refused bill and its line in the thought log. Shoot at 4.
- `pay_server` (11.4): the server walking a slip to a table. Shoot at about 10.
- Run each once per theme. List them in `CLAUDE.md`.
- `docs/DESIGN.md`: paying goes in section 1, written as built.
- `docs/STYLE_GUIDE.md` "As built": the bill bubble, the slip and the open-purse stamp.

## Open, with a default

- **One bill per table or per guest?** Default: one per table, paid by the whole party
  at once. Per guest is more trips; try it only if tables feel too easy.
- **Is leaving without paying a strike?** Default: no, only lost money and opinion.
- **What happens to a wrong bill?** Default: refused, as above. An undercharge could
  instead be paid happily (money lost, no complaint); say if you want that.
- **Does a fast payment add to the tip?** Default: no. The time waited already lowers
  patience, and the tip is worked out at paying time, so a slow bill costs some tip.
