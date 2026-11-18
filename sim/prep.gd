class_name Prep
extends RefCounted
## Scoring for the prep minigames: every one ends good, plain or bad (heat tools can
## also spoil). Pure: the widgets in game/ only show it.

const GOOD := 1.0    # tunable: the quality each result gives an ingredient
const PLAIN := 0.75
const BAD := 0.45
## Grill and fryer timing, in seconds on the heat with a tool of quality 1.0.
const GRILL_NEARLY := 2.4   # before this it is still raw: taking it off changes nothing
const GRILL_DONE := 4.0     # underdone (plain) until here
const GRILL_PERFECT := 7.5  # good until here, then it dries out (plain, falling)
const GRILL_BURN := 12.0    # spoiled


## Perfect plates (review, item 6). A tray served at PERFECT_AT or better is perfect;
## perfect trays in a row make a streak. Each step of the streak raises that guest's tip,
## and from STREAK_REP_FROM on the town hears about the cooking.
const PERFECT_AT := 0.95
const STREAK_TIP := 0.1        # tunable: tip raised this much per perfect tray in a row
const STREAK_TIP_MAX := 5      # tunable: up to this many steps (+50%)
const STREAK_REP_FROM := 3     # tunable: the streak at which word gets round
const STREAK_REP := 0.03       # tunable: affinity for the guest (friends hear 40%)


static func is_perfect(tray_quality: float) -> bool:
	return tray_quality > PERFECT_AT


## The tip scale for a tray served `streak` perfect trays into a run (0 for none).
static func streak_tip(streak: int) -> float:
	return 1.0 + STREAK_TIP * clampi(streak, 0, STREAK_TIP_MAX)


## The affinity a perfect tray `streak` into a run earns its guest.
static func streak_rep(streak: int) -> float:
	return STREAK_REP if streak >= STREAK_REP_FROM else 0.0


static func quality_of(result: String) -> float:
	return {"good": GOOD, "plain": PLAIN, "bad": BAD}.get(result, 0.0)


## What taking a piece off the grill after `t` seconds gives: {state, result, quality}.
## state is "raw" (nothing happened), "prep" or "burnt"; result is "", "good",
## "plain" or "spoiled". Drying out keeps a smooth curve from plain down to bad.
## `q` is the tool's quality at the job (PRD 8.3): see heat_times.
static func grill(t: float, q := 1.0) -> Dictionary:
	return _heat(t, heat_times("grill", q))


## A grill or fryer's timeline for a tool of quality `q`: [raw until, done from, good
## until, burnt at]. Quality is difficulty: the good window and the slow slide to
## burnt both stretch by `q`, so a stand-in (0.6) is narrower and a specialist (1.6)
## roomier than a base tool (1.0, the old timings).
static func heat_times(job: String, q := 1.0) -> Array:
	var t: Array = [GRILL_NEARLY, GRILL_DONE, GRILL_PERFECT, GRILL_BURN] if job != "fry" \
			else [FRY_MIN, FRY_GOOD, FRY_LATE, FRY_BURN]
	var good_end: float = t[1] + (t[2] - t[1]) * q
	return [t[0], t[1], good_end, good_end + (t[3] - t[2]) * q]


static func _heat(t: float, tt: Array) -> Dictionary:
	if t < tt[0]:
		return {"state": "raw", "result": "", "quality": 0.0}
	if t < tt[1]:
		return {"state": "prep", "result": "plain", "quality": PLAIN}
	if t <= tt[2]:
		return {"state": "prep", "result": "good", "quality": GOOD}
	if t < tt[3]:
		return {"state": "prep", "result": "plain",
			"quality": lerpf(PLAIN, BAD, (t - tt[2]) / (tt[3] - tt[2]))}
	return {"state": "burnt", "result": "spoiled", "quality": 0.0}

## Fry: like the grill, then a rest on the drain rack before it can be picked up.
const FRY_MIN := 1.0       # lifted before this it is still raw
const FRY_GOOD := 3.0      # early (plain) until here
const FRY_LATE := 5.0      # good until here, then late (plain)
const FRY_BURN := 8.0      # spoiled
const FRY_REST := 2.0      # tunable: seconds on the drain rack before it can be picked up
## Boil: start it and leave it. Done after this long, and it waits; it never burns.
const BOIL_TIME := 5.0
## Chop: a marker sweeps the bar; press as it crosses the notch in the middle.
const CHOP_SWEEPS := 3
const CHOP_SWEEP_TIME := 0.9   # tunable: seconds for one sweep, left to right
const CHOP_NOTCH := 0.09       # tunable: half the notch's width, as a share of the bar
## Slice: mash to the count before the timer ends, then stop.
const SLICE_COUNT := 6         # tunable
const SLICE_TIME := 2.6        # tunable
const SLICE_SLACK := 3         # presses over the count that are still plain
## Pour: hold to fill; let go as high as you dare.
const POUR_RATE := 0.45        # tunable: share of the cup filled a second
const POUR_GOOD := 0.85
const POUR_PLAIN := 0.6
## Reward and penalty (tunable): speed times this, for this long.
const BURST_SPEED := 1.5
const PENALTY_SPEED := 0.5
const BOOST_TIME := 1.0
## A piece that plays itself (an auto slicer): seconds it takes, always good (tunable).
const AUTO_TIME := 0.8
## Tools that give no burst or penalty, whatever happens.
const NO_REWARD: Array[String] = ["boil", "none"]


## What lifting the basket after `t` seconds gives: {state, result, quality}. The
## smooth curve of the grill is kept: early and late fall from plain toward bad.
static func fry(t: float, q := 1.0) -> Dictionary:
	return _heat(t, heat_times("fry", q))


## How long boiling takes with a tool of quality `q`: boiling has no skill, so a
## better pot is simply quicker.
static func boil_time(q := 1.0) -> float:
	return BOIL_TIME / maxf(q, 0.1)


## Boiling: done or not; once done it is always plain.
static func boil(t: float, q := 1.0) -> Dictionary:
	if t < boil_time(q):
		return {"state": "raw", "result": "", "quality": 0.0}
	return {"state": "prep", "result": "plain", "quality": PLAIN}


## Whether a press with the marker at `pos` (0 to 1 along the bar) hits the notch.
static func chop_hit(pos: float, q := 1.0) -> bool:
	return absf(pos - 0.5) <= chop_notch(q)


## Tool quality is the minigame's difficulty (PRD 8.3). 1.0 plays as before; a
## stand-in (0.6) is narrower and faster; a specialist (1.6) roomier and slower.
## How the presses and sweeps scale with quality (tunable).
static func _pace(q: float) -> float:
	return 0.5 + 0.5 * q


## Half the chop notch's width for a tool of quality `q`.
static func chop_notch(q := 1.0) -> float:
	return CHOP_NOTCH * q


## Seconds for one sweep of the chop marker.
static func chop_sweep(q := 1.0) -> float:
	return CHOP_SWEEP_TIME * _pace(q)


## Seconds to slice to the count.
static func slice_time(q := 1.0) -> float:
	return SLICE_TIME * _pace(q)


## Presses over the count that are still plain.
static func slice_slack(q := 1.0) -> int:
	return maxi(1, roundi(SLICE_SLACK * q))


## Where a pour turns good: a better tap leaves a wider band below the brim.
static func pour_good(q := 1.0) -> float:
	return clampf(1.0 - (1.0 - POUR_GOOD) * q, POUR_PLAIN + 0.05, 0.97)


## How fast the cup fills: a stand-in rushes.
static func pour_rate(q := 1.0) -> float:
	return POUR_RATE / _pace(q)


## Three sweeps: all three in the notch is good, two plain, one or none bad.
static func chop(hits: int) -> String:
	if hits >= CHOP_SWEEPS:
		return "good"
	return "plain" if hits == CHOP_SWEEPS - 1 else "bad"


## Exactly the count in time is good; one to three over plain; more, or short of
## the count when the timer ends, bad.
static func slice(presses: int, q := 1.0) -> String:
	if presses < SLICE_COUNT:
		return "bad"
	if presses == SLICE_COUNT:
		return "good"
	return "plain" if presses - SLICE_COUNT <= slice_slack(q) else "bad"


## Let go at `fill` (0 to 1; over 1 has overflowed).
static func pour(fill: float, q := 1.0) -> String:
	if fill > 1.0:
		return "bad"
	if fill >= pour_good(q):
		return "good"
	return "plain" if fill >= POUR_PLAIN else "bad"


## "burst", "penalty" or "" for a result with a tool. A piece that plays itself (an
## auto slicer) gives neither.
static func reward(tool: String, result: String, auto := false) -> String:
	if NO_REWARD.has(tool) or auto:
		return ""
	if result == "good":
		return "burst"
	return "penalty" if result == "bad" or result == "spoiled" else ""


# ---------- The new jobs (PRD 8.6) ----------
# Each is short and plays on the one Use button, like the seven above. Tool quality
# is difficulty: a wider band or window, a gentler pace (`_pace`).

## Grate: hold to rub faster, let go to slow. The grater fills while the speed sits in
## the green band; over the top is a scraped knuckle (bad). Fill it in time.
const GRATE_RISE := 1.1     # tunable: speed gained a second while held
const GRATE_FALL := 0.9     # tunable: speed lost a second when let go
const GRATE_LOW := 0.4      # the band's bottom
const GRATE_HIGH := 0.75    # its top for a tool of quality 1.0
const GRATE_FILL := 1.6     # seconds in the band to fill the pile
const GRATE_GOOD := 3.2     # filled by this many seconds (x pace) is good, else plain
const GRATE_LIMIT := 6.0    # not filled by now (x pace) is bad
## Saw: the blade runs back and forth; press as it reaches the end of each stroke.
const SAW_STROKES := 4
const SAW_STROKE_TIME := 0.7   # tunable: seconds for one stroke, end to end
const SAW_END := 0.2           # tunable: the share of a stroke, at its end, a press counts in
## Juice: hold to press a half down on the cone, let go with the pressure in the green.
## Too hard squirts the pips (a miss). Three halves.
const JUICE_HALVES := 3
const JUICE_RISE := 0.9     # tunable: pressure gained a second while held
const JUICE_GOOD := 0.6     # the green band's bottom for a tool of quality 1.0; its top is JUICE_TOP
const JUICE_TOP := 0.9
const JUICE_MIN := 0.12     # letting go below this was no squeeze at all
## Blend: press to pulse. Each pulse rocks the jug; it settles on its own. Too much
## rocking and the lid flies off (bad). Pulse it smooth in time.
const BLEND_PULSES := 7
const BLEND_KICK := 0.3     # tunable: rocking a pulse adds, for a tool of quality 1.0
const BLEND_SETTLE := 0.55  # rocking lost a second
const BLEND_GOOD := 3.0     # done by this many seconds (x pace) is good, else plain
const BLEND_LIMIT := 6.0    # not done by now (x pace) is bad
## Steam: the lid rattles as the steam builds; lift it (press) while the gauge is green.
## Early is still firm (bad), late soft (plain); left too long it goes mushy (bad).
const STEAM_TIME := 3.2     # tunable: seconds for the gauge to fill
const STEAM_LOW := 0.55     # share of the gauge where green starts
const STEAM_HIGH := 0.8     # where it ends, for a tool of quality 1.0
const STEAM_OVER := 1.0     # mushy from here: the minigame ends bad


## The grate's speed after `delta` seconds, held or not.
static func grate_speed(v: float, held: bool, delta: float, q := 1.0) -> float:
	return maxf(0.0, v + (GRATE_RISE / _pace(q) if held else -GRATE_FALL) * delta)


## The grate's green band [low, high] for a tool of quality `q`.
static func grate_band(q := 1.0) -> Vector2:
	return Vector2(GRATE_LOW, minf(0.95, GRATE_LOW + (GRATE_HIGH - GRATE_LOW) * q))


## Grating's result: filled after `t` seconds, or not ("" while it goes on).
## `scraped`: the speed went over the top.
static func grate(t: float, filled: bool, scraped: bool, q := 1.0) -> String:
	if scraped:
		return "bad"
	if filled:
		return "good" if t <= GRATE_GOOD * _pace(q) else "plain"
	return "bad" if t >= GRATE_LIMIT * _pace(q) else ""


## Seconds for one saw stroke.
static func saw_stroke(q := 1.0) -> float:
	return SAW_STROKE_TIME * _pace(q)


## Whether a press at `pos` (0 to 1 through a stroke) is at its end.
static func saw_hit(pos: float, q := 1.0) -> bool:
	return pos >= 1.0 - SAW_END * q


## Four strokes: all four on the end is good, three plain, fewer bad.
static func saw(hits: int) -> String:
	if hits >= SAW_STROKES:
		return "good"
	return "plain" if hits == SAW_STROKES - 1 else "bad"


## How fast the juice press's pressure builds.
static func juice_rate(q := 1.0) -> float:
	return JUICE_RISE / _pace(q)


## Where the juice band starts: a better juicer leaves a wider band.
static func juice_good(q := 1.0) -> float:
	return clampf(JUICE_TOP - (JUICE_TOP - JUICE_GOOD) * q, 0.2, JUICE_TOP - 0.05)


## Whether letting go at pressure `p` juiced the half well.
static func juice_hit(p: float, q := 1.0) -> bool:
	return p >= juice_good(q) and p <= JUICE_TOP


## Three halves: all three is good, two plain, fewer bad.
static func juice(hits: int) -> String:
	if hits >= JUICE_HALVES:
		return "good"
	return "plain" if hits == JUICE_HALVES - 1 else "bad"


## The rocking one pulse adds: a better blender rocks less.
static func blend_kick(q := 1.0) -> float:
	return BLEND_KICK / maxf(q, 0.1)


## The jug's rocking after `delta` seconds of settling.
static func blend_settle(w: float, delta: float) -> float:
	return maxf(0.0, w - BLEND_SETTLE * delta)


## Blending's result ("" while it goes on): spilled is bad; all pulses in good time
## good, else plain; out of time bad.
static func blend(t: float, pulses: int, spilled: bool, q := 1.0) -> String:
	if spilled:
		return "bad"
	if pulses >= BLEND_PULSES:
		return "good" if t <= BLEND_GOOD * _pace(q) else "plain"
	return "bad" if t >= BLEND_LIMIT * _pace(q) else ""


## Seconds for the steam gauge to fill (a better steamer is slower, so roomier).
static func steam_time(q := 1.0) -> float:
	return STEAM_TIME * _pace(q)


## The steam gauge's green band, as shares of the gauge.
static func steam_band(q := 1.0) -> Vector2:
	return Vector2(STEAM_LOW, minf(0.97, STEAM_LOW + (STEAM_HIGH - STEAM_LOW) * q))


## Lifting the lid at `frac` of the gauge (1.0 or more: left too long).
static func steam(frac: float, q := 1.0) -> String:
	var band := steam_band(q)
	if frac >= STEAM_OVER:
		return "bad"
	if frac < band.x:
		return "bad"
	return "good" if frac <= band.y else "plain"
