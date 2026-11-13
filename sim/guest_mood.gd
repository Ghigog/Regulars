class_name GuestMood
extends RefCounted
## The four things we track about every guest, plus what they are thinking.

var patience := 1.0  # drains while queueing or waiting for food
var disgust := 0.0   # rises when they can see something gross
var joy := 0.5       # atmosphere, friends, kindness
var savour := 0.0    # how good the food was
var thoughts: Array[String] = []
var discounted := false  # the chef offered half price while they waited
var comped := false      # the chef made the meal free

## A free meal is for a guest who is very unhappy: nearly out of patience, or disgusted.
const COMP_BELOW := 0.25     # patience below which a free meal can be offered
const COMP_PATIENCE := 0.6   # patience a free meal buys back (half price: 0.35)
const COMP_JOY := 0.25       # joy it adds (half price: 0.1)
const COMP_CALM := 0.2       # disgust it takes away: they forgive a little


func think(t: String) -> bool:
	if thoughts.has(t):
		return false
	thoughts.append(t)
	return true


func latest_thought() -> String:
	return "" if thoughts.is_empty() else thoughts[-1]


func wait(delta: float, seconds_to_snap: float) -> void:
	patience = maxf(0.0, patience - delta / seconds_to_snap)


const NOTICE := 0.005   # disgust per second below which a guest has not really noticed

## Disgust does nothing until it crosses a threshold. Three stages, each worse:
##   1 Ick        they wince, enjoy the visit less and tip less
##   2 Disgusted  they also tell their friends, and think less of the place
##   3 Revolted   they also never come back
const DISGUST_STAGES: Array[float] = [0.2, 0.45, 0.75]
const DISGUST_NAMES: Array[String] = ["", "Ick", "Disgusted", "Revolted"]
const DISGUST_ICONS: Array[String] = ["", "ick", "gross", "stink"]


func disgust_level() -> int:
	var level := 0
	for t in DISGUST_STAGES:
		if disgust >= t:
			level += 1
	return level


## The disgust that counts: none at all below the first stage.
func felt_disgust() -> float:
	return disgust if disgust_level() > 0 else 0.0

## How fast something nasty disgusts, per second. Every source follows one rule: it
## starts at `base`, doubles every `doubling` seconds of `age`, and tops out at `cap`.
## So a fresh plate is nothing and an old one is foul; rubbish goes from bad to awful fast.
static func gross_rate(base: float, age: float, doubling: float, cap: float) -> float:
	return minf(cap, base * pow(2.0, maxf(0.0, age) / doubling))


func see_gross(strength: float, delta: float, thought: String) -> void:
	disgust = minf(1.0, disgust + strength * delta)
	if strength >= NOTICE:   # they notice at once; it only starts to matter at the first stage
		think(thought)


func delight(amount: float, thought := "") -> void:
	joy = clampf(joy + amount, 0.0, 1.0)
	if thought != "":
		think(thought)


## An apology for the wait: half price. Buys back some patience and goodwill, once.
func offer_discount() -> bool:
	if discounted:
		return false
	discounted = true
	patience = minf(1.0, patience + 0.35)
	delight(0.1, "Half price? That's decent of them")
	return true


## Upset enough that a free meal is the right apology.
func very_unhappy() -> bool:
	return patience < COMP_BELOW or disgust_level() >= 2


## The bigger apology: the meal is on the house. Once per visit, only when very unhappy.
func offer_comp() -> bool:
	if comped or not very_unhappy():
		return false
	comped = true
	patience = minf(1.0, patience + COMP_PATIENCE)
	disgust = maxf(0.0, disgust - COMP_CALM)
	delight(COMP_JOY, "On the house? That's really kind")
	return true


## What they pay for a meal with this list price.
func bill_for(price: int) -> int:
	if comped:
		return 0
	return ceili(price / 2.0) if discounted else price


func taste(quality: float) -> void:
	savour = clampf(quality, 0.0, 1.0)
	joy = clampf(joy + 0.15 * savour, 0.0, 1.0)


func walked_out() -> bool:
	return patience <= 0.0


## How they feel right now, for the dot above their head: "joy", "meh" or "mad".
func face() -> String:
	var live := 0.5 * patience + 0.5 * joy - felt_disgust()
	if live > 0.6:
		return "joy"
	return "meh" if live > 0.3 else "mad"


## Which of the eight faces to wear (style guide, sheet 3).
func expression(eating := false, stormed := false) -> String:
	if stormed:
		return "angry"
	if eating:
		return "chewing"
	if disgust_level() >= 2:
		return "disgusted"
	if patience < 0.15:
		return "snap"
	if patience < 0.35:
		return "impatient"
	if joy > 0.75:
		return "delighted"
	# Most people, most of the time, look pleasant.
	return "content" if joy > 0.4 else "neutral"


## Final verdict on the visit, from -1 (furious) to 1 (delighted).
func satisfaction() -> float:
	return clampf(0.35 * savour + 0.3 * joy + 0.2 * patience - 0.5 * felt_disgust(), -1.0, 1.0)


func tip_for(bill: int, bonus := 1.0) -> int:
	return roundi(bill * clampf(satisfaction(), 0.0, 1.0) * 0.6 * bonus)
