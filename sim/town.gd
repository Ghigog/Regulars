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
const FLYER_PRICE := 15
const FLYER_BOOST := 0.25

var people: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _init(seed_value := 1) -> void:
	rng.seed = seed_value
	for i in NAMES.size():
		people.append({
			"name": NAMES[i], "affinity": 0.0, "friends": [], "visits": 0, "today": 0.0,
			"shirt": SHIRTS[i % SHIRTS.size()], "skin": i % 4,
		})
	# A ring of friendships plus a few long-distance ones, so gossip travels.
	for i in NAMES.size():
		_befriend(i, (i + 1) % NAMES.size())
		if i % 3 == 0:
			_befriend(i, (i + 5) % NAMES.size())


func _befriend(a: int, b: int) -> void:
	if a == b or are_friends(a, b):
		return
	people[a].friends.append(b)
	people[b].friends.append(a)


func are_friends(a: int, b: int) -> bool:
	return (people[a].friends as Array).has(b)


func visit_chance(i: int) -> float:
	var affinity: float = people[i].affinity
	return clampf(0.4 + affinity * 0.5, 0.05, 0.95)


## Who turns up today. Later days guarantee a bigger crowd.
func roll_guests(day: int, boost := 0.0) -> Array[int]:
	var coming: Array[int] = []
	var staying: Array[int] = []
	for i in people.size():
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


## Records how a visit went. The guest's friends hear about it too.
func record_visit(i: int, satisfaction: float) -> float:
	var delta := (satisfaction - 0.3) * 0.5
	_nudge(i, delta)
	people[i].visits += 1
	for f: int in people[i].friends:
		_nudge(f, delta * FRIEND_SHARE)
	return delta


func record_kindness(i: int, amount := 0.2) -> void:
	_nudge(i, amount)


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
