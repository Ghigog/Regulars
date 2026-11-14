class_name Pantry
extends RefCounted
## Ingredients: what each one is, which tool preps it, what it adds to a dish's price
## and what it costs to stock for a night. Pure data and lookups.

## The seven prep tools. "pour" happens at the drink's own station; "none" is no step.
const TOOLS: Array[String] = ["grill", "fry", "boil", "chop", "slice", "pour", "none"]
## The tool station (a catalog id) each tool needs in the room. Pour and none need none.
const TOOL_STATION := {"grill": "stove", "fry": "fryer", "boil": "pot", "chop": "board", "slice": "slicer"}
const TOOL_NAMES := {"grill": "grill", "fry": "fryer", "boil": "pot", "chop": "chopping board", "slice": "slicer"}
const THEMES: Array[String] = ["diner", "seaside"]
const READY_FEE := 1.5   # tunable: a ready-made station costs this many times the fee to stock
## tunable: which ingredients can be bought ready-made (prepped, always plain).
const READY_MADE: Array[String] = ["lettuce", "tomato", "onion", "cheese", "courgette", "pepper"]

## worth: what it adds to an item's price. fee: what it costs to stock a night (tunable).
## colour/prepped: how it looks raw and after prep. shape: how the food models draw it.
const ITEMS := {
	"bun": {"name": "Bun", "theme": "diner", "tool": "none", "tags": ["bread"], "worth": 2, "fee": 3,
		"colour": "#d9a05b", "prepped": "#d9a05b", "shape": "bun"},
	"patty": {"name": "Patty", "theme": "diner", "tool": "grill", "tags": ["meat"], "worth": 6, "fee": 8,
		"colour": "#c96b6b", "prepped": "#6b3f2a", "shape": "patty"},
	"lettuce": {"name": "Lettuce", "theme": "diner", "tool": "chop", "tags": ["vegetable"], "worth": 1, "fee": 2,
		"colour": "#7fbf4d", "prepped": "#8fcf5d", "shape": "leaf"},
	"tomato": {"name": "Tomato", "theme": "diner", "tool": "chop", "tags": ["vegetable"], "worth": 1, "fee": 2,
		"colour": "#d9473a", "prepped": "#e0584a", "shape": "round"},
	"onion": {"name": "Onion", "theme": "diner", "tool": "chop", "tags": ["vegetable"], "worth": 1, "fee": 2,
		"colour": "#e6d3e8", "prepped": "#efe2f0", "shape": "ring"},
	"cheese": {"name": "Cheese", "theme": "diner", "tool": "slice", "tags": ["dairy"], "worth": 2, "fee": 3,
		"colour": "#f2c53d", "prepped": "#f2c53d", "shape": "slab"},
	"potato": {"name": "Fries", "theme": "diner", "tool": "fry", "tags": ["vegetable", "fried"], "worth": 4, "fee": 4,
		"colour": "#e8d9a8", "prepped": "#f0b545", "shape": "sticks"},
	"corn": {"name": "Corn cob", "theme": "diner", "tool": "boil", "tags": ["vegetable"], "worth": 3, "fee": 3,
		"colour": "#f2d45c", "prepped": "#f7c934", "shape": "cob"},
	"soda": {"name": "Soda", "theme": "diner", "tool": "pour", "tags": ["drink"], "worth": 3, "fee": 3, "drink": true,
		"colour": "#7a3b2e", "prepped": "#7a3b2e", "shape": "cup"},
	"roll": {"name": "Bread roll", "theme": "seaside", "tool": "none", "tags": ["bread"], "worth": 2, "fee": 3,
		"colour": "#d8a868", "prepped": "#d8a868", "shape": "bun"},
	"fish": {"name": "Fish fillet", "theme": "seaside", "tool": "grill", "tags": ["fish"], "worth": 7, "fee": 9,
		"colour": "#e9c9c0", "prepped": "#d9a066", "shape": "fillet"},
	"calamari": {"name": "Calamari", "theme": "seaside", "tool": "fry", "tags": ["fish", "fried"], "worth": 5, "fee": 6,
		"colour": "#eee6dc", "prepped": "#e8b04e", "shape": "ring"},
	"lemon": {"name": "Lemon", "theme": "seaside", "tool": "slice", "tags": ["fruit"], "worth": 1, "fee": 2,
		"colour": "#f5dc3c", "prepped": "#f8e66a", "shape": "round"},
	"courgette": {"name": "Courgette", "theme": "seaside", "tool": "chop", "tags": ["vegetable"], "worth": 2, "fee": 2,
		"colour": "#4f8f3a", "prepped": "#9fcf6a", "shape": "round"},
	"pepper": {"name": "Pepper", "theme": "seaside", "tool": "chop", "tags": ["vegetable"], "worth": 2, "fee": 2,
		"colour": "#d9473a", "prepped": "#e86a4a", "shape": "leaf"},
	"new_potato": {"name": "New potatoes", "theme": "seaside", "tool": "boil", "tags": ["vegetable"], "worth": 3, "fee": 3,
		"colour": "#d9c08a", "prepped": "#e6cf8f", "shape": "pebbles"},
	"beans": {"name": "Green beans", "theme": "seaside", "tool": "boil", "tags": ["vegetable"], "worth": 2, "fee": 2,
		"colour": "#5f9f45", "prepped": "#6fb04f", "shape": "sticks"},
	"wine": {"name": "White wine", "theme": "seaside", "tool": "pour", "tags": ["drink"], "worth": 5, "fee": 5, "drink": true,
		"colour": "#efe39a", "prepped": "#efe39a", "shape": "glass"},
}


static func has(id: String) -> bool:
	return ITEMS.has(id)


static func name_of(id: String) -> String:
	return str(ITEMS[id].name) if ITEMS.has(id) else id


static func tool_of(id: String) -> String:
	return str(ITEMS[id].tool)


static func is_drink(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].get("drink", false)


static func tags_of(id: String) -> Array:
	return ITEMS[id].tags


## Whether it needs a step at a tool station before it goes on a tray. Pour is done
## at the drink's own station, so a drink comes off it already prepped.
static func needs_prep(id: String) -> bool:
	return TOOL_STATION.has(tool_of(id))


## Every ingredient of a theme, in table order.
static func for_theme(theme: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ITEMS:
		if ITEMS[id].theme == theme:
			out.append(id)
	return out


static func can_be_ready(id: String) -> bool:
	return READY_MADE.has(id)


## What stocking this ingredient for a night costs, ready-made or not.
static func fee_of(id: String, ready := false) -> int:
	var fee: int = ITEMS[id].fee
	return roundi(fee * READY_FEE) if ready else fee


## The catalog id of the station that hands this ingredient out.
static func station_id(id: String, ready := false) -> String:
	return ("ready_" if ready else "crate_") + id


## The ingredient a station hands out and whether it is ready-made, or {} if the
## catalog id is not an ingredient station.
static func station_ingredient(station: String) -> Dictionary:
	for prefix in ["crate_", "ready_"]:
		if station.begins_with(prefix) and ITEMS.has(station.trim_prefix(prefix)):
			return {"id": station.trim_prefix(prefix), "ready": prefix == "ready_"}
	return {}


## The tool a tool station gives, or "" if the catalog id is not one.
static func station_tool(station: String) -> String:
	for t: String in TOOL_STATION:
		if TOOL_STATION[t] == station:
			return t
	return ""
