class_name Staff
extends RefCounted
## Staff (PRD 10, sections 3 to 8): job posts, who applies, the CV pile, hiring and
## haggling, wages, satisfaction, breaks, days off and the five-day week, chat, training
## and firing. Pure: duties are plain ids it is given (it never reads the room), and
## townspeople come in as plain dictionaries (tolerances, rating, how much they like the
## restaurant). What it does to the town (an opinion drop, a changed tolerance) is
## returned for the caller to apply.
##
## A person is keyed by their town index. Skill in a kind is 6 minus their tolerance in
## that topic, kept as a float here so training can raise it a little at a time.

## The three kinds of duty, named by the tolerance topic they use.
const KINDS: Array[String] = ["food", "service", "clean"]
const KIND_WORDS := {"food": "Cooking", "service": "Serving", "clean": "Cleaning"}

## Every duty the game knows: its kind and how heavy it is (coins a day it adds to the
## asking wage, before `DUTY_SHARE`). Heavier duties are worth more: mop over sponge,
## fryer over board. Others can be added with `register_duty`. All weights tunable.
const DUTIES := {
	# Cooking: one per prep tool kind, plus fetching and assembling.
	"grill": {"kind": "food", "weight": 4.0},
	"fryer": {"kind": "food", "weight": 4.0},
	"pot": {"kind": "food", "weight": 3.0},
	"board": {"kind": "food", "weight": 2.0},
	"slicer": {"kind": "food", "weight": 2.0},
	"tap": {"kind": "food", "weight": 1.0},
	# PRD 8.6's new jobs, one duty per tool.
	"grater": {"kind": "food", "weight": 2.0},
	"bread_knife": {"kind": "food", "weight": 2.0},
	"juicer": {"kind": "food", "weight": 2.0},
	"blender": {"kind": "food", "weight": 3.0},
	"steamer": {"kind": "food", "weight": 3.0},
	"fetch": {"kind": "food", "weight": 1.0},
	"assemble": {"kind": "food", "weight": 2.0},
	# Serving.
	"take_orders": {"kind": "service", "weight": 2.0},
	"carry_trays": {"kind": "service", "weight": 3.0},
	"clear_tables": {"kind": "service", "weight": 2.0},
	"help_up": {"kind": "service", "weight": 1.0},
	# Cleaning: one per cleaning tool kind, plus the sink and the bin.
	"mop": {"kind": "clean", "weight": 4.0},
	"sponge": {"kind": "clean", "weight": 2.0},
	"scraper": {"kind": "clean", "weight": 3.0},
	"spill_kit": {"kind": "clean", "weight": 2.0},
	"wash_up": {"kind": "clean", "weight": 3.0},
	"empty_bin": {"kind": "clean", "weight": 1.0},
}

# ---------- Posts ----------
const MAX_BREAKS := 3
const MAX_DAYS_OFF := 2

# ---------- Applying ----------
const WEAK_BELOW := 3.0         # a skill under this (1 or 2 stars) is a weak kind
const WEAK_PENALTY := 3.0       # tunable: fit lost per duty in a weak kind
const APPLY_CHANCE := 0.6       # tunable: chance scale; chance = this x fit x like
const MAX_NEW_CVS := 4          # tunable: the most new CVs in one night, all posts together

# ---------- Wages ----------
const WAGE_BASE := 5.0          # tunable: coins a day per star of rating
const DUTY_SHARE := 1.0         # tunable: share of each duty's weight added to the ask

# ---------- Satisfaction ----------
const TARGET_AT_PAR := 0.6      # tunable: target when paid exactly what the work is worth to them
const WEAK_DUTY_FACTOR := 2.0   # a duty in a weak kind counts double toward what it is worth
const BREAK_ADD := 0.05         # tunable: target added per break a day
const DAY_OFF_ADD := 0.1        # tunable: target added per day off a week (more than a break)
const SAT_STEP := 0.35          # tunable: share of the gap to the target closed each night
const UNPAID_HIT := 0.4         # satisfaction lost when a night's wage cannot be paid
const BOTTOM := 0.2             # the bottom fifth
const QUIT_NIGHTS := 3          # tunable: nights in a row at the bottom before they quit
const VISIT_FROM := 0.6         # above this, on a day off they may come in to eat

# ---------- Low satisfaction at work ----------
const LOW_FROM := 0.5           # tunable: below this they start to slow and slip up
const SLOW_MAX := 0.6           # tunable: extra reaction time at 0 satisfaction (1.6x)
const MISTAKE_MAX := 0.3        # tunable: mistake chance at 0 satisfaction
const SPITE_SHARE := 0.3        # tunable: share of mistakes made on purpose

# ---------- Haggling ----------
const HAGGLE_DROP := 3.0        # tunable: chance lost per whole ask below it (10% under = -0.3)
const HAGGLE_LOW_SAT := 0.5     # tunable: acceptance at 0 satisfaction is this share of the full
const HAGGLE_COUNTERS := 2      # refused counters before they decide
const TAKE_LAST_FROM := 0.5     # at or above this satisfaction they take the last offer, else walk
const ACCEPT_DUTY_SCALE := 1.0  # tunable: chance to take a new duty = this x satisfaction after

# ---------- Firing ----------
const FIRE_DROP := 0.1          # tunable: opinion lost when fired with severance
const FIRE_DROP_HARSH := 0.3    # tunable: opinion lost when fired without
const FIRE_FRIEND_SHARE := 0.5  # tunable: share of a harsh firing their friends hear about

# ---------- The week, breaks, chat, training ----------
const WEEK := 5
const BREAK_SECONDS := 8.0      # tunable: a break in game seconds
const CHAT_SHARE := 0.05        # tunable: share of the gap closed per second of chat
const TRAIN_PER_TASK := 0.02    # tunable: skill gained per task done in that kind

var rng := RandomNumberGenerator.new()
var posts: Dictionary = {}       # post id -> {id, name, duties, breaks, days_off}
var cvs: Array[Dictionary] = []  # the pile, oldest first
var employees: Dictionary = {}   # person -> employee dictionary
var extra_duties: Dictionary = {}   # registered duty id -> {kind, weight}
var _next_post := 1
var _next_cv := 1


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


# ---------- Duties ----------

func register_duty(id: String, kind: String, weight: float) -> void:
	extra_duties[id] = {"kind": kind, "weight": weight}


func _duty(id: String) -> Dictionary:
	if extra_duties.has(id):
		return extra_duties[id]
	return DUTIES.get(id, {"kind": "", "weight": 0.0})


func duty_kind(id: String) -> String:
	return _duty(id).kind


func duty_weight(id: String) -> float:
	return float(_duty(id).weight)


## The kinds a list of duties covers, each once, in KINDS order.
func kinds_of(duties: Array) -> Array[String]:
	var out: Array[String] = []
	for k in KINDS:
		for d in duties:
			if duty_kind(d) == k:
				out.append(k)
				break
	return out


# ---------- Skills ----------

static func skills_from(tolerance: Dictionary) -> Dictionary:
	var s := {}
	for k in KINDS:
		s[k] = 6.0 - float(tolerance.get(k, 3))
	return s


static func is_weak(skills: Dictionary, kind: String) -> bool:
	return float(skills.get(kind, 3.0)) < WEAK_BELOW


## Whole stars for a CV or the staff list.
static func stars(skill: float) -> int:
	return clampi(int(floor(skill + 0.0001)), 1, 5)


# ---------- Posts ----------

## Opens a post (one opening). Refused (-1) when open posts plus hires already fill the desks.
func add_post(post_name: String, duties: Array, breaks: int, days_off: int, desks: int) -> int:
	if not can_post(desks):
		return -1
	var id := _next_post
	_next_post += 1
	var d: Array[String] = []
	for x in duties:
		if not d.has(String(x)):
			d.append(String(x))
	posts[id] = {"id": id, "name": post_name, "duties": d,
		"breaks": clampi(breaks, 0, MAX_BREAKS), "days_off": clampi(days_off, 0, MAX_DAYS_OFF)}
	return id


## Taking a post down also clears its CVs from the pile.
func remove_post(id: int) -> void:
	posts.erase(id)
	cvs = cvs.filter(func(c): return c.post != id)


func seats_used() -> int:
	return posts.size() + employees.size()


func can_post(desks: int) -> bool:
	return seats_used() < desks


## Selling a desk is refused while it would leave a post or a hire without one.
func can_sell_desk(desks: int) -> bool:
	return seats_used() <= desks - 1


# ---------- Applying ----------

## How well someone suits a set of duties, 0 to 1: their skill summed over the kinds the
## duties cover, less `WEAK_PENALTY` for each duty in a kind they are weak at, over the most
## that sum could be.
func fit(skills: Dictionary, duties: Array) -> float:
	var kinds := kinds_of(duties)
	if kinds.is_empty():
		return 0.0
	var sum := 0.0
	for k in kinds:
		sum += float(skills.get(k, 3.0))
	for d in duties:
		var k := duty_kind(d)
		if k != "" and is_weak(skills, k):
			sum -= WEAK_PENALTY
	return clampf(sum / (5.0 * kinds.size()), 0.0, 1.0)


func apply_chance(skills: Dictionary, like: float, post_id: int) -> float:
	if not posts.has(post_id):
		return 0.0
	return clampf(APPLY_CHANCE * fit(skills, posts[post_id].duties) * clampf(like, 0.0, 1.0), 0.0, 1.0)


## The asking wage a day: `WAGE_BASE` x rating plus a share of each duty's weight.
func asking_wage(rating: int, duties: Array) -> int:
	var w := WAGE_BASE * rating
	for d in duties:
		w += duty_weight(d) * DUTY_SHARE
	return int(round(w))


func has_cv(person: int) -> bool:
	for c in cvs:
		if c.person == person:
			return true
	return false


## The night's applicants. Each candidate is {id, tolerance: {food, service, clean},
## rating, like (0 to 1), away (staying away: a grudge)}. Anyone employed, staying away
## or already in the pile does not apply. Each person tries the open posts in order and
## sends at most one CV; at most `MAX_NEW_CVS` arrive. Returns the new CVs.
func roll_applicants(candidates: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if posts.is_empty():
		return out
	var order := candidates.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var post_ids := posts.keys()
	post_ids.sort()
	for c in order:
		if out.size() >= MAX_NEW_CVS:
			break
		var person := int(c.id)
		if c.get("away", false) or employees.has(person) or has_cv(person):
			continue
		var skills := skills_from(c.get("tolerance", {}))
		for pid in post_ids:
			if rng.randf() < apply_chance(skills, float(c.get("like", 0.0)), pid):
				var cv := _make_cv(person, skills, int(c.get("rating", 3)), float(c.get("like", 0.0)), pid)
				cvs.append(cv)
				out.append(cv)
				break
	return out


func _make_cv(person: int, skills: Dictionary, rating: int, like: float, post_id: int) -> Dictionary:
	var cv := {"id": _next_cv, "person": person, "post": post_id, "skills": skills,
		"rating": rating, "like": like, "ask": asking_wage(rating, posts[post_id].duties),
		"haggle": _new_haggle(asking_wage(rating, posts[post_id].duties))}
	_next_cv += 1
	return cv


func cv(cv_id: int) -> Dictionary:
	for c in cvs:
		if c.id == cv_id:
			return c
	return {}


func dismiss(cv_id: int) -> void:
	cvs = cvs.filter(func(c): return c.id != cv_id)


# ---------- Haggling ----------

func _new_haggle(ask: int) -> Dictionary:
	return {"ask": ask, "refused": 0, "last": 0}


## The chance they accept `offer` against `ask`: falls by `HAGGLE_DROP` per whole ask
## below it, and is lower with low satisfaction.
static func haggle_chance(ask: int, offer: int, satisfaction: float) -> float:
	if offer >= ask:
		return 1.0
	if ask <= 0 or offer <= 0:
		return 0.0
	var gap := float(ask - offer) / float(ask)
	var mood := lerpf(HAGGLE_LOW_SAT, 1.0, clampf(satisfaction, 0.0, 1.0))
	return clampf((1.0 - gap * HAGGLE_DROP) * mood, 0.0, 1.0)


## One counter-offer. Returns "accept", "refuse", "take_last" (they gave up haggling and
## took this offer) or "walk". `h` is updated in place.
func _haggle(h: Dictionary, offer: int, satisfaction: float) -> String:
	h.last = offer
	if rng.randf() < haggle_chance(h.ask, offer, satisfaction):
		return "accept"
	h.refused += 1
	if h.refused < HAGGLE_COUNTERS:
		return "refuse"
	return "take_last" if satisfaction >= TAKE_LAST_FROM else "walk"


# ---------- Hiring ----------

## Hires from a CV at the asking wage (or `wage` when set). The post is filled, so it and
## its other CVs go. Returns the person, or -1.
func hire(cv_id: int, wage := -1, day := 1) -> int:
	var c := cv(cv_id)
	if c.is_empty() or not posts.has(c.post):
		return -1
	var p: Dictionary = posts[c.post]
	var e := {"person": c.person, "post_name": p.name, "duties": p.duties.duplicate(),
		"breaks": p.breaks, "days_off": p.days_off, "wage": c.ask if wage < 0 else wage,
		"skills": c.skills.duplicate(), "rating": c.rating, "satisfaction": 0.0,
		"bottom_nights": 0, "week_off": [] as Array[int], "hired_day": day, "pending": {}}
	employees[c.person] = e
	e.satisfaction = target(c.person)
	remove_post(c.post)
	return c.person


## Haggling at hire: the applicant's satisfaction is how much they like the restaurant.
## On "accept" or "take_last" they are hired at the offer; on "walk" their CV leaves the pile.
func haggle_hire(cv_id: int, offer: int, day := 1) -> String:
	var c := cv(cv_id)
	if c.is_empty():
		return ""
	var r := _haggle(c.haggle, offer, c.like)
	if r == "accept" or r == "take_last":
		hire(cv_id, offer, day)
	elif r == "walk":
		dismiss(cv_id)
	return r


func employee(person: int) -> Dictionary:
	return employees.get(person, {})


# ---------- Pay and satisfaction ----------

## What a set of duties is worth to someone a day: their own base plus each duty's share,
## a duty in a weak kind counting double.
func worth(skills: Dictionary, rating: int, duties: Array) -> float:
	var w := WAGE_BASE * rating
	for d in duties:
		var f := WEAK_DUTY_FACTOR if is_weak(skills, duty_kind(d)) else 1.0
		w += duty_weight(d) * DUTY_SHARE * f
	return w


func _target_for(e: Dictionary, duties: Array, wage: int, breaks: int, days_off: int) -> float:
	var w := worth(e.skills, e.rating, duties)
	var ratio := float(wage) / w if w > 0.0 else 1.0
	return clampf(TARGET_AT_PAR * ratio + breaks * BREAK_ADD + days_off * DAY_OFF_ADD, 0.0, 1.0)


## Where their satisfaction is heading each night.
func target(person: int) -> float:
	var e := employee(person)
	if e.is_empty():
		return 0.0
	return _target_for(e, e.duties, e.wage, e.breaks, e.days_off)


## A change during the day: their own tolerances at work, a slip (PRD 9).
func nudge(person: int, amount: float) -> void:
	var e := employee(person)
	if not e.is_empty():
		e.satisfaction = clampf(e.satisfaction + amount, 0.0, 1.0)


## The end of the night: wages are paid from `cash` in hiring order while it lasts (days
## off are paid). Satisfaction moves toward its target; anyone unpaid takes `UNPAID_HIT`.
## `QUIT_NIGHTS` nights in a row at the bottom fifth and they quit. Returns
## {paid: coins, unpaid: [person], quit: [person]}.
func end_night(cash: int) -> Dictionary:
	var paid := 0
	var unpaid: Array[int] = []
	var quit: Array[int] = []
	for person in employees.keys():
		var e: Dictionary = employees[person]
		e.satisfaction += (target(person) - e.satisfaction) * SAT_STEP
		if cash - paid >= e.wage:
			paid += e.wage
		else:
			unpaid.append(person)
			e.satisfaction -= UNPAID_HIT
		e.satisfaction = clampf(e.satisfaction, 0.0, 1.0)
		if e.satisfaction <= BOTTOM:
			e.bottom_nights += 1
		else:
			e.bottom_nights = 0
		if e.bottom_nights >= QUIT_NIGHTS:
			quit.append(person)
	for person in quit:
		employees.erase(person)
	return {"paid": paid, "unpaid": unpaid, "quit": quit}


func wages_due() -> int:
	var sum := 0
	for e in employees.values():
		sum += e.wage
	return sum


## Satisfaction in a word for the staff list, from the top: at or above each bound.
## The last, "Fed up", is the bottom fifth, where nights count toward quitting.
const MOOD_WORDS := [[0.8, "Happy"], [0.6, "Content"], [0.4, "So-so"], [BOTTOM + 0.0001, "Unhappy"], [-1.0, "Fed up"]]


static func mood_word(satisfaction: float) -> String:
	for m: Array in MOOD_WORDS:
		if satisfaction >= float(m[0]):
			return m[1]
	return "Fed up"


## 0 at `LOW_FROM` satisfaction and above, 1 at none.
static func low_factor(satisfaction: float) -> float:
	return clampf((LOW_FROM - satisfaction) / LOW_FROM, 0.0, 1.0)


## Reaction time multiplier: 1.0 when content, up to 1 + `SLOW_MAX`.
static func slowness(satisfaction: float) -> float:
	return 1.0 + SLOW_MAX * low_factor(satisfaction)


static func mistake_chance(satisfaction: float) -> float:
	return MISTAKE_MAX * low_factor(satisfaction)


## Rolls one task for a mistake: "" (none), "slip" (burnt food, a dropped tray, dirt left
## behind) or "spite" (the same, on purpose).
func roll_mistake(person: int) -> String:
	var e := employee(person)
	if e.is_empty() or rng.randf() >= mistake_chance(e.satisfaction):
		return ""
	return "spite" if rng.randf() < SPITE_SHARE else "slip"


# ---------- Managing staff ----------

## Offering a new duty. They accept with a chance from their satisfaction after the change
## (now, moved by how much the change shifts the target). Returns {ok: true} when taken,
## or {ok: false, raise: coins} naming the raise that would make up for it.
func propose_duty(person: int, duty: String) -> Dictionary:
	var e := employee(person)
	if e.is_empty():
		return {"ok": false, "raise": 0}
	if e.duties.has(duty):
		return {"ok": true}
	var after: Array = e.duties.duplicate()
	after.append(duty)
	var shift := _target_for(e, after, e.wage, e.breaks, e.days_off) - target(person)
	var chance := clampf(ACCEPT_DUTY_SCALE * (e.satisfaction + shift), 0.0, 1.0)
	if rng.randf() < chance:
		e.duties.append(duty)
		return {"ok": true}
	# The wage that keeps the old ratio of pay to worth, at least one coin more.
	var old_ratio := float(e.wage) / worth(e.skills, e.rating, e.duties)
	var needed := int(ceil(old_ratio * worth(e.skills, e.rating, after) - 0.0001))
	var r := maxi(needed - e.wage, 1)
	e.pending = {"duty": duty, "raise": r, "haggle": _new_haggle(e.wage + r)}
	return {"ok": false, "raise": r}


## The player's answer to a named raise: "withdraw" (drop the duty), "approve" (pay it and
## add the duty), "deny" (they quit) or "haggle" with a smaller raise `offer` (section 5,
## on the whole wage). Returns "added", "withdrawn", "refuse" or "quit".
func answer_raise(person: int, choice: String, offer := 0) -> String:
	var e := employee(person)
	if e.is_empty() or e.pending.is_empty():
		return ""
	var p: Dictionary = e.pending
	match choice:
		"withdraw":
			e.pending = {}
			return "withdrawn"
		"approve":
			e.wage += p.raise
			e.duties.append(p.duty)
			e.pending = {}
			return "added"
		"deny":
			employees.erase(person)
			return "quit"
		"haggle":
			var r := _haggle(p.haggle, e.wage + offer, e.satisfaction)
			if r == "refuse":
				return "refuse"
			if r == "walk":
				employees.erase(person)
				return "quit"
			e.wage += offer
			e.duties.append(p.duty)
			e.pending = {}
			return "added"
	return ""


## Removing a duty is free and raises satisfaction: now, by as much as it raises the
## target (the same "after the change" `propose_duty` reads), and so every night after.
func remove_duty(person: int, duty: String) -> void:
	var e := employee(person)
	if e.is_empty() or not e.duties.has(duty):
		return
	var before := target(person)
	e.duties.erase(duty)
	_lift(e, before)


## A break a day more, free; satisfaction rises as `remove_duty`'s does.
func add_break(person: int) -> bool:
	var e := employee(person)
	if e.is_empty() or e.breaks >= MAX_BREAKS:
		return false
	var before := target(person)
	e.breaks += 1
	_lift(e, before)
	return true


## A day off a week more, free; worth more than a break. The days are picked next week.
func add_day_off(person: int) -> bool:
	var e := employee(person)
	if e.is_empty() or e.days_off >= MAX_DAYS_OFF:
		return false
	var before := target(person)
	e.days_off += 1
	_lift(e, before)
	return true


## Satisfaction moves now by as much as the change moved the target.
func _lift(e: Dictionary, target_before: float) -> void:
	e.satisfaction = clampf(e.satisfaction + target(e.person) - target_before, 0.0, 1.0)


## A raise the player gives unasked. Wages are never cut: fire and rehire.
func give_raise(person: int, amount: int) -> void:
	var e := employee(person)
	if not e.is_empty() and amount > 0:
		e.wage += amount


## Firing, with severance (a day's wage) or without. Returns {person, cost, drop,
## friend_drop}: the caller pays the cost and lowers their opinion (and their friends').
func fire(person: int, severance: bool) -> Dictionary:
	var e := employee(person)
	if e.is_empty():
		return {}
	employees.erase(person)
	if severance:
		return {"person": person, "cost": e.wage, "drop": FIRE_DROP, "friend_drop": 0.0}
	return {"person": person, "cost": 0, "drop": FIRE_DROP_HARSH,
		"friend_drop": FIRE_DROP_HARSH * FIRE_FRIEND_SHARE}


# ---------- The week and days off ----------

## Weeks run days 1 to 5, 6 to 10 ... `week_day` is 0 to 4.
static func week_of(day: int) -> int:
	return (day - 1) / WEEK


static func week_day(day: int) -> int:
	return (day - 1) % WEEK


## At the start of each week's first build phase (`day` is the week's first day), everyone
## hired before it picks their days off, at random, never two in a row, avoiding days
## someone else took when they can. Someone hired mid-week starts next week.
func start_week(day: int) -> void:
	var taken := [0, 0, 0, 0, 0]
	var people := employees.keys()
	people.sort()
	for i in range(people.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = people[i]
		people[i] = people[j]
		people[j] = t
	for person in people:
		var e: Dictionary = employees[person]
		e.week_off = [] as Array[int]
		e.week_start = day
		if e.hired_day > day or e.days_off <= 0:
			continue
		var best: Array = []
		var best_clash := 999
		for days in _day_sets(e.days_off):
			var clash := 0
			for d in days:
				clash += taken[d]
			if clash < best_clash:
				best_clash = clash
				best = [days]
			elif clash == best_clash:
				best.append(days)
		var pick: Array = best[rng.randi_range(0, best.size() - 1)]
		for d in pick:
			e.week_off.append(d)
			taken[d] += 1


## Every set of `n` week days (0 to 4) with no two in a row.
static func _day_sets(n: int) -> Array:
	var out := []
	if n == 1:
		for a in WEEK:
			out.append([a])
	elif n == 2:
		for a in WEEK:
			for b in range(a + 2, WEEK):
				out.append([a, b])
	return out


## The first day of the week `day` falls in.
static func week_first(day: int) -> int:
	return week_of(day) * WEEK + 1


## Whether they have picked days off for the week `day` falls in (someone hired mid-week,
## or since the week began, has not: they start next week).
func picked_week(person: int, day: int) -> bool:
	var e := employee(person)
	return not e.is_empty() and e.has("week_start") and week_of(int(e.week_start)) == week_of(day)


## The staff list's week: five {day, off} for the week `day` falls in.
func week_boxes(person: int, day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var first := week_first(day)
	for k in WEEK:
		out.append({"day": first + k, "off": is_day_off(person, first + k)})
	return out


func is_day_off(person: int, day: int) -> bool:
	var e := employee(person)
	if e.is_empty() or not e.has("week_start") or week_of(day) != week_of(e.week_start):
		return false
	return e.week_off.has(week_day(day))


## On a day off, a satisfied employee may come in to eat like any guest.
func may_visit(person: int, day: int) -> bool:
	if not employees.has(person):
		return true
	return is_day_off(person, day) and employees[person].satisfaction > VISIT_FROM


# ---------- Breaks ----------

## When each of `n` breaks starts: `day_length * i / (n + 1)` for i = 1 to n.
static func break_starts(n: int, day_length: float) -> Array[float]:
	var out: Array[float] = []
	for i in range(1, n + 1):
		out.append(day_length * i / (n + 1))
	return out


func on_break(person: int, t: float, day_length: float) -> bool:
	var e := employee(person)
	if e.is_empty():
		return false
	for s in break_starts(e.breaks, day_length):
		if t >= s and t < s + BREAK_SECONDS:
			return true
	return false


# ---------- Chat ----------

## Two helpers chatting for `delta` seconds: their satisfaction moves toward each other's.
func chat(a: int, b: int, delta: float) -> void:
	var ea := employee(a)
	var eb := employee(b)
	if ea.is_empty() or eb.is_empty():
		return
	var f := clampf(CHAT_SHARE * delta, 0.0, 0.5)
	var gap: float = eb.satisfaction - ea.satisfaction
	ea.satisfaction += gap * f
	eb.satisfaction -= gap * f


# ---------- Training ----------

## One task done in a kind raises that skill by `TRAIN_PER_TASK` (to 5). Returns the new
## tolerance (6 minus skill) for the caller to write to the town: the change is permanent.
func train(person: int, kind: String) -> float:
	var e := employee(person)
	if e.is_empty() or not KINDS.has(kind):
		return 0.0
	e.skills[kind] = minf(float(e.skills[kind]) + TRAIN_PER_TASK, 5.0)
	return 6.0 - e.skills[kind]


func tolerance(person: int, kind: String) -> float:
	var e := employee(person)
	return 6.0 - float(e.skills[kind]) if not e.is_empty() else 0.0


# ---------- The desk's duty list (PRD 10.3) ----------

## What each duty is called on the desk screen.
const DUTY_WORDS := {
	"grill": "Grill", "fryer": "Fryer", "pot": "Stock pot", "board": "Chopping board",
	"slicer": "Slicer", "tap": "Pour drinks",
	"grater": "Grater", "bread_knife": "Bread knife", "juicer": "Juicer", "blender": "Blender", "steamer": "Steamer", "fetch": "Fetch ingredients", "assemble": "Assemble trays",
	"take_orders": "Take orders", "carry_trays": "Carry trays to tables", "clear_tables": "Clear tables",
	"help_up": "Help fallen people up", "mop": "Mop", "sponge": "Sponge", "scraper": "Scraper",
	"spill_kit": "Spill kit", "wash_up": "Wash up", "empty_bin": "Empty the bin",
}
## A prep tool (as `Catalog.tool_of` names it) and its duty. Tools are listed by kind:
## ticking the grill covers every stove.
## Every job a tool does (`Kitchen.jobs_known`) has a duty here, 8.6's new ones included.
const TOOL_DUTIES := {"grill": "grill", "fry": "fryer", "boil": "pot", "chop": "board", "slice": "slicer",
	"pour": "tap", "grate": "grater", "saw": "bread_knife", "juice": "juicer", "blend": "blender", "steam": "steamer"}
## Cleaning duties: each clears floor dirt with its tool.
const CLEAN_TOOLS: Array[String] = ["mop", "sponge", "scraper", "spill_kit"]
## A room piece that brings a cleaning duty (PRD 9.4: the bucket comes with a mop, the sponge
## is sold on its hook). The robot sweeper works by itself and needs no one.
const CLEAN_PIECES := {"mop_bucket": "mop", "mop": "mop", "sponge": "sponge", "scraper": "scraper",
	"spill_kit": "spill_kit"}
## Every tree node a cleaning home can be bought up to (PRD 9.5) brings its line's duty
## too, through the tool it keeps (`clean_duty`): a flat mop's bucket is still the mop's.
## Duties listed whatever is in the room.
const FIXED_DUTIES := {"food": ["fetch", "assemble"], "service": ["take_orders", "carry_trays", "clear_tables", "help_up"],
	"clean": ["wash_up", "empty_bin"]}
const MAX_POST_NAME := 18
const LIKE_AT_NEUTRAL := 0.5   # how much someone with no opinion yet likes the restaurant, for applying


## The duties a post can hold tonight, by kind: one line per tool kind in the room (prep
## tools as `Catalog.tool_of` names them, cleaning tools by piece id), then the fixed
## tasks. {"food": [...], "service": [...], "clean": [...]}, each in `DUTIES` order.
static func room_duties(tools: Array, pieces: Array) -> Dictionary:
	var have := {}
	for t in tools:
		if TOOL_DUTIES.has(t):
			have[TOOL_DUTIES[t]] = true
	for p in pieces:
		var d := str(CLEAN_PIECES.get(p, clean_duty(Kitchen.tool_of(p) if Kitchen.has_node(p) else str(p))))
		if d != "":
			have[d] = true
	var out := {}
	for k in KINDS:
		var list: Array[String] = []
		for id: String in DUTIES:
			if DUTIES[id].kind == k and (have.has(id) or (FIXED_DUTIES[k] as Array).has(id)):
				list.append(id)
		out[k] = list
	return out


## A post's duties whose tool is no longer in the room (greyed on the desk).
static func missing_duties(duties: Array, room: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for d in duties:
		var found := false
		for k in room:
			found = found or (room[k] as Array).has(d)
		if not found:
			out.append(String(d))
	return out


## The duty for working a tool (a kitchen node): the duty of the job it does best, so a
## stock pot is the pot's duty even at the grill, and a sharp knife is the board's.
static func duty_of_tool(node: String) -> String:
	if not Kitchen.has_node(node):
		return ""
	var jobs := Kitchen.jobs_of(node)
	var best := ""
	for job: String in jobs:
		if best == "" or float(jobs[job]) > float(jobs[best]):
			best = job
	return str(TOOL_DUTIES.get(best, ""))


## The cleaning duty a cleaning tool is used under (PRD 10.7): every mop on the bucket
## line is the mop's, the scourer the sponge's, the grease scraper and spill kit their own.
static func clean_duty(tool: String) -> String:
	if not CleanTools.TOOLS.has(tool):
		return ""
	if CleanTools.is_mop(tool):
		return "mop"
	match tool:
		"grease_scraper":
			return "scraper"
		"spill_kit":
			return "spill_kit"
	return "sponge"


static func duty_word(id: String) -> String:
	return str(DUTY_WORDS.get(id, id.capitalize()))


## How much someone likes the restaurant, 0 to 1, from their affinity (-1 to 1).
static func like_of(affinity: float) -> float:
	return clampf(LIKE_AT_NEUTRAL + affinity, 0.0, 1.0)


## The town as `roll_applicants` wants it on `day`: everyone, with their tolerances,
## rating and liking; anyone holding a grudge or gone for good is staying away.
static func candidates(town: Town, day: int) -> Array:
	var out := []
	for i in town.people.size():
		var p: Dictionary = town.people[i]
		out.append({"id": i, "tolerance": (p.tolerance as Dictionary).duplicate(), "rating": town.rating(i),
			"like": like_of(float(p.affinity)), "away": town.holds_grudge(i, day) or p.gone})
	return out
