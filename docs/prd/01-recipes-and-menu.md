# PRD 1: Recipes, ingredients and the menu

**Size:** very large; build it in the seven milestones at the end, each mergeable.
**Needs:** nothing. **Touches:** new `sim/pantry.gd` (ingredients), `sim/menu.gd`,
`sim/prep.gd` (minigame scoring), `sim/town.gd` (tastes), `sim/catalog.gd`,
`sim/ledger.gd`, `game/main.gd`, `game/station.gd`, `game/build.gd`, `game/guest.gd`,
`game/hud.gd`, `game/icons.gd`, `game/fx.gd`, both test files, all three docs.

## Goal

Replace the hard-coded burger (fridge, stove, plate) with the core of the game: the
player buys ingredient stations and tools, writes and names a menu from what they can
make, pays to stock it each night, and cooks each order through short toy-like prep
minigames. Townspeople have hidden tastes and only eat what they like, so the menu
decides who comes in.

## Decided

| Topic | Decision |
| --- | --- |
| Dishes | Data. A menu item is an ordered list of ingredients. Order only sets how it looks stacked; it never refuses one. |
| Courses | Mains, sides, drinks. Every theme has all three. |
| Themes | Both in this PRD: diner (burgers, fries, soda) and seaside (fish, vegetables, white wine). |
| Stations | Each ingredient comes from its own station, so a bigger menu needs a bigger kitchen. |
| Prep | At most one prep step per ingredient, set by its **tool**. Seven tools, one minigame each (below). |
| Ready-made | Some ingredients can be bought ready-made as a shop upgrade that skips prep. |
| Stock | A flat fee per stocked ingredient per night. Stock never runs out during a day. |
| Restock note | The build phase shows what tomorrow's stock will cost. |
| Menu | Set each night; the player may change it or carry on. The player names every item and guests order by that name. No limit on the number of items. |
| Price | Automatic from the ingredients, with a three-level setting per item: cheap, fair, dear. |
| Orders | A guest orders a main, and adds a side and a drink when the menu has ones they like. Everything for one guest goes on one tray. |
| Tastes | Each townsperson likes and dislikes ingredients. **Always hidden.** Guests only eat what they like. |
| Nothing they like | They read the menu at the door and walk on. No strike; a small drop in opinion that friends hear about. |
| What the player learns | The guest card shows how often that guest ordered each item. Thoughts and gossip hint at tastes ("So many things with vegetables. I love vegetables!"). |
| Starting kitchen | Empty, with a budget. The player builds the first kitchen and menu on night zero. |
| Minigame reward | Doing a prep well gives a one-second burst of movement speed; doing it badly gives a one-second penalty. |
| Minigame look | Each has its own very simple interface, fun and toy-like, like the rest of the game. |

## How it works today

- One dish. The chef takes a raw patty from the fridge, cooks it on the stove
  (`Station.COOK_TIME`, `PERFECT_END`, `BURN_TIME`, `quality_at`, the dial), puts it on
  a plate from the plate stack, and serves it. The use code is in `game/main.gd` around
  lines 2190 to 2300. The bill is the constant `BILL` (12).
- Order-taking is built: the chef takes the order at the table, then
  `order_for(guest)` (`main.gd` line 2048) picks the dish and the guest stores it in
  `Guest.order`; the bubble draws its icon; serving checks the dish in hand against it.
  **`order_for` is the one place the menu plugs in.**
- Guests keep a thought log (`GuestMood.thoughts`); the guest card shows the last six.
- Dirty plates go from table to sink; scraps go in the bin (`Station.dirty`, `count`).
- Catalog entries are data in `Catalog.ITEMS`; the stove is sold in three tiers.

## Requirements

### 1. Ingredients (`sim/pantry.gd`, pure)

1. An ingredient is data: `id`, `name`, `theme`, `tool`, `worth` (what it adds to an
   item's price), `fee` (what it costs to stock for a night), `tags` (such as `meat`,
   `fish`, `vegetable`, `dairy`, `bread`, `fried`, `drink`), `drink` (true if it can
   only go in a drink), and the look of its raw and prepped forms.
2. Starting list. Worth and fee are *tunable*; a plain cheeseburger should come to
   about the 12 a burger costs today.

| Theme | Ingredient | Tool | Tags | Worth | Fee a night |
| --- | --- | --- | --- | --- | --- |
| Diner | Bun | none | bread | 2 | 3 |
| Diner | Patty | grill | meat | 6 | 8 |
| Diner | Lettuce | chop | vegetable | 1 | 2 |
| Diner | Tomato | chop | vegetable | 1 | 2 |
| Diner | Onion | chop | vegetable | 1 | 2 |
| Diner | Cheese | slice | dairy | 2 | 3 |
| Diner | Potato (fries) | fry | vegetable, fried | 4 | 4 |
| Diner | Corn cob | boil | vegetable | 3 | 3 |
| Diner | Soda | pour | drink | 3 | 3 |
| Seaside | Bread roll | none | bread | 2 | 3 |
| Seaside | Fish fillet | grill | fish | 7 | 9 |
| Seaside | Calamari | fry | fish, fried | 5 | 6 |
| Seaside | Lemon | slice | fruit | 1 | 2 |
| Seaside | Courgette | chop | vegetable | 2 | 2 |
| Seaside | Pepper | chop | vegetable | 2 | 2 |
| Seaside | New potatoes | boil | vegetable | 3 | 3 |
| Seaside | Green beans | boil | vegetable | 2 | 2 |
| Seaside | White wine | pour | drink | 5 | 5 |

### 2. Stations

3. **Ingredient stations.** One catalog entry per ingredient (a crate, tub or fridge
   drawer showing the ingredient), Kitchen category, tagged with its theme (the theme
   tag in PRD 7; add it here if this lands first). Use at one gives the chef the raw
   ingredient. It never runs out.
4. **Tool stations.** Grill (the existing stove, renamed in the shop only if the art
   needs it), fryer, pot (boil), chopping board, slicer. Sold in the shop to both
   themes. A tool takes one ingredient at a time; a higher tier takes more at once or
   works faster, following the stove's pattern (three tiers).
5. **Pour** happens at the drink's own station (soda fountain, wine barrel): it is both
   the ingredient station and the tool.
6. **Ready-made.** A second catalog entry for some ingredients ("Chopped lettuce tub"):
   it costs more to buy and half as much again to stock, hands out the ingredient
   already prepped, and its quality is always *plain*, never *good*. First list: lettuce,
   tomato, onion, cheese, courgette, pepper. See "Open".
7. **Fixtures.** The fridge goes. The plate stack becomes the **tray stack**. Sink, bin,
   counters and the pass stay. The stove must be buyable at level 1 so a first kitchen
   is possible.
8. Every station can be moved, turned and sold like other pieces, and must stay
   reachable (`must_touch`).

### 3. Stocking and the nightly cost (`sim/menu.gd`, `sim/ledger.gd`)

9. Each ingredient station has a **stocked** switch, on by default, changed at night by
   using the station or from the menu screen.
10. Flipping the door card to open charges the sum of the fees of every stocked
    ingredient (ready-made at 1.5 times). It is a new line on the receipt ("Stock").
11. **The restock note** in the build phase shows tomorrow's total, updates as stations
    are bought, sold or switched, and lists the lines when opened. If the player cannot
    pay it, the door card will not flip and the note says so.
12. An item whose ingredients are not all stocked, or whose tools are not all in the
    room, is **off the menu** for the night: greyed on the menu screen with the reason
    ("No fryer", "Onion not stocked"), not offered to guests.

### 4. The menu (`sim/menu.gd`, pure; screen in `game/hud.gd`)

13. A menu item is `{id, name, course, ingredients, price_level}`. `ingredients` is an
    ordered list; the same ingredient may appear more than once (a double patty), up to
    6 in an item (*tunable*, a limit of the stacked look).
14. Courses: a **drink** is one or more drink ingredients and nothing else. **Mains**
    and **sides** are one or more non-drink ingredients. A one-ingredient item is
    allowed (a slice of cheese).
15. **Price** is the sum of the ingredients' worth times the level: cheap 0.8, fair
    1.0, dear 1.25 (*tunable*), rounded, at least 1. Cheap items are ordered more often
    (weight 1.5) and earn a small thought ("What a bargain"); dear ones less often
    (weight 0.6) and cost a little joy on paying ("Pricey") unless the guest's comfort
    is high. Shown as one, two or three coin marks, not only by colour.
16. **The menu screen**, opened at night from the build bar and from a menu board prop
    by the door: three columns (mains, sides, drinks). Add an item, pick ingredients
    from those the kitchen has, reorder them (a live picture of the stack), name it,
    set the price level, take it off for tonight or delete it. It shows each item's
    price and the night's stock cost.
17. **Naming.** Keyboard: type. Touch: the system keyboard. Controller: a letter grid.
    Up to 18 characters. A new item gets a made-up default name from its ingredients
    ("Cheese Patty Bun") so naming is never required.
18. The menu is kept from night to night. It cannot be changed during service.
19. The door card will not flip while the menu has no main that can be made. Night
    zero says so: "Buy an ingredient, a tool, and write a menu."
20. **The menu board** by the door lists the night's item names. It is what guests
    "read"; it is a prop, not a second screen.

### 5. Tastes and ordering (`sim/town.gd`, `sim/menu.gd`)

21. Each person gets, from the town's seed, a set of **liked** and **disliked**
    ingredients for the run's theme, mostly following tags (someone who likes
    vegetables likes most of them). Everything else is neutral. Rules for generation:
    nobody dislikes more than a third of the theme's ingredients; no ingredient is
    disliked by more than a fifth of the town; everyone likes at least one grill
    ingredient or one vegetable (*tunable*), so a small first menu still draws most of
    the town.
22. An item is **acceptable** to a guest when it contains nothing they dislike.
23. **The order.** A main: chosen among acceptable mains, weighted by
    `(1 + number of liked ingredients) x price-level weight`. A side, and a drink: added
    only if there is an acceptable one that has at least one liked ingredient, chosen
    the same way. `order_for(guest)` returns `{main, side, drink}` (side and drink may
    be empty).
24. **Nothing acceptable.** If no main is acceptable, the guest stops at the menu
    board, shows a thought ("Nothing I liked on the menu") and walks on. It is not a
    walkout and not a strike. Their opinion drops by 0.05 (*tunable*; the `variety`
    topic once PRD 2 is in), and friends hear it as usual. A group walks on together if
    any member finds nothing. The receipt counts them: "3 people found nothing they
    liked."
25. **Tastes are never listed anywhere.** What the player gets instead:
    - The guest card shows that person's orders so far, by item name and count, most
      ordered first ("Stupid Burger x3, Fries x2"). Counts survive a rename; a deleted
      item keeps its last name.
    - Thoughts on eating: a liked ingredient ("Just how I like it"); on reading the
      menu, when three or more items carry a tag they like ("So many things with
      vegetables. I love vegetables!").
    - Gossip lines carry the same two messages to friends.
26. **Savour** on eating is the tray's quality (section 7), raised by 0.1 for each
    liked ingredient on it, up to +0.3 (*tunable*).

### 6. Cooking: tickets and trays (`game/main.gd`)

27. **A ticket** is made when an order is taken. Open tickets show on a rail in the
    interface: the guest's face, and an icon and name for each item with its
    ingredients as small marks that get ticked off.
28. **A tray** comes from the tray stack and is put on a counter or the pass. An empty
    tray put down takes the oldest ticket without a tray; Turn while facing it moves it
    to the next ticket. The tray shows its ticket.
29. **Adding.** The chef brings an ingredient (prepped if it needs prep) to the tray
    and uses it. It goes to the first item on that ticket still missing it, main first.
    Order of adding never matters. An ingredient the ticket does not need, or a raw one
    that needs prep, is refused with the usual no-go feedback and a line saying why.
30. **Look.** The main stacks on a plate, the side sits in a small dish, the drink in a
    cup, all on the tray, each in the order the menu item lists its ingredients.
31. **Serving.** Only a complete tray can be picked up ("Needs fries" otherwise). The
    chef carries it to the table and uses it; it goes to the guest on its ticket. The
    guest's bubble already shows what they wait for.
32. **The bill** is the sum of the tray's item prices, then the mood scale (PRD 3),
    then half price or a free meal. `BILL` is removed.
33. **Mistakes.** A tray's contents, a spoiled ingredient or an unwanted one go in the
    bin (scraps, as now). A ticket whose guest leaves is torn off; a tray assigned to
    it shows no ticket and can be binned or re-assigned with Turn if the items match.
34. **After the meal** a dirty tray is left on the table and washed at the sink, by
    the same rules dirty plates follow now.
35. Counters hold a raw or prepped ingredient, as they hold a patty now.

### 7. Prep minigames (`sim/prep.gd` for scoring, pure; widgets in `game/`)

36. Every minigame is played with **Use only** (press, hold or mash), so it works the
    same on keys, pad and touch. The chef stands at the tool; Back leaves a press-based
    minigame and gives the ingredient back raw.
37. Every minigame ends in one of three results: **good**, **plain** or **bad**.
    Heat tools can also **spoil** the ingredient (burnt: bin it).

| Tool | How it plays | Good | Plain | Bad |
| --- | --- | --- | --- | --- |
| Grill | As the stove now: put it on, a dial runs, take it off at the right time. The chef is free to walk away. | Taken off in the perfect window. | Underdone or drying out. | Burnt: spoiled. |
| Fry | A timer like the grill: lower the basket, lift it in the window. Then it **rests on the drain rack** for 2 seconds (*tunable*) to cool and dry before it can be picked up. The chef is free during both. | Lifted in the window. | Early or late. | Burnt: spoiled. |
| Boil | Use starts it; it is done after a fixed time and waits. It cannot overcook. The easy one. | never | always | never |
| Chop | A marker sweeps left to right along a bar; press Use as it crosses the notch in the middle. Three sweeps, like a three-beat rhythm. | All three in the notch. | Two. | One or none. |
| Slice | Mash Use to reach the count shown (6, *tunable*) before the short timer ends, then stop. | Exactly the count, in time. | One to three over, in time. | More than three over, or out of time. |
| Pour | Hold Use and the cup fills; let go to stop. As high as possible without spilling. | In the top band (85% and up). | 60 to 85%. | Below 60%, or it overflows. |
| None | No step. The ingredient goes straight to the tray. | | always | |

38. **Reward and penalty.** *Good:* the chef moves at 1.5 times speed for 1 second.
    *Bad* or *spoiled:* the chef moves at half speed for 1 second. *Plain:* nothing.
    Both show on the chef (speed lines and a small star; a sweat drop and a wobble) and
    have their own sound. Boil and None give neither. All numbers *tunable*.
39. **Quality.** Each prepped ingredient carries a quality: good 1.0, plain 0.75, bad
    0.45 (*tunable*); the grill and fryer may keep the existing smooth curve
    (`Station.quality_at`) mapped onto the same range. Ready-made and no-prep
    ingredients are plain. A tray's quality is the average of its ingredients. This is
    what the guest tastes and what the critic's quality rating reads (PRD 2).
40. **Interfaces.** One small widget per tool, drawn in the world above the station in
    the paper-and-wood style, readable at the size of the existing cook dial:
    - Grill: the existing dial.
    - Fry: the dial, then a basket on a rack with drips counting down.
    - Boil: a pot with a ring that fills and a lid that rattles when done.
    - Chop: a wooden bar with a notch and a little knife as the marker.
    - Slice: a row of pips that fill with each press, with the target pip marked.
    - Pour: a glass that fills, with a line for the top band.

    Good, plain and bad must differ by shape or motion, not only colour.
41. Minigame state belongs to the chef playing it and takes a player index, so co-op
    (PRD 4) needs no rework. Two chefs cannot play one single-slot tool at once.

### 8. Starting a run

42. The dining room starts as it does now. The kitchen starts with the sink, the bin,
    the tray stack and counters only: **no ingredient stations and no tools**.
43. Starting money goes up from 50 to a budget that buys one simple main with change
    for a second ingredient: 150 (*tunable*; check against final catalog prices).
44. Night zero shows three short lines, one at a time, as the player goes: buy an
    ingredient station and a tool; write a menu; flip the door card.

## Out of scope

- Stock that runs out, buying quantities, spoilage, suppliers.
- Player-built combos, a second round (dessert, another drink), numeric prices typed by
  the player.
- More than one prep step for an ingredient; new tools beyond the seven.
- Showing a guest's likes and dislikes directly, anywhere.
- New themes, location-based tastes, staff.
- The critic (PRD 2) and themed non-kitchen pieces (PRD 7).

## Tests

`test/unit/test_sim.gd`:
- Every ingredient has all its fields; every tool named is one of the seven.
- Price: worth sum times level, rounded, at least 1; a plain cheeseburger is about 12.
- Night cost: the sum of stocked fees, ready-made at 1.5; an unstocked station costs 0.
- An item missing a stocked ingredient or a tool is off the menu.
- Course rules: a drink with a non-drink ingredient is refused; a one-ingredient main
  is allowed; more than 6 ingredients is refused.
- Taste generation obeys the three limits for several seeds, and is the same for a seed.
- Ordering: a guest never gets an item with a disliked ingredient; a side or drink is
  only added when it has a liked ingredient; with no acceptable main the result says
  walk on; cheap is picked more often than dear over many rolls.
- Each minigame's scoring at its edges (chop 3, 2, 1 hits; slice exact, +1, +3, +4, out
  of time; pour 84%, 85%, 100%, overflow; fry and grill windows; boil always plain).
- Tray quality is the average; the liked-ingredient bonus caps at +0.3.
- Order counts on a person survive a rename.

`test/unit/test_game.gd`:
- A full order from ticket to paid bill for a one-item and a three-item tray.
- A tray refuses an ingredient its ticket does not need, and a raw one that needs prep.
- An incomplete tray cannot be picked up.
- A good result speeds the chef for one second; a bad one slows them; plain does neither.
- The door card will not flip with no makeable main, or when the stock cannot be paid.
- A guest who finds nothing walks on without a strike, and the receipt counts them.
- Fries cannot be picked up until the rest time has passed.
- The old burger tests are replaced, not deleted without a matching new test.

## Demo hooks

`menu` (the menu screen with items in three columns), `menu_name` (naming an item),
`restock` (the note open), `ticket` (a rail with two tickets and a half-built tray),
`tray` (a full tray being carried), one per minigame (`prep_grill`, `prep_fry`,
`prep_boil`, `prep_chop`, `prep_slice`, `prep_pour`) shot mid-game, `prep_good` and
`prep_bad` (the chef's burst and penalty), `walkon` (a guest turning away at the board),
`orders_card` (a guest card with order counts), `night0` (the empty kitchen and first
hint). Each also with `REGULARS_THEME=seaside` where the content differs. The existing
`cook`, `order`, `lineup` and `crowd` demos must be updated to the new flow.

## Milestones

Build and merge in this order. Tests pass at the end of each.

1. **Sim.** `pantry.gd`, `menu.gd`, tastes in `town.gd`, pricing, night cost, ordering.
   No scene changes. All of the `test_sim.gd` list except minigames.
2. **Tickets and trays, grill only.** Ingredient stations, the tray stack, tickets,
   assembling and serving, the bill from the tray. A fixed test menu. The old fridge
   and plate flow is removed here. Diner burger playable end to end.
3. **The other tools.** Fry, boil, chop, slice, pour: scoring, widgets, the speed burst
   and penalty, quality.
4. **The menu screen.** Writing, naming, price levels, stocked switches, the restock
   note, the menu board, the empty start and night-zero hints.
5. **What the town tells you.** Walking on, the receipt line, order counts on the guest
   card, taste thoughts and gossip.
6. **Seaside.** Its ingredients, stations and food models.
7. **Docs and demos.** `docs/DESIGN.md` (sections 1, 3, 6, 7 and 9), the style guide's
   "As built" for every new model and widget, `CLAUDE.md` (test count, demo list, layout
   lines for the new `sim/` files).

## Open, with defaults

These were asked and not answered. The defaults above are what gets built unless Dylan
says otherwise.

- *Confirmed by Dylan, 13 November 2026:* slice (exact is good, one to three over is
  plain, more is bad), the penalty (half movement speed), and that every minigame
  result sets the food's quality.
- *Confirmed by Dylan, 13 November 2026:* each tool is its own station (pour at the
  drink's station); the ready-made ingredients are the chopped ones plus cheese; an
  empty tray put down takes the oldest ticket without a tray; boiling never gives the
  burst. In a group, someone who finds no main stays and orders any drink with nothing
  they dislike, or sits with nothing; the group walks on only if nobody has a main.
  Every station can be sold, the last stove included.
- **Where prep happens.** Default: at a separate tool station, except pour, which is at
  the drink's own station.
- **Which ingredients have a ready-made version.** Default: the chopped ones and cheese.
- **Tickets.** Assigning a tray to a ticket is this PRD's proposal for how the game
  knows which item an ingredient belongs to. Not yet confirmed by Dylan.
- **Groups walking on** when one member finds nothing. Default: the whole group goes.
- **Boil never gives the speed burst.** Default: correct, it is the easy one.
