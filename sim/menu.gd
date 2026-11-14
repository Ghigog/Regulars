class_name Menu
extends RefCounted
## The player's menu: named items in three courses, priced from their ingredients.
## Also what is makeable tonight, what the night's stock costs, and what a guest orders.
## An item is {id, name, course, ingredients, price_level, off}.

const COURSES: Array[String] = ["main", "side", "drink"]
const COURSE_NAMES := {"main": "Mains", "side": "Sides", "drink": "Drinks"}
const LEVELS: Array[String] = ["cheap", "fair", "dear"]
const MAX_INGREDIENTS := 6   # tunable: the most a stacked item can hold
const MAX_NAME := 18
const PRICE_MULT := {"cheap": 0.8, "fair": 1.0, "dear": 1.25}    # tunable
const ORDER_WEIGHT := {"cheap": 1.5, "fair": 1.0, "dear": 0.6}   # tunable: how often each level is picked
const LIKED_BONUS := 0.1      # tunable: savour added for each liked ingredient on the tray
const LIKED_BONUS_MAX := 0.3  # tunable: the most liked ingredients can add
const HINT_ITEMS := 3         # tunable: items carrying a liked tag before a guest remarks on it
## What guests think. Tastes are never listed; these lines only hint at them.
const NOTHING_THOUGHT := "Nothing I liked on the menu"
const LIKED_THOUGHT := "Just how I like it"
const TAG_WORDS := {"vegetable": "vegetables", "meat": "meat", "bread": "bread", "dairy": "cheese",
	"fish": "fish", "fried": "fried food", "fruit": "fruit", "drink": "drinks"}

var items: Array[Dictionary] = []
var retired := {}   # id -> last name, for items that were deleted
var _next := 1


## Why these ingredients cannot make an item of this course, or "" if they can.
static func refusal(course: String, ingredients: Array) -> String:
	if ingredients.is_empty():
		return "Add an ingredient"
	if ingredients.size() > MAX_INGREDIENTS:
		return "At most %d ingredients" % MAX_INGREDIENTS
	for ing: String in ingredients:
		if not Pantry.has(ing):
			return "Unknown ingredient"
		if course == "drink" and not Pantry.is_drink(ing):
			return "A drink holds only drinks"
		if course != "drink" and Pantry.is_drink(ing):
			return "Drinks go in the drinks column"
	return ""


static func price_of(item: Dictionary) -> int:
	var worth := 0
	for ing: String in item.ingredients:
		worth += int(Pantry.ITEMS[ing].worth)
	return maxi(1, roundi(worth * float(PRICE_MULT[item.get("price_level", "fair")])))


## A made-up name from the ingredients, topping first ("Cheese Patty Bun").
static func default_name(ingredients: Array) -> String:
	var words: Array[String] = []
	for k in range(ingredients.size() - 1, -1, -1):
		var n := Pantry.name_of(ingredients[k])
		if not words.has(n):
			words.append(n)
	var name := " ".join(words)
	while name.length() > MAX_NAME and words.size() > 1:
		words.remove_at(words.size() - 2)
		name = " ".join(words)
	return name.substr(0, MAX_NAME)


## Adds an item and returns it, or {} if the ingredients do not fit the course.
func add(course: String, ingredients: Array, name := "", level := "fair") -> Dictionary:
	if not COURSES.has(course) or refusal(course, ingredients) != "":
		return {}
	var item := {"id": _next, "name": "", "course": course, "ingredients": ingredients.duplicate(),
		"price_level": level, "off": false}
	_next += 1
	item.name = default_name(ingredients) if name.strip_edges() == "" else name.strip_edges().substr(0, MAX_NAME)
	items.append(item)
	return item


func find(id: int) -> Dictionary:
	for it in items:
		if int(it.id) == id:
			return it
	return {}


func rename(id: int, name: String) -> void:
	var it := find(id)
	if not it.is_empty():
		var clean := name.strip_edges().substr(0, MAX_NAME)
		it.name = default_name(it.ingredients) if clean == "" else clean


## Changes an item's ingredients if they still fit its course. Returns whether it did.
func set_ingredients(id: int, ingredients: Array) -> bool:
	var it := find(id)
	if it.is_empty() or refusal(it.course, ingredients) != "":
		return false
	it.ingredients = ingredients.duplicate()
	return true


func remove(id: int) -> void:
	var it := find(id)
	if not it.is_empty():
		retired[id] = it.name
		items.erase(it)


## An item's current name, or its last name if it was deleted.
func name_of(id: int) -> String:
	var it := find(id)
	if not it.is_empty():
		return it.name
	return str(retired.get(id, "?"))


func in_course(course: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in items:
		if it.course == course:
			out.append(it)
	return out


## What stocking the kitchen costs for a night. `stations` holds a record per
## ingredient station: {ingredient, ready, stocked}.
static func night_cost(stations: Array) -> int:
	var total := 0
	for s: Dictionary in stations:
		if s.get("stocked", true):
			total += Pantry.fee_of(s.ingredient, s.get("ready", false))
	return total


## Why an item cannot be made tonight ("No fryer", "Onion not stocked"), or "".
## `tools` lists the tools in the room ("grill", "fry", ...).
static func off_reason(item: Dictionary, stations: Array, tools: Array) -> String:
	if item.get("off", false):
		return "Off tonight"
	for ing: String in item.ingredients:
		var raw := false
		var ready := false
		var any := false
		for s: Dictionary in stations:
			if s.ingredient == ing:
				any = true
				if s.get("stocked", true):
					if s.get("ready", false):
						ready = true
					else:
						raw = true
		if not any:
			return "No %s" % Pantry.name_of(ing).to_lower()
		if not raw and not ready:
			return "%s not stocked" % Pantry.name_of(ing)
		var tool := Pantry.tool_of(ing)
		if not ready and Pantry.TOOL_STATION.has(tool) and not tools.has(tool):
			return "No %s" % Pantry.TOOL_NAMES[tool]
	return ""


## The items that can be offered tonight.
func tonight(stations: Array, tools: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in items:
		if off_reason(it, stations, tools) == "":
			out.append(it)
	return out


static func has_main(available: Array) -> bool:
	for it: Dictionary in available:
		if it.course == "main":
			return true
	return false


static func acceptable(item: Dictionary, dislikes: Array) -> bool:
	for ing: String in item.ingredients:
		if dislikes.has(ing):
			return false
	return true


static func liked_count(ingredients: Array, likes: Array) -> int:
	var n := 0
	for ing: String in ingredients:
		if likes.has(ing):
			n += 1
	return n


## One acceptable item of a course, weighted by (1 + liked ingredients) x level
## weight. With `need_like`, only items with a liked ingredient count. {} if none.
static func pick(course: String, available: Array, likes: Array, dislikes: Array,
		rng: RandomNumberGenerator, need_like := false) -> Dictionary:
	var pool: Array[Dictionary] = []
	var weights: Array[float] = []
	var total := 0.0
	for it: Dictionary in available:
		if it.course != course or not acceptable(it, dislikes):
			continue
		var liked := liked_count(it.ingredients, likes)
		if need_like and liked == 0:
			continue
		var w := (1.0 + liked) * float(ORDER_WEIGHT[it.get("price_level", "fair")])
		pool.append(it)
		weights.append(w)
		total += w
	if pool.is_empty():
		return {}
	var roll := rng.randf() * total
	for k in pool.size():
		roll -= weights[k]
		if roll <= 0.0:
			return pool[k]
	return pool[-1]


## What one guest orders: {main, side, drink}, each an item or {}. The main is any
## acceptable one; a side and a drink are added only when one has a liked ingredient.
static func order(available: Array, likes: Array, dislikes: Array, rng: RandomNumberGenerator) -> Dictionary:
	var main := pick("main", available, likes, dislikes, rng)
	if main.is_empty():
		return {"main": {}, "side": {}, "drink": {}}
	return {"main": main, "side": pick("side", available, likes, dislikes, rng, true),
		"drink": pick("drink", available, likes, dislikes, rng, true)}


## What a group orders. `tastes` holds {likes, dislikes} per member. If nobody finds
## a main, the whole group walks on. Otherwise a member with no main stays and has
## just a drink (any acceptable one), or nothing. Returns {walk, orders, found_nothing}
## where found_nothing lists the members (by index) with no main.
static func group_order(available: Array, tastes: Array, rng: RandomNumberGenerator) -> Dictionary:
	var orders: Array[Dictionary] = []
	var nothing: Array[int] = []
	for k in tastes.size():
		var t: Dictionary = tastes[k]
		var o := order(available, t.likes, t.dislikes, rng)
		if o.main.is_empty():
			nothing.append(k)
			o.drink = pick("drink", available, t.likes, t.dislikes, rng)
		orders.append(o)
	return {"walk": nothing.size() == tastes.size(), "orders": orders, "found_nothing": nothing}


## How good the meal tastes: the tray's average quality, raised for liked
## ingredients up to LIKED_BONUS_MAX.
static func savour(qualities: Array, ingredients: Array, likes: Array) -> float:
	if qualities.is_empty():
		return 0.0
	var sum := 0.0
	for q: float in qualities:
		sum += q
	return sum / qualities.size() + minf(LIKED_BONUS_MAX, LIKED_BONUS * liked_count(ingredients, likes))


## A tag the guest likes that at least HINT_ITEMS of tonight's items carry, or "".
static func tag_hint(available: Array, liked_tags: Array) -> String:
	for tag: String in liked_tags:
		var n := 0
		for it: Dictionary in available:
			for ing: String in it.ingredients:
				if Pantry.tags_of(ing).has(tag):
					n += 1
					break
		if n >= HINT_ITEMS:
			return tag
	return ""


## How a guest says a tag: "vegetables", "fried food".
static func tag_word(tag: String) -> String:
	return str(TAG_WORDS.get(tag, tag))


## What a guest thinks reading a menu with HINT_ITEMS or more items carrying a tag they like.
static func hint_thought(tag: String) -> String:
	var w := tag_word(tag)
	return "So many things with %s. I love %s!" % [w, w]
