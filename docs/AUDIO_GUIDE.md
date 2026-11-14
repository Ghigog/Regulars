# Regulars: audio style guide

The sound counterpart to `docs/STYLE_GUIDE.md`. In the game now: three real tracks in
`assets/music` (Daytime, Nighttime, Closed), switched by phase with a cross-fade (`MUSIC`
and `play_music` in `game/main.gd`), and synthesised effects from `tools/make_sfx.py`.
`Intro.mp3` loops on the title screen.

## The idea

The game is a toy diorama: painted wood, peg-people, warm light, paper-and-wood interface.
The music is made of the same stuff: small, acoustic, hand-played, a bit wonky. A toy-box
café band in the corner of the room. Not an orchestra, not chiptune.

## Rules

- **Instruments:** upright piano or toy piano, nylon guitar or ukulele, upright bass, brushed
  drums, wooden percussion (woodblock, marimba, shaker, spoons). Melody on clarinet,
  melodica or muted trumpet. No synths, except a soft pad at night.
- **Genre:** light swing, bossa, café jazz, with music-box whimsy. Cosy and slightly comic,
  never frantic.
- **Key and tempo:** major keys, warm jazz chords. Home key C major. About 95 bpm when calm,
  up to about 130 at the rush. Service tracks sit at 112.
- **Mix:** dry and close. Quiet enough that the sizzle and the doneness dial stay readable;
  the stove is the most important sound in the game.
- **One motif:** a single short "Regulars" tune (four to eight notes, hummable) appears in
  every track.
- **Themes re-dress, they do not replace.** A theme (seaside) keeps the tune and tempo and
  swaps the instruments, the same way the visuals re-skin the room.

## Tracks

| # | Track | When | Length | Notes |
|---|---|---|---|---|
| 1 | Service, main theme | During the day | 2–3 min loop | Three layers, see below. Heard most. |
| 2 | Closing time | Receipt, town book, build phase | 1.5–2 min loop | Slow, sparse motif: piano, bass, soft brushes. |
| 3 | Closed down | Game-over card | 20–30 s, then quiet loop | Rueful, not tragic. Motif in the minor, ends with a shrug. |
| 4 | Title | Title screen (still open) | 1 min loop | Motif played plainly. Can wait. |
| 5 | Seaside service | Pier theme | 2–3 min loop | Track 1 re-dressed: ukulele, lap steel, accordion. |

Priority: track 1 with its layers, then track 2, then stingers, then 3 to 5.

### Layers for the service track

Three stems of the same length and tempo, faded in sync as the day goes on:

1. **Morning:** bass, brushes, wood percussion.
2. **Lunch:** add guitar or piano comping and the melody.
3. **Rush:** add the horn line and busier drums (last third of the day, or a long queue).

Optional fourth "tension" stem (ticking woodblock, tighter hi-hat) when a guest is about to
walk out.

## Stingers

One to three seconds, same instruments, in the key of the service track:

- Day start (the "Day N" banner)
- Perfect patty served
- Walkout (a deflating clarinet or trombone slide)
- Day complete
- New best run
- Half price given, or a regular won over (a small warm chime)
- Crate opened, furniture placed (build phase)

## Ambience

Separate from the music: a quiet room-tone loop (murmur, cutlery, a street outside) and a
seaside one (waves, gulls, rope creak).

## Suno prompts

Custom mode, Instrumental on. Style text goes in "Style of Music"; structure tags go in the
lyrics box. Keep tempo, key and the phrase "dry close room sound" identical across prompts.

**1. Service** (with tags)

```text
Instrumental cosy café jazz, light swing, 112 bpm, C major. Upright piano, nylon guitar, upright bass, brushed drums, woodblock and marimba, playful clarinet melody. Toy-box whimsy, hand-played, warm, dry close room sound, small band in the corner of a diner. Simple hummable 6-note motif repeated. No vocals, no synths, seamless loop.
```

```text
[Intro: bass, brushes and woodblock only]
[Verse: add nylon guitar and piano comping]
[Theme: clarinet plays the main motif]
[Verse: marimba answers the motif]
[Build: busier drums, muted trumpet joins]
[Theme: full band, lively]
[Outro: back to bass and brushes, ends on the downbeat]
```

**2. Closing time** (raw; tags only if it wanders)

```text
Instrumental slow café jazz ballad, 78 bpm, C major. Solo upright piano with upright bass and very soft brushes, a little music box. Evening, lamps on, tidy-up after closing, gentle and content. Sparse, warm, dry close room sound. Same simple hummable motif played slowly. No vocals, no synths, seamless loop.
```

```text
[Intro: solo piano]
[Theme: piano with bass and soft brushes]
[Theme: music box doubles the melody]
[Outro: solo piano, ends softly]
```

**3. Closed down** (raw; add `[Short instrumental]` then `[End]` if it runs long)

```text
Instrumental short rueful jazz cue, 70 bpm, C minor. Solo clarinet over sparse upright piano, a sighing trombone slide, ends with a wry little shrug. Bittersweet but comic, not tragic. Toy-box feel, dry close room sound. No vocals, no synths. 30 seconds.
```

**4. Title** (raw)

```text
Instrumental warm café jazz theme, easy swing, 100 bpm, C major. Toy piano and upright piano state a simple hummable motif, nylon guitar, upright bass, brushed drums, woodblock. Welcoming, charming, handmade wooden-toy feel, dry close room sound. No vocals, no synths, seamless loop.
```

**5. Seaside service** (track 1's tags with ukulele, accordion and lap steel swapped in, or
Cover from track 1)

```text
Instrumental breezy seaside café swing, 112 bpm, C major. Ukulele, lap steel guitar, accordion melody, upright bass, brushed drums, shaker and woodblock. Sunny pier diner, toy-box whimsy, hand-played, warm, dry close sound. Simple hummable 6-note motif repeated. No vocals, no synths, seamless loop.
```

**Stingers** (raw; generate one track and cut the cues out by hand)

```text
Instrumental collection of very short jazz stingers separated by silence, C major. Clarinet, toy piano, marimba, woodblock, muted trumpet, trombone. Bright two-second fanfare, warm chime, cheerful flourish, deflating trombone slide, triumphant little tag. Dry close room sound. No vocals.
```

### Making them a set

- **Shared motif:** Suno does not carry a tune between generations. Get track 1 right, then
  Cover or Extend from it with the other style prompts.
- **Layers:** generate track 1 as a full arrangement, then split stems (bass and drums,
  chords, melody) for morning, lunch and rush.
- **Loops:** "seamless loop" is only a nudge. Trim to a bar line and crossfade.
- **Stray vocals:** if wordless vocals appear, put `[Instrumental]` in the lyrics box.
- **Licence:** check the plan grants commercial rights before shipping generated audio.

## Sound effects

The game ships 28 synthesised effects from `tools/make_sfx.py`. They are placeholders.
The prompts below are for ElevenLabs Sound Effects, to replace them and to add the
missing ones. Each entry gives the file name, the status (**have**, **split** for
one sound doing too many jobs, or **new**), the length, whether it loops, and the prompt.

### Rules for every effect

- **Material:** it's a toy diorama, so everything is painted wood, felt, card, tin and
  ceramic. Pick wood over metal and a soft thunk over a crack. Things sound
  slightly smaller and lighter than they would in real life.
- **Room:** dry and close, as if recorded a foot from a dolls' house. No big reverb, no
  cinematic whooshes, no sub-bass booms.
- **Mood:** cosy and slightly comic. Mistakes sound sheepish, not harsh. Rewards are warm
  chimes, not arcade jingles.
- **Pitch:** where an effect is musical (chimes, stingers), keep it in C major so it
  sits with the music.
- **Priority:** the stove sits above everything else in the mix. Interface sounds are quiet.
- **Variants:** generate 3 to 4 takes of anything that repeats often (steps, pickups,
  coins, cutlery). The game picks one at random and nudges the pitch about ±5%.

### ElevenLabs settings

- Set **Duration** by hand to the length given. Auto tends to pad short sounds.
- For a loop, switch **Loop** on and give 6 to 10 seconds, so the repeat isn't
  noticeable. Then trim to a zero crossing and check the seam in Godot (`loop_mode` on the
  import).
- Use a high **Prompt influence** (about 0.6 to 0.8) for one-shots. Use a lower one
  (about 0.4) for ambience, so it varies.
- Export WAV at 44.1 kHz. Trim the silence at the front so the sound lands on the frame
  it is triggered. Loudness-match each new sound to the one it replaces.

### 1. Stove and cooking

The most important sounds in the game. A player should be able to cook with their eyes
shut.

**`grill_drop.wav`** · new · 0.8 s · one-shot
> A small raw burger patty slapped down onto a hot flat-top griddle: a soft wet pat, then an instant bright hiss that flares up and settles. Close-miked, dry, a little cartoonish and appetising, like a toy kitchen that really works. No voices, no music.

**`sizzle_raw.wav`** · split (from `sizzle`) · 8 s · loop
> Steady gentle sizzle of a single raw patty on a griddle: quiet, wet, juicy bubbling with soft fat pops, even and calm. Close and dry, no kitchen clatter, no voices. Seamless loop.

**`sizzle_cooking.wav`** · split · 8 s · loop
> A burger patty halfway cooked on a hot griddle: a fuller, brighter sizzle with more frequent crisp fat pops and a faint crackle, lively but controlled. Close, dry, appetising. Seamless loop.

**`sizzle_done.wav`** · split · 8 s · loop
> A perfectly browned patty on the griddle: a drier, crisper, higher sizzle, tight little crackles, the wet bubbling mostly gone. It should sound ready to come off. Close, dry. Seamless loop.

The game cross-fades these three by doneness, so they need to match in loudness and
character.

**`smoke_warn.wav`** · new · 6 s · loop
> A patty left too long on a griddle: harsh dry crackling, spitting fat and a thin rising hiss of smoke, with an edge of trouble but still small and toy-like. Sounds like it's starting to catch. Close and dry. Seamless loop.

**`flip.wav`** · have · 0.5 s · one-shot
> A small wooden-handled spatula scrapes under a burger patty and flips it: a short metallic scrape, a soft airy flop, then a fresh burst of sizzle as it lands. Quick, satisfying, close and dry.

**`ding.wav`** · have · 1.0 s · one-shot
> A single bright, round tap on a small brass kitchen timer bell, pitched to C, with a short warm ring that fades fast. Cheerful and clear, like a toy diner bell. No reverb tail.

**`burn.wav`** · have · 1.2 s · one-shot
> A burger burning: a sudden angry hiss and a dry crackle collapsing into a sad little puff of smoke, then a quiet fizzle. Comic deflation, not alarming. Close and dry.

**`plate_food.wav`** · new · 0.5 s · one-shot
> A cooked patty and a soft bun placed onto a ceramic diner plate: a gentle squash of bread, a light clink of china underneath. Small, tidy and pleasing. Close and dry.

### 2. Service and guests

**`bell.wav`** · have · 1.5 s · one-shot
> A small brass shop bell on a curved spring above a wooden café door, jingling twice as the door swings open, with a soft creak of the hinge underneath. Friendly and welcoming, toy-sized, dry room.

**`sit.wav`** · new · 0.6 s · one-shot
> A small wooden chair scraped back across a wooden floor, then a soft settling bump as someone sits down. Short and light, like a dolls' house chair. Close and dry.

**`order_ready.wav`** · new · 0.7 s · one-shot
> Two light knuckle taps on a wooden table followed by a soft, polite little "ahem"-like woodblock pop: a guest signalling they're ready to order. Gentle and attention-catching but never rude. Dry and close.

**`order_take.wav`** · new · 0.9 s · one-shot
> A stubby pencil scribbling quickly on a paper order pad, two quick scratches and a tick, then the page flicked over. Brisk and efficient. Close and dry.

**`serve.wav`** · have · 0.6 s · one-shot
> A ceramic diner plate set down on a wooden table with a confident soft clunk and a tiny cutlery rattle. Warm and pleasing, the sound of "here you go". Dry and close.

**`perfect.wav`** · have · 1.5 s · one-shot
> A short sparkling reward: three rising notes on a toy glockenspiel in C major, C E G, ending in a soft shimmering chime. Delighted and warm, like a music box flourish, never arcade-y. Dry with only a tiny tail.

**`eat_loop.wav`** · new · 8 s · loop
> One person eating quietly at a diner table: occasional fork and knife clinks on china, a soft scrape, a cup set down. Sparse, relaxed and homely. Close, dry. Seamless loop.

**`impatient.wav`** · new · 1.0 s · one-shot
> A guest getting restless: quick fingertips drumming on a wooden table, three or four taps, ending with a small huffy wooden "tock". Comic and mildly grumpy. Close and dry.

**`pay.wav`** · split (from `coin`) · 0.6 s · one-shot
> Two or three small coins dropped onto a wooden counter, a light bright clink and a brief roll. Pleasant and modest. Close and dry.

**`pay_tip.wav`** · split · 1.0 s · one-shot
> A generous handful of coins poured onto a wooden counter, a bright cascade of clinks, then an old brass till drawer "ka-ching" with a tiny bell. Happy and rewarding, toy-sized. Close and dry.

**`pay_grudging.wav`** · split · 0.8 s · one-shot
> A single coin slapped down flat on a wooden table, then a short reluctant slide. Curt and sulky but comic. Close and dry.

**`comp.wav`** · new · 1.2 s · one-shot
> A soft warm "it's on the house" chime: two gentle descending notes on a felt-hammered marimba in C major, G to E, with a light sparkle. Kind and reassuring. Dry and close.

**`walkout.wav`** · new · 1.5 s · one-shot
> An unhappy guest leaving: a chair pushed back hard, three quick heavy wooden footsteps, then a café door shut a little too firmly with its little bell clanging once. Comic huffiness, not violent. Dry room.

**`stamp.wav`** · have · 0.4 s · one-shot
> A rubber stamp pressed down hard onto paper on a wooden desk: a crisp padded thump with a tiny inky smack. Official and final. Close and dry.

### 3. Peg-doll voices

No words. Each sound is a short wooden-toy blip that sounds a little like a voice, so
regulars have character without speech. Generate 4 takes of each, and the game varies
the pitch per guest.

**`voice_hm.wav`** · new · 0.4 s · one-shot
> A tiny wordless "hm?" from a small wooden toy character: a short rising hummed blip, like a breathy kazoo and a woodblock combined. Curious and friendly. Dry.

**`voice_ooh.wav`** · new · 0.5 s · one-shot
> A tiny delighted wordless "ooh!" from a small toy character: a bright rising cooed blip, soft and whistly, warm and pleased. Dry and close.

**`voice_huff.wav`** · new · 0.5 s · one-shot
> A tiny grumpy wordless "hmph" from a small toy character: a short low falling nasal blip, comically put out. Dry and close.

### 4. Cleaning

**`clear_table.wav`** · new · 1.0 s · one-shot
> Clearing a diner table: two ceramic plates stacked with a clink, cutlery swept on top with a rattle, all lifted together. Brisk, tidy, homely. Close and dry.

**`dish_pile.wav`** · new · 0.6 s · one-shot
> A dirty plate set onto an already teetering pile in a sink: a wobbly china clatter that just about settles. Slightly comic, a hint of "careful". Close and dry.

**`wash.wav`** · have · 1.5 s · one-shot
> Washing a plate in a small sink: a swish of soapy water, a squeaky rub of a sponge on china, a drip, then the plate set on a rack with a light clink. Clean and satisfying. Close and dry.

**`wipe.wav`** · new · 0.8 s · one-shot
> A damp cloth wiped in two quick circles across a wooden tabletop: a soft rhythmic squeak and swish. Tidy and pleasing. Close and dry.

**`bin_lift.wav`** · split (from `lift` and `rattle`) · 0.9 s · one-shot
> Lifting a full rubbish bag out of a small tin kitchen bin: the lid clanks open, the plastic bag rustles and crinkles, a muffled jumble of cans shifting inside. Close and dry.

**`bin_dump.wav`** · new · 0.8 s · one-shot
> A stuffed rubbish bag dropped into a big outdoor bin: a heavy soft thud, a crinkle, a lid banged shut with a tinny clang. Slightly outdoors, still small. Dry.

### 5. Chef

**`step_wood.wav`** · split (from `step`) · 0.25 s · one-shot (4 takes)
> One soft footstep of a small wooden peg-doll on a wooden parquet floor: a light hollow knock, felt-dampened. Gentle and quiet. Close and dry.

**`step_tile.wav`** · new · 0.25 s · one-shot (4 takes)
> One soft footstep of a small wooden peg-doll on a polished marble or tile floor: a light brighter clack, short and clean. Quiet. Close and dry.

**`pickup.wav`** · have · 0.3 s · one-shot (3 takes)
> A small wooden or ceramic object picked up off a counter: a light lift with a soft click and a tiny airy whisk. Quick and neat. Close and dry.

**`putdown.wav`** · have · 0.3 s · one-shot (3 takes)
> A small wooden or ceramic object set down on a wooden counter: a short soft knock. Satisfying and tidy. Close and dry.

**`blocked.wav`** · split (from `fail`) · 0.35 s · one-shot
> A soft hollow double woodblock "bonk-bonk", lower on the second note: a gentle "can't do that", like bumping a toy. Polite, not punishing. Dry.

**`mistake.wav`** · split (from `fail`) · 0.9 s · one-shot
> A short deflating comic cue: a muted trombone "wah-wahh" slide down, small and wry. Sheepish, not harsh. Dry close room sound.

### 6. Build phase

**`crate_open.wav`** · have (`rip`) · 1.2 s · one-shot
> Opening a small wooden shipping crate: a crowbar creak, two nails squeaking out, the lid popping loose, then a rustle of packing straw. Exciting like unwrapping a present. Close and dry.

**`place.wav`** · split (from `putdown`) · 0.5 s · one-shot
> A piece of toy wooden furniture plonked firmly into place on a wooden floor: a satisfying solid "thok" and a tiny rattle settling. Pleasing and chunky. Close and dry.

**`move.wav`** · have (`slide`) · 0.6 s · one-shot
> A small wooden table lifted and slid a short way across a wooden floor: a light scrape and a soft bump. Close and dry.

**`sell.wav`** · split (from `coin`) · 0.8 s · one-shot
> A wooden object lifted away with a soft whisk, followed by coins dropped into a tin cash box. Slightly different from a customer paying: a hollower tin rattle. Close and dry.

**`cant_place.wav`** · split (from `fail`) · 0.4 s · one-shot
> A soft wooden clack, as if a toy piece knocks against something and won't fit, with a tiny hollow wobble. Gentle "no room here". Dry and close.

**`paint_roll.wav`** · new · 6 s · loop
> A small paint roller rolling wet paint across a wall: a sticky soft squelching swish, back and forth in a steady rhythm. Calm and satisfying. Close and dry. Seamless loop.

**`wallpaper.wav`** · new · 1.0 s · one-shot
> A strip of wallpaper unrolled and smoothed onto a wall: a paper flap, a pasty slap, then a brush swept down it. Close and dry.

**`floor_tile.wav`** · new · 0.3 s · one-shot (4 takes)
> One small floor tile or parquet block clicked into place: a crisp light wooden or ceramic tap. Plays rapidly during a drag, so keep it very short and clean. Close and dry.

**`hammer.wav`** · new · 0.8 s · one-shot
> A small toy hammer tapping a nail into wood: three quick light taps, rising slightly in pitch. Busy and handy. Close and dry.

**`extend_room.wav`** · new · 1.8 s · one-shot
> A dolls' house wall swung open on hinges and a new section slotted in: a wooden creak, a sliding scrape and a solid click, then a short warm marimba flourish in C major. A small "ta-da". Dry.

### 7. Day loop and interface

**`day.wav`** · have · 1.5 s · one-shot
> Morning opening: a brass shop bell rung twice, a door's "Closed" sign flipped to "Open" with a light card slap, and a single cheerful toy-piano note in C. Fresh and hopeful. Dry room.

**`close.wav`** · new · 1.5 s · one-shot
> Closing up: a hanging card sign flipped with a soft slap, a small door latch clicked shut, and a gentle descending three-note toy-piano phrase in C, G E C. Content and tired. Dry.

**`page.wav`** · have · 0.6 s · one-shot
> One page of a paper wall calendar flipped over and settling: a crisp paper flap and a soft swish. Close and dry.

**`receipt.wav`** · have (`roll`) · 2.0 s · one-shot
> A small mechanical till printing a paper receipt: a quick buzzing chatter of the printer head, with the paper feeding out. Neat and mechanical, toy-sized. Close and dry.

**`receipt_tear.wav`** · new · 0.4 s · one-shot
> A paper receipt torn cleanly off a till's serrated edge: one crisp quick rip. Close and dry.

**`tick.wav`** · have · 0.1 s · one-shot
> A single tiny wooden click, like a bead moved on an abacus. Very short, light and crisp, for counting up numbers. Dry.

**`tab.wav`** · have · 0.2 s · one-shot
> A cardboard tab on a folder flicked open: a light papery snap. Quiet and tidy. Dry.

**`hover.wav`** · new · 0.08 s · one-shot
> The faintest soft wooden tick, like a fingertip brushing a toy block. Barely there, for the cursor moving over a button. Dry.

**`back.wav`** · new · 0.2 s · one-shot
> A soft papery card flicked closed, slightly lower and duller than an opening tab: a gentle "never mind". Dry.

**`flyers.wav`** · have (`flutter` and `rope`) · 1.5 s · one-shot
> A small stack of paper flyers fanned out and tossed into the air, fluttering down, with a soft creak of a rope pulley lifting a sign. Lively and hopeful. Light outdoor air, still dry.

**`best_run.wav`** · new · 2.5 s · one-shot
> A triumphant tiny fanfare: muted trumpet and toy piano playing a bright rising flourish in C major, finished with a little cymbal splash and a wooden clap. Proud and charming, hand-played. Dry close room sound.

**`run_over.wav`** · new · 3.0 s · one-shot
> The end of a run: a slow sighing clarinet line falling in C minor, a lamp switch clicked off, then a soft wooden door closing for the last time. Bittersweet and gently comic, not tragic. Dry.

### 8. Ambience

Loops that sit beneath the music, separate from it.

**`room_quiet.wav`** · new · 10 s · loop
> A small café with only one or two guests: a very soft murmur, the odd cup on saucer, a quiet clock ticking, distant street sounds through a closed window. Warm and relaxed. Close and dry. Seamless loop.

**`room_busy.wav`** · new · 10 s · loop
> A cosy café at lunchtime rush: lively wordless chatter of a dozen people, cutlery and plates clinking, chairs scraping, a laugh now and then. Busy but cosy, small room, no intelligible words. Seamless loop.

The game cross-fades `room_quiet` into `room_busy` as the room fills.

**`street.wav`** · new · 10 s · loop
> A quiet small-town street outside a café: distant footsteps on cobbles, a bicycle bell far away, birds, a soft breeze. Gentle and pleasant. Seamless loop.

**`seaside.wav`** · new · 10 s · loop
> A seaside pier café: soft waves lapping beneath wooden boards, gulls calling far off, rope creaking against a mooring post, a light sea breeze. Sunny and relaxed. Seamless loop.

**`night.wav`** · new · 10 s · loop
> An empty café after closing: deep quiet, a wall clock ticking, a fridge humming faintly, the odd creak of old wooden boards, crickets outside. Calm and peaceful. Seamless loop.

## To build in the game

- Built: track switching by phase (title, service, build, closed).
- Sound effects: replace the placeholder wavs as the ElevenLabs versions come in. Wire
  up the split sounds (`fail`, `coin`, `sizzle` and `step` each become several) and the
  new hooks: the doneness sizzle cross-fade, order-ready, impatience, eating, closing,
  voices, and random takes with pitch variation.
- Ambience bus with room tone cross-faded by how full the room is.
- Layer fading by `day_progress()` and queue length.
- Per-theme music and ambience alongside `REGULARS_THEME`.
