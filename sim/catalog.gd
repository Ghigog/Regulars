class_name Catalog
extends RefCounted
## Everything you can buy for the restaurant. A blueprint is {"id": String, "tier": int}.
## The game sells every tier straight from the catalog. The nightly crate and the shelf
## (offer, shelve, collect_ready) are parked: tested, but nothing in the game calls them.

const MAX_TIER := 3
const SHELF_DAYS := 2
const CATEGORIES: Array[String] = ["Kitchen", "Dining", "Decor", "Build"]
const TIER_PRICE: Array[int] = [1, 2, 4]   # price multiplier for tiers 1 to 3
const TIER_JOY := 0.1   # joy a decor piece gains for each tier above the first
## "tiers" is how many tiers are sold; "up" says what a higher tier does.
## A "tool" builds the room itself and is priced per tile or per wall; a "finish"
## tool paints or papers walls. "joy" is the flat joy a guest gets on sitting down
## with this piece under their seat; beside it or only in view they get less (see Decor).
## A tiered piece gains TIER_JOY a tier.
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
	"plant": {"name": "Potted fern", "price": 20, "level": 1, "category": "Decor", "tiers": 3,
		"joy": 0.2, "blurb": "Cheers guests seated beside it, a little those who see it",
		"up": "Cheers guests more, and further away"},
	"rug": {"name": "Woven rug", "price": 25, "level": 1, "category": "Decor", "tiers": 1,
		"joy": 0.15, "blurb": "Cheers guests seated on it, a little those near"},
	"table": {"name": "Table for two", "price": 40, "level": 2, "category": "Dining", "tiers": 3,
		"blurb": "Two more seats", "up": "Two comfier seats"},
	"booth": {"name": "Booth", "price": 60, "level": 2, "category": "Dining", "tiers": 3,
		"blurb": "Two cosy bench seats", "up": "Two cosier bench seats"},
	"table4": {"name": "Table for four", "price": 90, "level": 3, "category": "Dining", "tiers": 3,
		"blurb": "Seats a group of four", "up": "Four comfier seats"},
	"stove": {"name": "Stove", "price": 50, "level": 1, "category": "Kitchen", "tiers": 3, "tool_of": "grill",
		"blurb": "Grills patties and fish", "up": "Grills faster  burns faster"},
	"fryer": {"name": "Fryer", "price": 50, "level": 1, "category": "Kitchen", "tiers": 3, "tool_of": "fry",
		"blurb": "Fries potatoes and calamari", "up": "Fries faster  burns faster"},
	"pot": {"name": "Stock pot", "price": 35, "level": 1, "category": "Kitchen", "tiers": 3, "tool_of": "boil",
		"blurb": "Boils corn, potatoes and beans", "up": "Boils faster"},
	"board": {"name": "Chopping board", "price": 25, "level": 1, "category": "Kitchen", "tiers": 3, "tool_of": "chop",
		"blurb": "Chops vegetables", "up": "A slower, kinder knife"},
	"slicer": {"name": "Slicer", "price": 30, "level": 1, "category": "Kitchen", "tiers": 3, "tool_of": "slice",
		"blurb": "Slices cheese and lemons", "up": "More time to slice"},
	"crate_bun": {"name": "Bun crate", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "bun", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_patty": {"name": "Patty fridge", "price": 20, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "patty", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_lettuce": {"name": "Lettuce crate", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "lettuce", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_tomato": {"name": "Tomato crate", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "tomato", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_onion": {"name": "Onion sack", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "onion", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_cheese": {"name": "Cheese fridge", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "cheese", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_potato": {"name": "Potato sack", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "potato", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_corn": {"name": "Corn crate", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "corn", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_soda": {"name": "Soda fountain", "price": 40, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "soda", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_roll": {"name": "Bread basket", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "roll", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_fish": {"name": "Fish icebox", "price": 25, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "fish", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_calamari": {"name": "Calamari icebox", "price": 20, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "calamari", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_lemon": {"name": "Lemon crate", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "lemon", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_courgette": {"name": "Courgette crate", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "courgette", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_pepper": {"name": "Pepper crate", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "pepper", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_new_potato": {"name": "New potato sack", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "new_potato", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_beans": {"name": "Bean crate", "price": 15, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "beans", "blurb": "Hands out ingredients. Stocked each night"},
	"crate_wine": {"name": "Wine barrel", "price": 45, "level": 1, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "wine", "blurb": "Hands out ingredients. Stocked each night"},
	"ready_lettuce": {"name": "Chopped lettuce tub", "price": 35, "level": 2, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "lettuce", "ready": true, "blurb": "Ready to use, no prep. Always plain"},
	"ready_tomato": {"name": "Sliced tomato tub", "price": 35, "level": 2, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "tomato", "ready": true, "blurb": "Ready to use, no prep. Always plain"},
	"ready_onion": {"name": "Onion rings tub", "price": 35, "level": 2, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "onion", "ready": true, "blurb": "Ready to use, no prep. Always plain"},
	"ready_cheese": {"name": "Cheese slices", "price": 35, "level": 2, "category": "Kitchen", "tiers": 1, "theme": "diner",
		"ingredient": "cheese", "ready": true, "blurb": "Ready to use, no prep. Always plain"},
	"ready_courgette": {"name": "Chopped courgette tub", "price": 35, "level": 2, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "courgette", "ready": true, "blurb": "Ready to use, no prep. Always plain"},
	"ready_pepper": {"name": "Chopped pepper tub", "price": 35, "level": 2, "category": "Kitchen", "tiers": 1, "theme": "seaside",
		"ingredient": "pepper", "ready": true, "blurb": "Ready to use, no prep. Always plain"},
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
static func tool_of(id: String) -> String:
	if not ITEMS.has(id):
		return ""
	if ITEMS[id].has("tool_of"):
		return ITEMS[id].tool_of
	var ing := ingredient_of(id)
	return "pour" if ing != "" and Pantry.is_drink(ing) else ""


static func is_build_tool(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].get("tool", false)


## A tool that paints or papers walls.
static func is_finish(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].get("finish", false)


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
		if theme != "" and item.has("theme") and item.theme != theme:
			continue
		for tier in range(1, int(item.tiers) + 1):
			var bp := {"id": id, "tier": tier}
			var text := ("%s %s %s" % [label(bp), item.category, blurb_of(id, tier)]).to_lower()
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
