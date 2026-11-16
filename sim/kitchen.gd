class_name Kitchen
extends RefCounted
## The kitchen as cells (PRD 8): each cell holds a base (counter, shelf or tall piece),
## a top (one tool, on a counter only) and, against a wall, a high piece (cabinet, shelf,
## hood). Storage slots, the chilled rule and the upgrade trees live here. Pure logic:
## no scene dependencies.

## Tool quality: the minigame's difficulty. All tunable.
const BASE := 1.0             # a base tool at its own job
const STAND_IN := 0.6         # a tool at a job it can do, but is not for
const STAND_IN_FAR := 0.4     # a specialist's leftover stand-in (stock pot, fryer at grill)
const EFFICIENT_STEP := 0.15  # what an efficient step adds to every job of its parent
const SPECIALIST := 1.6       # a specialist at its one job

const EFFICIENT := "efficient"
const SPECIALIST_STEP := "specialist"

## How a piece sits in a cell:
## "top": a tool, on a counter-type base only.
## "counter": a base with a top (and storage below).
## "shelf": storage, no top; a base, or a high piece on a wall cell.
## "tall": a base that also fills the high layer; no top.
## "cabinet", "hood": high layer only, on a wall cell.
const FITS := {
	"top": ["top"], "counter": ["base"], "shelf": ["base", "high"], "tall": ["base"],
	"cabinet": ["high"], "hood": ["high"],
}

## The upgrade trees. A node with no "parent" is a root, bought in the shop; every other
## node only from its parent. "step": efficient or specialist. "jobs": quality per job;
## an efficient node with no "jobs" takes its parent's, each + EFFICIENT_STEP.
## "slots": kinds of stock it holds; "chilled": its slots take chilled kinds.
## "mess": floor mess factor for PRD 9 (1.0 when absent). Prices are first guesses.
## New jobs and ingredients (grater, bread knife, juicer, blender, steamer, coffee,
## beer tap, freezer) join in milestone 8.6.
const NODES := {
	# Cutting
	"board": {"name": "Chopping board", "fit": "top", "price": 25,
		"jobs": {"chop": BASE, "slice": STAND_IN}},
	"sharp_knife": {"name": "Sharp knife", "fit": "top", "price": 40, "parent": "board", "step": EFFICIENT},
	"butcher_block": {"name": "Butcher block", "fit": "top", "price": 65, "parent": "sharp_knife", "step": EFFICIENT},
	"slicer": {"name": "Slicer", "fit": "top", "price": 60, "parent": "board", "step": SPECIALIST_STEP,
		"jobs": {"slice": SPECIALIST, "chop": STAND_IN}},
	"auto_slicer": {"name": "Auto slicer", "fit": "top", "price": 120, "parent": "slicer", "step": EFFICIENT,
		"jobs": {"slice": SPECIALIST + EFFICIENT_STEP}, "auto": true},
	# Heat
	"stove": {"name": "Stove", "fit": "top", "price": 50,
		"jobs": {"grill": BASE, "boil": STAND_IN, "fry": STAND_IN}},
	"range": {"name": "Range", "fit": "top", "price": 80, "parent": "stove", "step": EFFICIENT},
	"two_hob_range": {"name": "Two-hob range", "fit": "top", "price": 130, "parent": "range", "step": EFFICIENT,
		"pans": 2},
	"char_grill": {"name": "Char grill", "fit": "top", "price": 110, "parent": "stove", "step": SPECIALIST_STEP,
		"jobs": {"grill": SPECIALIST}, "tags": ["smoky"]},
	"pot": {"name": "Stock pot", "fit": "top", "price": 60, "parent": "stove", "step": SPECIALIST_STEP,
		"jobs": {"boil": SPECIALIST, "grill": STAND_IN_FAR}},
	"fryer": {"name": "Fryer", "fit": "top", "price": 70, "parent": "stove", "step": SPECIALIST_STEP,
		"jobs": {"fry": SPECIALIST, "grill": STAND_IN_FAR}},
	"twin_fryer": {"name": "Twin fryer", "fit": "top", "price": 120, "parent": "fryer", "step": EFFICIENT,
		"pans": 2},
	# Pour: a dispenser stores its own drinks and needs no slot.
	"fountain": {"name": "Soda fountain", "fit": "top", "price": 40, "theme": "diner",
		"jobs": {"pour": BASE}, "drinks": ["soda"]},
	"two_tap_fountain": {"name": "Two-tap fountain", "fit": "top", "price": 70, "parent": "fountain",
		"step": EFFICIENT, "drinks": ["soda", "cola"]},
	"wine_barrel": {"name": "Wine barrel", "fit": "top", "price": 45, "theme": "seaside",
		"jobs": {"pour": BASE}, "drinks": ["wine"]},
	"wine_rack": {"name": "Wine rack", "fit": "top", "price": 75, "parent": "wine_barrel",
		"step": EFFICIENT, "drinks": ["wine", "red_wine"]},
	# Storage: the counter is the base; fridges are its specialist line.
	"counter": {"name": "Counter", "fit": "counter", "price": 15, "slots": 1},
	"double_counter": {"name": "Double counter", "fit": "counter", "price": 25, "parent": "counter",
		"step": EFFICIENT, "slots": 2},
	"long_counter": {"name": "Long counter", "fit": "counter", "price": 45, "parent": "double_counter",
		"step": EFFICIENT, "slots": 3},
	"fridge": {"name": "Under-counter fridge", "fit": "counter", "price": 50, "parent": "counter",
		"step": SPECIALIST_STEP, "slots": 1, "chilled": true},
	"tall_fridge": {"name": "Tall fridge", "fit": "tall", "price": 110, "parent": "fridge",
		"step": SPECIALIST_STEP, "slots": 2, "chilled": true},
	"glass_fridge": {"name": "Tall fridge, glass door", "fit": "tall", "price": 160, "parent": "tall_fridge",
		"step": EFFICIENT, "slots": 3, "chilled": true},
	"shelf": {"name": "Wall shelf", "fit": "shelf", "price": 10, "slots": 1},
	"wide_shelf": {"name": "Wide shelf", "fit": "shelf", "price": 20, "parent": "shelf", "step": EFFICIENT,
		"slots": 2},
	"cabinet": {"name": "Wall cabinet", "fit": "cabinet", "price": 20, "slots": 1},   # tunable price
	"hood": {"name": "Hood", "fit": "hood", "price": 30},   # tunable price; a flag for PRD 9
}

## Catalog pieces that are kitchen nodes under another id: the drink dispensers keep
## their crate ids until storage replaces the crates (8.4).
const CATALOG_IDS := {"crate_soda": "fountain", "crate_wine": "wine_barrel"}
## A base that becomes another when one more of it is placed on it: a counter placed
## on a counter is a double counter, still one cell (PRD 8, "Decided").
const STACKS := {"counter": "double_counter"}

## Cells against a wall, which have a high layer: Vector2i -> true.
var wall_cells := {}
## Vector2i -> {"base": id, "top": id, "high": id, "stock": {"base": [kinds], "high": [kinds]}}.
## Empty layers are "".
var cells := {}


# ---------- Tree data ----------

static func has_node(id: String) -> bool:
	return NODES.has(id)


static func parent_of(id: String) -> String:
	return str(NODES[id].get("parent", ""))


static func step_of(id: String) -> String:
	return str(NODES[id].get("step", ""))


static func is_root(id: String) -> bool:
	return parent_of(id) == ""


static func price_of(id: String) -> int:
	return int(NODES[id].price)


## What buying this node costs from its parent: the new price less the old.
static func step_price(id: String) -> int:
	return price_of(id) - (0 if is_root(id) else price_of(parent_of(id)))


static func children_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for n: String in NODES:
		if parent_of(n) == id:
			out.append(n)
	return out


static func root_of(id: String) -> String:
	while not is_root(id):
		id = parent_of(id)
	return id


## A node is bought only from its parent, so skipping steps is not allowed.
static func can_upgrade(from: String, to: String) -> bool:
	return NODES.has(to) and parent_of(to) == from


static func mess_of(id: String) -> float:
	return float(NODES[id].get("mess", 1.0))


## Quality per job. Efficient nodes without their own map take the parent's, + EFFICIENT_STEP.
static func jobs_of(id: String) -> Dictionary:
	var node: Dictionary = NODES[id]
	if node.has("jobs"):
		return node.jobs.duplicate()
	if step_of(id) == EFFICIENT:
		var out := {}
		var up := jobs_of(parent_of(id))
		for job: String in up:
			out[job] = up[job] + EFFICIENT_STEP
		return out
	return {}


## The quality this piece does a job at, or 0.0 if it cannot do it.
static func quality(id: String, job: String) -> float:
	return float(jobs_of(id).get(job, 0.0))


static func slots_of(id: String) -> int:
	return int(NODES[id].get("slots", 0)) if NODES.has(id) else 0


static func chills(id: String) -> bool:
	return NODES.has(id) and NODES[id].get("chilled", false)


static func fit_of(id: String) -> String:
	return str(NODES[id].fit)


## The node a catalog piece is ("" if it is not a kitchen piece).
static func node_of(catalog_id: String) -> String:
	if CATALOG_IDS.has(catalog_id):
		return CATALOG_IDS[catalog_id]
	return catalog_id if NODES.has(catalog_id) else ""


## The catalog piece whose behaviour a node has in the room: a sharp knife works as a
## board, a range as a stove, a two-tap fountain as the soda fountain, a fridge as a
## counter. Pieces with their own catalog entry (slicer, fryer, pot) are their own.
static func family_of(id: String) -> String:
	while true:
		var c: Variant = CATALOG_IDS.find_key(id)
		if c != null:
			return str(c)
		if Catalog.ITEMS.has(id) or not NODES.has(id) or is_root(id):
			return id
		id = parent_of(id)
	return id


## A piece that plays its minigame itself (the auto slicer).
static func is_auto(id: String) -> bool:
	return NODES.has(id) and NODES[id].get("auto", false)


## Every job any tool in the trees does, as "grill", "chop" and so on.
static func jobs_known() -> Array[String]:
	var out: Array[String] = []
	for n: String in NODES:
		for job: String in jobs_of(n):
			if not out.has(job):
				out.append(job)
	return out


## A catalog piece that is a tool and goes on a counter.
static func is_top(catalog_id: String) -> bool:
	var n := node_of(catalog_id)
	return n != "" and fit_of(n) == "top"


## A catalog piece that is a counter-type base (a tool can stand on it).
static func is_counter(catalog_id: String) -> bool:
	var n := node_of(catalog_id)
	return n != "" and fit_of(n) == "counter"


## What a base becomes with `id` placed on it ("" if they do not stack).
static func stacked(base: String, id: String) -> String:
	return str(STACKS[id]) if STACKS.has(id) and base == id else ""


## What a stacked base leaves behind when one piece comes off it ("" if it is not stacked).
static func unstacked(base: String) -> String:
	var lower: Variant = STACKS.find_key(base)
	return str(lower) if lower != null else ""


## Whether an ingredient must be kept in a fridge slot.
static func is_chilled(kind: String) -> bool:
	return Pantry.ITEMS.has(kind) and Pantry.ITEMS[kind].get("chilled", false)


# ---------- Cells ----------

func set_wall(cell: Vector2i, on := true) -> void:
	if on:
		wall_cells[cell] = true
	else:
		wall_cells.erase(cell)


func is_wall(cell: Vector2i) -> bool:
	return wall_cells.has(cell)


func _cell(cell: Vector2i) -> Dictionary:
	if not cells.has(cell):
		cells[cell] = {"base": "", "top": "", "high": "", "stock": {"base": [], "high": []}}
	return cells[cell]


## Sets a cell's base and top outright (the game keeps its cells in step this way).
## Stock already held there is kept. An empty base clears the cell.
func set_cell(cell: Vector2i, base: String, top := "") -> void:
	if base == "":
		cells.erase(cell)
		return
	var c := _cell(cell)
	c.base = base
	c.top = top


func get_piece(cell: Vector2i, layer: String) -> String:
	return str(cells[cell][layer]) if cells.has(cell) else ""


## The layer a piece would go into on this cell, or "" if it does not fit. A shelf goes
## low first, then high on a wall cell.
func layer_for(cell: Vector2i, id: String) -> String:
	if not NODES.has(id):
		return ""
	var base := get_piece(cell, "base")
	var fit := fit_of(id)
	if fit == "counter" and stacked(base, id) != "" and get_piece(cell, "top") == "":
		return "base"   # a counter on a bare counter: a double counter
	for layer: String in FITS[fit]:
		if get_piece(cell, layer) != "":
			continue
		match layer:
			"top":
				if base != "" and fit_of(base) == "counter":
					return layer
			"base":
				if fit == "tall" and get_piece(cell, "high") != "":
					continue
				return layer
			"high":
				if is_wall(cell) and not (base != "" and fit_of(base) == "tall"):
					return layer
	return ""


func can_place(cell: Vector2i, id: String) -> bool:
	return layer_for(cell, id) != ""


## Puts a piece in the cell. Returns the layer it went into, or "" if it did not fit.
func place(cell: Vector2i, id: String) -> String:
	var layer := layer_for(cell, id)
	if layer == "":
		return ""
	var up := stacked(get_piece(cell, "base"), id) if layer == "base" else ""
	_cell(cell)[layer] = up if up != "" else id
	return layer


## Takes the piece off a layer. A base with a tool on it cannot be lifted until the tool
## is. Returns {"id": piece, "stock": the kinds it held} or {} if nothing came off.
func remove(cell: Vector2i, layer: String) -> Dictionary:
	var id := get_piece(cell, layer)
	if id == "" or (layer == "base" and get_piece(cell, "top") != ""):
		return {}
	var c: Dictionary = cells[cell]
	c[layer] = ""
	var held: Array = []
	if c.stock.has(layer):
		held = c.stock[layer]
		c.stock[layer] = []
	return {"id": id, "stock": held}


## A low shelf under a high shelf draws as one closet.
func is_closet(cell: Vector2i) -> bool:
	var base := get_piece(cell, "base")
	var high := get_piece(cell, "high")
	return base != "" and high != "" and fit_of(base) == "shelf" and fit_of(high) == "shelf"


func has_hood(cell: Vector2i) -> bool:
	return get_piece(cell, "high") == "hood"


# ---------- Storage ----------

## How many kinds the cell can hold in all, both layers.
func slots(cell: Vector2i) -> int:
	return slots_of(get_piece(cell, "base")) + slots_of(get_piece(cell, "high"))


## How many of those are fridge slots.
func chilled_slots(cell: Vector2i) -> int:
	var n := 0
	for layer: String in ["base", "high"]:
		var id := get_piece(cell, layer)
		if chills(id):
			n += slots_of(id)
	return n


func stock(cell: Vector2i) -> Array:
	if not cells.has(cell):
		return []
	return cells[cell].stock.base + cells[cell].stock.high


## The layer a kind would be stored in, or "" if there is no free slot that takes it.
## Unchilled kinds prefer unchilled slots, to leave fridge room free.
func store_layer(cell: Vector2i, kind: String) -> String:
	if not cells.has(cell) or stock(cell).has(kind):
		return ""
	var chilled := is_chilled(kind)
	var best := ""
	for layer: String in ["base", "high"]:
		var id := get_piece(cell, layer)
		if id == "" or cells[cell].stock[layer].size() >= slots_of(id):
			continue
		if chilled and not chills(id):
			continue
		if not chilled and not chills(id):
			return layer
		if best == "":
			best = layer
	return best


func can_store(cell: Vector2i, kind: String) -> bool:
	return store_layer(cell, kind) != ""


func store(cell: Vector2i, kind: String) -> bool:
	var layer := store_layer(cell, kind)
	if layer == "":
		return false
	cells[cell].stock[layer].append(kind)
	return true


func unstore(cell: Vector2i, kind: String) -> bool:
	if not cells.has(cell):
		return false
	for layer: String in ["base", "high"]:
		if cells[cell].stock[layer].has(kind):
			cells[cell].stock[layer].erase(kind)
			return true
	return false


## Every kind stocked anywhere in the kitchen.
func stocked() -> Array[String]:
	var out: Array[String] = []
	for cell: Vector2i in cells:
		for kind: String in stock(cell):
			if not out.has(kind):
				out.append(kind)
	return out


## The best quality any tool on a counter does this job at, or 0.0 if none can.
func best_quality(job: String) -> float:
	var best := 0.0
	for cell: Vector2i in cells:
		var top := get_piece(cell, "top")
		if top != "":
			best = maxf(best, quality(top, job))
	return best
