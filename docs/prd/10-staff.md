# PRD 10: Staff

**Status:** built, all eight milestones (16 November 2026). What it built is in `docs/DESIGN.md` section 1.
**Size:** very large; eight milestones (10.1 to 10.8). **Needs:** per milestone (see
the end). 10.1 and 10.2 can start now; helpers in the room need PRDs 8 and 9 well along. **Touches:** new `sim/staff.gd` (applicants,
wages, satisfaction, haggling, breaks, training), new `sim/jobs.gd` (the task board),
`sim/town.gd` (tolerances), `sim/guest_mood.gd`, `sim/catalog.gd` (the desk),
`sim/ledger.gd` (wages), `game/main.gd`, a new `game/staff.gd` (helpers in the room),
`game/guest.gd`, `game/hud.gd`, a new `game/desk_screen.gd`, tests, docs.

## Goal

Hire townspeople to work in the restaurant. The player writes a job post at a desk,
townspeople who suit it apply, the player swipes through their CVs, and the hires do the
post's tasks by themselves during service. Pay, duties, breaks and satisfaction are
managed at the desks: adding work, haggling, training, firing.

All numbers marked *tunable* are starting values, named constants in `sim/staff.gd`.

## 1. Tolerances (every townsperson, guests included)

- Each townsperson has a tolerance for **food**, **service** and **clean**, 1 to 5,
  seeded with the run like tastes. Low tolerance means they care. Variety gets none.
- **Guest mood:** each topic's effect is scaled by tolerance: 1 is 1.6x, 3 is 1.0x, 5 is
  0.4x (*tunable*). Food scales the joy or letdown from food quality, service scales how
  fast patience drains, clean scales disgust.
- **Hints, not numbers:** guest cards never show tolerances, but thoughts and the card
  hint at them ("Fussy about the food", "Doesn't mind a mess", "Hates to wait"), shown
  once a guest has reacted strongly to that topic. A CV shows them in full.
- **Skill = 6 minus tolerance**, shown on a CV as Cooking (food), Serving (service) and
  Cleaning (clean), five stars each. Skill sets how well they do that kind of task: a
  cook's prep result, how much dirt a cleaner's wipe clears, how much a guest likes
  being served by them.
- **Rating:** a separate overall rating, 1 to 5 stars, seeded. It sets how fast they walk
  and work and the base of their asking wage.
- **Training changes tolerance.** Each task done raises that kind's skill a little
  (lowers the tolerance), *tunable* `TRAIN_PER_TASK`. Training someone is giving them a
  duty in a kind they are weak at and letting them do it. The change is permanent: a
  former cook who still visits as a guest is now fussier about food.

## 2. The desk

- A one-cell piece, bought and sold like any other, usable by either chef at night.
  Everything about staff happens at a desk.
- **One desk per employee.** Open posts plus hires can never exceed the number of desks.
  Selling a desk is refused while it would leave someone without one.
- A desk has an upgrade tree (PRD 8 style), for later: a locker (they arrive earlier and
  start faster), a noticeboard (more applicants), and so on. Not specified here; the
  desk ships with no upgrades.

## 3. The job post

Written at a desk at night, like naming a menu item. One post is **one opening**. It
stays up until filled or taken down. It holds:

- **A name** ("Grill cook").
- **Duties**, a checklist grouped under three headings, listing only tools in the room.
  Tools are listed by kind (ticking "stove" covers every stove) and a duty follows its
  tool's upgrades (a mop duty stays one when the mop becomes a flat mop). A tool sold out
  of the room greys its duty.
  - **Cooking:** one line per prep tool kind in the room, "Fetch ingredients" (from
    storage), "Assemble trays" (prepped food onto a tray against its ticket).
  - **Serving:** take orders, carry trays to tables, clear tables, help fallen people up.
  - **Cleaning:** one line per cleaning tool kind (mop, sponge, scraper, spill kit),
    "Wash up" (the sink), "Empty the bin".
- **Breaks:** how many five-minute breaks a day, 0 to 3. In game a break is a few seconds
  (*tunable*, `BREAK_SECONDS := 8.0`). Breaks are spaced evenly through the day: with
  `n` breaks, break `i` starts at `day_length * i / (n + 1)`. So two people with the same
  count break together and chat (section 7), and a 2-break and a 3-break person never
  overlap. Each break raises satisfaction, so breaks are a way to make a low wage a
  decent job.
- **Days off:** how many days off in each five-day week, 0 to 2. Each one raises
  satisfaction more than a break. The employee chooses which days (see "The week").
- No wage: each applicant names their own price.

### The week

Staff work in five-day weeks: days 1 to 5, 6 to 10, and so on (the critic's day 5 falls on
the last day of the first week). This PRD adds the week only for staff; rent or anything
else on it is later work. At the start of each week's first build phase, every employee
picks their days off for the week, at random, never two days in a row and avoiding a
day another employee already took when they can. The staff list shows the week as five
boxes per person, days off crossed, so the player can plan the menu and the floor. Days
off are paid. Someone hired mid-week starts taking days off the next week.

## 4. Applying

- Each night every townsperson who is not employed and not staying away may apply to
  each open post. Chance = fit x how much they like the restaurant. Fit is the sum of their
  skill over the kinds of duty in the post, less a penalty for each duty in a kind they
  are 1 or 2 stars at (so a messy person avoids a post with the mop in it).
- Applicants arrive at the start of the build phase and stand in a line outside the door.
  Their CVs go in a pile at the desks.
- **A CV** shows: name and face, the three skill ratings, the overall rating, the asking
  wage a day, and which post it is for.
- The pile is read as a stack: swipe right (drag, or a button) to hire, left to dismiss.
  A CV not read stays in the pile into the next night, and the one after, until the
  player dismisses it. The person stays out of the line once their CV is in the pile.

## 5. Hiring and haggling

- **Swipe right** hires at the asking wage. **Haggle** (a button on the CV) offers less,
  with the same rules as a raise below.
- **Haggling** (hiring, raises, or a refused duty): the player names a figure below the
  ask. They accept with a chance that falls the further below the ask it is (and lower
  with low satisfaction). After two refused counters they either take the last offer or
  walk away (quit, or for an applicant, leave), decided by satisfaction.
- A townsperson who works for you stops coming as a guest, except that on a day off a
  satisfied one (satisfaction above `VISIT_FROM := 0.6`) may come in to eat, as any guest,
  tolerances and all.

## 6. Pay and satisfaction

- **Asking wage a day** = `WAGE_BASE` x rating + a share for each duty, heavier duties
  worth more (mop more than sponge, fryer more than board).
- **Wages are paid at the end of the night**, a STAFF line on the restock note and the
  receipt, like ingredient stock. A wage that cannot be paid is not owed later; that
  employee loses a large chunk of satisfaction (`UNPAID_HIT := 0.4`) instead, and if it
  takes them to the bottom they leave by the usual rule.
- **Satisfaction**, 0 to 1. Each night it moves toward a target: pay against what their
  duties are worth to them. A duty in a kind they are weak at (1 or 2 stars) counts
  double. Breaks and days off add to the target. During the day it drops with their own tolerances at
  work (a clean-sensitive cook in a filthy kitchen, a food-sensitive server carrying bad
  food) and with slips (PRD 9). Idle chat and breaks move it (section 7).
- **Low satisfaction** makes them slower to react and more prone to mistakes: burnt
  food, a dropped tray, dirt left behind, some on purpose. At the bottom fifth for 3
  nights running (*tunable*) they quit.

## 7. Talking

When a helper is idle or on a break and another helper is idle or on a break nearby,
they chat: both get a speech bubble, and their satisfaction moves toward each other's
(`CHAT_SHARE` a second, *tunable*). A happy crew lifts a sour one, and a sour one drags
a happy crew down. Breaks are the player's way to arrange this.

## 8. Managing staff (the desk at night)

- **The staff list:** each hire with their face, duties, breaks, days off (the week as
  five boxes), wage, satisfaction (a meter and a word) and the three skills, which grow
  with training.
- **Adding a duty:** they accept with a chance from their satisfaction after the change.
  If they refuse: withdraw it, or negotiate. Negotiating, they name a raise; the player
  approves, denies (they quit) or haggles (section 5).
- **Removing a duty, adding a break or adding a day off** is free and raises satisfaction. **Cutting a
  wage** is not possible: fire and rehire.
- **Firing:** with severance (a day's wage) or without. Without, their opinion of the
  restaurant drops more and their friends hear it.

## 9. In service

- Everyone works the whole day, door open to door closed, except on their days off. They arrive as the door
  opens and leave as it closes; the build phase is the chefs' alone.
- **The task board** (`sim/jobs.gd`): every open task with its place and the duty it
  needs: an ingredient a ticket lacks (fetch, then prep), a tray to assemble, a tray to
  carry, a table to order, a table to clear, any dirt (a level 1 trail ranks last), a fallen person,
  dishes in the sink, a full bin.
- Each helper takes the nearest, most urgent task their duties allow and reserves it.
  A chef doing a task takes it off the board. A chef can take anything a helper is
  holding or cooking, and the helper moves to the next task.
- Helpers do not play minigames. The result rolls from skill, the tool's quality (PRD 8)
  and satisfaction. A bad roll drops grease as a bad chef prep does (PRD 9).
- With nothing to do they wait by a desk, or chat (section 7). They slip and are helped
  up like anyone.
- No commands during service: everything is set at the desks.

## Milestones

Build order and tandem work: `docs/prd/README.md`, "Build order for PRDs 8 to 10". Tests
for this PRD go in a new `test/unit/test_staff.gd`. Keep the desk out of the shop until
10.6 merges, so no build on `main` sells a hire who does nothing.

1. **10.1** Tolerances on townspeople, in guest mood, and as card hints. *Needs nothing.*
2. **10.2** `sim/staff.gd`: applying, CVs, wages, satisfaction, haggling, breaks, days off
   and the week, chat, training, firing. Tests only. *Needs nothing* (duties are ids it is
   given; it does not read the room).
3. **10.3** The desk and its screen: job posts with duties read from the room, the CV
   pile and swipe, haggling at hire. *Needs 10.2 and 8.2* (duties list tools by kind on
   counters).
4. **10.4** The staff list: duties, breaks, days off, raises, firing; wages on the
   restock note and receipt. *Needs 10.3.*
5. **10.5** `sim/jobs.gd`, the task board: every task kind with its duty. Tests only.
   *Needs 10.2, 8.4 (fetching from storage) and 9.4 (dirt, fallen people, mops).*
6. **10.6** Helpers in the room: walking, taking tasks, cooking, serving, cleaning, breaks,
   days off, chat. The desk goes on sale. *Needs 10.4 and 10.5.*
7. **10.7** **An all-staff run:** a demo (`REGULARS_DEMO=staff_only`) and a headless test
   where helpers run a whole day with no chef. Any task nobody can do shows up as stuck
   tickets or tables; decide then who does it and add the duty. *Needs 10.6 and 8.6* (every
   tool exists).
8. **10.8** Demos, style guide "As built", `DESIGN.md`. *Needs 10.7.*

## Open questions

None (16 November 2026). Shift hours and the desk's upgrades are later work.
