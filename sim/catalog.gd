class_name Catalog
extends RefCounted
## Everything you can buy for the restaurant. A blueprint is {"id": String, "tier": int}.
## The shop sells tier 1 and roots only; higher tiers and tree nodes are bought in a
## piece's upgrade tree (Upgrades). The nightly crate and the shelf
## (offer, shelve, collect_ready) are parked: tested, but nothing in the game calls them.

const MAX_TIER := 3
const SHELF_DAYS := 2
const CATEGORIES: Array[String] = ["Kitchen", "Pantry", "Dining", "Decor", "Build"]
const TIER_PRICE: Array[int] = [1, 2, 4]   # price multiplier for tiers 1 to 3
## PRD 10: the desk is kept out of the shop until helpers can work (10.6). The one
## switch that puts every "staff" piece on sale.
const STAFF_ON_SALE := false
const TIER_JOY := 0.1   # joy a decor piece gains for each tier above the first
## "tiers" is how many tiers are sold; "up" says what a higher tier does.
## A "tool" builds the room itself and is priced per tile or per wall; a "finish"
## tool paints or papers walls. "joy" is the flat joy a guest gets on sitting down
## with this piece under their seat; beside it or only in view they get less (see Decor).
## A tiered piece gains TIER_JOY a tier. "reach" (decor that stands on a cell) is how
## many cells off it is seen at its first tier; each tier above sees one further.
## "theme" limits a piece to one theme's shop (none: sold in every theme).
const ITEMS := {
	"floor_tile": {"name": "Tiled floor", "price": 5, "level": 1, "category": "Build", "tiers": 1, "tool": true,
		"blurb": "Grows the room  $5 a tile"},
	"floor_planks": {"name": "Plank floor", "price": 5, "level": 1, "category": "Build", "tiers": 1, "tool": true,
		"blurb": "Grows the room  $5 a tile"},
	"floor_parquet": {"name": "Parquet floor", "price": 10, "level": 2, "category": "Build", "tiers": 1, "tool": true,
		"joy": 0.1, "blurb": "Cheers guests seated on it, a little those near  $10 a tile"},
	"floor_marble": {"name": "Marble floor", "price": 20, "level": 3, "category": "Build", "tiers": 1, "tool": true,
		"joy": 0.2, "blurb": "Delights guests seated on it, cheers those near  $20 a tile"},
	"paint": {"name": "Sage paint", "price": 5, "level": 1, "category": "Build", "tiers": 1, "tool": true, "finish": true,
		"joy": 0.08, "blurb": "Cheers guests seated beside the wall  $5 a length"},
	"paper_stripe": {"name": "Striped wallpaper", "price": 10, "level": 2, "category": "Build", "tiers": 1, "tool": true, "finish": true,
		"joy": 0.14, "blurb": "Cheers guests seated beside the wall  $10 a length"},
	"paper_rose": {"name": "Rose wallpaper", "price": 20, "level": 3, "category": "Build", "tiers": 1, "tool": true, "finish": true,
		"joy": 0.2, "blurb": "Delights guests seated beside the wall  $20 a length"},
	"wall": {"name": "Wall", "price": 5, "level": 1, "category": "Build", "tiers": 1, "tool": true,
		"blurb": "Divides the room  $5 a length"},
	"door": {"name": "Door", "price": 20, "level": 1, "category": "Build", "tiers": 1, "tool": true,
		"blurb": "A way through that hides the view"},
	"arch": {"name": "Archway", "price": 15, "level": 1, "category": "Build", "tiers": 1, "tool": true,
		"blurb": "An open way through"},
	"screen": {"name": "Partition wall", "price": 10, "level": 1, "category": "Build", "tiers": 1,
		"blurb": "Blocks guests' view"},
	"counter": {"name": "Counter", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1,
		"blurb": "Extra worktop"},
	# The wall layer (PRD 8.5): a shelf stands low, or hangs high over another piece on a
	# wall; a cabinet and a hood only hang. Prices match Kitchen.NODES.
	"shelf": {"name": "Wall shelf", "price": 10, "level": 1, "category": "Kitchen", "tiers": 1,
		"blurb": "Stores one kind. Low, or high on a wall over another piece"},
	"cabinet": {"name": "Wall cabinet", "price": 20, "level": 1, "category": "Kitchen", "tiers": 1,
		"blurb": "Hangs on a wall over another piece. Stores one kind"},
	"hood": {"name": "Hood", "price": 30, "level": 1, "category": "Kitchen", "tiers": 1,
		"blurb": "Hangs on the wall over a stove and cuts its grease"},
	"plant": {"name": "Potted fern", "price": 20, "level": 1, "category": "Decor", "tiers": 3, "theme": "diner",
		"joy": 0.2, "reach": 3, "blurb": "Cheers guests seated beside it, a little those who see it",
		"up": "Cheers guests more, and further away"},
	"flower_stand": {"name": "Flower stand", "price": 15, "level": 1, "category": "Decor", "tiers": 1,
		"joy": 0.1, "reach": 1, "blurb": "Cheers guests seated right beside it"},
	"coat_stand": {"name": "Coat stand", "price": 20, "level": 1, "category": "Decor", "tiers": 1,
		"joy": 0.06, "reach": 1, "blurb": "Somewhere for the coats of guests beside it"},
	"floor_lamp": {"name": "Floor lamp", "price": 30, "level": 2, "category": "Decor", "tiers": 1,
		"joy": 0.12, "reach": 1, "blurb": "A warm light at night. Cheers guests beside it"},
	"gumball": {"name": "Gumball machine", "price": 45, "level": 2, "category": "Decor", "tiers": 1, "theme": "diner",
		"joy": 0.15, "reach": 2, "blurb": "Cheers guests beside it, a little those near"},
	"jukebox": {"name": "Jukebox", "price": 120, "level": 4, "category": "Decor", "tiers": 3, "theme": "diner",
		"joy": 0.25, "reach": 4, "blurb": "The diner's showpiece. Cheers guests across the room",
		"up": "Cheers guests more, and further away"},
	"palm": {"name": "Potted palm", "price": 20, "level": 1, "category": "Decor", "tiers": 3, "theme": "seaside",
		"joy": 0.2, "reach": 3, "blurb": "Cheers guests seated beside it, a little those who see it",
		"up": "Cheers guests more, and further away"},
	"lantern": {"name": "Ship's lantern", "price": 45, "level": 2, "category": "Decor", "tiers": 1, "theme": "seaside",
		"joy": 0.15, "reach": 2, "blurb": "Cheers guests beside it, a little those near"},
	"aquarium": {"name": "Aquarium", "price": 120, "level": 4, "category": "Decor", "tiers": 3, "theme": "seaside",
		"joy": 0.25, "reach": 4, "blurb": "The seaside's showpiece. Cheers guests across the room",
		"up": "Cheers guests more, and further away"},
	"rug": {"name": "Woven rug", "price": 25, "level": 1, "category": "Decor", "tiers": 1,
		"joy": 0.15, "blurb": "Cheers guests seated on it, a little those near"},
	"table": {"name": "Table for two", "price": 40, "level": 2, "category": "Dining", "tiers": 3,
		"blurb": "Two more seats", "up": "Two comfier seats"},
	"booth": {"name": "Booth", "price": 60, "level": 2, "category": "Dining", "tiers": 3,
		"blurb": "Two cosy bench seats", "up": "Two cosier bench seats"},
	"table4": {"name": "Table for four", "price": 90, "level": 3, "category": "Dining", "tiers": 3,
		"blurb": "Seats a group of four", "up": "Four comfier seats"},
	"stool": {"name": "Counter stool", "price": 25, "level": 1, "category": "Dining", "tiers": 3,
		"blurb": "One seat, for guests who come alone", "up": "A comfier seat"},
	"desk": {"name": "Desk", "price": 40, "level": 1, "category": "Kitchen", "tiers": 1, "staff": true,
		"blurb": "Write job posts and read CVs. One desk per employee"},
	"bin": {"name": "Bin", "price": 30, "level": 2, "category": "Kitchen", "tiers": 1,
		"blurb": "Another bin. The chef uses the nearest"},
	"dish_rack": {"name": "Dish rack", "price": 50, "level": 3, "category": "Kitchen", "tiers": 1,
		"blurb": "Beside a sink: it takes two more trays before it looks piled"},
	"sink": {"name": "Sink", "price": 70, "level": 3, "category": "Kitchen", "tiers": 1,
		"blurb": "Another place to wash up"},
	"stove": {"name": "Stove", "price": 50, "level": 1, "category": "Kitchen", "tiers": 1, "tool_of": "grill",
		"blurb": "Grills patties and fish. Boils and fries at a pinch. Upgrade it in hand"},
	"fryer": {"name": "Fryer", "price": 70, "level": 1, "category": "Kitchen", "tiers": 1, "tool_of": "fry",
		"blurb": "Fries potatoes and calamari"},
	"pot": {"name": "Stock pot", "price": 60, "level": 1, "category": "Kitchen", "tiers": 1, "tool_of": "boil",
		"blurb": "Boils corn, potatoes and beans"},
	"board": {"name": "Chopping board", "price": 25, "level": 1, "category": "Kitchen", "tiers": 1, "tool_of": "chop",
		"blurb": "Chops vegetables. Slices at a pinch. Upgrade it in hand"},
	"slicer": {"name": "Slicer", "price": 60, "level": 1, "category": "Kitchen", "tiers": 1, "tool_of": "slice",
		"blurb": "Slices cheese and lemons"},
	"box_bun": {"name": "Bun box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "bun", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_patty": {"name": "Patty box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "patty", "box": true, "blurb": "Stocks it every night. A fridge slot only"},
	"box_lettuce": {"name": "Lettuce box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "lettuce", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_tomato": {"name": "Tomato box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "tomato", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_onion": {"name": "Onion sack", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "onion", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_cheese": {"name": "Cheese box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "cheese", "box": true, "blurb": "Stocks it every night. A fridge slot only"},
	"box_potato": {"name": "Potato sack", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "potato", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_corn": {"name": "Corn box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "corn", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_roll": {"name": "Bread basket", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "roll", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_fish": {"name": "Fish box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "fish", "box": true, "blurb": "Stocks it every night. A fridge slot only"},
	"box_calamari": {"name": "Calamari box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "calamari", "box": true, "blurb": "Stocks it every night. A fridge slot only"},
	"box_lemon": {"name": "Lemon box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "lemon", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_courgette": {"name": "Courgette box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "courgette", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_pepper": {"name": "Pepper box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "pepper", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_new_potato": {"name": "New potato sack", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "new_potato", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	"box_beans": {"name": "Bean box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "beans", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge"},
	# PRD 8.6: boxes of the new kinds. Derived kinds (lemonade, milkshake, steamed corn) and
	# dispenser drinks have none.
	"box_shredded_cheese": {"name": "Cheese block box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "shredded_cheese", "box": true, "blurb": "Stocks it every night. A fridge slot only. Grate it"},
	"box_sourdough": {"name": "Sourdough loaves", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "sourdough", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge. Saw it"},
	"box_orange_juice": {"name": "Orange crate", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "orange_juice", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge. Juice it"},
	"box_ice_cream": {"name": "Ice cream tub", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "ice_cream", "box": true, "blurb": "Stocks it every night. A freezer slot only. Blend it for milkshakes"},
	"box_breadcrumbs": {"name": "Stale bread bag", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "breadcrumbs", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge. Grate it to coat fish"},
	"box_crusty_loaf": {"name": "Loaf basket", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "crusty_loaf", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge. Saw it"},
	"box_mussels": {"name": "Mussel net", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "mussels", "box": true, "blurb": "Stocks it every night. A fridge slot only. Steam them"},
	"box_fruit_smoothie": {"name": "Berry box", "price": 0, "level": 1, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "fruit_smoothie", "box": true, "blurb": "Stocks it every night. A counter slot, or a fridge. Blend it"},
	# PRD 8.6: the new jobs' tools. Reached only through their trees, so never in the shop.
	"grater": {"name": "Grater", "price": 70, "level": 1, "category": "Kitchen", "tiers": 1, "tool_of": "grate",
		"blurb": "Grates cheese and breadcrumbs"},
	"bread_knife": {"name": "Bread knife", "price": 45, "level": 1, "category": "Kitchen", "tiers": 1, "tool_of": "saw",
		"blurb": "Saws loaves"},
	"juicer": {"name": "Juicer", "price": 90, "level": 1, "category": "Kitchen", "tiers": 1, "tool_of": "juice",
		"blurb": "Juices oranges and lemons"},
	"blender": {"name": "Blender", "price": 150, "level": 1, "category": "Kitchen", "tiers": 1, "tool_of": "blend",
		"blurb": "Blends milkshakes and smoothies"},
	"steamer": {"name": "Steamer", "price": 100, "level": 1, "category": "Kitchen", "tiers": 1, "tool_of": "steam",
		"blurb": "Steams corn and mussels"},
	"coffee_machine": {"name": "Coffee machine", "price": 90, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "coffee", "blurb": "Pours coffee. Holds its own, no slot needed"},
	"beer_tap": {"name": "Beer tap", "price": 90, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "ale", "blurb": "Pours ale. Holds its own, no slot needed"},
	"fountain": {"name": "Soda fountain", "price": 40, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "soda", "blurb": "Pours soda. Holds its own, no slot needed"},
	"wine_barrel": {"name": "Wine barrel", "price": 45, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "wine", "blurb": "Pours white wine. Holds its own, no slot needed"},
	"ready_lettuce": {"name": "Chopped lettuce tub", "price": 0, "level": 2, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "lettuce", "box": true, "ready": true, "blurb": "Ready to use, no prep. Always plain. A counter slot, or a fridge"},
	"ready_tomato": {"name": "Sliced tomato tub", "price": 0, "level": 2, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "tomato", "box": true, "ready": true, "blurb": "Ready to use, no prep. Always plain. A counter slot, or a fridge"},
	"ready_onion": {"name": "Onion rings tub", "price": 0, "level": 2, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "onion", "box": true, "ready": true, "blurb": "Ready to use, no prep. Always plain. A counter slot, or a fridge"},
	"ready_cheese": {"name": "Cheese slices", "price": 0, "level": 2, "category": "Pantry", "tiers": 1, "theme": "diner",
		"ingredient": "cheese", "box": true, "ready": true, "blurb": "Ready to use, no prep. Always plain. A fridge slot only"},
	"ready_courgette": {"name": "Chopped courgette tub", "price": 0, "level": 2, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "courgette", "box": true, "ready": true, "blurb": "Ready to use, no prep. Always plain. A counter slot, or a fridge"},
	"ready_pepper": {"name": "Chopped pepper tub", "price": 0, "level": 2, "category": "Pantry", "tiers": 1, "theme": "seaside",
		"ingredient": "pepper", "box": true, "ready": true, "blurb": "Ready to use, no prep. Always plain. A counter slot, or a fridge"},
}

var shelf: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


static func label(bp: Dictionary) -> String:
	var tier: int = bp.tier
	return str(ITEMS[bp.id].name) + (" " + "+".repeat(tier - 1) if tier > 1 else "")


## Two different blueprints to choose between tonight.
func offer() -> Array[Dictionary]:
	var ids: Array = ITEMS.keys()
	var a := rng.randi_range(0, ids.size() - 1)
	var b := (a + rng.randi_range(1, ids.size() - 1)) % ids.size()
	return [{"id": ids[a], "tier": 1}, {"id": ids[b], "tier": 1}]


static func price_of(id: String, tier := 1) -> int:
	return int(ITEMS[id].price) * TIER_PRICE[tier - 1]


## The ingredient a station hands out ("" if it is not an ingredient station).
static func ingredient_of(id: String) -> String:
	return str(ITEMS[id].get("ingredient", "")) if ITEMS.has(id) else ""


## The prep tool a piece is ("" if none). A drink's station is its own pour tool.
## A box of one ingredient kind, stocked by placing it in a storage slot (PRD 8.4).
static func is_box(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].get("box", false)


static func tool_of(id: String) -> String:
	if not ITEMS.has(id):
		return ""
	if ITEMS[id].has("tool_of"):
		return ITEMS[id].tool_of
	var ing := ingredient_of(id)
	if is_box(id):
		return ""
	return "pour" if ing != "" and Pantry.is_drink(ing) else ""


static func is_build_tool(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].get("tool", false)


## A tool that paints or papers walls.
static func is_finish(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].get("finish", false)


## Whether a theme sells this piece: an entry with no "theme" is sold in every theme,
## and an empty theme matches everything. The theme id is passed in, never looked up.
static func sold_in(id: String, theme: String) -> bool:
	if not ITEMS.has(id) or (ITEMS[id].get("staff", false) and not STAFF_ON_SALE):
		return false
	return theme == "" or not ITEMS[id].has("theme") or ITEMS[id].theme == theme


## A decor piece that stands on one cell and is seen from "reach" cells (a fern,
## a jukebox); not a floor, finish or rug.
static func is_decor_piece(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].has("reach")


## The flat joy this piece gives a guest with it under their seat; a finish or fern
## is at best beside them, so gives half (see Decor). 0 for none.
static func joy_of(id: String, tier := 1) -> float:
	if not ITEMS.has(id) or not ITEMS[id].has("joy"):
		return 0.0
	return float(ITEMS[id].joy) + TIER_JOY * (tier - 1)


## Each tier above the first needs one more level.
static func level_of(id: String, tier := 1) -> int:
	return int(ITEMS[id].level) + tier - 1


static func blurb_of(id: String, tier := 1) -> String:
	return ITEMS[id].up if tier > 1 else ITEMS[id].blurb


func can_buy(id: String, money: int, level: int, tier := 1) -> bool:
	return tier >= 1 and tier <= int(ITEMS[id].tiers) and money >= price_of(id, tier) and level >= level_of(id, tier)


## Everything for sale that matches, cheapest first. `query` is matched against the
## name, the category and what the piece does; an empty query or category matches all.
static func search(query := "", category := "", theme := "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var words := query.strip_edges().to_lower().split(" ", false)
	for id: String in ITEMS:
		var item: Dictionary = ITEMS[id]
		if category != "" and item.category != category:
			continue
		if not sold_in(id, theme):
			continue
		var node := Kitchen.node_of(id)
		if node != "" and not Kitchen.is_root(node):
			continue   # reached only through its tree (PRD 8.3)
		var bp := {"id": id, "tier": 1}   # higher tiers are steps in the piece's tree now
		var text := ("%s %s %s" % [label(bp), item.category, blurb_of(id, 1)]).to_lower()
		var hit := true
		for w in words:
			hit = hit and text.contains(w)
		if hit:
			found.append(bp)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := price_of(a.id, a.tier)
		var pb := price_of(b.id, b.tier)
		return pa < pb if pa != pb else label(a) < label(b))
	return found


func can_shelve(bp: Dictionary) -> bool:
	return int(bp.tier) < MAX_TIER


func shelve(bp: Dictionary, day: int) -> void:
	shelf.append({"id": bp.id, "tier": int(bp.tier) + 1, "ready_day": day + SHELF_DAYS})


## Removes and returns the shelved blueprints that have finished improving.
func collect_ready(day: int) -> Array[Dictionary]:
	var ready: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for s in shelf:
		if int(s.ready_day) <= day:
			ready.append({"id": s.id, "tier": s.tier})
		else:
			waiting.append(s)
	shelf = waiting
	return ready
