class_name GuestMood
extends RefCounted
## The four things we track about every guest, plus what they are thinking.

var patience := 1.0  # drains while queueing or waiting for food
var reached_ick := false   # once Ick, disgust never fades below it: they remember
var disgust := 0.0   # rises when they can see something gross
var joy := 0.5       # atmosphere, friends, kindness
var savour := 0.0    # how good the food was
var thoughts: Array[String] = []
var discounted := false  # the chef offered half price while they waited
var comped := false      # the chef made the meal free
var skipped_bill := false  # ran out of patience waiting to pay, and left without (PRD 11)

## Paying (PRD 11). Waiting for the bill drains patience slower than waiting for food.
const PAY_GRACE := 35.0   # tunable: seconds a guest waits for the bill, whatever patience is left
var _pay_grace_given := false
const PAY_TABLE_SLOWER := 3.5   # tunable: seated at the table they wait this much longer for the bill than at the till
const PAY_PATIENCE_SCALE := 1.5   # tunable: seconds to snap, as a multiple of the table's
const WRONG_BILL_JOY := 0.1       # tunable: joy lost when handed a wrong bill

## A free meal is for a guest who is very unhappy: nearly out of patience, or disgusted.
const COMP_BELOW := 0.25     # patience below which a free meal can be offered
const COMP_PATIENCE := 0.6   # patience a free meal buys back (half price: 0.35)
const COMP_JOY := 0.25       # joy it adds (half price: 0.1)
const COMP_CALM := 0.2       # disgust it takes away: they forgive a little

# ---------------------------------------------------------------- tolerances (PRD 10.1)
## How much a guest minds each topic, 1 to 5 (low means they care), from Town. A 3 is
## today's guest exactly. Each topic's effect is scaled: food the joy from the food,
## service how fast patience drains, clean how fast disgust rises.
const TOL_TOPICS: Array[String] = ["food", "service", "clean"]
const TOL_FUSSY_SCALE := 1.6   # tunable: effect at tolerance 1
const TOL_EASY_SCALE := 0.4    # tunable: effect at tolerance 5 (3 is always 1.0)
## A strong reaction, which lets the card hint at the tolerance behind it.
## Each is measured before tolerance, so a fussy and an easy-going guest meet the same event.
const REACT_WAIT := 0.5        # tunable: share of a full patience bar's wait that counts as long
const REACT_FOOD_GOOD := 0.8   # tunable: food quality at or above which it was felt
const REACT_FOOD_POOR := 0.4   # tunable: food quality at or below which it was felt

var tolerance := {"food": 3, "service": 3, "clean": 3}
## Wealth (review, item 3), 1 (poor) to 5 (rich), from Town, read like a tolerance: a
## Dear item on their order costs happiness, PRICEY_HIT each at 3, scaled 1.6 to 0.4.
var wealth := 3
var pricey := 0.0                 # happiness lost to the prices they ordered at
const PRICEY_HIT := 0.08          # tunable: per Dear item, for a guest of middling means
var reacted: Array[String] = []   # topics they have reacted strongly to, in order
var waited := 0.0                 # waiting so far, as a share of a full bar at tolerance 3

## Hint lines for the card, by topic: [fussy (1-2), easy-going (4-5)]. No numbers shown.
const TOL_HINTS := {
	"food": ["Fussy about the food", "Not fussy about food"],
	"service": ["Hates to wait", "Happy to wait"],
	"clean": ["Can't stand a mess", "Doesn't mind a mess"],
	"wealth": ["Watches the pennies", "Money's no object"],
}
## What they think as the hint is revealed, by topic: [fussy, easy-going].
const TOL_THOUGHTS := {
	"food": ["I'm particular about my food", "Food's food, I'm not fussy"],
	"service": ["I hate waiting around", "No rush, I've got all day"],
	"clean": ["I can't stand a mess", "A bit of mess never hurt anyone"],
	"wealth": ["Pricey for what it is", "Treat yourself, I say"],
}


## The effect scale for a tolerance: 1.6 at 1, 1.0 at 3, 0.4 at 5, straight lines between.
static func tolerance_scale(tol: int) -> float:
	var t := clampi(tol, 1, 5)
	if t <= 3:
		return lerpf(TOL_FUSSY_SCALE, 1.0, (t - 1) / 2.0)
	return lerpf(1.0, TOL_EASY_SCALE, (t - 3) / 2.0)


## From the seat (Seating): anger (service) and disgust (clean) hit harder above 1.0.
var seat_tolerance := 1.0
## From the seat: a factor on the tip.
var seat_tip := 1.0


func scale_for(topic: String) -> float:
	var s := tolerance_scale(_tol(topic))
	return s * seat_tolerance if topic == "service" or topic == "clean" else s


## A topic's tolerance, wealth included (poor reads as fussy, rich as easy-going).
func _tol(topic: String) -> int:
	return wealth if topic == "wealth" else int(tolerance.get(topic, 3))


## They read their order's prices: `dear` items at the Dear level. Each costs happiness,
## more for a poorer guest; the first time they think a line that hints at their means.
## Returns the happiness lost.
func read_prices(dear: int) -> float:
	pricey = 0.0
	if dear <= 0:
		return 0.0
	pricey = PRICEY_HIT * dear * scale_for("wealth")
	react("wealth")
	if wealth == 3:
		think(TOL_THOUGHTS.wealth[0])   # anyone notices a dear bill
	return pricey


## Notes a strong reaction to `topic`. The first time, for a guest who is not middling
## about it, they think a line that hints at their tolerance. Returns that line or "".
func react(topic: String) -> String:
	if reacted.has(topic):
		return ""
	reacted.append(topic)
	var tol := _tol(topic)
	if tol == 3:
		return ""
	var line: String = TOL_THOUGHTS[topic][0 if tol < 3 else 1]
	think(line)
	return line


## The card's hint lines, in the order they were revealed. Middling topics give none.
func tolerance_hints() -> Array[String]:
	var out: Array[String] = []
	for topic in reacted:
		var tol := _tol(topic)
		if tol != 3:
			out.append(TOL_HINTS[topic][0 if tol < 3 else 1])
	return out


func think(t: String) -> bool:
	if thoughts.has(t):
		return false
	thoughts.append(t)
	return true


func latest_thought() -> String:
	return "" if thoughts.is_empty() else thoughts[-1]


func wait(delta: float, seconds_to_snap: float) -> void:
	patience = maxf(0.0, patience - delta / seconds_to_snap * scale_for("service"))
	waited += delta / seconds_to_snap
	if waited >= REACT_WAIT:
		react("service")


const NOTICE := 0.005   # disgust per second below which a guest has not really noticed

## Disgust does nothing until it crosses a threshold. Three stages, each worse:
##   1 Ick        they wince, enjoy the visit less and tip less
##   2 Disgusted  they also tell their friends, and think less of the place
##   3 Revolted   they also never come back
const DISGUST_STAGES: Array[float] = [0.2, 0.45, 0.75]
## Disgust halves about every this many seconds while nothing gross is in view. (tunable)
const DISGUST_HALF_LIFE := 20.0
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


## Disgust passes when nothing gross is in view: it halves every DISGUST_HALF_LIFE, but a
## guest who has been Ick keeps at least that much.
func fade(delta: float) -> void:
	var floor_to := DISGUST_STAGES[0] if reached_ick else 0.0
	if disgust > floor_to:
		disgust = maxf(floor_to, disgust * pow(0.5, delta / DISGUST_HALF_LIFE))


func see_gross(strength: float, delta: float, thought: String) -> void:
	var felt := strength * scale_for("clean")
	disgust = minf(1.0, disgust + felt * delta)
	if disgust >= DISGUST_STAGES[0]:
		reached_ick = true
	if felt >= NOTICE:   # they notice at once; it only starts to matter at the first stage
		think(thought)
	if strength >= NOTICE:   # a mess anyone would see: an easy-going guest shrugs it off
		react("clean")


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


## One happiness score (review, item 5): satisfaction() drives the bill scale, the
## eating time, the tip and the opinion. Comfort is that same score out of the most it
## can reach (HAPPY_FULL), 0 to 1, read once as the food lands (after the first taste)
## and kept in `served_comfort` so the bill and the stay agree.
const HAPPY_FULL := 0.85        # satisfaction with perfect food, joy and patience
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
	return clampf(satisfaction() / HAPPY_FULL, 0.0, 1.0)


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
	joy = clampf(joy + 0.15 * savour * scale_for("food"), 0.0, 1.0)
	if savour >= REACT_FOOD_GOOD or savour <= REACT_FOOD_POOR:
		react("food")


func walked_out() -> bool:
	return patience <= 0.0


## Waiting to pay (PRD 11): patience runs at `PAY_PATIENCE_SCALE` of the table's, and
## `PAY_TABLE_SLOWER` times slower again while still `seated` (at the till it is not).
## Running out means they leave without paying: `skipped_bill`, not a walkout strike.
func wait_to_pay(delta: float, table_seconds: float, seated: bool) -> void:
	var seconds_to_snap := table_seconds * PAY_PATIENCE_SCALE * (PAY_TABLE_SLOWER if seated else 1.0)
	if not _pay_grace_given:
		_pay_grace_given = true
		patience = maxf(patience, minf(1.0, PAY_GRACE * scale_for("service") / seconds_to_snap))
	wait(delta, seconds_to_snap)
	if walked_out():
		skipped_bill = true


## Handed a bill that is wrong: they refuse it, a little less happy, and say why.
func refuse_bill(line: String) -> void:
	joy = clampf(joy - WRONG_BILL_JOY, 0.0, 1.0)
	thoughts.erase(line)   # said again if it happens again
	think(line)


## How they feel right now, for the dot above their head: "joy", "meh" or "mad".
func face() -> String:
	var live := 0.5 * patience + 0.5 * joy - felt_disgust()
	if live > 0.6:
		return "joy"
	return "meh" if live > 0.3 else "mad"


## How they feel, each feeling on its own so they can show together: anger 0-1 (a light
## flush once impatient, 0.75 at the snap, 1.0 when stormed out), disgust as its stage 0-3,
## delight 0-1 (only while neither angry nor disgusted).
const ANGER_FLUSH := 0.35   # tunable: anger the moment they turn impatient
const ANGER_SNAP := 0.75    # tunable: anger as patience reaches the snap point
const ANGER_EMPTY := 0.95   # tunable: anger at no patience at all
const DELIGHT_FROM := 0.75  # joy above which they glow


func feelings(stormed := false) -> Dictionary:
	var anger := 0.0
	if stormed:
		anger = 1.0
	elif patience < 0.15:
		anger = lerpf(ANGER_SNAP, ANGER_EMPTY, (0.15 - patience) / 0.15)
	elif patience < 0.35:
		anger = lerpf(ANGER_FLUSH, ANGER_SNAP, (0.35 - patience) / 0.2)
	var stage := disgust_level()
	var glow := 0.0
	if joy > DELIGHT_FROM and anger == 0.0 and stage == 0:
		glow = (joy - DELIGHT_FROM) / (1.0 - DELIGHT_FROM)
	return {"anger": anger, "disgust": stage, "delight": glow}


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
	return clampf(0.35 * savour + 0.3 * joy + 0.2 * patience - 0.5 * felt_disgust() - pricey, -1.0, 1.0)


## The parts of satisfaction() that belong to a topic (Town.TOPICS), for filing the
## visit's change in opinion. `tray_quality` is the tray's own quality: savour above
## it came from liked things on the menu, so it counts as variety. Joy is left out
## (it is `other`).
func satisfaction_terms(tray_quality := -1.0) -> Dictionary:
	var food := savour if tray_quality < 0.0 else minf(savour, tray_quality)
	return {"speed": 0.2 * patience, "clean": -0.5 * felt_disgust(),
		"quality": 0.35 * food, "variety": 0.35 * (savour - food)}


func tip_for(bill: int, bonus := 1.0) -> int:
	return roundi(bill * clampf(satisfaction(), 0.0, 1.0) * 0.6 * bonus * seat_tip)
