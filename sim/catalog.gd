class_name Catalog
extends RefCounted
## Everything you can buy for the restaurant. A blueprint is {"id": String, "tier": int}.
## The game sells every tier straight from the catalog. The nightly crate and the shelf
## (offer, shelve, collect_ready) are parked: tested, but nothing in the game calls them.

const MAX_TIER := 3
const SHELF_DAYS := 2
const CATEGORIES: Array[String] = ["Kitchen", "Dining", "Decor", "Build"]
const TIER_PRICE: Array[int] = [1, 2, 4]   # price multiplier for tiers 1 to 3
## "tiers" is how many tiers are sold; "up" says what a higher tier does.
## A "tool" builds the room itself and is priced per tile or per wall; a "finish"
## tool paints or papers walls. "joy" is how much a seated guest's joy rises each
## second from a floor under them, a finish near them or a rug under them.
const ITEMS := {
	"floor_tile": {"name": "Tiled floor", "price": 5, "level": 1, "category": "Build", "tiers": 1, "tool": true,
		"blurb": "Grows the room  $5 a tile"},
	"floor_planks": {"name": "Plank floor", "price": 5, "level": 1, "category": "Build", "tiers": 1, "tool": true,
		"blurb": "Grows the room  $5 a tile"},
	"floor_parquet": {"name": "Parquet floor", "price": 10, "level": 2, "category": "Build", "tiers": 1, "tool": true,
		"joy": 0.005, "blurb": "Guests seated on it are happier  $10 a tile"},
	"floor_marble": {"name": "Marble floor", "price": 20, "level": 3, "category": "Build", "tiers": 1, "tool": true,
		"joy": 0.01, "blurb": "Guests seated on it are much happier  $20 a tile"},
	"paint": {"name": "Sage paint", "price": 5, "level": 1, "category": "Build", "tiers": 1, "tool": true, "finish": true,
		"joy": 0.003, "blurb": "Cheers guests seated near the wall  $5 a length"},
	"paper_stripe": {"name": "Striped wallpaper", "price": 10, "level": 2, "category": "Build", "tiers": 1, "tool": true, "finish": true,
		"joy": 0.006, "blurb": "Cheers guests seated near the wall  $10 a length"},
	"paper_rose": {"name": "Rose wallpaper", "price": 20, "level": 3, "category": "Build", "tiers": 1, "tool": true, "finish": true,
		"joy": 0.01, "blurb": "Delights guests seated near the wall  $20 a length"},
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
		"blurb": "Cheers nearby guests", "up": "Cheers guests further away"},
	"rug": {"name": "Woven rug", "price": 25, "level": 1, "category": "Decor", "tiers": 1,
		"joy": 0.005, "blurb": "Cheers guests seated on it"},
	"table": {"name": "Table for two", "price": 40, "level": 2, "category": "Dining", "tiers": 3,
		"blurb": "Two more seats", "up": "Two comfier seats"},
	"booth": {"name": "Booth", "price": 60, "level": 2, "category": "Dining", "tiers": 3,
		"blurb": "Two cosy bench seats", "up": "Two cosier bench seats"},
	"table4": {"name": "Table for four", "price": 90, "level": 3, "category": "Dining", "tiers": 3,
		"blurb": "Seats a group of four", "up": "Four comfier seats"},
	"stove": {"name": "Stove", "price": 80, "level": 3, "category": "Kitchen", "tiers": 3,
		"blurb": "Cook two things at once", "up": "Cooks faster  burns faster"},
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


static func is_build_tool(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].get("tool", false)


## A tool that paints or papers walls.
static func is_finish(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].get("finish", false)


## Joy per second a seated guest gets from this floor, finish or rug; 0 for none.
static func joy_of(id: String) -> float:
	return float(ITEMS[id].get("joy", 0.0)) if ITEMS.has(id) else 0.0


## Each tier above the first needs one more level.
static func level_of(id: String, tier := 1) -> int:
	return int(ITEMS[id].level) + tier - 1


static func blurb_of(id: String, tier := 1) -> String:
	return ITEMS[id].up if tier > 1 else ITEMS[id].blurb


func can_buy(id: String, money: int, level: int, tier := 1) -> bool:
	return tier >= 1 and tier <= int(ITEMS[id].tiers) and money >= price_of(id, tier) and level >= level_of(id, tier)


## Everything for sale that matches, cheapest first. `query` is matched against the
## name, the category and what the piece does; an empty query or category matches all.
static func search(query := "", category := "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var words := query.strip_edges().to_lower().split(" ", false)
	for id: String in ITEMS:
		var item: Dictionary = ITEMS[id]
		if category != "" and item.category != category:
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
