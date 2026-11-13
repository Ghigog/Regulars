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

## To build in the game

- Built: track switching by phase (title, service, build, closed).
- Layer fading by `day_progress()` and queue length.
- Per-theme music and ambience alongside `REGULARS_THEME`.
