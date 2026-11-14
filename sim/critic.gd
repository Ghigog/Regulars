class_name Critic
extends RefCounted
## The food critic (PRD 2). One townsperson, the same all run, eats as a critic every
## fifth day. They rate speed, cleanliness, food quality and variety, give stars out of
## five, and the review in the paper replaces what the town thinks on those four things
## and moves the crowd for the next few days. Pure: the game feeds in what happened.

const TOPICS: Array[String] = ["speed", "clean", "quality", "variety"]
const TOPIC_WORDS := {"speed": "Speed", "clean": "Cleanliness", "quality": "Food", "variety": "Variety"}
const EVERY := 5                  # they visit on days 5, 10, 15 ...
## Speed: their patience when the tray arrives. At or above each step earns 5, 4, 3, 2.
const SPEED_STEPS: Array[float] = [0.85, 0.7, 0.5, 0.3]   # tunable
const NOTICED := 0.02             # tunable: disgust below this means they noticed nothing
const VARIETY_WIDE := 3           # tunable: items in one course for the "wide course" point
const VARIETY_INGREDIENTS := 8    # tunable: distinct ingredients for the last point
const WALKOUT_CAP := 2            # tunable: the most stars a walkout can earn
const RESET_STEP := 0.1           # tunable: opinion per star above or below 3 after a review
const AGREE_GAP := 0.05           # tunable: gap below which the town and the critic agree
## Extra visit chance for the days after a review, by stars (index = stars).
const BOOST: Array[float] = [0.0, -0.25, -0.10, 0.0, 0.10, 0.25]   # tunable
const BOOST_DAYS := 4             # tunable: days the boost lasts
const MIDDLE := Vector2(0.25, 0.75)   # they arrive in the middle half of the day

const HEADLINES: Array[String] = [
	"",
	"AVOID AT ALL COSTS",
	"A DISAPPOINTING SUPPER",
	"FAIR FARE, NO FUSS",
	"A FINE TABLE IN TOWN",
	"A TRIUMPH ON THE HIGH STREET",
]
## What the town calls each topic, inside a sentence.
const TOPIC_NOUNS := {"speed": "the service", "clean": "the washing-up", "quality": "the cooking",
	"variety": "the menu"}
## [topic][good] when the critic agrees with the town, and [topic][good] when they do not.
const AGREE := {
	"speed": ["As the town already says, you will wait for your supper.",
		"As the town already says, the food comes out quick as a wink."],
	"clean": ["As the town already says, the place could do with a scrub.",
		"As the town already says, you could eat off the floor."],
	"quality": ["As the town already says, the cooking is not up to much.",
		"As the town already says, the cooking is first rate."],
	"variety": ["As the town already says, the menu is thin.",
		"As the town already says, there is something on the menu for everyone."],
}
const CONTRADICT := {
	"speed": ["The town may praise the service, but we waited and waited.",
		"Whatever you have heard about the wait, our supper came quickly."],
	"clean": ["The town may call it spotless, but we saw otherwise.",
		"Whatever you have heard about the washing-up, we found it spotless."],
	"quality": ["The town may rave about the cooking, but ours was a let-down.",
		"Whatever you have heard about the cooking, ours was a delight."],
	"variety": ["The town may like the menu, but we found little to choose from.",
		"Whatever you have heard about the menu, we found plenty to choose from."],
}
## The critic's own thoughts, in the usual log. A sharp player can spot them.
const THOUGHTS := {
	"menu": "Let's see what this menu has to say",
	"gross": "Making a note of that sink",
	"wait": "Noted: the wait",
	"good": "Hm. Writing that down. Favourably",
	"bad": "Hm. Writing that down",
	"leave": "That's my column written",
}

var critic_idx := 0
var next_visit := EVERY
var known := false               # true once a review has named them
var last_review := {}            # the latest review, for the town book
var _boost := 0.0
var _boost_from := 0
var _boost_to := -1              # last day the boost applies
var _rng := RandomNumberGenerator.new()


## Picks the critic from a town of `people` with the run's seed.
func _init(seed_value := 1, people := Town.NAMES.size()) -> void:
	_rng.seed = hash("critic:%d" % seed_value)
	critic_idx = _rng.randi_range(0, people - 1)


## Whether the critic comes on `day`.
func visits_on(day: int) -> bool:
	return day == next_visit


## The door closed before they arrived: they come tomorrow instead.
func postpone(day: int) -> void:
	if day == next_visit:
		next_visit = day + 1


## When they arrive, in seconds, on a day `length` seconds long: the middle half.
func arrival_time(length: float) -> float:
	return length * lerpf(MIDDLE.x, MIDDLE.y, _rng.randf())


## The extra visit chance a review gives on `day`. Stacks with flyers.
func visit_boost(day: int) -> float:
	return _boost if day >= _boost_from and day <= _boost_to else 0.0


## What the critic orders: what anyone would, or failing that the best match the menu
## has (most liked, fewest disliked ingredients). They are never turned away.
static func order(available: Array, likes: Array, dislikes: Array, rng: RandomNumberGenerator) -> Dictionary:
	var o := Menu.order(available, likes, dislikes, rng)
	if not o.main.is_empty():
		return o
	var best := {}
	var best_score := -INF
	for it: Dictionary in available:
		if it.course != "main":
			continue
		var score := Menu.liked_count(it.ingredients, likes) - Menu.liked_count(it.ingredients, dislikes)
		if score > best_score:
			best_score = score
			best = it
	return {"main": best, "side": Menu.pick("side", available, likes, dislikes, rng, true),
		"drink": Menu.pick("drink", available, likes, dislikes, rng, true)}


# ---------------------------------------------------------------- ratings

static func speed_rating(patience: float) -> int:
	for k in SPEED_STEPS.size():
		if patience >= SPEED_STEPS[k] - 0.0001:
			return 5 - k
	return 1


## From the disgust they felt when they left and its stage (GuestMood.disgust_level).
static func clean_rating(disgust: float, level: int) -> int:
	if level == 0:
		return 5 if disgust < NOTICED else 4
	return 4 - level


## The tray's average quality, 0 to 1, mapped evenly onto 1 to 5.
static func quality_rating(quality: float) -> int:
	return clampi(1 + roundi(clampf(quality, 0.0, 1.0) * 4.0), 1, 5)


## From tonight's menu: a point per course with an item, one for a course of three or
## more, one for eight or more different ingredients. At least 1.
static func variety_rating(available: Array) -> int:
	var per_course := {}
	var ings := {}
	for it: Dictionary in available:
		per_course[it.course] = int(per_course.get(it.course, 0)) + 1
		for ing: String in it.ingredients:
			ings[ing] = true
	var points := mini(per_course.size(), 3)
	if per_course.values().any(func(n: int) -> bool: return n >= VARIETY_WIDE):
		points += 1
	if ings.size() >= VARIETY_INGREDIENTS:
		points += 1
	return clampi(points, 1, 5)


## All four ratings from one visit. `patience` is theirs as the tray arrived, `quality`
## the tray's (negative if they never ate), `disgust` and `level` as they left.
## A walkout (out of patience, or revolted) rates speed 1.
static func rate(patience: float, quality: float, disgust: float, level: int, available: Array,
		walked_out: bool) -> Dictionary:
	return {
		"speed": 1 if walked_out else speed_rating(patience),
		"clean": clean_rating(disgust, level),
		"quality": quality_rating(quality) if quality >= 0.0 else 1,
		"variety": variety_rating(available),
	}


## The mean of the four, rounded; at most WALKOUT_CAP after a walkout.
static func stars(ratings: Dictionary, walked_out := false) -> int:
	var sum := 0.0
	for t in TOPICS:
		sum += int(ratings[t])
	var s := clampi(roundi(sum / TOPICS.size()), 1, 5)
	return mini(s, WALKOUT_CAP) if walked_out else s


## The opinion everyone holds on a topic after a review with `rating`.
static func opinion_for(rating: int) -> float:
	return (rating - 3) * RESET_STEP


## The confirm-or-contradict line: the topic where the town's average opinion is
## furthest from the rating; if they all agree, the most striking rating.
static func verdict_line(ratings: Dictionary, averages: Dictionary) -> String:
	var topic := ""
	var gap := 0.0
	for t in TOPICS:
		var g := opinion_for(int(ratings[t])) - float(averages.get(t, 0.0))
		if absf(g) > absf(gap) + 0.0001:
			topic = t
			gap = g
	if topic != "" and absf(gap) >= AGREE_GAP:
		return CONTRADICT[topic][1 if gap > 0.0 else 0]
	var strongest := TOPICS[0]
	for t in TOPICS:
		if absi(int(ratings[t]) - 3) > absi(int(ratings[strongest]) - 3):
			strongest = t
	return AGREE[strongest][1 if int(ratings[strongest]) >= 3 else 0]


## Prints the review: works out the line against what the town thinks, resets the four
## topics for everyone, starts the visit boost, names the critic and books the next
## visit. Returns the review: {day, name, ratings, stars, walked_out, headline, line, first}.
func publish(ratings: Dictionary, walked_out: bool, town: Town, day: int) -> Dictionary:
	var s := stars(ratings, walked_out)
	var averages := {}
	for t in TOPICS:
		averages[t] = town.topic_average(t)
	var review := {
		"day": day, "name": town.people[critic_idx].name, "idx": critic_idx,
		"ratings": ratings.duplicate(), "stars": s, "walked_out": walked_out,
		"headline": HEADLINES[s], "line": verdict_line(ratings, averages), "first": not known,
	}
	var opinions := {}
	for t in TOPICS:
		opinions[t] = opinion_for(int(ratings[t]))
	town.reset_topics(opinions)
	_boost = BOOST[s]
	_boost_from = day + 1
	_boost_to = day + BOOST_DAYS
	known = true
	last_review = review
	next_visit = (day / EVERY + 1) * EVERY
	return review


## A thought of the critic's own for `kind` (see THOUGHTS).
static func thought(kind: String) -> String:
	return str(THOUGHTS.get(kind, ""))
