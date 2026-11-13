# Regulars: style guide

The running record of the game's look. Each time the concept artist delivers a sheet, the
images go in `docs/art/` and this file gets: what was delivered, the artist's own
comments, the style rules we take from it, and anything that differs from the brief
(`docs/ART_BRIEF.md`) or from the game as built.

**Reading the sheets.** The art is produced by an image model, so layouts, labels and
sizes are sometimes wrong and comments sometimes contradict the drawing. Treat every sheet
as inspiration, not an exact spec. Where a sheet contradicts a locked rule or the brief, the
rule wins. The conflicts that matter are settled in "Resolved conflicts" below.

**Freedom to depart.** Everything here, locked rules included, serves the game. An
implementer may stray from any concept, sheet or rule where it works better in the engine
or for play (readability, performance, feel, a better idea). Make the change, keep the spirit
(toy diorama, readable at 60 px and 20 px, the palette roles), and note the departure in this
guide so the record stays true.

Rules marked **locked** come from the artist's stated decisions. Rules marked
**observed** are read off the images and still need the artist to confirm.

## Resolved conflicts

Decisions that settle places where the sheets disagree with each other or with the brief.
Implementers should follow these, not the individual drawings.

| Topic | Decision |
| --- | --- |
| Legs and arms | **Legless, glide and bob** (sheet 2). Legs, shoes and attached arms drawn in sheets 1, 4, 5 and 6 are ignored. Hands are floating mittens. |
| Sleeves | None. Outfits come from the four patterns on sheet 4 as material swaps or thin trim on the standard body. Cap sleeves seen on the sheet 2 figure are not part of the base. |
| Base under the body | A smooth rounded base, not a separate peg. Seated guests perch on the chair seat. |
| Faces | The eight faces on sheet 3 are the game's face set. The more detailed faces on sheet 4 are a variety study only. |
| Wall cross-section | Dark trim brown `#3a2c22`, as the artist's comments say, even though the frames show cream tops. |
| Serving pass colour | Coral (sheet 8 and the brief). The teal pass in the sheet 1 frame is not followed. |
| Guest palette | Cool, muted colours only. Never coral, green, yellow or red on guests. Yellow mittens on dishwashers are allowed as staff gear. |
| Chef | Tall puffed toque, white jacket, player-colour trim only (P1 coral, P2 teal, P3 yellow, P4 green). The "co-op chef" drawn in a server's waistcoat on sheet 5 is ignored. |
| Queue | Five guests, per the brief and the artist's comment. |
| Outlines and grain | The game uses flat colour with no outlines. Dark outlines and painted wood grain on the concept sheets are drawing style. Floors may have a faint grain. |
| Doneness display | The radial dial from sheet 9 replaces the horizontal bar. It sits above each burner, not hidden behind hanging cabinets. |
| Palette values | Sheet 7's sampled hex values (in its table) are a **suggestion**, not a requirement. The game's current colours are fine to keep; adopt the sampled ones where they look better. |
| Wall cabinets and range hood | Optional kitchen dressing. They must never hide the stove or its dial from the fixed camera. |

## Decisions and open items

**Decided**
- **Logo:** the peg-doll direction, ideally the bottom-left version on sheet 15 (the badge-shaped
  one: gold and orange letters, chef hat and guest heads on the letters, teal shield, burger and
  a wooden "TOWN DINER" banner). The top-right peg-doll version is the alternative.
- **Name:** "Regulars" for now.

**Open, to be decided later**
1. **Title screen.** The artist promised a composition but only delivered logos.
2. **Colour-blind support.** Player identity, anger (red) and disgust (green) rely on colour.
   Adding a number on each chef or a shape on each mood is suggested but undecided.
3. **Subtitle.** "Town Diner" appears on the logos and may become a per-theme subtitle.

## As built

The first art pass is in the game. This is where it follows the guide loosely or not at
all, and why. Screenshots: see `CLAUDE.md` for the `REGULARS_SHOT` and `REGULARS_DEMO` variables.

**How it is made**
- Nothing is modelled in Blender yet. Every mesh is generated in GDScript: chamfered
  boxes (the 3 cm bevel), lathed shapes (bodies, plates, pots, hats) and flat cut-out
  cards (dial, bubbles, effects). The shapes follow the rules, so pieces can be replaced
  by Blender models one at a time.
- Icons and effect frames are polygon artwork in `game/icons.gd`, shared by the world and
  the HUD. Effects are four frames, flat colour, hard edges, no alpha.

**Anchor pass (12 Nov 2026).** The midday style frame (`01_style_frame_midday.jpg`) is the
anchor for the environment and sheet 2 for the character; where they disagree with a rule
or a later sheet, they win. What changed:
- Every box is a rounded box with smooth normals (4.5 cm radius, was a 3 cm flat chamfer).
- Palette moved to the anchor: deep teal `#1f6470` cabinets and tiles against cream, coral
  `#f07a63`, warmer oak planks, greige backdrop `#d9cfc1`, grey paving.
- Walls are 30 cm thick soft cream slabs with no dark trim cap. The knee-high cutaway is
  coral with a cream cap. This overrides "Resolved conflicts: dark cap, no coral face".
- The pass is the anchor's teal counter with a coral foot (was a coral block). Tables are
  soft-cornered square tops on teal pedestals (were round); chairs are rounded coral.
- Pegs follow the turnaround: turned wooden foot, darker hem with a yellow stripe, capped
  sleeves, cream mittens with cuffs, a head 12% larger, a tiny coral nose, a soft paint sheen.
- Lighting: a soft key and a high, tinted fill, so nothing is harsh. Cast shadows are soft and only 60% dark; the sun's path is described below. The day ends in an orange sunset with mauve shade (the sheet 1 evening frame) while table lamps and sconces come up. Filmic tonemapping. The camera needs tight clip planes (1 to 80) or an orthographic view gets no sun shadows, and the sun needs small shadow biases or shadows drift away from their casters.
- Diorama: there is no base board. Floors, paving, road and walls are thick pieces of their own material that rest straight on a large sheet of paper (the theme backdrop colour), which catches the cast shadows as in the sheet 1 frames. There is no garden: the lawn, hedges and picket fence are gone. The road, pavement and street furniture stay, along the right-hand side.
- Street rule: the street runs the length of the entrance wall. Its near end stops flush with the near edge of the floor. Its far end runs on past the tall wall that heads toward the street, to where the street's edge sits on the line of that wall's top edge as the camera sees it (wall thickness plus wall height times 14/15).
- Sun: a real arc, whatever the room's shape. It rises on the right of the screen and sets on the left, leaning 24 degrees toward the camera, so shadows run across the picture: leftward in the morning, rightward by evening.
- Tilt-shift: a screen-space blur (`game/shaders/tilt_shift.gdshader`) on a canvas layer between the world and the interface. A band across the middle of the screen (from 27% to 67% of the height) stays sharp, and the blur grows smoothly above and below it, evenly across each row, as a tilted lens does on a photo of a model. It replaced a depth-of-field blur, which blurred by distance from the camera and so cut off at object edges (the door frame blurred while the pavement beside it stayed sharp). The interface is not blurred. The options screen (O) turns it off; `TILT_SHIFT` in `game/main.gd` is the default.
- Shading: every solid surface uses one cel shader (`game/shaders/cel.gdshader`): three gentle light steps blended with a soft falloff, smooth cast shadows, and a fine procedural grain on warm wood. The ink line is a second pass (`game/shaders/ink.gdshader`) that draws each solid again, slightly swollen and inside out, tinted by its surface colour. A screen-space outline was tried and dropped: it gave dashed lines where two edges ran close together.
- Proportions: pegs are drawn at 1.3 times their built size (`Peg.SCALE`), about 1.5 m, so they stand head and shoulders over a counter as in sheet 1. Tables, chairs and worktops are thicker to match (table top at 0.74 m, chair backs to 0.9 m). The grid is unchanged.
- Roundness: every lathed shape has the gentle bends of its profile turned into curves, so bodies, hats, pedestals and lamp shades have round silhouettes. The chef's toque is a soft crown with five billowing lobes. The default furniture bevel is 5 cm and the entrance arch's is 5 cm. Walls are crisp: 2.5 cm.
- Street props follow sheet 12b: a lamp post with a stepped foot and a four-sided lantern; a bench of thick slats on dark chunky legs with a leaning back; a teal bin with a thick dark rim; a wooden balance bike (wooden wheels, dark tyres, coral frame, wooden saddle and handlebar); a tree with a chunky trunk, branch stubs and a lobed crown in a stone surround with grass.
- Room: arranged as in the sheet 1 frames, as an L. The kitchen's back wall stands two rows forward of the dining room's, with a short jog wall between. The entrance and the street are on the right-hand side (the low coral wall with the arch); the near-left side has no wall, the floor simply ends. The cooking line (two stoves, bin, counter) runs down the left wall under a hood with wall cabinets beside it; the fridge, a round-topped doorway, the plate stack and the sink are on the kitchen's back wall; the pass runs front to back with a till on its far end. Tables have a slab top with a small bevel on a slim pedestal; chairs stand on four pale wooden legs. The first room is still 10 x 7 with the 4 x 2 corner behind the kitchen left as bare ground; the player can floor it.
- Walls follow the sheet 1 frame, not sheet 11: plain cream with flat tops and no dark cap. Each run is a union of overlapping slabs, so corners and openings have no seams. Where a tall wall is cut short the cut face is painted coral (sheet 11's cutaway rule). The diner's windows are real openings lined with a rounded coral frame, no glass or sill. The seaside theme keeps a solid wall with portholes. The kitchen's round-topped opening is gone: the player now builds the room (below).
- Built rooms: walls are drawn from the floor plan by one rule, after sheet 1 and sheet 11's cutaway. A wall with floor in front and bare ground behind (the back and left of any room) is a full-height cream wall; every other wall, those between two floors and those on the street side, is the knee-high cutaway with a coral face and cream cap; on the near side the floor simply ends. Dining (plank) back walls get wainscot or clapboard, windows about every 3 m and a sconce near each end; tiled walls stay plain. Doors in a tall wall have a coral frame and a teal door standing ajar; in a knee-high wall they are a pair of teal cafe doors on coral posts. Archways are round-topped in a tall wall and two cream posts with coral ball caps in a low one. One that cannot be used turns grey under a gold road-sign warning card (a new icon, `warning`). Build tools show as green squares or bars on the floor, coral where refused or being removed.
- Kitchen models: a single sloped hood canopy over the stoves with a run of tall wall cabinets beside it; the stove follows sheet 8 (raised back, four burners with the pan on the back one, a knob row, an oven door with a window and bar handle); the bin is sheet 8's dark tapered tub with a steel rim; the pass has one unbroken teal body and worktop (the frame's colours, not sheet 8's coral front).
- Dining: long floorboards running front to back in a calmer brown; a small candle in a glass on each table in place of the mushroom lamp. The framed prints and the coat stand are gone; sconces, the jar shelf and the rug stay. Pavement slabs are 1.5 m. The paper darkens gently toward its corners.
- Still short of the anchor: no range hood, no cash register, street dressing is unchanged,
  chairs have no wooden legs showing, and nothing is modelled in Blender.

**Departures**

| Topic | What the game does | Why |
| --- | --- | --- |
| Faces | Built from small sculpted dots and strokes on the head, not textures. Nose dropped everywhere (the small-size rule). | Stays crisp at any zoom; no texture pipeline. |
| Mood tint | Tints the whole head (orange about to snap, green disgust, red angry), not a gradient from the top. | Flat colour only; reads the same at 60 px. |
| Patience | A chunky patience meter stays under the thought bubble. | The face and tint alone were too slow to read across six guests. |
| Names | A small ink name tag stays over each guest. | "Named townsfolk" is the point of the game; prompts say "Serve Mabel". |
| Thoughts | Bubbles show one icon (burger, Zzz, green cloud, heart). The written thoughts are still recorded in `sim/` but no longer shown. | Sheet 13. |
| Popups | "+$12" stays as ink text beside the coin. "ready!", "burnt!" and "walked out" became stars, flames and the anger mark. | Amounts matter; the rest reads without words. |
| Felix and Nell | Looks invented from the kit (auburn side-sweep and cream collar; top-knot and periwinkle dungarees). | Never drawn. |
| Stove | Steel body, one large burner with the frying pan always on it. | One cooking slot per stove; a pan over four small burners looked wrong. Steel keeps it distinct from the teal counters. |
| Patty looks | "Nearly there" and "dry" are looks only. The game still has three item kinds (raw, cooked, burnt) and the same timings. | No gameplay change. |
| Controls | The chef turns to face the way it moves (eight ways), and uses whichever neighbouring station is most in front, preferring one with something to do. | One key moves diagonally across the grid from this camera, so the chef almost never faced a station squarely. |
| Dial | Shown while a patty cooks; hidden once it burns (flames take over). | The burnt state needs no gauge. |
| Fridge | Shut, and swings open on use to show the meat. | The "open" state has nothing else to hang on. |
| Station states | Not built: sink full of suds, overflowing bin. Washing plays the bubble effect. | No gameplay behind them yet. |
| Outer walls | Stand just outside the floor instead of centred on the grid edge. The front cutaway is centred on its edge. | Keeps the back row of stations and the floor whole. |
| Cutaway | Wall colour with a dark trim cap, including the right-hand wall, which had no wall before. | "Resolved conflicts": dark cap, no coral face. |
| Kitchen dressing | Wall cabinets on the left wall, jar shelf by the stoves, no range hood. | Nothing may hide a stove or its dial. |
| Four-seat table | Sheet 10's square plank top on four square legs, with a chair on each side: two coral, two wood (darker legs), same size and back height as the table for two's. | One piece per cell: the chairs stand on the seat cells. |
| Booth | Teal benches with a coral seat cushion and two coral back cushions on a dark wooden plinth, facing across a narrow plank table on a dark pedestal. Seats one guest per bench, not sheet 10's two; backs stop at the chairs' height. | Fits one cell like the other tables; a four-seat booth would need two cells. |
| Lighting | Sconces on the far walls, a mushroom lamp on each table, a street lamp. No floor lamp. All come up as the sun goes down. | Every corner in the room is walkable. |
| Shopfront | The hanging burger sign sits on the coral door frame. No awning or upper wall. | Those only show in title and photo views, which do not exist yet. |
| Camera | Same angles. Between days the view is wide (size 14.5, was 13.5) so the whole slab and its edge are in frame; during service it moves in on the room and queue (size 11.5, characters about 84 px tall). | The diorama reads best wide; play reads best close. |
| Palette | Brief values nudged toward sheet 7; the dining floor is less saturated than either. | Under warm light the sampled orange glowed. |
| Font | Patrick Hand (open licence, `assets/fonts/`), set in capitals on the interface. | The sheets use hand-drawn rounded capitals. |
| Service HUD | A square desk calendar (coral "DAY" header, binder rings, wooden back) with a wooden clock beside it: 8 am to 8 pm over the day, with a window showing the sun or the moon. The money tag hangs from the calendar on a string and swings as a pendulum. Walkouts are on a pinned cream card on a framed cork board that hangs on two ropes from the top of the screen. The prompt is one wood-edged tab holding the keycap and the word. The controls line shows on day 1 only. | Replaces sheet 14a's plaque and sun dial at the user's request. |
| HUD motion | Every prop moves, with a sound: the clock rolls out from behind the calendar (roll). A new day: the clock rolls back, the calendar lifts with a soft shadow left on the desk (lift), jiggles (rattle), turns a page over the top (page), thumps down (thump) and the clock rolls out. End of day: the tag is torn off (rip), flutters (flutter) and lands on the receipt's right edge (rustle); the board is pulled up on its ropes (rope). Building: the old tag drops away and a new one falls from behind the calendar and dangles (rustle). Service: the board drops in on its ropes. A walkout: a rubber stamp comes down and thumps the next slot (stamp); the ink is glossy, creeps slightly and dries darker over about two seconds, with gaps and specks from the rubber. | The new tag drops when building starts, not at the next service, because money is needed while building. Sounds are made by `tools/make_sfx.py`. |
| Receipt and game over | Receipt rows are capitals with colons and no icons, a coin stack by the total, and a taped yellow "TOWN GOSSIP:" note. The game-over card is a tent card on a wooden stand with a dark ribbon reading "CLOSED DOWN" (the sheet says "GAME OVER") and three centred lines between ornament rules. | Sheets 14b and 14c. |
| Options | O opens a clipboard card with Audio (SFX and music volume) and Graphics (tilt-shift on or off) tabs. The game pauses behind it. | Not on the sheets. |
| World-space bars | Cooking dials and patience bars always draw on top of the room. The order bubble sits above the patience bar. | They were hidden behind the kitchen and each other. |
| Disgust stages | Nothing shows until disgust reaches Ick. Ick: two wavy stink lines. Disgusted: three lines and a puff. Revolted: the sheet 14 green cloud. | Sheet 13 effect, split into three stages to match the rules. |
| Resting faces | Guests look content from a lower joy (0.4) and only look impatient or angry late (patience under 0.35 and 0.15). | The default read as scowling. |
| Themes | Chosen with `REGULARS_THEME=seaside`. Seaside swaps walls (clapboard), windows (portholes), wall art (life ring and paddle), floors, pavement (boardwalk with rope bollards) and road (sea with foam). Stations are untouched. | Sheet 16. No picker yet because the title screen is open. |
| Town book | A second page on the end-of-day clipboard (T): the gossip-note yellow paper, a dark ribbon, each townsperson's name with five ink-rimmed pips and an up or down arrow for today's change. Standing reads by pip count and a word, never by colour alone. | Sheet 14 suggested the gossip note as the home for reputation; a full list needed its own page. |
| Receipt and door card | The receipt has "Town book" and "Set up for day N". There is no "Open" button: an OPEN (leaf green) / CLOSED (dark coral) paper card hangs on two strings from a nail under the door lintel, facing the street, and E at the doorway spins it on its string with a swing from the nail. It reads by colour at 20 px; the lettering is a bonus. | Not on any sheet |
| Half price | Uses the keycap prompt ("HALF PRICE FOR GUS"), a small star burst and the heart bubble. No new art. | Not on the sheets. |
| Shop | Opened with Tab between days. A wooden tray with a paper inset along the bottom. On a kraft mat, one row of pieces (a live render of each model with its price underneath, no card behind it) slides left and right so the selected piece is always in the middle, over a white disc with a blurred edge. The pieces either side are small (42% of the middle one) and close together, about five each way, fading out toward keycaps at the ends that point left and right. As a piece comes into the middle it grows to full size, lifts, tips toward the camera and starts to turn slowly. Under the row: the name and a few plain words on what the piece does (no punctuation), then the ink-rimmed cream search box on the left, the coral category tabs centred, and the key reminders on the right. No level readout. Nothing is drawn in the middle of the screen, so the room stays in view. Models are drawn in their own little world from the game camera angle, without SSAO or tilt-shift. Flyers are a stack of printed sheets under Extras. Every move has a sound: `slide` (tray in and out), `tick` (piece to piece), `tab` (category), `flip` (door card). | Not on any sheet |
| Reach marks | Carrying a fern or the bin lays a pale white square on the floor for its reach and a flat disc on every seat: `GOOD` green where it reaches, `DANGER` red where it does not. The discs draw over furniture so chairs never hide them. | Not on any sheet |
| Guest card | Click a guest during service: a cream label card under the punch-card with the name, standing and visit number, what they are doing, four ink-rimmed meters read by length, and their last six thoughts, newest first. | Sheet 14 has no inspect panel; built from its label card. Nothing marks the chosen guest in the room yet. |
| Placement ghost | The real piece bobs just off the floor under the mouse. Where it cannot go the piece is hidden and a red cross lies on the spot, drawn through any furniture already there. | Shape, not colour, says yes or no. |
| Player-built partitions | The sheet 11 partition, 1.0 m at tier 1 and 10 cm taller per tier. Higher-tier furniture keeps the yellow skirting bands. | Tier dressing is a placeholder. |

**Not yet done:** Blender kit, hired staff, co-op chefs 2 to 4 (trim colours exist in
`Peg.PLAYER_TRIM`), future dishes, title screen, colour-blind
support.

## Rules so far

| Topic | Rule | Status | From |
| --- | --- | --- | --- |
| Edges | Every 90-degree corner has a thick, visible bevel that catches a soft highlight. | locked | Sheet 1 |
| Shadows | Soft and diffused, close to ambient occlusion. No hard, high-contrast cast shadows. | locked | Sheet 1 |
| Lighting feel | A well-lit miniature set in a cosy room. | locked | Sheet 1 |
| Cutaway walls | Thick solid blocks. Exposed cross-section in dark trim brown `#3a2c22`. | locked | Sheet 1 |
| Diorama edge | A clean, thick floating slab. Pavement ends abruptly at the block edge. No fade. | locked | Sheet 1 |
| Camera | 37 degrees down, rotated 45 degrees, orthographic. | locked | Brief, confirmed in sheet 1 |
| Materials | Painted wood and soft vinyl. Matte with a gentle sheen; faint wood grain on floors only. | observed | Sheet 1 |
| Character body | One shared base: huge sphere head, short barrel body, no neck, no legs. Sheet 2 replaces the legged bodies seen in sheet 1. | locked | Sheet 2 |
| Movement | Characters glide and bob. No walk cycle. | locked | Sheet 2 |
| Arms | Floating mitten hands, not attached arms. Hands can carry an accent colour. | locked | Sheet 2 |
| Head | Sits in a shallow dip between rounded shoulders. Always the largest shape. | locked | Sheet 2 |
| Carrying | Items are held forward of the body and tilted up 20 to 30 degrees so the top faces the camera. | locked | Sheet 2 |
| Proportions | Head is a little under half the total height and wider than the body. | observed | Sheet 2 |
| Faces | Dot eyes, tiny nose dot, small mouth, round blush cheeks that never go away. Brows appear only for negative moods. | observed | Sheets 1, 2, 3 |
| Mood colour | Strong moods tint the whole head from the top down: orange to full red for anger, green for disgust. | observed | Sheet 3 |
| Small-size faces | At game size the nose is dropped and lines are thicker; eyes, brows and mouth only. | observed | Sheet 3 |
| Guest outfits | Cool, muted colours only: blues, teals, purples, browns, creams, charcoal. Never coral, green, yellow or red on guests. | locked | Sheet 4 |
| Player chef | Only playable chefs wear the tall puffy toque (about 25% taller silhouette) and a bright white jacket and hat, so the player is always the lightest, tallest thing in a crowd. | locked | Sheet 5 |
| Co-op colours | Four players differ by trim only (toque band, neck scarf, jacket trim, buttons): P1 coral, P2 teal, P3 yellow, P4 green. Jackets stay white. | locked | Sheet 5 |
| Hired staff | Server, dishwasher and host use the kitchen's deep teal and dark brown, flat-topped silhouettes and one role prop each. | locked | Sheet 5 |
| Posing | Emotion and action are carried by tilting the whole body (lean 20-25 degrees into a run, slump when bored, pitch back in disgust), squash and stretch, and floating hands. | locked | Sheet 6 |
| State tells | Negative states pair motion with a cue: steam or flame for panic, hand-blur arcs for tapping, full-head tint (red storming out, green disgust). | locked | Sheet 6 |
| Social | Friends at a table turn heads inward and wave with their outer hands. | locked | Sheet 6 |
| Finish | Mostly matte. Roughness 0.85-0.95 for walls, fabric, skin, plastic; 0.55-0.65 for wood and metal; 0.35-0.45 for tile and food. No mirror chrome. | locked | Sheet 7 |
| Gradients | Flat colour fills only. Allowed: a 10-15% darkening on the bottom 15 cm of walls, cabinets and character bases, and the mood tint on heads. | locked | Sheet 7 |
| Shadow colour | Warm plum-brown `#5a423a`, never black or cool grey. Darkens at most 35-45%, soft wide edges. | locked | Sheet 7 |
| Bevel | Every structural edge and prop corner gets a uniform 3 cm bevel. | locked | Sheet 7 |
| Stations | Each station owns a distinct top-plane silhouette. Fridge 1.7 m tall; stove, sink, counters and the pass all share a 0.9 m surface height so carried items sit flush. | locked | Sheet 8 |
| Station states | Fridge shut/open (red meat inside); sink empty/full of suds (raised bubbles); stove off, cooking (orange ring, white steam, pan), burning (toy flames, dark smoke); plate stack at 4/2/0 with a coral mat showing at 0; bin empty/overflowing with crumpled paper. | locked | Sheet 8 |
| The pass | Five squares in coral with 1 m slot dividers on top. | locked | Sheet 8 |
| Patty stages | Raw: plump pastel-pink puck. Nearly there: tan with a golden seared ring. Perfect: rich mahogany, sear marks, a steam puff. Dry: thinner, flatter, pale and chalky. Burnt: jagged charcoal "hockey puck" with grey smoke. Failure stays funny, not grim. | locked | Sheet 9 |
| Plates | Plated burger shows colour bands (bun, green lettuce, yellow cheese, patty); half-eaten has a crescent bite; dirty plate is flat with a brown sauce swirl and triangle crumbs. | locked | Sheet 9 |
| Doneness dial | Replaces the horizontal bar with a chunky radial ring gauge: cream warm-up arc, green sweet-spot with a star at Perfect, shrinking through yellow into red. A thick white needle sweeps clockwise. | locked | Sheet 9 |
| Future dishes | Steak and fries, pan salmon, eggs and bacon, tomato pasta all share the same chunky beveled toy style and read at 20 px. | locked | Sheet 9 |
| Lighting | No hanging lamps. Use wall sconces on the two back walls (primary), low mushroom table lamps (0.24 m tall), and narrow corner floor lamps in non-walkable corners (accent). | locked | Sheet 10 |
| Seating | Chair and booth backs stop at 0.62 m (seat 0.20 m) so a seated guest's whole head stays visible from the camera. | locked | Sheet 10 |
| Dining props | Round two-seat table, four-seat table, booth, woven rug (0.015 m thick), potted ferns S/M/L, coat stand, menu A-frame board, wall art. | locked | Sheet 10 |
| Cutaway | Any wall facing the camera drops to a 0.55 m knee-height cutaway capped with dark trim brown. No transparency. | locked | Sheet 11 |
| Wall kit | Full walls 2.4 m, low partitions 1.0 m, 0.24 m thick, centred on 1 m grid edges, 3 cm bevels, symmetrical ends so pieces chain and rotate freely. Pieces: plain, window, door, corner, low partition, kitchen-dining doorway. | locked | Sheet 11 |
| Finishes | Kitchen floors: teal and cream checker, cream mosaic tile, coral and cream tile. Dining floors: warm oak planks, light beech parquet, dark walnut planks. Walls: off-white plaster, teal wainscoting, coral stripe wallpaper. | locked | Sheet 11 |
| Doorway | 1 m wide with a flat 0.01 m wooden threshold that hides the seam between any kitchen and any dining floor. | locked | Sheet 11 |
| Exterior | The restaurant stands alone on a plot, no tall neighbours. Boundaries are low hedges and a 0.55 m wooden fence. Both pavement and a two-lane road end cleanly at the slab edge. | locked | Sheet 12 |
| Shopfront | Striped coral and cream awning, hanging wooden burger sign, coral-trimmed door, twin front windows, 0.55 m wooden planters. Awning and upper frames show in title and photo views; in play the front wall drops to the cutaway. | locked | Sheet 12 |
| Street furniture | Lamp post, bench, bin, bike and tree sit on the outer road-side curb only, never over the five-guest queue line. | locked | Sheet 12 |
| Effects | Camera-facing toy billboards: flat cut-out cards, four-frame sequences, crisp edges, no soft alpha feathering. | locked | Sheet 13 |
| Heat ladder | Steam is off-white, cooking smoke warm grey-cream, burning smoke charcoal with red sparks, so a pan and a fire read differently at a glance. Sizzle spatter is yellow droplets. | locked | Sheet 13 |
| Rewards | Perfect: gold and white four-point stars. Payment: a chunky gold coin that pops before banking into the HUD. Washing: translucent teal and white bubbles. | locked | Sheet 13 |
| Thought bubbles | Two small lead-in dots into a thick-rimmed cream cloud holding one bold icon: burger (wants food), dark dots and Zzz (bored), green odour cloud (saw something gross), coral heart (loved it). | locked | Sheet 13 |
| Mood effects | Disgust is rising green wisps growing into a green puff; walkout anger is a red vein-pop symbol with small puffs. | locked | Sheet 13 |
| Interface | Diegetic paper and wood: cream paper (`#fff6e6` / `#f4ead8`) on 3 cm-bevelled warm wood or dark trim, plum-brown drop shadows, dark brown ink for all text. Coral, green, yellow and red are kept for live status stamps and icons. | locked | Sheet 14 |
| Service HUD | Top-left: wooden "DAY n" plaque with a circular sun-sweep dial, plus a cream price-tag with a coin for money. Top-right: a punch-card with three slots, each walkout stamped with a red angry face. The station prompt is a keycap tile and paper label over the station the chef faces ("[E] COOK"). | locked | Sheet 14 |
| Cards | End of day: a torn diner receipt on a wooden clipboard (meals, sales, tips, walkouts, total earned) with a pinned town-gossip note. Game over: a folded coral-trimmed menu card (days survived, total earned, best run). | locked | Sheet 14 |
| Icons | Eight wooden-enamel icons with a dark brown rim and a 3 cm bevel, readable at 24 px: money (coin), tip (notes and coin), walkout (red angry token), patience (hourglass), disgust (green cloud), joy (heart), food quality (star), day (sun card). | locked | Sheet 14 |
| Logo | Peg-doll letters, bottom-left version (see Decisions). Chunky bevelled toy look, dark brown borders, coral, yellow and teal accents; must read at 64 px. | decided | Sheet 15 |
| Themes | A theme is a re-skin of the same kit: gameplay grid, station shapes, heights and bevels stay identical; walls, windows, floors, wall art and the slab edge swap. First proof: seaside pier shack. | locked | Sheet 16 |
| Guest hooks | Each regular has one top-down read: a hat, a hair shape or a bold shirt. | locked | Sheet 4 |
| Kit | 5 skin tones, 8 hair shapes, 6 hats, 2 face extras, 10 outfit colours, 4 outfit patterns. | locked | Sheet 4 |
| Assembly | Hair and hats share one scalp socket on the head. Outfits are material swaps or thin trim on the standard body. | locked | Sheet 4 |
| Hair | A solid sculpted cap in one colour, wrapping the head like a hood with the face left bare. | observed | Sheets 1, 2 |

---

## Sheet 1: style frames

**Delivered.** Two frames of the same scene, lighting only differs.

| File | Variant |
| --- | --- |
| `docs/art/01_style_frame_midday.jpg` | A: midday, bright and neutral |
| `docs/art/01_style_frame_evening.jpg` | B: evening, low sun and warm lamps |

### Artist's comments (verbatim)

> Here are the initial style frames for Sheet 1! I've established the core look with the
> 37°/45° isometric camera, chunked-out character proportions, and the "painted wood/soft
> vinyl" diorama aesthetic.

> - **How rounded are edges?** Every sharp 90-degree corner (on counters, tables, and
>   walls) has a thick, visible bevel. This does two things: it sells the "chunky, safe
>   wooden toy" feel, and it catches soft specular highlights to help distinct shapes pop
>   at that tiny 20px–60px scale.
> - **How strong are shadows?** They are soft, diffused, and act mostly like ambient
>   occlusion. Harsh, high-contrast cast shadows create noise and ruin readability on small
>   screens. We want the lighting to feel like a well-lit miniature set in a cozy room.
> - **What do cutaway walls look like?** They are rendered as thick, solid blocks. I used
>   the dark trim brown (`#3a2c22`) for the exposed "cross-section" of the walls. This
>   creates a bold, dark frame around the playable area that visually contains the diorama
>   without distracting from the bright interior floors.
> - **How does the diorama end?** It's a clean, thick floating slab. Fading the street out
>   feels too ethereal and breaks the physical "toy" illusion. By ending the pavement
>   abruptly at the block's edge, it feels exactly like a modular toy set you could pick up
>   and put on a table.

### What the frames show

Colours below are described by eye, not sampled.

**Scene**
- The restaurant sits on a thick slab with a wooden edge, floating on a plain backdrop.
  A strip of grey paving slabs runs along the front.
- Far walls are full height, cream, about a third of a grid square thick, with rounded tops.
- The front wall is cut to knee height: coral face, cream cap. A coral door frame stands
  full height in it.
- Window openings have thick coral frames. A deep teal skirting band runs along the base
  of the dining room walls.

**Kitchen**
- Deep teal cabinets above and below, darker than the game's current teal, each door with
  a small brass handle.
- Warm tan worktops. A steel-grey range with a hood above it and a frying pan on the hob.
- Teal and cream checker floor.
- The serving counter is deep teal with a tan top, not coral. A cash register sits on it.

**Dining room**
- Warm wood plank floor with a faint grain.
- Square tan tables on a single teal pedestal. Coral chairs with wooden legs and a back.
- Table clutter: plates, a ketchup bottle, crumpled napkins, cutlery.

**Characters**
- About three heads tall. The head is the largest shape.
- Short arms ending in mitten hands; short legs and brown shoes. Seated guests bend at the knee.
- Faces: dot eyes, brows, blush cheeks, a small mouth. One guest is plainly cross, read
  from the brows alone.
- Clothes are a plain jumper and trousers in muted coral, sage green or navy.
- The chef is all white with a tall puffed hat.

**Food**
- The burger is a tall stack (bun, patty, cheese, lettuce) on a white plate, larger
  relative to a character than in the game now.
- The patty cooks in a frying pan with wisps of steam.

**Lighting**
- Midday: neutral, even light, pale grey-beige backdrop, soft contact shadows.
- Evening: low orange light from the right, long soft shadows, dusky mauve backdrop.
  Warm practical lights inside: a glow under the kitchen wall cabinets and a candle on a table.

### Differences from the brief and the current game

| Topic | Brief or game | Style frame | Effect on the game |
| --- | --- | --- | --- |
| Character body | Peg: cylinder, floating hands, no legs | Arms, legs, shoes, hair | Needs modelled and animated characters, not primitives |
| Tables | Round, two seats facing across | Square, pedestal base | Small model change |
| Serving counter | Coral | Deep teal with tan top | Colour change; coral moves to walls, chairs and frames |
| Kitchen | Counters only | Wall cabinets and a range hood | New props; check they do not hide the stove timer |
| Cooking | Patty sits on the burner | Patty in a frying pan | New prop and carry item |
| Front wall | Low cream wall | Low coral wall with cream cap, tall door frame | Model change |
| Windows | Blue panes on a coral band | Open cut-outs with coral frames | Model change |
| Guests in frame | Six, including one walking in and one impatient | Six, matches | None |
| Interface elements | Patience bars, order icons, name labels | None shown | Still to be designed (sheets 3 and 14) |


---

## Sheet 2: character base

**Delivered.** One turnaround of the shared body: front, side, back, and a view from the
game camera, with a height ruler down the left side.

| File | Content |
| --- | --- |
| `docs/art/02_character_turnaround.webp` | Front, side, back and 37-degree view |

### Artist's comments (verbatim)

> Here is Sheet 2, establishing our universal character base!
> To make sure these characters read perfectly at 60 pixels tall and fit our toy-box
> world, here is how I answered the design constraints for this rig:

> - **The Leg Decision:** I went with no legs (glide and bob). The cylinder body simply
>   rounds off at the bottom into a smooth base. Adding stubby feet or a skirt introduced
>   unnecessary noise to the silhouette. A bobbing animation loop will sell the movement
>   perfectly while keeping the geometry cheap and the read crystal clear.
> - **How do arms work?** Floating mitten hands. Trying to attach short sleeves or thin
>   arms created awkward negative space and got muddy at a small scale. Floating hands are
>   an established trope in cozy games, and they allow us to pop the bright accent colors
>   (like the coral) away from the body for distinct actions without clipping issues.
> - **How does the head join the body?** No neck. The massive sphere head nestles directly
>   into a shallow depression between the rounded shoulders. This emphasizes the
>   "bobblehead/wooden peg" toy look and ensures the head (which carries the vital mood
>   expressions) remains the absolute largest, most readable shape from the top-down camera.
> - **How is an item held?** The floating hands position the item (like a burger or dirty
>   plate) extended slightly forward and tilted upward. Because our camera points down at
>   37 degrees, if characters held plates perfectly flat against their chests, the camera
>   would just see the rim of the plate intersecting the belly. Tilting the item upwards by
>   about 20-30 degrees ensures the flat top of the plate squarely faces the player.

### What the sheet shows

Described by eye; the ruler has tick marks but no numbers.

**Proportions**
- The head is a near-perfect sphere, a little under half the total height, and wider
  than the body.
- The body is a short barrel with rounded shoulders, slightly wider at the hips.
- Under the body is a short, narrower wooden peg that the figure stands on.

**Head and face**
- Bare wood-toned face with visible grain. Two small dark dot eyes set wide apart, a tiny
  nose dot, a short smile, and round coral blush cheeks.
- A blue cap covers the top, back and sides of the head like a hood, leaving an oval
  face opening. From behind the head is a plain blue ball.
- Features sit in the lower half of the face.

**Body and clothes**
- Coral waistcoat with a blue centre panel, one button, a blue hem band with a yellow
  stripe, and a pale dotted pattern on the chest.
- Yellow cap sleeves at the shoulders.
- Cream mitten hands with a separate thumb, hanging at hip height just clear of the body.

**From the game camera**
- The head covers the shoulders and most of the chest. What reads is the cap colour, the
  face, the hands, and a band of body colour below.

### Differences from the brief, sheet 1 and the current game

| Topic | Before | Sheet 2 | Effect on the game |
| --- | --- | --- | --- |
| Legs | Sheet 1 guests had legs and shoes | No legs | Sheet 1 characters are superseded. Close to what the game does now. |
| Arms | Sheet 1 guests had arms | Floating mitten hands | Matches the game's floating hands; needs mitten shapes. |
| Body shape | Game: plain cylinder with a dome top | Barrel with shoulders on a short peg | New character model. |
| Head | Game: sphere a bit wider than the body | Much larger sphere with a hood-like cap | New model; hair and hats become cap variants. |
| Face | Game: two dot eyes | Eyes, nose, mouth, blush | Face needs a texture or decal, not just spheres. |
| Carrying | Game: item held flat in front | Tilted up 20 to 30 degrees | Small change to the held-item transform. |
| Rendering | Brief: no outlines, flat colour | Drawn with dark outlines and painted grain | Drawn style only; the game keeps flat colour, no outlines. |


---

## Sheet 3: faces and expressions

**Delivered.** One sheet of heads, each drawn large ("concept view") and again small
("60px game size view"), with a column of the smallest versions down each side.

| File | Content |
| --- | --- |
| `docs/art/03_faces_expressions.jpg` | Eight faces, large and small |

### Artist's comments

None supplied with this sheet.

### What the sheet shows

Eight faces can be made out. The printed labels are unreliable (see below), so the names
here are by what each face looks like.

| Expression | Eyes | Brows | Mouth | Head colour |
| --- | --- | --- | --- | --- |
| Neutral | Round dots | None | Small "w" | Plain |
| Content | Closed upward arcs | None | Gentle smile | Plain |
| Delighted | Dots with a white sparkle | Short raised dashes | Open smile with tongue | Plain, pinker cheeks |
| Impatient | Half-lidded dots | Flat lines pressed on the eyes | Straight line | Plain |
| About to snap | Dots | Steep angled wedges | Wavy line | Orange flush from the top |
| Disgusted | Squeezed shut, "> <" | Angled | Wavy line | Green flush from the top |
| Angry | Narrowed | Heavy angled wedges | Downturned arc | Whole head red |
| Chewing | One open, one winking | One raised | Puffed cheek to one side, with motion ticks | Plain |

**Shared traits**
- The head is a wood-toned ball with faint horizontal grain.
- Coral blush cheeks stay on every face.
- All features are the same dark brown as the outline.
- Features sit in the lower half of the head, as the brief asked for a camera looking down.
- The small versions keep eyes, brows and mouth, drop the nose, and thicken the lines.

### Differences from the brief and the current game

| Topic | Brief or game | Sheet 3 | Effect on the game |
| --- | --- | --- | --- |
| Count | Eight named expressions | Eight faces, matching the list | None |
| Game size | Each must read at 20 px across | Small versions are shown, but not at a stated pixel size | Needs checking in engine |
| Mood read | Game: floating patience bar | Face plus head colour | Bar could be dropped or kept as a backup once faces are in |
| Face build | Game: two sphere eyes | Drawn features that swap per mood | Needs face textures (an atlas of eight) on the head |
| Head colour | Game: fixed skin tone | Tints red or green with mood | A tint parameter on the head material |


---

## Sheet 4: townsfolk

**Delivered.** Two images: the modular kit (4B) and a line-up of twelve named regulars (4A).

| File | Content |
| --- | --- |
| `docs/art/04a_townsfolk_lineup.jpg` | Twelve regulars in two rows |
| `docs/art/04b_townsfolk_kit.jpg` | Skin tones, hair, hats, face extras, outfit colours and patterns |

### Artist's comments (verbatim)

> Here is Sheet 4, broken into the 12-Regulars Line-Up and the Modular Kit they are built
> from. Every character uses the universal legless cylinder rig and high-set facial layout
> from Sheets 2 and 3, with strong top-down silhouette hooks so players can spot regulars
> at a glance.

> - **Top-Down Silhouette Hooks:** Because the camera looks down at 37°, each regular
>   relies on an unmistakable crown or shoulder read—like Hattie's wide sun hat, Ingrid's
>   tall blonde updo, Otis's glossy bald head and white beard, or Leopold's black bowler.
>   Remaining roster names like Felix and Nell slot straight into this kit (e.g., Felix
>   with the wavy crop, glasses, and charcoal stripe; Nell with twin buns and a cream
>   collared top).
> - **UI-Safe Outfit Palette:** The 10 base clothing swatches stick strictly to cool
>   blues, deep teals, purples, browns, creams, and charcoals. Keeping coral (`#e56b5d`),
>   green (`#5fd38d`), yellow (`#ffd34e`), and red (`#ff6b5e`) completely off guest shirts
>   guarantees that floating UI markers, plates, and mood flushes never get lost against
>   a crowd.
> - **Blender Assembly Rules:** All 8 hair shapes and 6 hats share a single spherical
>   scalp socket on the 0.55 m head, while the 4 outfit patterns (`STRIPE`, `APRON`,
>   `COLLAR`, `DUNGAREES`) map cleanly onto the standard 0.4 m x 0.6 m body cylinder via
>   simple material/UV swaps or thin extruded trim meshes.

### What the sheets show

**Kit (4B)**
- **Skin tones (5):** pale, light peach, golden tan, medium brown, deep brown. Each has
  its own face-marker set (eyes, brows, blush, mouth) tuned to read on that tone.
- **Hair (8):** bald, short side-swept, black bob with fringe, low bun, tight curls,
  twin buns, high top-knot bun, wavy crop.
- **Hats (6):** flat cap, blue beanie, wide sun hat, black bowler, bobble hat, purple beret.
- **Face extras (2):** round glasses, full beard.
- **Outfit colours (10):** navy, royal blue, periwinkle, deep teal, slate, lilac, plum,
  brown, cream, charcoal.
- **Outfit patterns (4):** stripe jumper, apron over a top, collared top, dungarees.

**Line-up (4A)**
- Mabel: grey bun, lilac collared top, wrinkles.
- Otis: bald, white beard and moustache, dungarees.
- Priya: twin buns, deep skin, teal top with a cream band.
- Gus: flat cap, navy apron.
- Ingrid: tall blonde bun, striped periwinkle jumper.
- Tobias: wavy brown hair, round glasses, brown shirt.
- Wren: blue beanie, striped top.
- Hattie: wide sun hat, grey curls, plum dress.
- Leopold: black bowler, grey hair, round glasses, charcoal coat.
- Suki: black bob, blue dungarees.
- Barnaby: beanie, full beard, slate jumper.
- Odette: purple beret, curls, purple apron.
- Felix and Nell are named in the comment only; the line-up has twelve and these two
  were not drawn.

### Differences from the brief, earlier sheets and the game

| Topic | Before | Sheet 4 | Effect on the game |
| --- | --- | --- | --- |
| Legs | Sheet 2: none | Line-up shows legs, feet and arms | Conflicts with sheet 2; sheet 2 wins (see Resolved conflicts) |
| Hands | Sheet 2: floating mittens | Mittens, but attached at the sides | Minor; follow sheet 2 |
| Skin tones | Game: four | Five | Add a fifth |
| Outfit colours | Game: seven shirt colours incl. coral, green | Ten cool colours, no coral, green, yellow or red | Replace the shirt palette |
| Hats and hair | Game: none | Six hats, eight hair shapes | New modular parts |
| Extras | Game: none | Glasses, beard | New parts |
| Names | Game roster: 14 names | Twelve drawn, Felix and Nell described | Draw the remaining two later |
| Eyes | Sheet 3 faces | Brows and mouth vary more here; faces are more detailed | Faces here are a variety study, not the final face set |


---

## Sheet 5: chef and staff

**Delivered.** One sheet: the player's chef and hired staff on the top row, four co-op chef
colour variants on the bottom row.

| File | Content |
| --- | --- |
| `docs/art/05_chef_and_staff.jpg` | Chef, server, co-op chef, two dishwashers, host, and the four player colours |

### Artist's comments (verbatim)

> Here is Sheet 5, establishing the player's Chef, the three unlockable Staff Roles built
> on the universal peg-doll rig, and the 4-Player Co-op Chef Variants.

> **What Makes the Player Instantly Findable in a Crowded Room**
> - **Exclusive Vertical Silhouette (The Tall Toque):** Guests and hired staff keep low,
>   rounded crown profiles—bald heads, buns, flat caps, or bowlers. Only playable chefs wear
>   the tall, puffy toque, extending their silhouette height by roughly 25% so they poke
>   cleanly above crowded tables from the 37° top-down camera.
> - **Maximum Luminance Contrast (Pure White):** Townspeople wear muted mid-tone blues,
>   purples, browns, and charcoals against warm wood (`#d9a066`) and teal-checker floors.
>   The chef's crisp, bright white jacket and hat act as the single highest-value light
>   block moving through the scene, preventing the player from ever blending into a cluster
>   of seated diners.
> - **Reserved High-Chroma Co-op Trim:** Because coral (`#e56b5d`), yellow (`#ffd34e`),
>   and green (`#5fd38d`) were strictly excluded from regular guest outfits, assigning those
>   saturated hues (plus bright teal) to the chef's toque band, neck scarf, and
>   double-breasted trim lets up to four co-op players track themselves at 60 pixels tall
>   without muddy full-body recolors.
> - **Architectural Palette for Hired Staff:** The Server, Dishwasher, and Host use the
>   restaurant's deep teal (`#3f7f86`) and dark trim brown (`#3a2c22`) with flat-topped
>   silhouettes and role-specific props (serving tray, yellow wash mittens, menu board).
>   Visually tying hired staff to the kitchen's cabinet palette lets the eye read them as
>   steady background helpers while the bright white chefs command immediate foreground
>   focus.

### What the sheet shows

**Top row**
- **Chef:** tall puffed toque, orange-brown face, white double-breasted jacket with round
  buttons, red-coral neckerchief, white trousers.
- **Server:** deep teal waistcoat over a white shirt, bow tie, dark trousers, a round tray
  held out to the side.
- **Co-op chef:** the same body as the chef with dark hair, teal waistcoat and a tray
  (reads as a server, not a chef).
- **Dishwasher (two versions):** headband on one, dark curls on the other. Teal apron
  with a chest pocket, yellow rubber mittens.
- **Host:** brown suit, white shirt, name badge, a menu board under one arm.

**Bottom row: player colours**
- Four distinct colour sets, all on the same white chef: coral, teal, yellow, green.
- Each colours the toque band, neckerchief, jacket hem and cuffs, and button dots.
- Two of the six slots repeat (teal and yellow appear twice).

### Differences from the brief and the current game

| Topic | Before | Sheet 5 | Effect on the game |
| --- | --- | --- | --- |
| Chef hat | Game: small dome hat | Tall puffed toque, 25% taller | New hat model, new silhouette |
| Chef body | Game: white peg | Double-breasted jacket, scarf, trousers and shoes | New outfit; shoes and legs conflict with sheet 2 |
| Co-op colours | Brief: four colour variants | Coral, teal, yellow, green on trim | Four materials for trim |
| Staff roles | Brief: server, dishwasher, host | Same three, one with two designs | Roles ready for later |
| Server tray | Not in game | Held out to one side | Fits the sheet 2 "tilted item" rule |


---

## Sheet 6: key poses

**Delivered.** Two sheets: chef poses (6A) and guest poses (6B). Inspiration for the
animation list; legs and shoes drawn here are ignored in favour of the legless rig.

| File | Content |
| --- | --- |
| `docs/art/06a_chef_key_poses.jpg` | Idle, running, carrying plate, carrying patty, putting down, flipping meat, washing up, panicking |
| `docs/art/06b_guest_key_poses.jpg` | Walking, queueing, bored in queue, sitting down, tapping impatiently, served, paying, eating, storming out, recoiling in disgust, friends noticing |

### Artist's comments (verbatim)

> Here is Sheet 6, split into Chef Key Poses and Guest Key Poses & Social Interaction so
> all twenty animation states read clearly from the 37° top-down camera.

> **Animation Readability & Rig Notes (60px Scale)**
> - **Exaggerated Torso Pitch & Squash-and-Stretch:** Because the characters have no legs
>   or elbows, locomotion and emotion rely on tilting the entire 0.4 m × 0.6 m body
>   cylinder. Running and Storming Out lean 20°–25° forward on the movement vector, Bored
>   in Queue compresses vertically with a slumped head tilt, and Recoiling in Disgust
>   pitches sharply backward away from the table.
> - **Upward-Tilted Carry & Action Silhouettes:** In Carrying Plate, Carrying Patty, and
>   Putting Down, the floating mittens push props forward and tilt them 25°–30° toward the
>   camera so the circular plate or patty silhouette never clips into the white chef
>   jacket.
> - **High-Contrast State Tells:** Urgent or negative states pair silhouette motion with
>   instant visual cues—white steam/flame puffs for Panicking, rapid hand-blur arcs for
>   Tapping Impatiently, and full-head color shifts (red for Storming Out, sickly green for
>   Recoiling in Disgust).
> - **Two-Character Social Framing:** For Friends Noticing, both seated regulars rotate
>   their heads 45° inward across the corner of the table and raise their outer mittens
>   into a synchronized wave, creating a symmetrical double-wave silhouette that stands out
>   immediately in a busy dining room.

### Ideas worth taking

- **Chef:** panicking has both hands up and wide eyes, with flames on the pan; flipping
  meat tosses the patty out of a frying pan; washing up shows suds and flying bubbles;
  carrying a patty holds a spatula out with the patty on it, tilted to the camera.
- **Guests:** served is a small tap or hop on the table; paying places a coin on the table;
  eating holds the burger up with one hand and a plate in the other, cheeks full;
  storming out has puffs of steam at the feet and a fully red head; disgust is a green head
  with hands pulled in toward the face.
- **Seating:** seated guests sit on a chair with the table between them and the camera, a
  clear way to show who is sitting where.
- **Social:** friends noticing is a mirrored double wave across the table corner.

---

## Sheet 7: colour and material key

**Delivered.** The final palette as swatches, eight material balls, and a bevel reference cube.

| File | Content |
| --- | --- |
| `docs/art/07_colour_material_key.jpg` | Palette, material balls, 3 cm bevel cube |

### Artist's comments (verbatim)

> **Shader & Surface Rules (Blender / Engine Spec)**
> - **Matte vs. Glossy:** The world is predominantly matte to satin-matte so the 37°
>   top-down camera never suffers from harsh specular glare.
>   - Fully Matte (`Roughness 0.85–0.95`, zero specular): Wall, Fabric, Skin, and Plastic
>     (painted wood and soft vinyl toy finish).
>   - Satin-Matte (`Roughness 0.55–0.65`, broad soft roll-off): Wood (lacquered beech/oak
>     furniture) and Metal Appliance (brushed satin steel/enamel—never mirror chrome).
>   - Controlled Semi-Gloss (`Roughness 0.35–0.45`, small soft highlight): Tile and Food
>     (glazed burger buns and sizzling patties), giving interactive kitchen floors and tiny
>     20px food props a crisp top highlight that reads at a glance.
> - **Gradients:** Flat solid color fills only—no procedural noise, painted wood grain, or
>   multi-tone surface gradients on base meshes. The only two permitted gradients are:
>   1. A subtle 10–15% vertical ambient-occlusion darkening at the bottom 15 cm of walls,
>      cabinets, and character bases to anchor them to the floor.
>   2. Dynamic radial mood flushes on character heads (blending base skin into `#ff6b5e`
>      red for anger or sickly green for disgust).
> - **Shadow Depth & Colour:** Shadows are never pure black or cool grey. They use a warm
>   plum-brown tint (`#5a423a`) and are capped at a 35%–45% maximum value drop with soft,
>   wide penumbras. Keeping shadow contrast shallow prevents dark corners from swallowing
>   tiny plates, coins, or patties on the 1 m grid.
> - **Edge Rounding Rule:** Every structural edge and prop corner receives a uniform `3 cm`
>   (`0.03 m`) single-segment bevel. Standardizing on a `0.03 m` bevel in Blender
>   eliminates razor-sharp 90° edges that alias at 1440 × 900, keeps polygon budgets low,
>   and catches a consistent, toy-safe rim highlight across every asset.

### Palette

The sheet shows swatches but no hex codes, so these values were sampled from the image
(a small average around each swatch centre). They are a touch lighter and more saturated
than the brief's placeholder values, which is likely the image's rendering; round to the
brief's value where the two are close.

| Role | Sampled | Brief placeholder |
| --- | --- | --- |
| Backdrop | `#f5dfb8` | `#f0dfc4` |
| Walls | `#f3ebe0` | `#fff6e6` |
| Kitchen tile, teal | `#99c3b5` | `#8fc7c3` |
| Kitchen tile, cream | `#f2ead4` | `#f4ead8` |
| Dining wood | `#dc9d4e` | `#d9a066` |
| Accent (coral) | `#f67a60` | `#e56b5d` |
| Cabinets | `#30676c` | `#3f7f86` |
| Good | `#96cfac` | `#5fd38d` |
| Warning | `#ffd452` | `#ffd34e` |
| Danger | `#e83d36` | `#ff6b5e` |
| Dark trim | `#473123` | `#3a2c22` |
| Chef white | `#fefefe` | none |

### Material balls

Wall (matte off-white), wood (warm with faint rings), tile (teal and cream checker, glossy
top highlight), metal (light grey with a soft highlight), plastic (coral), fabric (deep
teal with a fine weave), food (glossy bun), skin (peach).

---

## Sheet 8: kitchen props

**Delivered.** Two sheets: appliances and sink (8A) and counters, plate stacks, bin and serving pass (8B).

| File | Content |
| --- | --- |
| `docs/art/08a_kitchen_appliances_sink.jpg` | Fridge shut and open, sink empty and full of suds, stove off, cooking and burning |
| `docs/art/08b_kitchen_counters_pass.jpg` | Plain counter, plate stack at 4, 2 and 0, bin empty and overflowing, five-square serving counter |

### Artist's comments (verbatim)

> **Top-Down Readability & Blender Spec Notes**
> - **Top-Surface Station Identity:** Because the 37° camera primarily reveals top faces,
>   each station owns a unique top-plane silhouette and material contrast:
>   - **Fridge (`1.7 m` tall):** Nearly double counter height with a clean off-white
>     (`#fff6e6`) cap that stands out immediately against the teal-and-cream checker floor.
>     Opening the door swings out a bold white slab and exposes saturated red meat blocks
>     inside.
>   - **Stove (`0.9 m` tall):** Brushed satin-steel top with four high-contrast dark
>     circular burners—unmistakable beside smooth wooden prep counters. State changes use
>     layered vertical cues: glowing orange ring + white steam puffs for Cooking, and tall
>     red-orange toy flames + dark smoke puffs for Burning.
>   - **Sink (`0.9 m` tall):** Deep recessed steel basin with a curved top-mounted faucet.
>     When Full of Suds, raised white-and-sky-blue bubble spheres fill the basin above the
>     rim so dirty-dish readiness reads from across the room.
> - **Uniform `0.9 m` Counter Standard & Stacking:** Plain Counter, Plate Stack, and the
>   5-square Serving Counter ("The Pass") share an exact `0.9 m` surface elevation and
>   `3 cm` edge bevels so carried items snap cleanly onto any counter top without vertical
>   offsets. Even at 0 Plates, a recessed coral circular mat marks the plate-stack station
>   so players never mistake it for a plain prep counter.
> - **The Pass & Waste Readability:** Painting the 5-square Serving Counter in the
>   signature coral accent (`#e56b5d`) with 1-meter top slot dividers visually anchors the
>   kitchen-to-dining handoff zone, while the Bin pairs a dark-trim open void (Empty)
>   against an unmistakable heap of white crumpled paper balls (Overflowing).

### What the sheets show

- **Counter:** deep teal body with two cabinet doors and brass handles, tan top with a
  bevelled edge.
- **Plate stack:** the same counter with a stack of cream plates on top, shorter as it
  empties.
- **Fridge:** a rounded retro cream fridge with two doors and grey handles; open, it shows
  shelves of red patties, bottles and a crisper drawer.
- **Stove:** teal body with a grey top, four dark burners, three knobs and an oven door.
  Cooking shows a glowing ring and a pan with a patty; burning shows flames and smoke.
- **Sink:** counter body with a steel basin and curved tap, filling with bubbles.
- **Bin:** a square brown bin with a grey rim, empty or heaped with paper and scraps.
- **Pass:** a long coral block with a tan top divided into slots, and a teal base strip.

### Ideas worth taking

- Frying pan on the burner as the cooking vessel, with the patty visible in it.
- Cream retro fridge with rounded corners as the tall landmark in the kitchen.
- Bubbles rising above the sink rim as a readable "dirty dishes waiting" cue.
- The coral mat under an empty plate stack so the station stays recognisable.

---

## Sheet 9: food and carried items

**Delivered.** Two sheets: patties, plates and the doneness dial (9A), and future dishes with their raw ingredients (9B).

| File | Content |
| --- | --- |
| `docs/art/09a_patties_plates_dial.jpg` | Five patty stages, clean plate, plated burger, half-eaten, dirty plate, doneness dial |
| `docs/art/09b_future_dishes.jpg` | Raw steak, salmon, egg and bacon, pasta and tomato; cooked steak and fries, pan salmon, eggs and bacon, tomato pasta |

### Artist's comments (verbatim)

> **20px Readability & UX Breakdown**
> - **Unmistakable Patty Progression:** Because cooked meat sits at roughly 20 pixels wide
>   on screen, each stage pairs a distinct color shift with a clear silhouette and height
>   change:
>   - **Raw:** Tall, plump pastel-pink puck with soft rounded edges and pale fat dots.
>   - **Nearly There:** Warm tan base ringed by a golden-brown seared crust so players can
>     anticipate the flip or pull.
>   - **Perfect:** Rich mahogany-brown puck with the controlled semi-gloss highlight defined
>     in Sheet 7, crisp crosshatch sear marks, and a clean white steam puff.
>   - **Dry:** Noticeably thinner, flattened pale-brown disc with chalky, matte edges—
>     signaling lost juiciness without looking ruined.
>   - **Burnt:** A shrunken, jagged charcoal-black cartoon hockey puck trailing gray smoke
>     puffs, keeping failure states funny and toy-like rather than grim.
> - **Plate & Burger Silhouettes:** The Plated Burger stacks high-contrast color bands
>   (golden bun, `#5fd38d` ruffled lettuce, `#ffd34e` cheese corners, and dark patty) so a
>   finished dish never blends into an empty off-white Clean Plate. The Half-Eaten state
>   cuts a sharp, comical crescent bite out of the stack, while the Dirty Plate swaps the 3D
>   stack for a flat brown sauce swirl and triangular crumbs.
> - **Upgraded Stove UI (`Doneness Dial`):** A thin horizontal bar with a tiny needle gets
>   muddy above a 1 m stove when multiple burners are active. Replacing it with a chunky
>   radial ring gauge gives the player peripheral readability: a thick white wedge sweeps
>   clockwise through a neutral cream warm-up arc into a high-contrast `#5fd38d` green
>   sweet-spot sector (crowned with a pop-up star when `Perfect`), before rapidly shrinking
>   through `#ffd34e` yellow into `#ff6b5e` red right before burning.
> - **Style Stretch Across Future Menu Items:** Pairing raw and cooked silhouettes for
>   Steak & Fries (T-bone cutout vs. yellow block fries), Pan Salmon (striped coral fillet
>   vs. green broccoli dome), Eggs & Bacon (white oval + wavy strip vs. bright yellow yolk
>   dome), and Tomato Pasta (straight yellow bundle + red sphere vs. coiled noodle bowl)
>   confirms that the chunky `3 cm`-beveled wooden toy language scales cleanly to new
>   recipes without relying on fine texture detail.

### What the sheets show

- **Patties:** a five-step row from pink puck to charred lump, each at the same footprint,
  with a tiny game-size burnt patty beside it.
- **Plates:** a plain cream plate; a tall burger with golden bun, lettuce, cheese and
  patty; the same burger with a bite out of it and crumbs; a smeared dirty plate.
- **Doneness dial:** a dark-brown round gauge with a cream arc, a green sector with a star,
  a yellow and then red sector, and a thick white needle in the middle; a 20 px version
  sits beside it.
- **Future dishes:** raw T-bone steak, salmon fillet, egg and bacon, pasta bundle with a
  tomato; cooked steak with fries and sauce, breaded salmon with broccoli and lemon, fried
  egg with bacon, and a bowl of spaghetti with tomato sauce and basil.

### Ideas worth taking

- Burger is much taller and more colourful than the current game burger; a stack of
  distinct colour bands reads best small.
- The doneness dial could sit above each burner as a ring that fills as the meat cooks.
- Raw ingredients each have their own silhouette, which suits a fridge that shows what
  is inside.
- A second future dish tier (steak, salmon, eggs, pasta) is ready to model when the menu grows.

---

## Sheet 10: dining room props

**Delivered.** Two sheets: seating and rugs (10A) and decor, plants and lighting (10B).

| File | Content |
| --- | --- |
| `docs/art/10a_dining_seating_rugs.jpg` | Round two-seat table, four-seat table, dining booth, woven rug |
| `docs/art/10b_dining_decor_lighting.jpg` | Ferns (S/M/L), wall art, coat stand, menu board, wall sconce, low table lamp, corner floor lamp |

### Artist's comments (verbatim)

> **Camera-Safe Lighting & Seating Readability Rules**
> - **Why Hanging Lamps Fail & Which Fixtures Work:** Because the orthographic camera looks
>   down at 37° rotated 45°, any pendant lamp suspended at ~1.8 m–2.2 m projects diagonally
>   across the floor grid and parks its shade directly over guests seated one to two squares
>   behind it. Three fixture types solve this without blocking gameplay reads:
>   1. **Wall Sconces (Primary Pick):** Mounted along the two tall far-back walls, sconces
>      sit completely behind all walkable and seated grid tiles, casting warm pools of light
>      into the room with zero silhouette occlusion and zero floor footprint.
>   2. **Low-Profile Table Lamps (Secondary Pick):** Capped at `0.24 m` tall (`1.14 m` total
>      elevation on a `0.9 m` tabletop), a tiny mushroom-dome lamp sits below a seated
>      guest's chin and cheek line, illuminating the table surface and burger without
>      overlapping faces from above.
>   3. **Corner Floor Lamps (Accent Only):** Placed strictly in non-walkable back corners or
>      against far-wall dividers with a narrow `0.35 m` shade, ensuring no guest can ever
>      path behind the shade relative to the camera vector.
> - **Chair & Booth Backrest Height Constraint:** Standard dining chairs and booth benches
>   cap their backrests at `0.62 m` off the floor (`~0.20 m` seat height plus a `0.42 m`
>   backrest). Because a seated character's `0.6 m` torso cylinder and `0.55 m` spherical
>   head sit cleanly above that lip, even guests seated on the camera-facing side of a
>   Round Table, Four-Seat Table, or Dining Booth keep their entire head and high-set
>   facial expression unobstructed.
> - **Floor & Perimeter Props:** The Woven Rug is modeled as a thin `0.015 m` beveled pad so
>   gliding characters never clip into raised edges, while the Potted Ferns (S / M / L),
>   Coat Stand, and Menu Board rely on distinct vertical silhouettes (foliage spheres,
>   turned wooden pegs, and a dark-trim A-frame) that read cleanly on `1 m` border squares.

### What the sheets show

- **Round table:** warm wood top on a dark pedestal, two coral chairs with wooden legs, one
  seated peg guest shown for scale.
- **Four-seat table:** square wooden table with four chairs, two coral and two wood.
- **Booth:** two teal bench seats with coral cushions facing across a wooden table.
- **Rug:** cream woven rug with coral and teal stripes and fringe.
- **Ferns:** three sizes in coral and striped pots.
- **Wall art:** two framed abstract prints (coral, teal and cream) on a wall panel.
- **Coat stand:** turned wood pole with a blue coat.
- **Menu board:** wooden A-frame with a chalkboard.
- **Lighting:** a wall sconce with a coral shade and warm glow; a small coral mushroom table
  lamp on a teal block; a tall floor lamp with a cream cylinder shade.

### Ideas worth taking

- Wall sconces as the main dining light, which also gives evening glow without blocking guests.
- The mushroom table lamp as the candle-like glow on each table.
- Coral chairs and teal booth seats, which tie the room to the brand colours.
- Chair and booth backs kept low (0.62 m) so faces stay readable from above.

---

## Sheet 11: architecture kit

**Delivered.** Two sheets: modular wall pieces with the cutaway rule (11A) and floor and wall finishes (11B).

| File | Content |
| --- | --- |
| `docs/art/11a_modular_walls.jpg` | Plain wall, window, door, corner, low partition, kitchen-dining doorway, cutaway rule |
| `docs/art/11b_floor_wall_finishes.jpg` | Three kitchen floors, three dining floors, three wall finishes |

### Artist's comments (verbatim)

> **Player-Built Tiling & Cutaway Spec (Blender / Engine Rules)**
> - **The Cutaway Rule (`0.55 m` Knee-Height Cut):** Rather than hiding near walls
>   completely or making them semi-transparent (which creates muddy alpha sorting over
>   characters), any exterior or room-dividing wall facing toward the camera automatically
>   switches to its knee-height cutaway mesh (`0.55 m` tall) capped with the solid dark trim
>   brown (`#3a2c22`) cross-section. At `0.55 m`, the player can still read their exact
>   floorplan, doors, and windows at a glance while keeping `0.9 m` counters and `1.25 m`
>   characters completely unobstructed.
> - **Seamless `1 m` Grid Tiling & Symmetry:**
>   - **Grid-Edge Straddling:** All full walls (`2.4 m` tall), Low Partition Walls (`1.0 m`
>     tall), and Corner Pieces sit centered on `1 m` grid edges with a uniform `0.24 m`
>     thickness and `3 cm` bevels, leaving the full `1 m × 1 m` walkable floor tile clear
>     for furniture and pathfinding.
>   - **Symmetrical Joinery:** Every wall segment uses symmetrical left/right end caps so
>     Plain Walls, Windows, Doors, and Corners can be rotated or chained in any order
>     without visible UV seams or protruding trim.
>   - **Kitchen-Dining Doorway Transition:** The interior Kitchen-Dining Doorway (`1 m`
>     wide) features a flat `0.01 m` beveled wooden threshold saddle at floor level,
>     cleanly masking the seam wherever any of the 3 Kitchen Floor Finishes meets any of
>     the 3 Dining Floor Finishes.

### What the sheets show

- **Walls:** cream plaster blocks with a thick dark brown cap; the window has a rounded
  coral frame, the door a coral frame with a wooden door, the corner is an L.
- **Low partition:** teal panelled base with a tan wooden cap and a thin coral line.
- **Doorway:** open wooden frame between a teal checker kitchen floor and a wood dining floor.
- **Cutaway:** an L-shaped wall where the camera-facing arm drops to knee height; the cut
  ends are coral.
- **Floors:** each a slab with a visible edge, in the finishes listed in the rules above.
- **Wall finishes:** cream plaster, teal panelled lower wall with a wood rail, coral and
  cream vertical stripes.

### Ideas worth taking

- The cutaway wall: the near walls simply shrink to knee height, so no transparency is
  needed and the floorplan stays readable.
- Thick dark-brown wall caps that frame the room, matching the artist's first style frame.
- Rounded coral window and door frames as the signature accent.
- Floor finishes as swappable tiles for the later Sims-style building system.

---

## Sheet 12: exterior and street

**Delivered.** Two sheets: shopfront, queue and road (12A) and street furniture with the standalone plot (12B).

| File | Content |
| --- | --- |
| `docs/art/12a_shopfront_queue_road.jpg` | Shopfront, five-guest queue, pavement and road, floating slab edge |
| `docs/art/12b_street_furniture_edge.jpg` | Lamp post, bench, street bin, bike, tree, and the standalone plot with hedges and fence |

### Artist's comments (verbatim)

> - **What Is Beyond the Edges of the Scene:** Locking in the floating tabletop slab
>   established in Sheet 1, the entire diorama terminates abruptly in a thick,
>   `3 cm`-beveled cross-section block resting on the solid warm cream backdrop (`#f0dfc4`).
>   Neither the pavement nor the two-lane grey asphalt road fades into distance fog; cutting
>   both off cleanly at the slab's perimeter preserves the tactile "modular wooden playset"
>   feel and prevents players from reading dead off-screen space as playable territory.
> - **Standalone Plot vs. Neighbours:** The restaurant stands alone as a single hero
>   building on its diorama plot. Placing full-height neighbouring shops on the left or
>   right flanks would occlude the 37° orthographic camera angle and pull eye-tracking away
>   from the playable restaurant grid. Adjacent property boundaries are instead signaled by
>   low, non-occluding perimeter cues—trimmed green hedges and a `0.55 m` wooden fence
>   border—so the building's silhouette stays completely clear from every corner.
> - **Shopfront Details & Live-Play Occlusion Rule:** The street facade showcases the
>   brand's signature coral (`#e56b5d`) and off-white (`#fff6e6`) palette via a striped
>   awning, chunky wooden hanging sign, coral-trimmed front door, twin picture windows, and
>   `0.55 m`-tall wooden flower planters. Because the restaurant's front wall sits on the
>   camera-facing cutaway edge in standard play, the full awning and upper window frames
>   appear in exterior/title framing and photo mode, while live service drops the front wall
>   to the `0.55 m` knee-height cutaway—leaving the doorway threshold, planters, and all five
>   queueing pavement squares unobstructed.
> - **Street Furniture (`1 m` Curb Grid):** The Lamp Post, Bench, Street Bin, Bike, and
>   Street Tree snap onto `1 m` curb tiles along the outer pavement edge. Keeping tall
>   vertical silhouettes (the lamp post and layered-sphere tree) strictly on the outer
>   road-side curb ensures they frame the street nicely without ever overlapping the
>   5-guest queue line or the dining room interior.

### What the sheets show

- **Shopfront:** a small cream building with a flat roof edged in thick dark brown, a coral
  and cream striped scalloped awning, coral-framed windows and door, and a wooden hanging
  sign carrying a burger.
- **Queue:** six regulars standing in a line along the pavement (Mabel, Otis, Suki and
  others), each with their own silhouette.
- **Street:** grey pavement slabs, a grey road with white dashes, all sitting on a thick
  dark-brown slab that floats on the backdrop.
- **Props:** an old-style lamp post with a warm glow, a slatted wooden bench, a teal bin,
  a coral bike, a layered-sphere tree in a stone surround.
- **Plot:** the shop with hedges and a low picket fence around it.

### Ideas worth taking

- The hanging burger sign and striped awning as the shop's face and logo hint.
- The dark thick slab as the diorama base, with pavement and road cut clean at the edge.
- Lamp post and bench as the first street props; a bike or tree as later unlockable decor.
- Wooden planters at the doorway to frame the entrance.

---

## Sheet 13: effects

**Delivered.** Two sheets: cooking and reward effects (13A) and mood effects with thought bubbles (13B).

| File | Content |
| --- | --- |
| `docs/art/13a_cooking_reward_effects.jpg` | Steam, cooking smoke, black burning smoke, sizzle spatter, perfect sparkle, coin pop, sink bubbles (four frames each) |
| `docs/art/13b_mood_thought_bubbles.jpg` | Disgust effect, walkout anger, thought bubble shape, and four icon bubbles at large and 20 px |

### Artist's comments (verbatim)

> - **Camera-Aligned Toy Billboards:** Every 4-frame particle sequence uses flat, unlit or
>   lightly shaded cutout cards oriented toward the 37° orthographic camera with rounded
>   `3 cm`-style toy silhouettes and zero alpha-gradient feathering—keeping particles crisp
>   at `1440 × 900` without soft-particle sorting artifacts.
> - **Instant Heat & Hazard Separation:** Steam (`#fff6e6` off-white curls), Cooking Smoke
>   (soft warm grey-cream puffs), and Black Burning Smoke (charcoal `#3a2c22` clouds flecked
>   with `#ff6b5e` sparks) step down sharply in luminance so players can distinguish an
>   active pan from an imminent stove fire in peripheral vision. Sizzle Spatter adds
>   high-frequency `#ffd34e` yellow droplets on active burner contact.
> - **Reward & Utility Readability:** Perfect Sparkle pairs four-point `#ffd34e` gold and
>   white stars over newly plated dishes, Coin Pop bounces a single chunky `#ffd34e` coin on
>   payment before it banks into the HUD, and Sink Bubbles float translucent `#8fc7c3`
>   teal-and-white spheres above the basin rim while washing up.
> - **Thought Bubble Silhouette & Icon Contrast:** The Thought Bubble Shape pops open over 4
>   frames using two ascending lead-in dots into a thick-rimmed `#fff6e6` cloud that
>   isolates interior icons from busy wood and checker floors. Each state icon relies on a
>   single bold shape and color cue—golden-brown burger (Wants a Burger), dark trim
>   `#3a2c22` ellipsis and `Zzz` (Bored), sickly green odor cloud and splat (Saw Something
>   Gross), and saturated `#e56b5d` coral heart (Loved It).

### What the sheets show

- **Cooking:** steam curling up from a stove, a grey-cream smoke puff growing and fading,
  a dark smoke cloud with orange sparks, a pan with yellow spatter flicking upward.
- **Rewards:** gold stars bursting then dissolving; a coin that hops, spins, glints and
  lands; teal bubbles growing and popping into a ripple.
- **Mood:** green wisps rising into a green cloud; a red four-armed anger mark with small
  puffs; a bubble forming from dots into a cloud.
- **Icons:** burger, "..." with zZ, green blob, red heart, each also shown at 20 px.

### Ideas worth taking

- Four frames per effect is a good sprite budget: fast to make, easy to play as a short loop.
- The thought bubble forming from dots is a nice entrance animation, and the cream cloud
  keeps icons readable on any floor.
- The anger mark above a walkout guest is a clear, funny "about to leave" tell.
- Coin pop could end by flying up to the money counter.

---

## Sheet 14: interface

**Delivered.** Three images: the service screen over the style frame (14A), the end-of-day and game-over cards (14B), and the icon set (14C). This completes the 14 sheets of the brief.

| File | Content |
| --- | --- |
| `docs/art/14a_service_screen.jpg` | Service HUD mockup over the restaurant |
| `docs/art/14b_end_of_day_game_over.jpg` | End-of-day receipt on a clipboard, game-over menu card |
| `docs/art/14c_icon_set.jpg` | Money, tip, walkout, patience, disgust, joy, food quality, day |

### Artist's comments (verbatim)

> **UI Materiality & Readability Spec (Engine / HUD Rules)**
> - **Diegetic Tabletop Paper & Wood System:** Rather than floating translucent bars, every
>   HUD panel uses off-white/cream paper stock (`#fff6e6` / `#f4ead8`) mounted on
>   `3 cm`-beveled warm wood (`#d9a066`) or dark trim (`#3a2c22`) backing cards with soft
>   plum-brown drop shadows (`#5a423a`). Printing all numerals and labels in dark brown ink
>   (`#3a2c22`) keeps text crisp against the cream cards while leaving high-saturation
>   `#e56b5d` coral, `#5fd38d` green, `#ffd34e` yellow, and `#ff6b5e` red strictly reserved
>   for live status stamps and icons.
> - **Service Screen Hierarchy (`1440 × 900`):**
>   - **Day & Shift Progress (Top-Left):** Pairs a chunky cream wooden plaque (`DAY 4`) with
>     a circular sun-sweep dial so players feel closing time approaching without reading tiny
>     numbers.
>   - **Cash Tally (Top-Left):** A compact cream receipt tag anchored by the embossed gold
>     coin icon (`$142`) that pulses with the Coin Pop animation whenever a table pays.
>   - **Three Walkout Markers (Top-Right):** Styled as a physical cardboard loyalty/strike
>     punch-card with three recessed slots—each walkout slams a red `#ff6b5e` angry-face ink
>     stamp into the next slot so remaining strikes read peripherally.
>   - **Contextual Station Prompt (`[ E ] COOK`):** Rendered as a small tactile keycap tile
>     plus paper label hovering directly over the active `1 m` station tile the chef faces,
>     keeping eyes locked on the kitchen action rather than screen corners.
> - **End-of-Day Receipt & Game-Over Cards:**
>   - **End-of-Day Card:** Formatted as a zigzag-torn diner receipt clipped to a wooden
>     clipboard (`MEALS SERVED`, `SALES`, `TIPS`, `WALKOUTS`, and bold `TOTAL EARNED`),
>     finished with a pinned yellow-cream note strip featuring a single Town Gossip quote
>     from that day's regulars.
>   - **Game-Over Card:** Formatted as a folded coral-trimmed tabletop menu card summarizing
>     `DAYS SURVIVED`, `TOTAL EARNED`, and `BEST RUN` in bold dark brown type.
> - **Unified Wooden-Enamel Icon Set (`24px` Minimum Read):** All eight icons (`MONEY`,
>   `TIP`, `WALKOUT`, `PATIENCE`, `DISGUST`, `JOY`, `FOOD QUALITY`, `DAY`) share the same
>   rounded `3 cm` bevel language, dark brown outer rim (`#3a2c22`), and distinct
>   silhouette/hue coding—mirroring the exact visual language of the Thought Bubbles and
>   Mood VFX from Sheet 13.

> That wraps up all 14 sheets in the brief! Let me know if you'd like any revisions, extra
> variants, or a consolidated asset checklist before kicking off 3D modeling in Blender.

### What the sheets show

- **Service screen:** the day plaque and sun dial top left with a money tag hanging below,
  a walkout punch-card top right with one red stamp, and an "[E] COOK" keycap label above
  the stove.
- **End of day:** a cream receipt with a coral "END OF DAY" ribbon, rows of figures in a
  hand-lettered face, and a taped yellow gossip note, all on a wooden clipboard.
- **Game over:** a folded menu-card stand with a dark ribbon title, three icons separating
  the lines, and a curled page corner.
- **Icons:** thick wooden-enamel tokens drawn in the same chunky style as the props.

### Ideas worth taking

- Paper and wood panels, not translucent bars, so the interface feels like part of the toy world.
- The sun dial as the day timer: the whole shift reads as a sun crossing the sky.
- The punch-card for walkouts, with a red stamp slamming into the next slot.
- The gossip note on the end-of-day receipt is a good home for the town-reputation system later.
- Still outstanding from the brief: the title screen composition from sheet 15.

---

## Sheet 15: logo directions

**Delivered.** One sheet of three logo directions for the working title "Regulars", each large and at 64 px. The title screen composition promised in the comment did not come with it.

| File | Content |
| --- | --- |
| `docs/art/15a_logo_directions.jpg` | Three logo directions |

### Artist's comments (verbatim)

> Here is Sheet 15, establishing three distinct branding directions for the working title
> "Regulars" alongside a cohesive title screen composition. Both sheets maintain our
> 37-degree orthographic view, beveled toy-materiality, and rich warm-to-cool palette.
>
> **Sheet 15A: Logo Directions.** This sheet explores three stylized logo options, showing
> each both large and in tiny 64px scale. All three directions embrace the chunky,
> round-bevel wooden-toy look with dark brown borders (`#3a2c22`) and high-contrast
> coral/yellow/teal accents:
> 1. **"Table & Diner" (Traditional & Cozy):** Playful, hand-carved lowercase letters in
>    warm cream and gold, nestled under a coral-and-white awning on a wooden menu board,
>    flanked by a tiny bowl and burger.
> 2. **"Character Peg-Doll" (Character-Centric):** Tall, spirited gold/orange letters with
>    tiny chef hats and guest-stylized silhouettes integrated directly into the word,
>    backed by a robust teal and wood shield.
> 3. **"Stamp & Badge" (Diner Patch):** A circular, stamped enamel badge featuring a
>    smiling guest peg-doll, a burger, and a "TOWN DINER" subtitle banner, heavily
>    utilizing the signature coral (`#e56b5d`) and teal (`#3f7f86`).

### What the sheet shows

- **1. Awning (cosy):** "REGULARS" in cream capitals on a dark brown sign under a striped
  coral and cream awning, with a burger on one side and a bowl on the other.
- **2. Peg-doll (playful):** big gold and orange letters, with a chef hat, a bun-haired
  guest, a straw hat and a blue cap perched on the letters, on a teal and wood backing.
  The 64 px version shortens to "FR".
- **3. Badge (retro):** a round teal checker disc with a guest peg-doll on top, a coral
  ribbon reading "REGULARS", a burger, and a wooden "TOWN DINER" banner underneath.

### Ideas worth taking

- The peg-doll direction is closest to the characters in the game, and its hats on
  letters echo the townsfolk kit.
- The badge works well as a small app icon or loading mark, and ties to the diner theme
  and teal checker floor.
- The awning sign is the most readable at small size and matches the shopfront.
- "Town Diner" works as a subtitle for this first theme; later themes could swap it.

---

## Sheet 16: second theme (seaside pier shack)

**Delivered.** The style frame redone as a seaside pier shack with the same layout and characters, to prove the kit stretches to new themes.

| File | Content |
| --- | --- |
| `docs/art/16_second_theme_seaside_pier.jpg` | Pier shack style frame |

### Artist's comments (verbatim)

> **How the Modular Kit Stretches to a Seaside Pier Shack**
> - **Zero-Change Gameplay Grid & Silhouettes:** The `10 × 7` floorplan (`4 × 7` kitchen on
>   the left, `6 × 7` dining room on the right), `0.9 m` counter elevation, and `3 cm` edge
>   bevels carry over unchanged. Every functional station—fridge, four-burner stove, sink,
>   and the 5-square coral serving pass—keeps its exact top-plane geometry so players read
>   the kitchen instantly without relearning station shapes.
> - **Surface & Prop Swaps on the Architecture Kit:** Standard off-white plaster walls swap
>   to painted coastal clapboard panels, rectangular windows swap to round portholes on the
>   same `1 m` wall socket, and wall art swaps to a nautical life-ring and wooden paddle.
>   The dining floor shifts to sun-bleached driftwood planks while keeping the `0.55 m`
>   knee-height front cutaway rule intact so seated guests and dirty plates stay
>   unobstructed.
> - **Floating Pier & Water Slab Edge:** Replacing the grey concrete pavement and asphalt
>   road with weathered pier boardwalk planks, rope-and-post bollards, and a turquoise ocean
>   water strip along the front slab edge transforms the setting while preserving the
>   bounded tabletop toy look.
> - **Preserved Character & UI Contrast:** Keeping the chef in pure white with coral trim
>   and townsfolk in muted blues, purples, and browns ensures characters, steamed patties,
>   and red anger flushes pop cleanly against the coastal wood and seafoam-and-cream checker
>   tiles.

### What the frame shows

- Same kitchen and serving pass; the dining room walls are pale seafoam and white
  clapboard with round brass portholes and a red and white life ring.
- Grey driftwood plank floor, weathered chairs and tables.
- A pier boardwalk with rope and post railings along the front, and a strip of turquoise
  sea with white foam at the slab edge.
- The same guests, queueing along the pier.

### Ideas worth taking

- A theme is a swap of surfaces and a few props over one set of stations, so new
  locations stay cheap to add.
- Portholes, a life ring and a rope railing are a quick way to say "seaside" without
  changing the layout.
- The water strip is a good alternative to the road for the slab edge.
