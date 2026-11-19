# Regulars: how it looks and feels

Every agent that builds something a person sees reads this first and follows it. Two agents
should build the same screen the same way. This file is the short, opinionated rulebook;
the long record of the art lives in `docs/STYLE_GUIDE.md` (art source of truth, its "Resolved
conflicts" and "Rules so far" win over concept images), `docs/AUDIO_GUIDE.md` (sound and music)
and `docs/DESIGN.md` (game design: what is built and what is parked). `AGENTS.md` says how to
run the game and take screenshots. Where this file and the code differ, the "Where the code
differs" section at the end says which wins.

## The brief, in the maker's words

> The game has a theme of analog, wooden toys. It's about simplicity, relaxation, and growth.
> It's very simple.

Everything below follows from that. If a choice is unclear, pick the one that is more
**wooden, more analog, simpler, and calmer**.

## The feeling: five principles

**1. Wooden toys, not screens.** Everything looks like it was turned, painted and glued by
hand: painted wood, soft vinyl, brass, paper, card. Matte with a gentle sheen; never mirror
chrome, glass, neon or glow-UI. *In practice:* the world is a toy diorama (peg-doll people with
no legs and floating mitten hands, chunky rounded boxes with a 5 cm bevel, a thick slab on a sheet
of paper). The interface is physical objects too: a wooden desk calendar with binder rings, a
money tag on a string, a cork board on ropes, a clipboard with a torn receipt. A new
screen is a card, tag, note or tray, not a flat rectangle.

**2. Analog, not digital.** Things are pressed, stamped, torn, hung and turned, not faded or
toggled. *In practice:* a walkout is a rubber stamp that thumps a slot and dries darker; the
open/closed sign is a paper card on two strings that spins; the new day turns a calendar page;
doneness is a radial dial with a needle, not a percentage. No numbers where an object can say it.

**3. Simple and readable.** One idea per surface, flat colour, a fixed camera. Characters must
read at about 60 px, food and icons at about 20 px. *In practice:* each station has its own
silhouette; each food state differs by shape, not only colour; each icon is one bold shape.
If it needs a paragraph to explain, remove something.

**4. Relaxed.** The player is cooking for neighbours, not defending a base. Failure is funny, not
grim; pressure is shown softly. *In practice:* a burnt patty is a "hockey puck" with grey smoke
and a wobble, not a red alarm; guests lose patience with a slow tint and a thought bubble; a
walkout is a stamp and a sigh (a deflating clarinet), not a siren. No countdown timers in
big red numerals, no screen flashes, no shouting.

**5. Growth you can see.** The player's progress is the diner itself, and the town knowing
them. *In practice:* every upgrade changes what is on screen (a brass stud on the worktop edge
per efficiency step, a second pan on the two-hob stove, a new rug, a fuller room); named
townsfolk (Mabel, Otis) return, and the town book shows their standing as pips and an arrow.
Spend and reward feedback show the thing getting bigger: a coin pops, then banks into the tag.

## Voice and tone

- Warm, small-town, plain words, a touch of dry humour. Like a handwritten note on the counter.
- Short. A label is one to three words ("COOK", "Hang", "Set up for day 3"). A line of help is one
  plain sentence with no punctuation fuss. Say the thing, then stop.
- Talk about people by name: "Serve Mabel", "HALF PRICE FOR GUS", never "Customer 3".
- Failure is gentle and a bit funny: "LEFT UNPAID", "CLOSED DOWN", "Nothing I liked on the menu".
  Never blame the player, never use "Error", "Invalid" or "Failed".
- No jargon, no exclamation marks in system text, no emoji. Numbers appear where money matters
  ("+$12"); otherwise prefer words, pips and icons.
- Interface text is set in capitals in Patrick Hand (see Type). Write the string in normal
  case in code only where the surrounding screen does.

## Colour

Colour tokens are named constants in code. **Use the constant, never a literal hex.** If you
need a colour that is not here, add it where the family lives and add it to this table.

| Role | Token | Value | Defined in |
|---|---|---|---|
| Ink: all text, rims, outlines | `Hud.INK` / `Build.TRIM` / `Icons.INK` | `#3a2c22` | `game/hud.gd`, `game/build.gd`, `game/icons.gd` |
| Cream paper: cards, labels, buttons' text | `Hud.CREAM` / `Build.PAPER` | `#fff6e6` | same |
| Paper inset (a field's well) | `Hud.PAPER` | `#f4ead8` | `game/hud.gd` |
| Kraft (mats, crates) | `Hud.KRAFT` | `#e6cfa6` | `game/hud.gd` |
| Newsprint (the critic only) | `Hud.NEWSPRINT` | `#ede5d0` | `game/hud.gd` |
| Wood, interface | `Hud.WOOD` | `#b9824e` | `game/hud.gd` |
| Wood, world / dark wood | `Build.WOOD`, `Build.WOOD_DARK` | `#b07a48`, `#7a5235` | `game/build.gd` |
| Coral: the accent, buttons, tabs, the pass | `Build.CORAL` (world), `Hud.CORAL` (interface) | `#f07a63`, `#ee7560` | `game/build.gd`, `game/hud.gd` |
| Teal: cabinets, tiles, P2 | `Build.CABINET`, `Build.TILE_TEAL` | `#1f6470`, `#236a74` | `game/build.gd` |
| Cream wall, tile | `Build.WALL`, `Build.TILE_CREAM` | `#f6eedd`, `#f1e8cc` | `game/build.gd` |
| Backdrop paper | `Build.BACKDROP` | `#d9cfc1` | `game/build.gd` (per theme) |
| Good / done | `Build.GOOD`, `Icons.GREEN` | `#6fcf97`, `#7fbf6a` | `game/build.gd`, `game/icons.gd` |
| Warning / gold | `Build.WARN`, `Icons.GOLD` | `#ffd452`, `#f2b632` | same |
| Danger | `Build.DANGER`, `Icons.RED` | `#e83d36` | same |
| Shadow | `Hud.SHADOW` | plum-brown `#5a423a` at 38% | `game/hud.gd` |
| Night | `HudWidgets` night | `#2f3e63` | `game/hud/widgets.gd` |

Rules:
- **Warm paper and wood do the work.** Coral is the one accent. Green, yellow and red are
  reserved for live status (done, careful, trouble), stamps and icons, never for decoration.
- **Guests wear cool, muted colours only** (blues, teals, purples, browns, creams, charcoal).
  Never coral, green, yellow or red. Player chefs are white with trim: P1 coral, P2 teal, P3
  yellow, P4 green (`Peg.PLAYER_TRIM`).
- **Shadows are plum-brown, never black or grey.** Text is dark brown ink, never black.
- **Flat fills.** No gradients, except a 10 to 15% darkening at the foot of walls and bases.
- **Colour never carries meaning alone.** Pair it with shape, a word or a count (see Components).
  Colour-blind support as a whole is still open; do not decide it here.
- Surface finish (roughness): 0.85 to 0.95 walls, fabric, plastic (`Build.R_MATTE`); 0.55 to 0.65
  wood and metal (`R_WOOD`); 0.35 to 0.45 tile and food (`R_GLOSS`).
- Two themes exist (diner, seaside). A theme swaps materials and colours, never gameplay, shapes,
  heights or bevels. Anything you add must work in both; screenshot both.

## Type

- One face: **Patrick Hand** (`assets/fonts/PatrickHand-Regular.ttf`, OFL), hand-lettered and
  rounded. Get it with `Hud.lettering()`; the interface `Theme` is built in `Hud._theme()` in
  `game/hud.gd`. Do not add a second face, and do not use the engine default.
- Set in **capitals** on the interface. Ink on cream; cream on coral buttons.
- Sizes in use, so pick from these: **16** small tags, tabs and search; **20** buttons (the
  theme default); **24** card headings and fields; **36** in-world name tags; **64** banners
  ("DAY 3"). Do not invent in-between sizes.
- One weight. Hierarchy comes from size, colour (ink or coral) and the paper it sits on, never from
  bold or italic.
- World text (names, menu board) is camera-facing and sized in world pixels; the menu board is
  chalked cream on dark.

## Spacing and radii

- The game's unit is the 1 m grid; walls are 0.3 m thick (`Scenery.WALL_T`), full walls 2.4 m,
  cutaways 0.55 m, work surfaces 0.9 m, `Build.BEVEL` 0.05 m.
- Interface spacing is on a 4 px grid: separation 5 to 8 between lines, panel margins 14 by 10
  (`HudWidgets.Sheet` default), label cards 16 by 12, wider cards 20 to 28. Gaps between sibling
  cards 8 to 12. Keep screen edges at least 22 px clear.
- Radii: **5 to 6** paper and labels, **8** fields, **9 to 10** buttons and keycaps, **12** wooden
  trays and plaques, **24** the clipboard. Round everything; a sharp corner is a mistake, except
  the torn zigzag foot of a bill.
- A raised thing has a plum-brown shadow offset straight down (3 to 6 px) and, for wood, a dark
  foot and a lighter lip (the 5 cm bevel). Build these with `HudWidgets.Sheet` kinds (`paper`,
  `label`, `inset`, `wood`, `clip`, `key`), not by hand.
- Camera is fixed: orthographic, 37 degrees down, rotated 45 degrees. Never add a free camera or
  perspective view.

## Motion

- **Things move like objects with weight.** Ease out for arrivals (about 35 uses of `EASE_OUT`
  in code), ease in for departures; `TRANS_CUBIC` or `TRANS_SINE`. No bounce-spam, no linear
  slides, no spring physics on text.
- Durations: **0.18 to 0.25 s** small feedback (press, tick, hover); **0.3 to 0.6 s** things
  entering or leaving (a card, a tab, the tray); up to **1 s** for a signature move (calendar
  page, tag torn off). Nothing a player waits on is longer than that; never block input on a
  decorative move.
- Every prop has its own gesture: roll (clock), lift and rattle (calendar), page-turn, thump, rip
  and flutter (tag), rope pull (board), stamp, spin on a string (door card). Reuse these before
  inventing a new one.
- Characters glide and bob; no walk cycle. Emotion is body tilt (lean 20 to 25 degrees into a run,
  slump when bored), squash and stretch, floating hands.
- Effects are flat cut-out billboards in four frames, crisp edges, no soft alpha (steam, smoke,
  sparkle, bubbles, stars). Heat ladder: steam off-white, smoke warm grey, burning smoke charcoal.
- Lighting is soft: a gentle key and tinted fill, soft shadows about 60% dark, filmic tonemap, a
  sun that arcs right to left, an orange sunset with lamps coming up at night. Tilt-shift blur on
  the world only, never the interface; the Options screen can turn it off.
- Respect the pause: the game pauses behind Options and other cards.

## Sound

Full detail in `docs/AUDIO_GUIDE.md`. In short:
- **Every physical interaction has a sound**, generated by `tools/make_sfx.py` into `assets/sfx/`
  and played with `game.audio.sfx(id)` (`game/main/audio.gd`), which varies pitch a little so
  repeats do not sound mechanical. A new prop or gesture gets a new sound, in the same family
  (wood, paper, brass, bell).
- The stove sizzle and doneness dial are the most important sound: nothing may mask them.
- Music is acoustic and hand-played: piano or toy piano, nylon guitar, upright bass, brushes,
  woodblock, clarinet or melodica. No synths except a soft night pad. Light swing and bossa, cosy
  and a little comic. One recurring "Regulars" tune. Tracks: Daytime, Nighttime, Closed, Intro
  (`MUSIC` in `game/main.gd`). A theme swaps instruments, keeps tune and tempo.
- Quiet by default (`MUSIC_DB`), cross-fade between tracks (`MUSIC_FADE`), volumes in Options.
- Sound confirms; it never nags. No alarms, buzzers or voices.

## Components and their states

Build from the existing parts in `game/hud/widgets.gd` and the `Theme` in `game/hud.gd`. Before
making a new widget, check there and in `game/hud/*.gd`.

| Component | Look | Where |
|---|---|---|
| Button (stamp) | Coral rounded rect, cream text, darker 5 px foot, plum shadow | `Hud._stamp_button` |
| Keycap prompt | Cream cap on a wood-edged tab: the key and the word ("E  COOK") | `HudWidgets.Sheet` kind `key` |
| Card / receipt / menu | Cream paper on wood or clipboard, ink text, coral ribbon heading | `Sheet` kinds `paper`, `clip`, `wood` |
| Label card | Cream, 2 px ink rim, 5 px radius | `Sheet` kind `label` |
| Text field | Cream, 2 px ink border, 8 px radius, ink at 45% placeholder | `Hud._theme` (`LineEdit`) |
| Slider | Ink-22% track, coral fill | `Hud._theme` (`HSlider`) |
| Meter | Chunky bar read by length, ink-rimmed; fill green, tan or coral by level, plus a word | `HudWidgets.RepMeter` |
| Icon | Flat polygon, dark rim, one bold shape, reads at 20 px | `game/icons.gd` |

States every component must handle:
- **Default, hover, pressed:** hover lightens the fill 10%, pressed darkens 12% and sinks the
  foot. Never rely on hover alone: the game is played on keyboard, controller and touch too.
- **Focus:** a controller or keyboard cursor is shown (coral frame, or the chef's trim colour in
  co-op), not the engine's blue outline (`StyleBoxEmpty` is used for the theme's focus on purpose;
  supply your own cue).
- **Disabled / unavailable:** muted tan `#c9b9a3` with cream text, or the piece dimmed with a dashed
  inner rule; always **say why in words** ("Can't be made tonight: no buns").
- **Empty:** a calm, physical empty state: an empty tray, a blank card, one plain line ("No one
  has applied yet"). Never a blank screen or a spinner.
- **Loading:** the game has almost none; do not add spinners. If something must wait, show a
  prop in motion (a turning page, a swinging tag) and keep input responsive.
- **Error / refused:** a coral line or a coral cross in the place of the thing, gentle wording,
  and a wobble or soft "fail" sound. Placement that cannot happen shows the piece hidden and a red
  cross on the spot. Never a modal error box.
- **Success:** a gold star spins up, a coin pops and banks, a soft ding. Small and brief.
- **Shape plus colour:** done = green + tick, miss = coral + cross, hit = star, quality = pips by
  count. State must read in greyscale.
- **Touch and pad:** hints change with `REGULARS_INPUT=touch|pad` (`game/controls.gd`). Touch targets
  at least 44 px; keep controls off the screen edges where the device's gestures and bars sit (the
  joystick and Use button are inset, see `game/controls.gd`). Layouts must hold on a phone-wide and a
  desktop window.

## Do and don't

| Do | Don't |
|---|---|
| Build a new screen as a paper card on wood with an ink rim, using `HudWidgets.Sheet`. | Add a flat grey panel, a Godot default control or a blue focus ring. |
| Use `Hud.INK`, `Hud.CREAM`, `Hud.CORAL` etc. by name. | Paste `#000`, `#fff`, a new hex, or `Color.RED`. |
| Show a number as an object: pips, a coin, a dial, a tag. | Show a bare progress percentage or a debug-looking readout. |
| Ease a card in over about 0.3 s with a small sound (`slide`, `tick`, `flip`). | Fade opacity in and out with no sound, or add a 2 s intro. |
| Say "LEFT UNPAID", "Serve Mabel", "Hates to wait". | Say "Error", "Customer 3", "Transaction failed". |
| Mark success or trouble with shape and colour together. | Use red or green alone. |
| Make a burnt patty funny: puck, smoke, wobble. | Flash the screen, buzz, or show a skull. |
| Match the neighbours: radius, shadow, spacing of the screen next door. | Invent a new radius, size or shadow because it was convenient. |
| Show growth: change the model, add a mark, show a new prop. | Show growth only as a bigger number. |
| Screenshot both themes and both 60 px and 20 px reads. | Ship a visual change you have only compiled. |

Worked example: a "Staff" row in a list. Cream paper (`Sheet` kind `paper`, 6 px radius), margins
14 by 10, ink name at 24, post and wage at 16, satisfaction as a face (happy, flat, cross) plus a
word plus a meter (coral, tan, green), a coral button with a 5 px foot to fire. Unaffordable
raise: tan disabled button, cream text, a line in words saying why. Empty list: a blank paper row
"Nobody on the books yet". The card eases in (0.3 s, ease out) with the `slide` sound.

## Where the code differs from this file

The maker's words ("analog, wooden toys; simplicity, relaxation, growth") win over the code. The
code mostly agrees with them; known gaps for the next change to close:

- **Two corals.** The interface uses `#ee7560` (`Hud.CORAL`, `Icons.CORAL`), the world `#f07a63`
  (`Build.CORAL`). Pick one (the world's) and make the others point at it. Same for ink, defined
  three times (`Hud.INK`, `Build.TRIM`, `Icons.INK`) and cream (`Hud.CREAM`, `Build.PAPER`,
  `Icons.CREAM`): they match, so define each once.
- **Colour literals in widgets.** Several `Color("#...")` values live inline (`#c9b9a3` disabled,
  `#cbbfa8` keycap, `#b3aba0` clip steel, `#2f3e63` night). They should become named tokens.
- **No shared type scale or spacing constants.** Sizes (16, 20, 24, 36, 64) and margins are
  literals at each call site. The scales above are the intended tokens; a future change should add
  them as constants in `game/hud.gd` and replace the literals.
- **No shared motion constants.** Durations and easing are per call site; the ranges above are
  the rule.
- **Blueprint blue** (`#2c5c8c`) on the upgrade tree is a deliberate, documented departure from
  paper and wood ("plans for this piece"). It stays; do not spread it.
- **The old style guide says** dark trim caps on walls and a coral "Cutaway"; the later anchor pass
  made walls cream with coral cut faces. The anchor pass and `docs/STYLE_GUIDE.md` "As built" win.
- **Open, so do not decide:** the title screen composition, colour-blind support, and the "Town
  Diner" subtitle. The name "Regulars" and the peg-doll logo are decided.
- Departing from this file is allowed when it works better for play or the engine; keep the spirit
  (wooden, analog, simple, calm, growing) and note the departure here and in
  `docs/STYLE_GUIDE.md` "As built".
