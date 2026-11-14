class_name Town
extends RefCounted
## The named townsfolk who might eat at your restaurant, and how word of mouth
## moves between friends.

const NAMES: Array[String] = [
	"Mabel", "Otis", "Priya", "Gus", "Ingrid", "Tobias", "Wren",
	"Hattie", "Leopold", "Suki", "Barnaby", "Odette", "Felix", "Nell",
]
const SHIRTS: Array[String] = ["#b85c9e", "#3f7f86", "#e9a23b", "#4a6fa5", "#6c5ce7", "#d9534f", "#5fb37a"]
const FRIEND_SHARE := 0.4
const STANDINGS: Array[String] = ["Staying away", "Wary", "Undecided", "Likes you", "Loves you"]
const GOOD_VISIT := 0.3     # satisfaction above this counts toward a streak
const REGULAR_STREAK := 3   # good visits in a row that make someone a regular
const REGULAR_TIP := 1.25
const GRUDGE_DAYS := 2      # full days a guest stays away after walking out
const FLYER_PRICE := 15
const FLYER_BOOST := 0.25
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
const NOTHING_LIKED_DROP := 0.05        # tunable: opinion lost finding nothing on the menu

var people: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var taste_seed := 1
var theme := "diner"


func _init(seed_value := 1) -> void:
	rng.seed = seed_value
	taste_seed = seed_value
	for i in NAMES.size():
		people.append({
			"name": NAMES[i], "affinity": 0.0, "friends": [], "visits": 0, "today": 0.0,
			"streak": 0, "away_until": 0, "sore": false, "grudges": 0, "gone": false, "deals": 0,
			"shirt": SHIRTS[i % SHIRTS.size()], "skin": i % 4,
			"likes": [], "dislikes": [], "liked_tags": [], "orders": {},
		})
	# A ring of friendships plus a few long-distance ones, so gossip travels.
	for i in NAMES.size():
		_befriend(i, (i + 1) % NAMES.size())
		if i % 3 == 0:
			_befriend(i, (i + 5) % NAMES.size())
	make_tastes(theme)


# ---------------------------------------------------------------- tastes

## Gives everyone liked and disliked ingredients for `theme_id`, from the town's seed.
## Tastes mostly follow tags. Nobody dislikes more than a third of the theme, no
## ingredient is disliked by more than a fifth of the town, and everyone likes at least
## one grill ingredient or vegetable. Uses its own generator, so it never changes who
## visits or how groups form.
func make_tastes(theme_id: String) -> void:
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
## strike, but they think a little less of the place and their friends hear it.
func record_found_nothing(i: int) -> float:
	_nudge(i, -NOTHING_LIKED_DROP)
	for f: int in people[i].friends:
		_nudge(f, -NOTHING_LIKED_DROP * FRIEND_SHARE)
	return -NOTHING_LIKED_DROP


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
	return clampf(0.4 + affinity * 0.5, 0.05, 0.95)


## Who turns up today. Later days guarantee a bigger crowd.
func roll_guests(day: int, boost := 0.0) -> Array[int]:
	var coming: Array[int] = []
	var staying: Array[int] = []
	for i in people.size():
		if holds_grudge(i, day) or people[i].gone:
			continue   # not coming, and not available to fill out a thin crowd
		if rng.randf() < visit_chance(i) + boost:
			coming.append(i)
		else:
			staying.append(i)
	var minimum := mini(3 + day, people.size())
	while coming.size() < minimum and not staying.is_empty():
		coming.append(staying.pop_at(rng.randi_range(0, staying.size() - 1)))
	for i in range(coming.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := coming[i]
		coming[i] = coming[j]
		coming[j] = tmp
	return coming


## Splits today's guests into groups of friends, at most `max_size` each. Nobody is
## grouped with a stranger, so someone whose friends are not coming arrives alone.
func make_groups(coming: Array[int], max_size: int) -> Array[Array]:
	var left := coming.duplicate()
	var groups: Array[Array] = []
	while not left.is_empty():
		var first: int = left.pop_front()
		var group: Array[int] = [first]
		# Most people would rather bring company than eat alone.
		var want := max_size if rng.randf() < 0.7 else rng.randi_range(1, max_size)
		for f: int in people[first].friends:
			if group.size() >= want:
				break
			if left.has(f):
				left.erase(f)
				group.append(f)
		groups.append(group)
	return groups


func _nudge(i: int, amount: float) -> void:
	var affinity: float = people[i].affinity
	people[i].affinity = clampf(affinity + amount, -1.0, 1.0)
	people[i].today += people[i].affinity - affinity


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
func gossip_line(i: int, delta: float) -> String:
	var friends := friend_names(i)
	if friends == "" or absf(delta) < 0.05:
		return ""
	if delta > 0.0:
		return "%s will tell %s." % [people[i].name, friends]
	return "%s will warn %s." % [people[i].name, friends]


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
	var delta := record_visit(i, -0.5)
	people[i].sore = true
	return delta


## Records how a visit went. The guest's friends hear about it too. A good visit
## builds their streak and forgives a grudge; a poor one breaks the streak.
func record_visit(i: int, satisfaction: float) -> float:
	var delta := (satisfaction - 0.3) * 0.5
	if satisfaction > GOOD_VISIT:
		people[i].streak += 1
		if people[i].sore:
			people[i].sore = false
			delta += 0.1
	else:
		people[i].streak = 0
	_nudge(i, delta)
	people[i].visits += 1
	for f: int in people[i].friends:
		_nudge(f, delta * FRIEND_SHARE)
	return delta


## What a guest does about the disgust `level` they left with (GuestMood stages).
## Disgusted: they tell their friends and think less of the place. Revolted: the
## friends hear worse, and the guest never comes back. Returns the news, if any.
func record_disgust(i: int, level: int) -> String:
	if level < 2:
		return ""
	var revolted := level >= 3
	_nudge(i, -0.3 if revolted else -0.1)
	for f: int in people[i].friends:
		_nudge(f, -0.15 if revolted else -0.08)
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
	var worst := 0
	for i in people.size():
		if people[i].affinity > people[best].affinity:
			best = i
		if people[i].affinity < people[worst].affinity:
			worst = i
	var parts: Array[String] = []
	if people[best].affinity > 0.05:
		parts.append("%s is telling friends about you." % people[best].name)
	if people[worst].affinity < -0.05:
		parts.append("%s is warning people off." % people[worst].name)
	return "The town hasn't made up its mind yet." if parts.is_empty() else " ".join(parts)
