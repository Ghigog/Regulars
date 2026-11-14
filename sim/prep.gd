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
