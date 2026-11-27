class_name Dish
extends RefCounted
## One plate, one cup, or a loose stack of food on a worktop (a bun on a cooked patty
## before it is plated). Pure. Food goes on a plate, drinks in a cup; a loose stack has
## no vessel and is plated before it is served. A served dish is one menu item: what is
## on it matches that item's ingredients exactly, in any order. Food only combines into
## something tonight's menu could make. A dirty dish has been eaten off and holds nothing.

const PLATE := "plate"
const CUP := "cup"

var vessel := ""                  # PLATE, CUP, or "" for a loose stack
var ings: Array[String] = []      # ingredient ids, in the order they went on
var qs: Array[float] = []         # each one's quality (a marinated piece's already has its bonus)
var marks: Array[bool] = []       # each one came from a Marinated box (it keeps a glaze on the plate)
var dirty := false
var ticket := -1                  # helpers: the ticket this dish is being built for (-1: none)
var line := -1                    # and which of its lines


static func make(vessel_: String, dirty_ := false) -> Dish:
	var d := Dish.new()
	d.vessel = vessel_
	d.dirty = dirty_
	return d


## A loose stack of two things already made: what was on the worktop, then what went on it.
static func stack(first: String, q1: float, second: String, q2: float) -> Dish:
	var d := Dish.new()
	d.ings.append(Tray.parse(first).id)
	d.qs.append(q1)
	d.ings.append(Tray.parse(second).id)
	d.qs.append(q2)
	d.marks.assign([false, false])
	return d


func is_empty() -> bool:
	return ings.is_empty()


## Whether this vessel can hold an item of this course: a drink in a cup, food on a
## plate, either as a loose stack.
static func fits_vessel(vessel_: String, item: Dictionary) -> bool:
	if vessel_ == CUP:
		return item.course == "drink"
	if vessel_ == PLATE:
		return item.course != "drink"
	return true


## Whether every id in `ids` is in the item, each as often as it is listed there or less.
static func sub_of(ids: Array, item: Dictionary) -> bool:
	var left: Array = (item.ingredients as Array).duplicate()
	for id: String in ids:
		var k := left.find(id)
		if k < 0:
			return false
		left.remove_at(k)
	return true


## Whether `ids` are exactly the item's ingredients, in any order.
static func same_as(ids: Array, item: Dictionary) -> bool:
	return ids.size() == (item.ingredients as Array).size() and sub_of(ids, item)


## Why the ingredient kind `k` cannot go on, or "" if it can. `items` is the menu.
func refusal(k: String, items: Array) -> String:
	if dirty:
		return "Wash it first"
	var p := Tray.parse(k)
	if p.is_empty():
		return "That doesn't go on a plate"
	if p.state == "burnt":
		return "That's burnt. Bin it"
	if p.state == "raw" and Pantry.needs_prep(p.id):
		return "%s needs %s first" % [Pantry.name_of(p.id), Tray.verb(Pantry.tool_of(p.id))]
	if vessel == CUP and not Pantry.is_drink(p.id):
		return "Only drinks go in a cup"
	if vessel != CUP and Pantry.is_drink(p.id):
		return "Drinks go in a cup"
	return _menu_refusal(ings + [p.id], items)


## Why everything on `other` (a loose stack, or a lone kind made into one) cannot go
## onto this dish, or "".
func merge_refusal(other: Dish, items: Array) -> String:
	if dirty:
		return "Wash it first"
	for id: String in other.ings:
		if vessel == CUP and not Pantry.is_drink(id):
			return "Only drinks go in a cup"
		if vessel != CUP and Pantry.is_drink(id):
			return "Drinks go in a cup"
	return _menu_refusal(ings + other.ings, items)


func _menu_refusal(ids: Array, items: Array) -> String:
	if ids.size() > Menu.MAX_INGREDIENTS:
		return "That's too much for one plate"
	for it: Dictionary in items:
		if fits_vessel(vessel, it) and sub_of(ids, it):
			return ""
	for it: Dictionary in items:   # the right things, one too many of something
		if not fits_vessel(vessel, it):
			continue
		var left: Array = (it.ingredients as Array).duplicate()
		var extra := ""
		for id: String in ids:
			if left.has(id):
				left.erase(id)
			elif (it.ingredients as Array).has(id):
				extra = id
			else:
				extra = "-"
				break
		if extra != "" and extra != "-":
			return "One %s is enough" % Pantry.name_of(extra).to_lower()
	var names: Array[String] = []
	for id in ids:
		var n := Pantry.name_of(id).to_lower()
		if not names.has(n):
			names.append(n)
	if names.size() == 1:
		return "Nothing on the menu has %s" % names[0]
	return "Nothing on the menu has %s with %s" % [", ".join(names.slice(0, -1)), names[-1]]


## `marinated`: the piece came from a Marinated box, so it scores the bonus on top (clamped).
func add(k: String, q: float, marinated := false) -> void:
	ings.append(Tray.parse(k).id)
	qs.append(Prep.marinate(q) if marinated else q)
	marks.append(marinated)


## Whether the piece at `i` came from a Marinated box.
func is_marinated(i: int) -> bool:
	return i < marks.size() and marks[i]


func any_marinated() -> bool:
	return marks.has(true)


## Moves everything on `other` onto this dish.
func take_all(other: Dish) -> void:
	ings.append_array(other.ings)
	qs.append_array(other.qs)
	marks.append_array(other.marks)
	other.ings.clear()
	other.qs.clear()
	other.marks.clear()


## Empties it into the bin. A plate or cup keeps its vessel.
func scrape() -> void:
	ings.clear()
	qs.clear()
	marks.clear()


## The menu item this dish is, exactly, or {}. A loose stack can be one but is never served.
func item_of(items: Array) -> Dictionary:
	if ings.is_empty() or dirty:
		return {}
	for it: Dictionary in items:
		if fits_vessel(vessel, it) and same_as(ings, it):
			return it
	return {}


## The first menu item this dish could still become, or {}.
func heading_for(items: Array) -> Dictionary:
	for it: Dictionary in items:
		if fits_vessel(vessel, it) and sub_of(ings, it):
			return it
	return {}


## Ready to serve: on a plate or in a cup, and exactly an item.
func is_ready(items: Array) -> bool:
	return vessel != "" and not item_of(items).is_empty()


## Each ingredient's quality laid out as `item` lists them: an Array of quality, -1.0
## for one not on the dish. What a guest's order line gets when it is served.
func have_for(item: Dictionary) -> Array[float]:
	var out: Array[float] = []
	var used := {}
	for id: String in item.ingredients:
		var q := -1.0
		for k in ings.size():
			if ings[k] == id and not used.has(k):
				used[k] = true
				q = qs[k]
				break
		out.append(q)
	return out


## The ingredients as they should stack, in the order the item they are heading for
## lists them (so a bun wraps the patty however it went on): [ids, have].
func layout(items: Array) -> Array:
	var it := heading_for(items)
	if it.is_empty():
		var have: Array[float] = []
		have.assign(qs)
		return [ings.duplicate(), have]
	var ids: Array = (it.ingredients as Array).duplicate()
	return [ids, have_for(it)]


## What is still needed to become `item`: ingredient ids, a kind twice for two.
func needs_for(item: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var have := have_for(item)
	for k in have.size():
		if have[k] < 0.0:
			out.append(str(item.ingredients[k]))
	return out


func quality() -> float:
	var sum := 0.0
	for q in qs:
		sum += q
	return sum / qs.size() if not qs.is_empty() else 0.0


func duplicate_dish() -> Dish:
	var d := Dish.new()
	d.vessel = vessel
	d.ings = ings.duplicate()
	d.qs = qs.duplicate()
	d.marks = marks.duplicate()
	d.dirty = dirty
	d.ticket = ticket
	d.line = line
	return d
