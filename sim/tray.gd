class_name Tray
extends RefCounted
## One guest's order as it reaches their table: a line for each menu item on their
## ticket (main, then side, then drink), and what of each has been served. Food is
## carried out on plates and drinks in cups (`Dish`); each one served fills its line.
## (Named for the trays it once was; the carried tray is now only a way to hold more.) Pure.
## A held or stored ingredient is a kind string: "raw:patty", "prep:patty", "burnt:patty".

var ticket := -1                     # the ticket id it belongs to, -1 for none
var lines: Array[Dictionary] = []    # {item, have: Array of quality, or -1.0 if missing}


static func kind(state: String, ingredient: String) -> String:
	return "%s:%s" % [state, ingredient]


## {state, id} for an ingredient kind, or {} if `k` is not one.
static func parse(k: String) -> Dictionary:
	var parts := k.split(":")
	if parts.size() != 2 or not Pantry.has(parts[1]) or not ["raw", "prep", "burnt"].has(parts[0]):
		return {}
	return {"state": parts[0], "id": parts[1]}


## Sets the tray up for a ticket's items, in course order. Clears what was on it.
func assign(ticket_id: int, items: Array) -> void:
	ticket = ticket_id
	lines.clear()
	for course in Menu.COURSES:
		for it: Dictionary in items:
			if it.course == course:
				var have: Array[float] = []
				for _i in it.ingredients.size():
					have.append(-1.0)
				lines.append({"item": it, "have": have})


func is_empty() -> bool:
	for l in lines:
		for q: float in l.have:
			if q >= 0.0:
				return false
	return true


func is_complete() -> bool:
	if lines.is_empty():
		return false
	for l in lines:
		for q: float in l.have:
			if q < 0.0:
				return false
	return true


## Why this ingredient cannot go on the tray, or "" if it can.
func refusal(k: String) -> String:
	var p := parse(k)
	if p.is_empty():
		return "That doesn't go on a tray"
	if lines.is_empty():
		return "This tray has no ticket"
	if p.state == "burnt":
		return "That's burnt. Bin it"
	if p.state == "raw" and Pantry.needs_prep(p.id):
		return "%s needs %s first" % [Pantry.name_of(p.id), verb(Pantry.tool_of(p.id))]
	if _slot(p.id).is_empty():
		return "No %s on this ticket" % Pantry.name_of(p.id).to_lower()
	return ""


static func verb(tool: String) -> String:
	return {"grill": "grilling", "fry": "frying", "boil": "boiling", "chop": "chopping",
		"slice": "slicing", "grate": "grating", "saw": "sawing", "juice": "juicing", "blend": "blending",
		"steam": "steaming", "pour": "pouring"}.get(tool, "prep")


## The first line still missing this ingredient, main first: {line, index} or {}.
func _slot(id: String) -> Dictionary:
	for li in lines.size():
		var l: Dictionary = lines[li]
		for k in l.item.ingredients.size():
			if l.item.ingredients[k] == id and float(l.have[k]) < 0.0:
				return {"line": li, "index": k}
	return {}


## Puts the ingredient on. Returns "" or why it was refused.
func add(k: String, quality: float) -> String:
	var why := refusal(k)
	if why != "":
		return why
	var s := _slot(parse(k).id)
	lines[s.line].have[s.index] = quality
	return ""


## What is still missing, by name: "Needs fries" or "".
func missing() -> String:
	var names: Array[String] = []
	for l in lines:
		for k in l.item.ingredients.size():
			if float(l.have[k]) < 0.0:
				var n := Pantry.name_of(l.item.ingredients[k]).to_lower()
				if not names.has(n):
					names.append(n)
	return "" if names.is_empty() else "Needs " + ", ".join(names)


## The average quality of what is on the tray.
func quality() -> float:
	var qs := qualities()
	var sum := 0.0
	for q in qs:
		sum += q
	return sum / qs.size() if not qs.is_empty() else 0.0


func qualities() -> Array[float]:
	var out: Array[float] = []
	for l in lines:
		for q: float in l.have:
			if q >= 0.0:
				out.append(q)
	return out


## Every ingredient the tray's items list.
func ingredients() -> Array[String]:
	var out: Array[String] = []
	for l in lines:
		for ing: String in l.item.ingredients:
			out.append(ing)
	return out


## The sum of the item prices: the bill before mood and deals.
func price() -> int:
	var total := 0
	for l in lines:
		total += Menu.price_of(l.item)
	return total


func item_ids() -> Array[int]:
	var out: Array[int] = []
	for l in lines:
		out.append(int(l.item.id))
	out.sort()
	return out


## Whether this tray's items are exactly `items` (so it can move to that ticket).
func matches(items: Array) -> bool:
	var ids: Array[int] = []
	for it: Dictionary in items:
		ids.append(int(it.id))
	ids.sort()
	return ids == item_ids()


## Moves a tray to another ticket with the same items, keeping what is on it.
func reassign(ticket_id: int) -> void:
	ticket = ticket_id


## A served dish fills the first line for its item still empty. Returns the line, or -1
## when no line wants it.
func serve_dish(d: Dish, items: Array) -> int:
	var it := d.item_of(items)
	if it.is_empty() or d.vessel == "":
		return -1
	var li := open_line(int(it.id))
	if li < 0:
		return -1
	lines[li].have = d.have_for(lines[li].item)
	return li


## The names of the items with nothing served yet, in course order: ["Soda"].
func waiting_for() -> Array[String]:
	var out: Array[String] = []
	for it in waiting_items():
		out.append(str(it.name))
	return out


## The menu items with nothing served yet, in line order.
func waiting_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in lines:
		if not _served(l):
			out.append(l.item)
	return out


## The first line for this menu item with nothing served on it yet, or -1.
func open_line(item_id: int) -> int:
	for li in lines.size():
		var l: Dictionary = lines[li]
		if int(l.item.id) == item_id and not _served(l):
			return li
	return -1


func _served(l: Dictionary) -> bool:
	for q: float in l.have:
		if q >= 0.0:
			return true
	return false


## How many of its lines have been served.
func served_count() -> int:
	var n := 0
	for l in lines:
		if _served(l):
			n += 1
	return n


## The vessel each line goes out in: cups for drinks, plates for the rest.
static func vessel_of(item: Dictionary) -> String:
	return Dish.CUP if item.course == "drink" else Dish.PLATE


## Takes everything off (into the bin), keeping the ticket.
func scrape() -> void:
	for l in lines:
		for k in l.have.size():
			l.have[k] = -1.0
