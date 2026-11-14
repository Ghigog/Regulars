class_name Prep
extends RefCounted
## Scoring for the prep minigames: every one ends good, plain or bad (heat tools can
## also spoil). Pure: the widgets in game/ only show it.

const GOOD := 1.0    # tunable: the quality each result gives an ingredient
const PLAIN := 0.75
const BAD := 0.45
## Grill and fryer timing, in seconds on the heat at tier 1 (a higher tier runs faster).
const GRILL_NEARLY := 2.4   # before this it is still raw: taking it off changes nothing
const GRILL_DONE := 4.0     # underdone (plain) until here
const GRILL_PERFECT := 7.5  # good until here, then it dries out (plain, falling)
const GRILL_BURN := 12.0    # spoiled


static func quality_of(result: String) -> float:
	return {"good": GOOD, "plain": PLAIN, "bad": BAD}.get(result, 0.0)


## What taking a piece off the grill after `t` seconds gives: {state, result, quality}.
## state is "raw" (nothing happened), "prep" or "burnt"; result is "", "good",
## "plain" or "spoiled". Drying out keeps a smooth curve from plain down to bad.
static func grill(t: float) -> Dictionary:
	if t < GRILL_NEARLY:
		return {"state": "raw", "result": "", "quality": 0.0}
	if t < GRILL_DONE:
		return {"state": "prep", "result": "plain", "quality": PLAIN}
	if t <= GRILL_PERFECT:
		return {"state": "prep", "result": "good", "quality": GOOD}
	if t < GRILL_BURN:
		return {"state": "prep", "result": "plain",
			"quality": lerpf(PLAIN, BAD, (t - GRILL_PERFECT) / (GRILL_BURN - GRILL_PERFECT))}
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
## Tools that give no burst or penalty, whatever happens.
const NO_REWARD: Array[String] = ["boil", "none"]


## What lifting the basket after `t` seconds gives: {state, result, quality}. The
## smooth curve of the grill is kept: early and late fall from plain toward bad.
static func fry(t: float) -> Dictionary:
	if t < FRY_MIN:
		return {"state": "raw", "result": "", "quality": 0.0}
	if t < FRY_GOOD:
		return {"state": "prep", "result": "plain", "quality": PLAIN}
	if t <= FRY_LATE:
		return {"state": "prep", "result": "good", "quality": GOOD}
	if t < FRY_BURN:
		return {"state": "prep", "result": "plain",
			"quality": lerpf(PLAIN, BAD, (t - FRY_LATE) / (FRY_BURN - FRY_LATE))}
	return {"state": "burnt", "result": "spoiled", "quality": 0.0}


## Boiling: done or not; once done it is always plain.
static func boil(t: float) -> Dictionary:
	if t < BOIL_TIME:
		return {"state": "raw", "result": "", "quality": 0.0}
	return {"state": "prep", "result": "plain", "quality": PLAIN}


## Whether a press with the marker at `pos` (0 to 1 along the bar) hits the notch.
static func chop_hit(pos: float) -> bool:
	return absf(pos - 0.5) <= CHOP_NOTCH


## Three sweeps: all three in the notch is good, two plain, one or none bad.
static func chop(hits: int) -> String:
	if hits >= CHOP_SWEEPS:
		return "good"
	return "plain" if hits == CHOP_SWEEPS - 1 else "bad"


## Exactly the count in time is good; one to three over plain; more, or short of
## the count when the timer ends, bad.
static func slice(presses: int) -> String:
	if presses < SLICE_COUNT:
		return "bad"
	if presses == SLICE_COUNT:
		return "good"
	return "plain" if presses - SLICE_COUNT <= SLICE_SLACK else "bad"


## Let go at `fill` (0 to 1; over 1 has overflowed).
static func pour(fill: float) -> String:
	if fill > 1.0:
		return "bad"
	if fill >= POUR_GOOD:
		return "good"
	return "plain" if fill >= POUR_PLAIN else "bad"


## "burst", "penalty" or "" for a result with a tool.
static func reward(tool: String, result: String) -> String:
	if NO_REWARD.has(tool):
		return ""
	if result == "good":
		return "burst"
	return "penalty" if result == "bad" or result == "spoiled" else ""
