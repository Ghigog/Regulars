# Regulars

A Godot 4.7 restaurant-survival game: cook meat, serve named townsfolk, earn money, survive
as many days as possible. Working title. The current build is a vertical slice.

## Run and test

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .                      # play
/Applications/Godot.app/Contents/MacOS/Godot --headless --import           # in a fresh checkout or worktree, and after adding assets
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd   # tests (GUT 9.7.1)
```

All 715 tests should pass before and after any change. Screenshots for checking visuals:
`REGULARS_SHOT=/abs/path.png REGULARS_SHOT_AT=13.5 REGULARS_DEMO=cook godot --path .`
(`REGULARS_DEMO` is `cook` (a patty on the grill, the chef holding an empty plate), `summary`, `closed`, `lineup` (every townsperson and face, close up), `fx`, `town`, `kind`, `flyers`, `build` (the shop), `build_no`, `build_find`, `build_move`, `build_range` (a fern's reach), `build_range_floor` (a marble drag in progress), `build_range_rug` (a new rug, one seat ticked full), `build_range_paint` (a paint drag along the back wall), `build_dining` (a booth and a table for four in the room; `build_dining_shop` for the shop's Dining tab), `build_tools` (the shop's Build tab), `build_till` (the till taken off the pass from its counter's card, held over the next counter), `build_room` (an extension, walls, doors, two greyed out), `build_drag` (a floor drag in progress), `build_finish` (parquet, marble, paint, both wallpapers and a moved rug), `door`, `close` (closing early), `messy` (a piled sink, an overflowing bin, the chef carrying the bag), `night_clean` (a messy day carried into the night: the "Still dirty" note, "Clear table", then a plate carried to the sink; shoot at 4 and 6.5), `options` or `options_gfx` (the options screen, first slider chosen), `inspect`, `tolerance` (a seated guest's card hinting "Hates to wait" and "Doesn't mind a mess"; shoot at 10), `newday` (receipt, build, then the calendar turning), `walkout` (a walkout knocking the reputation meter down), `dirt` (floor dirt at every level along the front, footprints, guests slowed tracking in a whole-cell spill at the door; shoot at about 7), `slip` (a guest down on a level 4 cell, dazed with stars, a friend who saw it bent over helping them up, the help bar filling; shoot at about 7.5), `desk_line` (PRD 10.3: two desks with the CV pile, the chef at one, applicants lined up outside), `desk_post` (writing a job post), `desk_cvs` (the CV pile, the top CV half dragged right), `desk_staff` (PRD 10.4: the staff list, three hires, the week with days off crossed, a happy, a so-so and a fed-up one), `desk_raise` (managing a hire who named a raise for a new duty), `desk_wages` (the receipt with a STAFF line and two wages unpaid), `desk_haggle` (a low offer on the top CV refused), `desk_restock` (the restock note with tonight's STAFF wages), `desk_fire` (PRD 10.8: the fed-up washer opened, both fire buttons out), `helpers` (PRD 10.6: a grill cook, a server and a washer at work, aprons on, two desks along the front; shoot at about 8 to 20; run once per theme), `helpers_break` (the server and the washer on their break chatting by the desks, speech bubbles up; shoot at 4), `helpers_slip` (PRD 10.8: the washer down on a level 4 cell, dazed, the server bent over helping them up; shoot at about 2 to 2.5, the help is quick), `staff_only` (PRD 10.7: a busy day 8 run by five helpers with no chef, the kitchen grown back with every tool, the cleaning trees and the floor treated; shoot at about 40; run once per theme), `mop` (PRD 9.4: a mop bucket, a sponge on its wall hook, the chef mid-clean along a trail of dirt with a dirty mop, a sponge left lying; shoot at 3), `robot` (the robot sweeper drifting from its dock to a puddle; shoot at about 3.5), `mop_night` (at night a table moved off the puddle under it, the chef with the mop; shoot at 3), `mop_line` (PRD 9.6: the mop bucket's whole tree in a row, each mop head up in its pail, the robot's dock, the four small tools on hooks, a hood beside an extractor, the chef pushing a floor scrubber; shoot at 3; run once per theme), `treat` (PRD 9.5: at night a strip of each floor treatment's film, some with dirt, the sealing primer dimmed as switched off, boxes on a counter, the chef laying cleaner; shoot at 3), `treat_day` (the same in service, every film in force; shoot at 3), `tree_box`, `tree_bucket`, `tree_sponge` (the upgrade tree of a treatment box, the mop bucket and the sponge's hook; shoot at 3), `crowd` (a rush: every table taken, a long line at the door; shoot at about 12), `comp` (a free meal for a fed-up guest), `order` (a table waiting to order, then the order taken and its tickets on the rail; shoot at 9 and 10.5), `ticket` (tickets on the rail, a bun on a patty on the pass, the chef with a plate for it; shoot at 10), `tray` (a ticket's plates carried on a tray; shoot at 10), `prep_grill`, `prep_fry`, `prep_boil`, `prep_chop`, `prep_slice`, `prep_pour`, and PRD 8.6's `prep_grate`, `prep_saw`, `prep_juice`, `prep_blend`, `prep_steam` (each minigame frozen mid-play at its tool; run the new ones once per theme), `prep_good` and `prep_bad` (the chef's burst and penalty) (all `prep_*` frozen, shoot at 2), `menu` (the menu screen, three columns), `menu_name` (naming an item), `restock` (the restock note open), `night0` (the starter kitchen and the menu hint), `walkon` (a pair who find nothing turn away at the board; shoot at about 7), `orders_card` (a guest card with order counts; shoot at 10), `critic` and `critic_bad` (the day-5 receipt with a good review, and a walkout's; shoot at 4), `critic_known` (the named critic seated with a quill on their card; shoot at 10), `critic_town` (the town book with the critic marked and "Last review"; shoot at 3), `mood` (a content and a fed-up guest served at once, the content one's card open at 9; the fed-up one pays at 12.4, the content one at 15.7), `build_new` (every PRD 7 piece placed; run once per theme), `counters` (PRD 8.2: a double counter, a board on a double counter, a stove on the pass; shoot at 3), `tree` (PRD 8.3: a board picked up and the shop opened on its upgrade tree; shoot at 3), `tree_stove` (the stove's tree, scrolled down to the fryer, an arrow where it runs off; shoot at 3), `tree_counter` (the counter's tree with its fridge line), `tree_fern` (a fern's short tree), `tree_cut` (PRD 8.6: the cutting tree scrolled to the grater and bread knife lines; `tree` shows its top), `jobs` (PRD 8.6: the new tools in a row and every new kind, made and raw, on counters, close up; shoot at 3.5, run once per theme), `upgraded` (a row of upgraded pieces in the kitchen; shoot at 3), `storage_card` (a bare counter's card where it stands: Upgrade, Move, Turn and Sell cards, then its boxes, a chilled kind offering "Fridge $35"; `pantry` is the same), `storage_card_up` (the same card on its Upgrades tab), `storage_fridge` (a length of the pass made a fridge on its card and turned where it stands, its door toward the camera), `boxes_open` (crates standing on a bare counter, a fridge door caught open; all three shoot at 3, run once per theme), `wall` (PRD 8.5: the start's hoods over the stoves and cabinets by the back door, one with a box, a low and a high shelf as a closet, a tall fridge in the corner; shoot at 3; run once per theme), `wall_build` (a wall cabinet's ghost hung over the plate stack, the high band lit behind it; shoot at 3), `storage` (boxes in a double counter, two under-counter fridges and the pass, their tags over each cell, a box held over the pass; shoot at 3), `pay_call` (PRD 11: a table ready to pay, a guest waving with the bill bubble at the chef in sight, a second table behind a partition not calling; shoot at about 8), `pay_till` (two guests queued at the till, bubbles up; shoot at about 8), `pay_bill` (the bill screen open, two tables waiting, three items ticked; shoot at 3), `pay_hand` (the chef handing a slip over, the bar half full; shoot at 3), `pay_wrong` (a refused bill and its line on the guest card; shoot at 4), `pay_server` (the server handing a slip over at a table; shoot at about 4.5) (run each pay demo once per theme), `coop` (two chefs in service, two bubbles, two hint lines; shoot at 8), `coop_build` (two ghosts at night, one crossed; shoot at 3), `coop_door` (the door card half turned, one chef ready; shoot at 3), `coop_ready` (the receipt with player one ready; shoot at 4), `pause` (the pause menu: Resume, Options, Quit to title), `picker` (the theme card after Play) or `title` (the title
screen, which a plain run shows first); see `_apply_demo` in `game/main.gd`.
Add `REGULARS_THEME=seaside` for the second theme (its own food, stations, shop and fixed Fish roll menu; a plain run picks the theme on a card after Play, and setting this skips the card), and `REGULARS_INPUT=touch` or `=pad`
to show the touch buttons or controller hints.) Run `--headless --import` once after
adding a script with a new `class_name`, and once in any fresh checkout or worktree
before anything else: the `.godot` import cache is not in git, and without it the game
script fails to load and a screenshot run hangs instead of saving.

## Layout

- `sim/`: pure game logic, no scene dependencies, unit-tested. Keep it that way.
  `floorplan.gd` is the room's shape (floors, built walls, doors); outer walls are derived.
  `pantry.gd` is the ingredients (tool, tags, worth, nightly fee) for both themes;
  `menu.gd` the player's menu (courses, prices, what is makeable tonight, the night's
  stock cost, what a guest orders, taste hints); `prep.gd` the minigame scoring, quality
  and the burst/penalty; `tray.gd` one guest's order: what of each ticket line has been served; `dish.gd` a plate, cup or loose stack of food (what combines, what it is, PRD: plates and cups); `clean_tools.gd` the floor
  cleaning tools (mop, sponge, homes, rinsing, the robot sweeper, PRD 9.4); `critic.gd` the
  critic (who, when, the four ratings, stars, the review line and what it does to the town);
  `kitchen.gd` the kitchen's cells (base, top, and the high layer on wall cells, PRD 8.5), storage slots (boxes of stock, PRD 8.4) and tree data; `upgrades.gd` the upgrade trees as sold
  (keys, step prices, layout); `floor_mess.gd` floor dirt (levels, overflow, tracking,
  slipping, PRD 9); `treatments.gd` the floor treatments (cleaner, primer, finish, PRD 9.5);
  `bill.gd` a table's bill (PRD 11: built from the orders, checked against the one written
  at the till, priced);
  `town.gd` the townspeople (forty a theme, tastes, wealth, opinions by topic, tolerances
  for PRD 10.1, the crowd and the day's length); `ledger.gd` money, XP and the rolling
  reputation meter that ends a run; `staff.gd`
  staff (posts, CVs, hiring, haggling, wages, satisfaction, the week; `Catalog.STAFF_ON_SALE`
  puts the desk on sale); `jobs.gd` the task board (`JobBoard`, PRD 10.5: every open task and
  its duty, helpers reserving, chefs taking over, helper prep rolls), filled with plain data
  by the game; `helper_work.gd` how a helper does each task (steps, walking and working
  speed, chat, where they wait, PRD 10.6).
- `game/`: the scene layer. `main.gd` owns the world, the day loop and the shared screens;
  each chef's own state (build hand, drag, aim, ghosts, cursor) lives on `Player` (`player.gd`),
  and functions that act for a chef take it (chef 1 when none is named). Visuals are generated
  in code: `build.gd` (palette, bevelled boxes, lathed shapes, food, stations), `peg.gd`
  (characters), `scenery.gd` (room, street, themes), `icons.gd` and `fx.gd` (flat icons,
  bubbles, effects), `hud.gd` (paper-and-wood interface), `title.gd` (title screen and logo),
  `desk_screen.gd` (the staff desk: job posts, the CV pile and the staff list, PRD 10), `prep_widget.gd` (the prep minigame gauges and the good/plain/bad pop), `bill_screen.gd` (the bill screen at the till, PRD 11), `save.gd` (the saved game: written at the start of each night, read by Continue on the title; `user://regulars_save.dat`) and `pause_menu.gd` (the pause menu), `menu_screen.gd`
  (the menu screen and the restock and night-zero notes), `clean_kit.gd` (tools held, kept, lying about, and the
  robot sweepers, PRD 9.4), `floor_dirt.gd` (floor dirt in the room: drawing it, feet,
  slips and helping up, PRD 9), `crew.gd` (hired helpers in service: the board rebuilt from
  the room, tasks walked step by step, breaks, chat; the staff demos and the all-staff run,
  PRD 10.6 and 10.7), `helper.gd` (one helper: a chef's body in their own look with an
  apron), `menu_board.gd` (tonight's
  names chalked on the A-frame by the door), `tree_screen.gd` (the upgrade tree on blueprint paper).
- `test/unit/`: GUT tests. `assets/sfx/`: generated by `tools/make_sfx.py`. `assets/music/`: real tracks, mapped in `MUSIC` in `game/main.gd`.
- `docs/DESIGN.md`: what is built, what is parked, and what art work is left.
- `docs/STYLE_GUIDE.md`: **the art source of truth.** Rules, resolved conflicts, palette,
  and the artist's comments for each of 16 sheets. Its "As built" section lists where the
  game departs from them. Images are in `docs/art/`.
- `docs/AUDIO_GUIDE.md`: the music and sound style, track list and Suno prompts. Not built yet.
- `docs/ART_BRIEF.md`: the original request to the artist (reference only).

## Working on the art

- You have freedom to stray from any concept, sheet or rule where it works better in the
  engine or for play. Keep the spirit (toy diorama, readable at 60 px and 20 px, the palette
  roles) and note the departure in the style guide.
- The concept sheets came from an image model and contain mistakes. They are inspiration,
  not specs. Follow the "Resolved conflicts" and "Rules so far" sections of the style guide
  where a drawing disagrees. Do not copy flaws such as legs on characters or mislabelled faces.
- Camera is fixed: orthographic, 37 degrees down, rotated 45 degrees. Anything that matters
  to play must read at about 60 px (characters) and 20 px (food and icons).
- Do not change gameplay rules to match a picture. Ask first if a design needs one.
- Decided: logo is the peg-doll version (bottom-left on sheet 15); the name stays "Regulars".
  Still open, so do not pick: title screen, colour-blind support, the "Town Diner" subtitle.
- Sheet 7's sampled palette is a suggestion, not a requirement.

## Working economically

Every tool call re-sends the whole conversation, so keep context small.
- Concept images are large: look at one only when you need to, and rely on the style guide's
  written description for the rest.
- Use `grep` or a line range, not whole-file reads, on `docs/STYLE_GUIDE.md` (about 1,100 lines).
- Do mechanical edits and screenshot checks inline; start a subagent only for genuinely
  independent work.
