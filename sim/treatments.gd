class_name Treatments
extends RefCounted
## Floor treatments (PRD 9.5): cleaner, primer and finish, and their tree steps. Each is
## laid a cell at a time with the floor drag at night, one per cell, and lasts one day of
## service; while switched on it is re-laid every night. Laying is free, however many
## tiles: the cost is the product. A treatment's box is restocked every night like a
## food box, for a flat nightly fee ("fee") whatever the number of tiles, paid at the
## door with the stock and listed on the restock note (review, item 8, as changed by the
## owner). Switched off, it is not restocked and costs nothing. It is laid only while its
## box is stored somewhere (a storage slot, never with food, never in a fridge). The box
## is stocked from a counter's card, like food, and upgraded on that card's tree.
## Pure data and lookups.

## Each treatment: its name, its nightly box fee ("fee", in line with the food boxes'
## $2 to $8), its place in the tree ("parent", "step"), what the box's tree step costs
## ("unlock", the whole price from the root, which is free), and its effects. (all tunable)
## "one_press": dirt mops off in one press, whatever its level.
## "no_track": dirt is not carried off the cell by feet.
## "block": the chance a level landing here does not (tracked dirt still comes in).
## "speed": the multiplier on anyone's speed on it. "joy": decor joy, like a floor.
## "shows": how much more dirt on it puts guests off by sight (it shows more on a shine).
const ITEMS := {
	"cleaner": {"fee": 2, "name": "Floor cleaner", "unlock": 0, "one_press": true,
		"blurb": "Dirt mops off in one press, whatever the level"},
	"strong_cleaner": {"fee": 3, "name": "Strong cleaner", "unlock": 25, "parent": "cleaner",
		"step": "efficient", "one_press": true, "no_track": true,
		"blurb": "Mops off in one press, and feet do not track dirt off it"},
	"primer": {"fee": 3, "name": "Primer", "unlock": 40, "parent": "cleaner", "step": "specialist",
		"block": 0.4, "blurb": "Two in five spills do not land on it. Tracked dirt still does"},
	"sealing_primer": {"fee": 5, "name": "Sealing primer", "unlock": 90, "parent": "primer",
		"step": "efficient", "block": 0.6, "blurb": "Three in five spills do not land on it"},
	"finish": {"fee": 4, "name": "Floor finish", "unlock": 60, "parent": "cleaner", "step": "specialist",
		"speed": 1.1, "joy": 0.05, "shows": 1.25,
		"blurb": "Everyone a little faster on it, and a little joy. Dirt shows more"},
	"high_gloss": {"fee": 6, "name": "High gloss", "unlock": 150, "parent": "finish", "step": "specialist",
		"speed": 1.2, "joy": 0.1, "shows": 1.5,
		"blurb": "Faster still and more joy. Dirt shows a lot more"},
}

const BOX_PREFIX := "box_"
## Parked (owner's review of night zero): cleaning liquids went into the mop bucket's
## tree instead, so no treatment's box is sold. The one switch that puts them back.
const ON_SALE := false
const TOOL_PREFIX := "treat_"


static func has(key: String) -> bool:
	return ITEMS.has(key)


static func name_of(key: String) -> String:
	return str(ITEMS[key].name) if ITEMS.has(key) else ""


## A treatment's box fee a night, whatever the number of tiles it is laid on.
static func fee_of(key: String) -> int:
	return int(ITEMS[key].fee) if ITEMS.has(key) else 0


static func fee_words(key: String) -> String:
	return "$%d a night" % fee_of(key)


## The catalog id of a treatment's box ("box_cleaner") and of its laying tool ("treat_cleaner").
static func box_id(key: String) -> String:
	return BOX_PREFIX + key


static func tool_id(key: String) -> String:
	return TOOL_PREFIX + key


## The treatment a box id or a laying tool id stands for, or "".
static func key_of(id: String) -> String:
	for prefix: String in [BOX_PREFIX, TOOL_PREFIX]:
		if id.begins_with(prefix) and ITEMS.has(id.trim_prefix(prefix)):
			return id.trim_prefix(prefix)
	return ""


static func is_box(id: String) -> bool:
	return id.begins_with(BOX_PREFIX) and key_of(id) != ""


static func is_laying_tool(id: String) -> bool:
	return id.begins_with(TOOL_PREFIX) and key_of(id) != ""


# ---------- The tree ----------

static func parent(key: String) -> String:
	return str(ITEMS[key].get("parent", "")) if ITEMS.has(key) else ""


static func step(key: String) -> String:
	return str(ITEMS[key].get("step", ""))


static func children(key: String) -> Array[String]:
	var out: Array[String] = []
	for k: String in ITEMS:
		if parent(k) == key:
			out.append(k)
	return out


static func is_root(key: String) -> bool:
	return ITEMS.has(key) and parent(key) == ""


## The box's whole worth in its tree: what reaching it cost from the free root box.
static func unlock(key: String) -> int:
	return int(ITEMS[key].unlock)


# ---------- Effects ----------

static func one_press(key: String) -> bool:
	return ITEMS.has(key) and ITEMS[key].get("one_press", false)


static func no_track(key: String) -> bool:
	return ITEMS.has(key) and ITEMS[key].get("no_track", false)


static func block(key: String) -> float:
	return float(ITEMS[key].get("block", 0.0)) if ITEMS.has(key) else 0.0


static func speed(key: String) -> float:
	return float(ITEMS[key].get("speed", 1.0)) if ITEMS.has(key) else 1.0


static func joy(key: String) -> float:
	return float(ITEMS[key].get("joy", 0.0)) if ITEMS.has(key) else 0.0


static func shows(key: String) -> float:
	return float(ITEMS[key].get("shows", 1.0)) if ITEMS.has(key) else 1.0


# ---------- A night's laying ----------

## What re-laying costs tonight. `laid` is Vector2i -> key; `off` is key -> true for the
## treatments switched off; `boxed` is key -> true for those with a box in storage.
## Returns key -> {"cells": n, "fee": its box's nightly fee, "on"}, for every treatment
## laid anywhere or with a box stored. The fee is flat, however many tiles ("cells" is
## only counted for the note); one switched off or with no box stored costs nothing.
static func night_lines(laid: Dictionary, off: Dictionary, boxed: Dictionary) -> Dictionary:
	var out := {}
	for c: Vector2i in laid:
		var k: String = laid[c]
		if not out.has(k):
			out[k] = {"cells": 0, "fee": 0, "on": false}
		out[k].cells += 1
	for k: String in boxed:
		if not out.has(k):
			out[k] = {"cells": 0, "fee": 0, "on": false}
	for k: String in out:
		out[k].on = not off.has(k) and boxed.has(k)
		out[k].fee = fee_of(k) if out[k].on else 0
	return out


## The night's whole treatment bill: each stocked box switched on, its flat fee.
static func night_cost(laid: Dictionary, off: Dictionary, boxed: Dictionary) -> int:
	var lines := night_lines(laid, off, boxed)
	var sum := 0
	for k: String in lines:
		sum += int(lines[k].fee)
	return sum


## The cells that are treated for a day of service: laid, switched on, box stored.
static func active(laid: Dictionary, off: Dictionary, boxed: Dictionary) -> Dictionary:
	var out := {}
	for c: Vector2i in laid:
		var k: String = laid[c]
		if not off.has(k) and boxed.has(k):
			out[c] = k
	return out
