class_name Pantry
extends RefCounted
## Ingredients: what each one is, which tool preps it, what it adds to a dish's price
## and what it costs to stock for a night. Pure data and lookups.

## The prep tools. "pour" happens at the drink's own station; "none" is no step.
## Grate, saw, juice, blend and steam joined in PRD 8.6, each with a tree node.
const TOOLS: Array[String] = ["grill", "fry", "boil", "chop", "slice", "grate", "saw", "juice", "blend",
	"steam", "pour", "none"]
## The tool station (a catalog id) each tool needs in the room. Pour and none need none.
const TOOL_STATION := {"grill": "stove", "fry": "fryer", "boil": "pot", "chop": "board", "slice": "slicer",
	"grate": "grater", "saw": "bread_knife", "juice": "juicer", "blend": "blender", "steam": "steamer"}
const TOOL_NAMES := {"grill": "grill", "fry": "fryer", "boil": "pot", "chop": "chopping board", "slice": "slicer",
	"grate": "grater", "saw": "bread knife", "juice": "juicer", "blend": "blender", "steam": "steamer"}
const THEMES: Array[String] = ["diner", "seaside"]
const READY_FEE := 1.5   # tunable: a ready-made station costs this many times the fee to stock
## tunable: which ingredients can be bought ready-made (prepped, always plain).
const READY_MADE: Array[String] = ["lettuce", "tomato", "onion", "cheese", "courgette", "pepper"]

## worth: what it adds to an item's price. fee: what it costs to stock a night (tunable).
## colour/prepped: how it looks raw and after prep. shape: how the food models draw it.
## "from": a kind made from another's stock at a tool (lemonade from lemons at a juicer,
## PRD 8.6); it has no box of its own and costs no fee: its source's box stocks it.
## "coat": a coating, not a bread (breadcrumbs): it never wraps a stack.
const ITEMS := {
	"bun": {"name": "Bun", "theme": "diner", "tool": "none", "tags": ["bread"], "worth": 2, "fee": 3,
		"colour": "#d9a05b", "prepped": "#d9a05b", "shape": "bun"},
	"patty": {"name": "Patty", "theme": "diner", "tool": "grill", "tags": ["meat"], "chilled": true, "worth": 6, "fee": 8,
		"colour": "#c96b6b", "prepped": "#6b3f2a", "shape": "patty"},
	"lettuce": {"name": "Lettuce", "theme": "diner", "tool": "chop", "tags": ["vegetable"], "worth": 1, "fee": 2,
		"colour": "#7fbf4d", "prepped": "#8fcf5d", "shape": "leaf"},
	"tomato": {"name": "Tomato", "theme": "diner", "tool": "chop", "tags": ["vegetable"], "worth": 1, "fee": 2,
		"colour": "#d9473a", "prepped": "#e0584a", "shape": "round"},
	"onion": {"name": "Onion", "theme": "diner", "tool": "chop", "tags": ["vegetable"], "worth": 1, "fee": 2,
		"colour": "#e6d3e8", "prepped": "#efe2f0", "shape": "ring"},
	"cheese": {"name": "Cheese", "theme": "diner", "tool": "slice", "tags": ["dairy"], "chilled": true, "worth": 2, "fee": 3,
		"colour": "#f2c53d", "prepped": "#f2c53d", "shape": "slab"},
	"potato": {"name": "Fries", "theme": "diner", "tool": "fry", "tags": ["vegetable", "fried"], "worth": 4, "fee": 4,
		"colour": "#e8d9a8", "prepped": "#f0b545", "shape": "sticks"},
	"corn": {"name": "Corn cob", "theme": "diner", "tool": "boil", "tags": ["vegetable"], "worth": 3, "fee": 3,
		"colour": "#f2d45c", "prepped": "#f7c934", "shape": "cob"},
	"soda": {"name": "Soda", "theme": "diner", "tool": "pour", "tags": ["drink"], "worth": 3, "fee": 3, "drink": true,
		"colour": "#7a3b2e", "prepped": "#7a3b2e", "shape": "cup"},
	# PRD 8.6: the new jobs' kinds (tunable worth and fees).
	"shredded_cheese": {"name": "Grated cheese", "theme": "diner", "tool": "grate", "tags": ["dairy"], "chilled": true,
		"from": "cheese", "worth": 2, "fee": 0, "colour": "#f2c53d", "prepped": "#f7d258", "shape": "shreds"},
	"sourdough": {"name": "Sourdough", "theme": "diner", "tool": "saw", "tags": ["bread"], "worth": 3, "fee": 4,
		"colour": "#c98a4a", "prepped": "#ead2a4", "shape": "loaf"},
	"steamed_corn": {"name": "Steamed corn", "theme": "diner", "tool": "steam", "tags": ["vegetable"], "from": "corn",
		"worth": 4, "fee": 0, "colour": "#f2d45c", "prepped": "#ffde4f", "shape": "cob"},
	"ice_cream": {"name": "Ice cream", "theme": "diner", "tool": "none", "tags": ["dairy"], "frozen": true,
		"worth": 3, "fee": 3, "colour": "#f6e7c8", "prepped": "#f6e7c8", "shape": "scoop"},
	"orange_juice": {"name": "Orange juice", "theme": "diner", "tool": "juice", "tags": ["drink", "fruit"], "drink": true,
		"worth": 4, "fee": 4, "colour": "#f28a1e", "prepped": "#f9a72b", "shape": "juice"},
	"milkshake": {"name": "Milkshake", "theme": "diner", "tool": "blend", "tags": ["drink", "dairy"], "drink": true,
		"from": "ice_cream", "worth": 5, "fee": 0, "colour": "#f6e7c8", "prepped": "#f4b3c4", "shape": "shake"},
	"cola": {"name": "Cola", "theme": "diner", "tool": "pour", "tags": ["drink"], "worth": 3, "fee": 3, "drink": true,
		"colour": "#3b1d16", "prepped": "#3b1d16", "shape": "cup"},
	"coffee": {"name": "Coffee", "theme": "diner", "tool": "pour", "tags": ["drink"], "worth": 3, "fee": 2, "drink": true,
		"colour": "#5a3522", "prepped": "#5a3522", "shape": "mug"},
	"roll": {"name": "Bread roll", "theme": "seaside", "tool": "none", "tags": ["bread"], "worth": 2, "fee": 3,
		"colour": "#d49a55", "prepped": "#d49a55", "shape": "roll"},
	"fish": {"name": "Fish fillet", "theme": "seaside", "tool": "grill", "tags": ["fish"], "chilled": true, "worth": 7, "fee": 9,
		"colour": "#f27d5e", "prepped": "#ef8a5e", "shape": "fillet"},
	"calamari": {"name": "Calamari", "theme": "seaside", "tool": "fry", "tags": ["fish", "fried"], "chilled": true, "worth": 5, "fee": 6,
		"colour": "#f1e2dc", "prepped": "#e8b04e", "shape": "squid"},
	"lemon": {"name": "Lemon", "theme": "seaside", "tool": "slice", "tags": ["fruit"], "worth": 1, "fee": 2,
		"colour": "#f5d936", "prepped": "#f8e46a", "shape": "lemon"},
	"courgette": {"name": "Courgette", "theme": "seaside", "tool": "chop", "tags": ["vegetable"], "worth": 2, "fee": 2,
		"colour": "#3f7f34", "prepped": "#d9e6a0", "shape": "courgette"},
	"pepper": {"name": "Pepper", "theme": "seaside", "tool": "chop", "tags": ["vegetable"], "worth": 2, "fee": 2,
		"colour": "#d9473a", "prepped": "#e0503e", "shape": "pepper"},
	"new_potato": {"name": "New potatoes", "theme": "seaside", "tool": "boil", "tags": ["vegetable"], "worth": 3, "fee": 3,
		"colour": "#c9a96e", "prepped": "#eed58a", "shape": "pebbles"},
	"beans": {"name": "Green beans", "theme": "seaside", "tool": "boil", "tags": ["vegetable"], "worth": 2, "fee": 2,
		"colour": "#5f9f45", "prepped": "#72bf4a", "shape": "beans"},
	"wine": {"name": "White wine", "theme": "seaside", "tool": "pour", "tags": ["drink"], "worth": 5, "fee": 5, "drink": true,
		"colour": "#e8cf5e", "prepped": "#e8cf5e", "shape": "glass"},
	"breadcrumbs": {"name": "Breadcrumbs", "theme": "seaside", "tool": "grate", "tags": ["bread"], "coat": true,
		"worth": 1, "fee": 2, "colour": "#c98f4e", "prepped": "#e2b466", "shape": "crumbs"},
	"crusty_loaf": {"name": "Crusty loaf", "theme": "seaside", "tool": "saw", "tags": ["bread"], "worth": 3, "fee": 4,
		"colour": "#b5722f", "prepped": "#e8c48a", "shape": "loaf"},
	"mussels": {"name": "Mussels", "theme": "seaside", "tool": "steam", "tags": ["fish"], "chilled": true,
		"worth": 6, "fee": 7, "colour": "#2f3a52", "prepped": "#f2a052", "shape": "mussels"},
	"lemonade": {"name": "Lemonade", "theme": "seaside", "tool": "juice", "tags": ["drink", "fruit"], "drink": true,
		"from": "lemon", "worth": 4, "fee": 0, "colour": "#f5d936", "prepped": "#f7ee9c", "shape": "juice"},
	"fruit_smoothie": {"name": "Fruit smoothie", "theme": "seaside", "tool": "blend", "tags": ["drink", "fruit"], "drink": true,
		"worth": 5, "fee": 5, "colour": "#d9475a", "prepped": "#ea7b97", "shape": "shake"},
	"red_wine": {"name": "Red wine", "theme": "seaside", "tool": "pour", "tags": ["drink"], "worth": 5, "fee": 5, "drink": true,
		"colour": "#7a1f2e", "prepped": "#7a1f2e", "shape": "glass"},
	"ale": {"name": "Ale", "theme": "seaside", "tool": "pour", "tags": ["drink"], "worth": 4, "fee": 4, "drink": true,
		"colour": "#d9962e", "prepped": "#d9962e", "shape": "pint"},
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


## Bread wraps a stack when it is the one bread in it: a heel below, a top above.
## A coating (breadcrumbs) is bread to taste but never wraps.
static func is_bread(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].tags.has("bread") and not ITEMS[id].get("coat", false)


## The kind whose box stocks this one: its "from" (lemonade: lemon), else itself.
static func source_of(id: String) -> String:
	return str(ITEMS[id].get("from", id)) if ITEMS.has(id) else id


## A kind made from another's stock (lemonade, milkshake, steamed corn).
static func is_derived(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].has("from")


## The kinds made from this one at a tool, in table order (lemon: lemonade).
static func made_from(id: String) -> Array[String]:
	var out: Array[String] = []
	for k: String in ITEMS:
		if str(ITEMS[k].get("from", "")) == id:
			out.append(k)
	return out


## A drink poured from a dispenser (soda, cola, wine, ale), not made at a tool.
static func is_poured(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].tool == "pour"


## Whether a kind has a box in the Pantry: not a dispenser's drink, not a derived kind.
static func has_box(id: String) -> bool:
	return ITEMS.has(id) and not is_poured(id) and not is_derived(id)


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


## The catalog id of the box of this ingredient (PRD 8.4): "box_patty", or "ready_cheese"
## for the ready-made one.
static func box_id(id: String, ready := false) -> String:
	return ("ready_" if ready else "box_") + id


## The ingredient a box (or a plain kind) holds and whether it is ready-made, or {}
## if it is neither.
static func station_ingredient(box: String) -> Dictionary:
	if ITEMS.has(box):
		return {"id": box, "ready": false}
	for prefix in ["box_", "ready_"]:
		if box.begins_with(prefix) and ITEMS.has(box.trim_prefix(prefix)):
			return {"id": box.trim_prefix(prefix), "ready": prefix == "ready_"}
	return {}


## The ingredient kind of a box id or a kind ("" if neither).
static func kind_of(box: String) -> String:
	return str(station_ingredient(box).get("id", ""))


## The tool a tool station gives, or "" if the catalog id is not one.
static func station_tool(station: String) -> String:
	for t: String in TOOL_STATION:
		if TOOL_STATION[t] == station:
			return t
	return ""
