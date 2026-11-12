class_name Catalog
extends RefCounted
## Everything you can build, the nightly crate, and the blueprint shelf.
## A blueprint is {"id": String, "tier": int}. Shelving one returns it a tier higher.

const MAX_TIER := 3
const SHELF_DAYS := 2
const ITEMS := {
	"screen": {"name": "Partition wall", "price": 10, "level": 1, "blurb": "Blocks what guests can see."},
	"counter": {"name": "Counter", "price": 15, "level": 1, "blurb": "Somewhere to put things down."},
	"plant": {"name": "Potted fern", "price": 20, "level": 1, "blurb": "Nearby guests feel happier."},
	"table": {"name": "Table for two", "price": 40, "level": 2, "blurb": "Two more seats."},
	"stove": {"name": "Stove", "price": 80, "level": 3, "blurb": "Cook two things at once."},
}

var shelf: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


static func label(bp: Dictionary) -> String:
	var tier: int = bp.tier
	return str(ITEMS[bp.id].name) + " " + "+".repeat(tier - 1)


## Two different blueprints to choose between tonight.
func offer() -> Array[Dictionary]:
	var ids: Array = ITEMS.keys()
	var a := rng.randi_range(0, ids.size() - 1)
	var b := (a + rng.randi_range(1, ids.size() - 1)) % ids.size()
	return [{"id": ids[a], "tier": 1}, {"id": ids[b], "tier": 1}]


func can_buy(id: String, money: int, level: int) -> bool:
	return money >= int(ITEMS[id].price) and level >= int(ITEMS[id].level)


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
