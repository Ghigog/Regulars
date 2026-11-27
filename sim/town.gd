class_name Town
extends RefCounted
## The named townsfolk who might eat at your restaurant, and how word of mouth
## moves between friends.

const NAMES: Array[String] = [
	"Mabel", "Otis", "Priya", "Gus", "Ingrid", "Tobias", "Wren",
	"Hattie", "Leopold", "Suki", "Barnaby", "Odette", "Felix", "Nell",
]
## The rest of the town, drawn from a pool for each theme until the town is TOWN_SIZE.
## The first fourteen above are the ones on the concept sheets, in both towns.
const TOWN_SIZE := 40
const MORE_NAMES := {
	"diner": ["Dolores", "Earl", "Bev", "Clyde", "Rosalind", "Hank", "Loretta", "Vern", "Marge",
		"Dwight", "Juniper", "Walt", "Opal", "Rusty", "Ida", "Floyd", "Mae", "Chester", "Pearl",
		"Lyle", "Delia", "Homer", "Fern", "Archie", "Winnie", "Ezra", "Goldie", "Rex", "Dot", "Sal"],
	"seaside": ["Morwenna", "Jory", "Tamsin", "Bram", "Coral", "Silas", "Marina", "Kit", "Perran",
		"Bryony", "Ned", "Isolde", "Fin", "Delphine", "Cormac", "Elsie", "Tristan", "Maud", "Rowan",
		"Lowen", "Senara", "Jago", "Peg", "Ewan", "Kerensa", "Alf", "Nessa", "Lorcan", "Mo", "Ottilie"],
}
const SHIRTS: Array[String] = ["#b85c9e", "#3f7f86", "#e9a23b", "#4a6fa5", "#6c5ce7", "#d9534f", "#5fb37a"]
const FRIEND_SHARE := 0.4
const STANDINGS: Array[String] = ["Staying away", "Wary", "Undecided", "Likes you", "Loves you"]
const GOOD_VISIT := 0.3     # satisfaction above this counts toward a streak
const REGULAR_STREAK := 3   # good visits in a row that make someone a regular
const REGULAR_TIP := 1.25
const GRUDGE_DAYS := 2      # full days a guest stays away after walking out
const FLYER_PRICE := 15
## Town rating (the secondary objective): the town's mean affinity as 0 to 100 points, graded.
## tunable: the least points for each tier, best first; anything under the last is an F.
const TIERS := [["S", 60], ["A", 45], ["B", 35], ["C", 25], ["D", 15], ["E", 5]]
const FLYER_GUESTS := 2    # tunable: extra guests a batch of flyers brings, on top of the crowd floor
## Turnout (review, item 1). Everyone rolls to come from their own affinity, so a liked
## place fills up; a thin day is topped up to `crowd_floor`, which grows slowly.
const VISIT_BASE := 0.1      # tunable: visit chance at no opinion either way
const VISIT_LIKE := 0.45     # tunable: extra chance per point of affinity
const BIG_GROUP_DAY := 0.025 # tunable: more people bring all their friends, a day at a time
const MAX_PARTY := 12 # tunable: the biggest group the town ever sends
const SMALL_PARTY := 4 # groups up to this size are the norm
const BIG_PARTY_CHANCE := 0.03 # tunable: chance a group is bigger than SMALL_PARTY on day 0
const BIG_PARTY_DAY := 0.004 # tunable: that chance grows by this a day
const BIG_PARTY_CAP := 0.15 # tunable: and never passes this
const PARTY_PATIENCE_STEP := 0.08 # tunable: each guest beyond SMALL_PARTY adds this share of patience
const BRING_FRIENDS_DAY := 8 # tunable: from this day a friend brings a friend of their own
## Kindness. Half price and free meals win goodwill, and friends hear about free ones.
## Guests given deals often start to expect them: a full-price visit then lets them down.
const KIND_HALF := 0.2        # affinity for half price
const KIND_COMP := 0.4        # affinity for a free meal
const KIND_COMP_SHARE := 0.5  # share of a free meal's goodwill each friend gets
const DEALS_HALF := 1         # how much a half price adds to `deals`
const DEALS_COMP := 2         # how much a free meal adds
const EXPECT_AT := 3          # deals at which someone expects one
const EXPECTED_KINDNESS := 0.5  # an expected deal earns only this share of the goodwill
const LETDOWN_JOY := 0.15     # joy lost paying full price when they expected a deal
## Tastes. Hidden: guests only order what has nothing they dislike.
const TASTE_LIKE_TAG := 0.8      # tunable: chance an ingredient with a liked tag is liked
const TASTE_DISLIKE_TAG := 0.7   # tunable: chance one with the disliked tag is disliked
const TASTE_STRAY_LIKE := 0.12   # tunable: chance any other ingredient is liked
const TASTE_STRAY_DISLIKE := 0.08
const TASTE_TWO_TAGS := 0.3      # tunable: chance someone likes two tags, not one
const TASTE_HATE_TAG := 0.4      # tunable: chance someone dislikes a whole tag
const MAX_DISLIKED_SHARE := 1.0 / 3.0   # nobody dislikes more than this share of the theme
const MAX_DISLIKERS_SHARE := 0.2        # no ingredient is disliked by more than this share of the town
const UNPAID_OPINION := 0.2             # tunable: opinion lost leaving unpaid (half a walkout's)
const NOTHING_LIKED_DROP := 0.05        # tunable: opinion lost finding nothing on the menu
## Opinions by topic (PRD 2). Affinity is the sum of these five parts; the four the
## critic rates are kept apart so a review can replace them. Bookkeeping only until
## a review lands: every change is filed under one, after the usual clamp.
const TOPICS: Array[String] = ["speed", "clean", "quality", "variety"]
const TOPIC_MAX := 0.25   # tunable: the most one topic can hold either way; the rest goes to `other`

var people: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var taste_seed := 1
var theme := "diner"


func _init(seed_value := 1, theme_id := "diner") -> void:
	rng.seed = seed_value
	taste_seed = seed_value
	theme = theme_id
	var names := town_names(seed_value, theme_id)
	for i in names.size():
		people.append(new_person(names[i], i))
	# A ring of friendships plus a few long-distance ones, so gossip travels.
	var n := names.size()
	for i in n:
		_befriend(i, (i + 1) % n)
		if i % 3 == 0:
			_befriend(i, (i + 5) % n)
		if i % 7 == 2:
			_befriend(i, (i + 13) % n)
	make_tastes(theme)
	make_tolerances()
	make_ratings()
	make_wealth()


## One person with every key and its new-town default: the single definition of a person.
static func new_person(person_name: String, i: int) -> Dictionary:
	return {
		"name": person_name, "affinity": 0.0, "friends": [], "visits": 0, "today": 0.0,
		"streak": 0, "away_until": 0, "sore": false, "warning": false, "grudges": 0, "gone": false, "deals": 0,
		"shirt": SHIRTS[i % SHIRTS.size()], "skin": i % 4,
		"likes": [], "dislikes": [], "liked_tags": [], "orders": {},
		"opinion": {"speed": 0.0, "clean": 0.0, "quality": 0.0, "variety": 0.0, "other": 0.0},
		"tolerance": {"food": 3, "service": 3, "clean": 3},
	}


## After loading an older save: adds every person key (and opinion/tolerance topic) the
## save predates, with the new-town default. Saved values are never overwritten.
## How the whole town feels about the restaurant, 0 to 100: the mean affinity, floored at 0.
func sentiment_points() -> int:
	if people.is_empty():
		return 0
	var total := 0.0
	for p in people:
		total += float(p.affinity)
	return roundi(clampf(total / people.size(), 0.0, 1.0) * 100.0)


static func tier_for(points: int) -> String:
	for t in TIERS:
		if points >= int(t[1]):
			return t[0]
	return "F"


func fill_missing_keys() -> void:
	for i in people.size():
		var p: Dictionary = people[i]
		var fresh := new_person(p.get("name", ""), i)
		for k: String in fresh:
			if not p.has(k):
				p[k] = fresh[k]
			elif fresh[k] is Dictionary and k in ["opinion", "tolerance"] and p[k] is Dictionary:
				for sub: String in fresh[k]:
					if not p[k].has(sub):
						p[k][sub] = fresh[k][sub]


## The town's names: the fourteen drawn ones, then the theme's pool shuffled by the seed.
static func town_names(seed_value: int, theme_id: String) -> Array[String]:
	var names: Array[String] = NAMES.duplicate()
	var pool: Array = (MORE_NAMES.get(theme_id, MORE_NAMES.diner) as Array).duplicate()
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:names:%s" % [seed_value, theme_id])
	while names.size() < TOWN_SIZE and not pool.is_empty():
		names.append(pool.pop_at(r.randi_range(0, pool.size() - 1)))
	return names


# ---------------------------------------------------------------- tolerances (PRD 10.1)

const TOL_MIN := 1
const TOL_MAX := 5

## Gives everyone a tolerance for food, service and clean, 1 to 5 (low means they
## care), from the town's seed. Its own generator, so tastes and guest rolls are
## untouched. Two dice averaged: middling is common, the extremes rarer.
func make_tolerances() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:tolerance" % taste_seed)
	for p in people:
		var tol := {}
		for topic in GuestMood.TOL_TOPICS:
			tol[topic] = roundi((r.randi_range(TOL_MIN, TOL_MAX) + r.randi_range(TOL_MIN, TOL_MAX)) / 2.0)
		p.tolerance = tol


## Everyone's means, 1 (poor) to 5 (rich), from the town's seed on its own generator
## (review, item 3). Two dice averaged, like tolerances.
func make_wealth() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:wealth" % taste_seed)
	for p in people:
		p.wealth = roundi((r.randi_range(TOL_MIN, TOL_MAX) + r.randi_range(TOL_MIN, TOL_MAX)) / 2.0)


func wealth(i: int) -> int:
	return int(people[i].get("wealth", 3))


func tolerance(i: int, topic: String) -> int:
	return int((people[i].tolerance as Dictionary).get(topic, 3))


## Skill is 6 minus tolerance: someone who cares about food cooks it well (for CVs).
static func skill_for(tol: int) -> int:
	return 6 - clampi(tol, TOL_MIN, TOL_MAX)


func skill(i: int, topic: String) -> int:
	return skill_for(tolerance(i, topic))


## Everyone's overall rating as a worker, 1 to 5 stars (PRD 10.3, section 1): how fast
## they walk and work, and the base of their asking wage. Seeded like tolerances, from
## its own generator, so nothing else in the town moves. Two dice averaged.
func make_ratings() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:rating" % taste_seed)
	for p in people:
		p.rating = roundi((r.randi_range(TOL_MIN, TOL_MAX) + r.randi_range(TOL_MIN, TOL_MAX)) / 2.0)


func rating(i: int) -> int:
	return int(people[i].get("rating", 3))


# ---------------------------------------------------------------- tastes

## Gives everyone liked and disliked ingredients for `theme_id`, from the town's seed.
## Tastes mostly follow tags. Nobody dislikes more than a third of the theme, no
## ingredient is disliked by more than a fifth of the town, and everyone likes at least
## one grill ingredient or vegetable. Uses its own generator, so it never changes who
## visits or how groups form.
func make_tastes(theme_id: String) -> void:
	if theme_id != theme:   # the theme was picked after the town was made: its own townsfolk
		var names := town_names(taste_seed, theme_id)
		for i in mini(names.size(), people.size()):
			people[i].name = names[i]
	theme = theme_id
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%s" % [taste_seed, theme_id])
	var ings := Pantry.for_theme(theme_id)
	var tags: Array[String] = []
	for ing in ings:
		for t: String in Pantry.tags_of(ing):
			if not tags.has(t):
				tags.append(t)
	for p in people:
		var liked_tags: Array[String] = [tags[r.randi_range(0, tags.size() - 1)]]
		if r.randf() < TASTE_TWO_TAGS:
			var t2 := tags[r.randi_range(0, tags.size() - 1)]
			if not liked_tags.has(t2):
				liked_tags.append(t2)
		var hated := ""
		if r.randf() < TASTE_HATE_TAG:
			var t3 := tags[r.randi_range(0, tags.size() - 1)]
			if not liked_tags.has(t3):
				hated = t3
		var likes: Array[String] = []
		var dislikes: Array[String] = []
		for ing in ings:
			var its: Array = Pantry.tags_of(ing)
			var tagged_like := liked_tags.any(func(t: String) -> bool: return its.has(t))
			if tagged_like:
				if r.randf() < TASTE_LIKE_TAG:
					likes.append(ing)
			elif hated != "" and its.has(hated):
				if r.randf() < TASTE_DISLIKE_TAG:
					dislikes.append(ing)
			else:
				var roll := r.randf()
				if roll < TASTE_STRAY_LIKE:
					likes.append(ing)
				elif roll < TASTE_STRAY_LIKE + TASTE_STRAY_DISLIKE:
					dislikes.append(ing)
		var cap := floori(ings.size() * MAX_DISLIKED_SHARE)
		while dislikes.size() > cap:
			dislikes.remove_at(r.randi_range(0, dislikes.size() - 1))
		p.likes = likes
		p.dislikes = dislikes
		p.liked_tags = liked_tags
	var most := floori(people.size() * MAX_DISLIKERS_SHARE)
	for ing in ings:
		var haters: Array[int] = []
		for i in people.size():
			if (people[i].dislikes as Array).has(ing):
				haters.append(i)
		while haters.size() > most:
			var k := r.randi_range(0, haters.size() - 1)
			(people[haters[k]].dislikes as Array).erase(ing)
			haters.remove_at(k)
	var staples: Array[String] = []
	for ing in ings:
		if Pantry.tool_of(ing) == "grill" or Pantry.tags_of(ing).has("vegetable"):
			staples.append(ing)
	for p in people:
		var likes: Array = p.likes
		if staples.any(func(s: String) -> bool: return likes.has(s)):
			continue
		var open := staples.filter(func(s: String) -> bool: return not (p.dislikes as Array).has(s))
		if not open.is_empty():   # someone who dislikes every staple keeps their tastes as they are
			likes.append(open[r.randi_range(0, open.size() - 1)])
	# Liked tags that came to nothing are dropped, so hints never point at nothing.
	for p in people:
		p.liked_tags = (p.liked_tags as Array).filter(func(t: String) -> bool:
			return (p.likes as Array).any(func(ing: String) -> bool: return Pantry.tags_of(ing).has(t)))


func tastes_of(i: int) -> Dictionary:
	return {"likes": people[i].likes, "dislikes": people[i].dislikes}


## Counts an order of menu item `item_id` on guest `i`'s card.
func record_order(i: int, item_id: int) -> void:
	var orders: Dictionary = people[i].orders
	orders[item_id] = int(orders.get(item_id, 0)) + 1


## "Stupid Burger x3, Fries x2": what someone has ordered, most first. Names come from
## the menu, so they follow renames; a deleted item keeps its last name.
func order_summary(i: int, menu: Menu) -> String:
	var orders: Dictionary = people[i].orders
	var ids: Array = orders.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		return orders[a] > orders[b] if orders[a] != orders[b] else a < b)
	var parts: Array[String] = []
	for id: int in ids:
		parts.append("%s x%d" % [menu.name_of(id), orders[id]])
	return ", ".join(parts)


## Guest `i` read the menu and found no main they would eat. Not a walkout and no
## strike, but they think a little less of the place. Friends don't hear: only really bad visits spread.
func record_found_nothing(i: int) -> float:
	_nudge(i, -NOTHING_LIKED_DROP, {"variety": 1.0})
	return -NOTHING_LIKED_DROP


## Guest `i` waited to pay until they gave up and left without paying (PRD 11). Not a
## strike: they ate, the kitchen did its job. Half a walkout's drop, filed under speed;
## friends hear it. Returns the gossip line.
func left_unpaid(i: int) -> String:
	_nudge(i, -UNPAID_OPINION, {"speed": 1.0})
	people[i].warning = true
	for f: int in people[i].friends:
		_nudge(f, -UNPAID_OPINION * FRIEND_SHARE, {"speed": 1.0})
	var friends := friend_names(i)
	if friends == "":
		return "%s left without paying. Nobody came." % people[i].name
	return "%s will tell %s: left without paying, nobody came." % [people[i].name, friends]


## Guest `i` had a perfect plate in a run of them (review, item 6): they think better of
## the cooking, and their friends hear it.
func record_praise(i: int, amount: float) -> void:
	if amount <= 0.0:
		return
	_nudge(i, amount, {"quality": 1.0})
	for f: int in people[i].friends:
		_nudge(f, amount * FRIEND_SHARE, {"quality": 1.0})


## Staff member `i` was fired (PRD 10.4): their opinion drops by `drop`; without
## severance their friends hear it and drop by `friend_drop`. Returns the change.
func record_fired(i: int, drop: float, friend_drop := 0.0) -> float:
	var before: float = people[i].affinity
	_nudge(i, -drop)
	if friend_drop > 0.0:
		for f: int in people[i].friends:
			_nudge(f, -friend_drop)
	return float(people[i].affinity) - before


func _befriend(a: int, b: int) -> void:
	if a == b or are_friends(a, b):
		return
	people[a].friends.append(b)
	people[b].friends.append(a)


func are_friends(a: int, b: int) -> bool:
	return (people[a].friends as Array).has(b)


func visit_chance(i: int) -> float:
	if people[i].gone:
		return 0.0
	var affinity: float = people[i].affinity
	return clampf(VISIT_BASE + affinity * VISIT_LIKE, 0.02, 0.9)


## The day's arrival window, the same every day (review, item 1): later days are harder
## for the crowd, the bigger parties and the shorter patience (1 s a day, down to a 42 s floor), not easier for a longer day.
const DAY_LENGTH := 75.0   # tunable: seconds the door lets people in
const EARLY_EXTRA := 10.0  # tunable: the first days run this much longer each, for learning
const EARLY_DAYS := 2      # tunable: days 1 and 2 (+20 s, +10 s), then DAY_LENGTH


## How long day `day`'s door lets people in: a little longer on the first days.
static func day_length(day: int) -> float:
	return DAY_LENGTH + EARLY_EXTRA * maxi(0, EARLY_DAYS + 1 - day)


## How long a table waits, in seconds: 1 s less each day, down to a 42 s floor.
static func table_patience(day: int) -> float:
	return maxf(42.0, 55.0 - 1.0 * day)


## How long a party of `size` waits: table_patience up to SMALL_PARTY guests, a little more per guest beyond.
static func party_patience(day: int, size: int) -> float:
	return table_patience(day) * (1.0 + PARTY_PATIENCE_STEP * maxi(0, size - SMALL_PARTY))


## The fewest guests a day brings, whatever the town thinks: grows by one every other day.
static func crowd_floor(day: int) -> int:
	return 2 + day / 2


## Who turns up today. Reputation (and `boost`, from a review) decides the crowd; a thin
## day is topped up to `crowd_floor`. Flyers (`extra`) then add up to that many more people
## drawn from those staying home, so nobody holding a grudge or gone for good comes.
func roll_guests(day: int, boost := 0.0, extra := 0) -> Array[int]:
	var coming: Array[int] = []
	var staying: Array[int] = []
	for i in people.size():
		if holds_grudge(i, day) or people[i].gone:
			continue   # not coming, and not available to fill out a thin crowd
		if rng.randf() < visit_chance(i) + boost:
			coming.append(i)
		else:
			staying.append(i)
	var minimum := mini(crowd_floor(day), people.size())
	while coming.size() < minimum and not staying.is_empty():
		coming.append(staying.pop_at(rng.randi_range(0, staying.size() - 1)))
	for _n in extra:
		if staying.is_empty():
			break
		coming.append(staying.pop_at(rng.randi_range(0, staying.size() - 1)))
	for i in range(coming.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := coming[i]
		coming[i] = coming[j]
		coming[j] = tmp
	return coming


## Splits today's guests into groups of friends, at most `max_size` each. Nobody is
## grouped with a stranger (from BRING_FRIENDS_DAY a friend's friend may come along), so
## someone whose friends are not coming arrives alone.
## Later days bring bigger parties: more people bring every friend who is coming.
func make_groups(coming: Array[int], max_size: int, day := 1) -> Array[Array]:
	var left := coming.duplicate()
	var groups: Array[Array] = []
	max_size = mini(max_size, MAX_PARTY)
	var small := mini(SMALL_PARTY, max_size)
	var all_friends := minf(0.95, 0.6 + BIG_GROUP_DAY * day)
	var big_chance := minf(BIG_PARTY_CAP, BIG_PARTY_CHANCE + BIG_PARTY_DAY * day)
	while not left.is_empty():
		var first: int = left.pop_front()
		var group: Array[int] = [first]
		# Most people would rather bring company than eat alone.
		var want := small if rng.randf() < all_friends else rng.randi_range(1, small)
		# Rarely a big party, for the endgame's big tables.
		if max_size > small and rng.randf() < big_chance:
			want = rng.randi_range(small + 1, max_size)
		# On later days a friend brings a friend of their own, so parties grow.
		var reach := 1 if day < BRING_FRIENDS_DAY else group.size() + max_size
		var k := 0
		while k < mini(reach, group.size()) and group.size() < want:
			for f: int in people[group[k]].friends:
				if group.size() >= want:
					break
				if left.has(f):
					left.erase(f)
					group.append(f)
			k += 1
		groups.append(group)
	return groups


## Moves someone's affinity by `amount`, clamped as always, and files the change that
## landed under the topics in `split` (topic -> share of the change, summing to 1).
func _nudge(i: int, amount: float, split := {"other": 1.0}) -> void:
	var affinity: float = people[i].affinity
	people[i].affinity = clampf(affinity + amount, -1.0, 1.0)
	var moved: float = people[i].affinity - affinity
	people[i].today += moved
	var op: Dictionary = people[i].opinion
	for t: String in split:
		op[t] = float(op[t]) + moved * float(split[t])
		if t != "other" and absf(op[t]) > TOPIC_MAX:   # a topic holds so much; the rest is just liking the place
			op.other = float(op.other) + op[t] - signf(op[t]) * TOPIC_MAX
			op[t] = signf(op[t]) * TOPIC_MAX


## Someone's opinion on one topic ("speed", "clean", "quality", "variety" or "other").
func opinion(i: int, topic: String) -> float:
	return float(people[i].opinion[topic])


## What the town thinks of a topic, on average.
func topic_average(topic: String) -> float:
	var sum := 0.0
	for i in people.size():
		sum += opinion(i, topic)
	return sum / people.size()


## A review moves everyone's opinion on the topics it rated (topic -> value) `share` of
## the way toward it and leaves the rest alone, so one meal never wipes out what the town
## learned. Affinity is the clamped sum again; anything past the clamp comes out of
## `other`, so the parts always add up. Grudges and "never coming back" stay as they are.
func blend_topics(values: Dictionary, share := 1.0) -> void:
	for p in people:
		var op: Dictionary = p.opinion
		for t: String in values:
			op[t] = lerpf(float(op[t]), float(values[t]), share)
		var sum := 0.0
		for t: String in op:
			sum += float(op[t])
		var a := clampf(sum, -1.0, 1.0)
		op.other = float(op.other) + a - sum
		p.today += a - float(p.affinity)
		p.affinity = a


## The topic split of a visit's change in affinity, from the satisfaction terms
## (GuestMood.satisfaction_terms): each topic takes its share of the change, and the
## rest (joy, the baseline) is `other`. Shares sum to 1.
static func visit_split(terms: Dictionary, satisfaction: float) -> Dictionary:
	var delta := (satisfaction - 0.3) * 0.5
	if terms.is_empty() or absf(delta) < 0.000001:
		return {"other": 1.0}
	var split := {}
	var rest := 1.0
	for t in TOPICS:
		if terms.has(t):
			split[t] = 0.5 * float(terms[t]) / delta
			rest -= split[t]
	split.other = rest
	return split


## Forgets yesterday's changes. Call when a new day opens.
func new_day() -> void:
	for p in people:
		p.today = 0.0


## Where someone stands with the restaurant, from 0 (staying away) to 4 (loves you).
func standing(i: int) -> int:
	var a: float = people[i].affinity
	if a >= 0.4:
		return 4
	if a >= 0.1:
		return 3
	if a > -0.1:
		return 2
	return 1 if a > -0.4 else 0


## Which way their opinion moved today: 1, 0 or -1.
func trend(i: int) -> int:
	var t: float = people[i].today
	return 0 if absf(t) < 0.02 else signi(roundi(signf(t)))


## The word shown beside someone in the town book on `day`.
func status_word(i: int, day: int) -> String:
	if people[i].gone:
		return "Never coming back"
	if holds_grudge(i, day):
		var left := int(people[i].away_until) - day
		return "Grudge: %d more day%s" % [left, "" if left == 1 else "s"]
	if is_regular(i):
		return "Regular, %d in a row" % people[i].streak
	return STANDINGS[standing(i)]


func friend_names(i: int) -> String:
	var names: Array[String] = []
	for f: int in people[i].friends:
		names.append(people[f].name)
	if names.size() < 2:
		return "" if names.is_empty() else names[0]
	return ", ".join(names.slice(0, -1)) + " and " + names[-1]


## What a visit that moved their opinion by `delta` sets going. Empty when nothing much.
## `about` is what they will tell, if anything ("it was just how they like it").
## A drop only makes a line when `bad` (a really bad visit: a walkout).
func gossip_line(i: int, delta: float, about := "", bad := false) -> String:
	var friends := friend_names(i)
	if friends == "" or absf(delta) < 0.05 - 0.0001:
		return ""
	var tail := "." if about == "" else " " + about + "."
	if delta > 0.0:
		return "%s will tell %s%s" % [people[i].name, friends, tail]
	if not bad:
		return ""
	return "%s will warn %s%s" % [people[i].name, friends, tail]


## What a guest tells friends about the food, hinting at their tastes without naming
## them: a meal with something they like, or a menu full of a tag they like.
static func praise_about(liked_meal: bool, hint_tag: String) -> String:
	if liked_meal:
		return "it was just how they like it"
	if hint_tag != "":
		return "about all the things with " + Menu.tag_word(hint_tag)
	return ""


func is_regular(i: int) -> bool:
	return int(people[i].streak) >= REGULAR_STREAK


## How much more a regular tips.
func tip_bonus(i: int) -> float:
	return REGULAR_TIP if is_regular(i) else 1.0


func holds_grudge(i: int, day: int) -> bool:
	return day < int(people[i].away_until)


## How someone walks in: {"patience", "joy", "thought"} to start their visit with.
func greeting(i: int) -> Dictionary:
	if people[i].sore:
		return {"patience": 0.75, "joy": -0.1, "thought": "Last time was a disaster. One more chance"}
	if is_regular(i):
		return {"patience": 1.0, "joy": 0.1, "thought": "My favourite place"}
	if expects_deal(i):
		return {"patience": 1.0, "joy": 0.0, "thought": "They usually knock something off"}
	return {"patience": 1.0, "joy": 0.0, "thought": ""}


## A walkout on `day`: a bad visit, and they stay away for the next GRUDGE_DAYS days,
## twice as long each time it happens again. They come back sore.
func record_walkout(i: int, day: int) -> float:
	people[i].grudges += 1
	people[i].away_until = day + 1 + GRUDGE_DAYS * int(people[i].grudges)
	var delta := record_visit(i, -0.5, {}, true)
	people[i].sore = true
	people[i].warning = true
	return delta


## Records how a visit went. Friends hear good news, and bad news only when
## `spread_bad` (a walkout); a so-so visit lowers only the guest's own opinion. A good visit
## builds their streak and forgives a grudge; a poor one breaks the streak.
## `terms` (GuestMood.satisfaction_terms) say which topics the change is filed under;
## without them it all goes to `other`.
func record_visit(i: int, satisfaction: float, terms := {}, spread_bad := false) -> float:
	var delta := (satisfaction - 0.3) * 0.5
	var split := visit_split(terms, satisfaction)
	var sore_bonus := 0.0
	if satisfaction > GOOD_VISIT:
		people[i].streak += 1
		people[i].warning = false
		if people[i].sore:
			people[i].sore = false
			sore_bonus = 0.1
	else:
		people[i].streak = 0
	if sore_bonus > 0.0:   # forgiving is `other`: re-weigh the split for the whole change
		var whole := delta + sore_bonus
		for t: String in split:
			split[t] = float(split[t]) * delta / whole
		split.other = float(split.other) + sore_bonus / whole
		delta = whole
	_nudge(i, delta, split)
	people[i].visits += 1
	if delta > 0.0 or spread_bad:
		for f: int in people[i].friends:
			_nudge(f, delta * FRIEND_SHARE, split)
	return delta


## What a guest does about the disgust `level` they left with (GuestMood stages).
## Disgusted: they tell their friends and think less of the place. Revolted: the
## friends hear worse, and the guest never comes back. Returns the news, if any.
func record_disgust(i: int, level: int) -> String:
	if level < 2:
		return ""
	var revolted := level >= 3
	people[i].warning = true
	_nudge(i, -0.3 if revolted else -0.1, {"clean": 1.0})
	for f: int in people[i].friends:
		_nudge(f, -0.15 if revolted else -0.08, {"clean": 1.0})
	if revolted:
		people[i].gone = true
		people[i].streak = 0
		return "%s is revolted and is never coming back." % people[i].name
	return "%s is telling friends how dirty it was." % people[i].name


## A deal for guest `i`: "half" price or a free meal ("comp"). They like the place more
## (less if they had come to expect it), friends hear about a free meal, and every deal
## makes them a little more likely to expect the next one.
func record_kindness(i: int, kind := "half") -> void:
	var comp := kind == "comp"
	var amount := KIND_COMP if comp else KIND_HALF
	if expects_deal(i):
		amount *= EXPECTED_KINDNESS
	_nudge(i, amount)
	if comp:
		for f: int in people[i].friends:
			_nudge(f, amount * KIND_COMP_SHARE)
	people[i].deals += DEALS_COMP if comp else DEALS_HALF


## Whether guest `i` has had enough deals to expect one.
func expects_deal(i: int) -> bool:
	return int(people[i].deals) >= EXPECT_AT


## Guest `i` paid full price. If they expected a deal they are let down: returns the
## joy they lose (0 if not). Each full-price visit wears the habit down by one.
func paid_full_price(i: int) -> float:
	var letdown := LETDOWN_JOY if expects_deal(i) else 0.0
	people[i].deals = maxi(0, int(people[i].deals) - 1)
	return letdown


## One line of gossip for the end-of-day report.
func headline() -> String:
	var best := 0
	var worst := -1
	for i in people.size():
		if people[i].affinity > people[best].affinity:
			best = i
		if people[i].warning and (worst < 0 or people[i].affinity < people[worst].affinity):
			worst = i
	var parts: Array[String] = []
	if people[best].affinity > 0.05:
		parts.append("%s is telling friends about you." % people[best].name)
	if worst >= 0 and people[worst].affinity < -0.05:
		parts.append("%s is warning people off." % people[worst].name)
	return "The town hasn't made up its mind yet." if parts.is_empty() else " ".join(parts)
