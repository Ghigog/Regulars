# Regulars: concept art brief

> **Status.** All 16 sheets have been delivered and filed. The record of what came back,
> the rules taken from it, and the settled conflicts is `docs/STYLE_GUIDE.md`; the images
> are in `docs/art/`. This brief is the original request and is kept for reference. Where
> it disagrees with the style guide, the style guide wins.

A brief for a concept artist. It lists every sheet we need, what must be on it, and the
constraints the game imposes. Sheets are in priority order; 1 to 4 unlock the rest.

## The game in one paragraph

You run a small restaurant, seen from above as a cutaway diorama. Guests arrive, sit,
and wait for food. You control one chef directly: take meat from the fridge, cook it on
the stove, plate it, carry it to the table, then clear and wash the dirty plate. Each day
is busier than the last. Guests are named townsfolk who come back, and how they feel
(patience, disgust, joy, how good the food was) decides what they tip. The tone is warm,
funny and a little frantic: a toy restaurant full of small people with big feelings.

## What exists now

See `concept/concept_01.png` (first mood render) and `concept/shot_service.png` (the game
today). Treat these as a starting point, not a target. Everything is built from plain
boxes, cylinders and spheres. The proportions and palette are placeholders that happen to
work; the artist is free to improve them.

## Rules that apply to every sheet

**Camera.** Fixed and orthographic (no perspective). It looks down at about 37 degrees
from the horizontal, rotated 45 degrees, so the viewer sees the top, front-left and
front-right faces of everything. The two far walls are visible; the two near walls are cut
away or very low. Draw props and characters from this angle unless a sheet asks for
turnarounds.

**Scale.** The world is a grid of 1 m squares. The starting restaurant is 10 x 7 squares:
a 4 x 7 kitchen on the left and a 6 x 7 dining room on the right. Most furniture fills
one square. A character is about 1.25 m tall, with a head roughly 0.55 m across.

**Readability.** On a 1440 x 900 screen a character is only about 60 pixels tall and a
plate about 20 pixels wide. Anything that matters to play must read at that size by
silhouette and colour alone. Detail is welcome but must never be what tells two things apart.

**Style direction.** Toy diorama: chunky, rounded, friendly. Think painted wooden toys or
soft vinyl figures on a tabletop set. Flat colour with soft shadows; no outlines, no
texture noise, no realism. Shapes should be simple enough to model quickly in Blender.

**Current palette (placeholder, hex).**

| Role | Colour |
| --- | --- |
| Backdrop | `#f0dfc4` warm cream |
| Walls | `#fff6e6` off-white |
| Kitchen floor | `#8fc7c3` teal and `#f4ead8` cream checker |
| Dining floor | `#d9a066` / `#cf9458` wood |
| Accent, the "brand" colour | `#e56b5d` coral |
| Kitchen cabinets | `#3f7f86` deep teal |
| Good / perfect | `#5fd38d` green |
| Warning / money | `#ffd34e` yellow |
| Bad / danger | `#ff6b5e` red |
| Text, dark trim | `#3a2c22` brown |

**Deliverables.** Flat colour is enough; no rendering polish needed except on sheet 1.
PNG at 2x screen size or larger, with a layered source file. Label everything.

---

## 1. Style frames (highest priority)

**Purpose.** The single reference every later asset is matched to. If only one sheet gets
made, it is this one.

**Draw.** The whole restaurant at the game camera, mid-service, fully finished:

- The chef at the stove with one patty cooking and steam rising.
- Six guests: two eating happily, two waiting, one visibly impatient, one walking in.
- One uncleared table with a dirty plate, one burger sitting on the serving counter.
- The street edge along the front: pavement, doorway, a guest or two queueing outside.

**Must answer.** How rounded are edges? How strong are shadows? What do walls look like
where they are cut away? How does the diorama end at its edges: a floating slab, a
tabletop, or a street that fades out?

**Variants.** (a) Midday, bright and neutral. (b) Evening, low orange sun, warm lamps on
inside. Same layout, lighting only.

## 2. Character sheet

**Purpose.** Lock the body everyone shares. Guests, chef and future staff are all this body.

**Draw.**

- Turnaround: front, three-quarter, side, back. Also one view from the game camera.
- Proportion guide with measurements: currently a cylinder body 0.4 m wide and 0.6 m
  tall, rounded shoulders, a large sphere head, two floating mitten hands, no legs or feet.
- A decision on legs: none (they glide and bob), stubby feet, or a skirt-like base.

**Must answer.** How do arms work with no visible arms: floating hands, or short sleeves?
How does the head join the body? How is an item held so it is visible from above?

**Constraints.** Must read at 60 pixels tall. The head is the biggest shape because it
carries the face and is what the camera sees most.

## 3. Faces and expressions

**Purpose.** Faces should replace the floating patience bar as the main way to read a guest.

**Draw.** One head, eight expressions, each shown large and again at actual game size:

- Neutral, content, delighted (great food), impatient, about to snap, disgusted
  (saw something gross), angry (walking out), chewing.

**Must answer.** Eye style (dots, ovals, lines), whether there is a mouth, brows or
cheeks, and how much of the change is shape versus colour (for example going red).

**Constraints.** Seen from above at a steep angle, so features sit high on the head.
Each expression must be distinguishable at 20 pixels across.

## 4. Townsfolk variety

**Purpose.** Guests are named regulars the player learns to recognise ("Mabel always
tips well"). They need to look like individuals built from one kit.

**Draw.** Twelve guests in a line-up, then the kit they are made from:

- 5 skin tones, 8 hair shapes (including bald), 6 hats, glasses, beard, 10 outfit colours,
  3 or 4 outfit patterns (stripe, apron, collar, dungarees).
- Current names for flavour: Mabel, Otis, Priya, Gus, Ingrid, Tobias, Wren, Hattie,
  Leopold, Suki, Barnaby, Odette, Felix, Nell. A mix of ages and types.

**Constraints.** Each guest needs one feature that reads from above at a glance:
a hat, a hair colour, a bold shirt. Avoid coral, green, yellow and red as main outfit
colours; those mean something in the interface.

## 5. Chef and staff

**Draw.** The player's chef (white jacket, tall hat), plus three later roles on the same
body: server, dishwasher, host. Four colour variants of the chef for co-op players.

**Must answer.** What makes the player instantly findable in a crowded room.

## 6. Key poses

**Purpose.** Defines the animation list. Rough thumbnails are fine.

**Draw, from the game camera.**

- Chef: idle, running, carrying a plate, carrying a patty, putting something down,
  flipping or prodding meat, washing up, panicking at a burning stove.
- Guest: walking, queueing, bored in the queue, sitting down, waiting, tapping
  impatiently, served (small celebration), eating, paying, storming out, recoiling in disgust.
- Two friends noticing each other at a table.

## 7. Colour and material key

**Draw.** Final palette as swatches with a named role for each, and a material ball for
each surface: wall, wood, tile, metal appliance, plastic, fabric, food, skin.

**Must answer.** Matte or glossy? Any gradients? How dark do shadows go, and what colour
are they? One rule for edge rounding (for example "every edge has a 3 cm bevel").

## 8. Kitchen props

**Draw.** Each at the same scale, three-quarter view, one grid square unless noted:

- Fridge (the one tall item, about 1.7 m), stove with four burners, plain counter,
  sink, plate stack on a counter, bin, serving counter (the "pass", a row of 5 between
  kitchen and dining room, in the coral accent colour).
- States: fridge open and shut; stove off, cooking, burning; sink empty and full of suds;
  plate stack with 4, 2 and 0 plates; bin empty and overflowing.

**Constraints.** The player must tell stations apart from above without labels. The top
surface is the most visible face, so identity lives there. Counters are 0.9 m tall and
items sit on top of them.

## 9. Food and carried items

**Purpose.** Cooking is the core action, and its feedback is the look of the meat.

**Draw.** Large, and again at game size (about 20 pixels):

- Patty in five stages: raw, nearly there, perfect, dry, burnt.
- Plate, plated burger, half-eaten burger, dirty plate with crumbs.
- The doneness timer above the stove: currently a bar with a pink (raw), green (perfect)
  and orange (drying) zone and a needle. Propose something better that reads in a glance.
- For later: 3 or 4 more dishes and their raw ingredients, to check the style stretches.

**Constraints.** Raw, perfect and burnt must be unmistakable by colour and silhouette at
20 pixels. Perfect should look delicious; burnt should look funny rather than grim.

## 10. Dining room props

**Draw.** Round table for two with two chairs, a four-seat table, a booth, a potted fern
(small, medium, large), wall art, a rug, a coat stand, a menu board.

**Must answer.** Lighting fixtures that work from this camera. Hanging lamps were tried
and removed because the shade sits in front of whoever is behind it. Wall lights, table
lamps or floor lamps may work better.

**Constraints.** Chairs must leave the seated guest's head and face visible from above.

## 11. Architecture kit

**Draw.** The modular pieces the room is built from, each one grid square wide:

- Wall, wall with window, wall with door, corner, low partition wall.
- The cutaway rule: how a near wall is shown (removed, cut to knee height, or transparent).
- 3 floor finishes each for kitchen and dining room; 3 wall colours or wallpapers.
- A doorway from kitchen to dining room.

**Note.** Players will later place walls and floors themselves, so pieces must tile and
look right in any arrangement.

## 12. Exterior and street

**Draw.** The shopfront from the game camera: door, sign, awning, front windows,
planters. The pavement where guests queue (a row of up to five). The road beyond. Street
furniture: lamp post, bench, bin, bike, tree.

**Must answer.** What is beyond the edges of the scene. What the neighbours look like, or
whether the restaurant stands alone.

## 13. Effects

**Draw.** In the same flat style, as short 3 or 4 frame sequences:

- Steam, cooking smoke, black burning smoke, sizzle spatter.
- Sparkle for a perfect dish, coin pop for payment, bubbles at the sink.
- A disgust effect (stink lines or a green waft) and an anger effect for a walkout.
- Thought bubbles: the bubble shape, plus icons for "wants a burger", "bored", "saw
  something gross", "loved it".

## 14. Interface

**Draw.** Mockups at 1440 x 900 over a style frame:

- Service screen: day number and day progress, money, three walkout markers, the prompt
  above the station the chef is facing (for example "E  Cook").
- End-of-day card: meals served, sales, tips, walkouts, total earned, one line of town gossip.
- Game-over card: days survived, total earned, best run.
- Icon set in one style: money, tip, walkout, patience, disgust, joy, food quality, day.

**Constraints.** The interface should feel like part of the toy world (card, paper,
chalkboard, receipt) rather than a generic overlay. Text is dark brown on cream today.

## 15. Logo and title screen

**Draw.** Three logo directions for the working title "Regulars" (the name may change),
and one title screen composition using the restaurant.

## 16. Second theme (optional)

**Draw.** Style frame 1 redone as a different location, for example a seaside shack or a
night-market stall, with the same characters. This proves the kit stretches before more
is built on it.
