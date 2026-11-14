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


## Comfort: how they feel about the room and the service, from 0 to 1. Read once,
## when the food arrives, and kept in `served_comfort` so the bill and the stay agree.
## Savour is left out on purpose: comfort is about the place, not the dish.
const COMFORT_JOY := 0.6        # tunable
const COMFORT_PATIENCE := 0.4   # tunable
const BILL_LOW := 0.90    # tunable: bill scale at comfort 0 ("let's eat and go")
const BILL_HIGH := 1.25   # tunable: bill scale at comfort 1 ("they ordered extras")
const STAY_LOW := 0.80    # tunable: eating-time scale at comfort 0
const STAY_HIGH := 1.50   # tunable: eating-time scale at comfort 1
const COSY_FROM := 0.75   # comfort at and above which they say they could stay all day
const HURRIED_BELOW := 0.3  # comfort at and below which they want to eat and go
const COSY_THOUGHTS: Array[String] = ["I could stay here all day", "So cosy in here", "Maybe a little extra, then"]
const HURRIED_THOUGHTS: Array[String] = ["Let's eat and go", "Quick bite, then out", "Not lingering here"]

var served_comfort := -1.0   # below 0 until the food has arrived


func comfort() -> float:
	return clampf(COMFORT_JOY * joy + COMFORT_PATIENCE * patience - felt_disgust(), 0.0, 1.0)


## Called as the food lands on the table. Returns the thought it prompts, or "".
## `pick` chooses among the written variants (the caller passes something stable).
func settle_comfort(pick := 0) -> String:
	served_comfort = comfort()
	if served_comfort >= COSY_FROM:
		return COSY_THOUGHTS[pick % COSY_THOUGHTS.size()]
	if served_comfort <= HURRIED_BELOW:
		return HURRIED_THOUGHTS[pick % HURRIED_THOUGHTS.size()]
	return ""


## The comfort that counts for pay and stay: fixed at serving, or the live value before.
func pay_comfort() -> float:
	return served_comfort if served_comfort >= 0.0 else comfort()


static func bill_scale(c: float) -> float:
	return lerpf(BILL_LOW, BILL_HIGH, clampf(c, 0.0, 1.0))


static func stay_scale(c: float) -> float:
	return lerpf(STAY_LOW, STAY_HIGH, clampf(c, 0.0, 1.0))


## The list price scaled by their mood: whole money, at least 1.
func scaled_price(price: int) -> int:
	return maxi(1, roundi(price * bill_scale(pay_comfort())))


## The whole bill: base price, then the mood scale, then half price or free meal.
## Every caller goes through here, so a menu only changes the base price.
func pay_for(price: int) -> int:
	return bill_for(scaled_price(price))


## True when they paid the full (mood-scaled) price, with no deal.
func paid_full() -> bool:
	return not (discounted or comped)


## What they pay with this price after deals (half price, free meal) only.
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
