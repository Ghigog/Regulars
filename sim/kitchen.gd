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
## "hook": a wall hook (PRD 9.4), high layer only; holds one small cleaning tool.
## "floor": stands on the floor outside the kitchen's cells (the mop bucket, the robot's
## dock, PRD 9.5); in the trees only.
const FITS := {
	"top": ["top"], "counter": ["base"], "shelf": ["base", "high"], "tall": ["base"],
	"cabinet": ["high"], "hood": ["high"], "hook": ["high"], "floor": [],
}

## The upgrade trees. A node with no "parent" is a root, bought in the shop; every other
## node only from its parent. "step": efficient or specialist. "jobs": quality per job;
## an efficient node with no "jobs" takes its parent's, each + EFFICIENT_STEP.
## "slots": kinds of stock it holds; "chilled": its slots take chilled kinds.
## "mess": floor mess factor for PRD 9 (1.0 when absent). Prices are first guesses.
## The new jobs (grate, saw, juice, blend, steam) and their ingredients joined in 8.6.
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
	"grater": {"name": "Grater", "fit": "top", "price": 70, "parent": "slicer", "step": SPECIALIST_STEP,
		"jobs": {"grate": SPECIALIST, "slice": STAND_IN}},
	"rotary_grater": {"name": "Rotary grater", "fit": "top", "price": 110, "parent": "grater", "step": EFFICIENT,
		"jobs": {"grate": 1.8, "slice": STAND_IN + EFFICIENT_STEP}},
	"bread_knife": {"name": "Bread knife", "fit": "top", "price": 45, "parent": "board", "step": SPECIALIST_STEP,
		"jobs": {"saw": SPECIALIST, "chop": STAND_IN}},
	"juicer": {"name": "Juicer", "fit": "top", "price": 90, "parent": "bread_knife", "step": SPECIALIST_STEP,
		"jobs": {"juice": SPECIALIST}},
	"blender": {"name": "Blender", "fit": "top", "price": 150, "parent": "juicer", "step": SPECIALIST_STEP,
		"jobs": {"blend": SPECIALIST, "juice": STAND_IN}},
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
	"steamer": {"name": "Steamer", "fit": "top", "price": 100, "parent": "pot", "step": SPECIALIST_STEP,
		"jobs": {"steam": SPECIALIST}},
	"fryer": {"name": "Fryer", "fit": "top", "price": 70, "parent": "stove", "step": SPECIALIST_STEP,
		"jobs": {"fry": SPECIALIST, "grill": STAND_IN_FAR}},
	"twin_fryer": {"name": "Twin fryer", "fit": "top", "price": 120, "parent": "fryer", "step": EFFICIENT,
		"pans": 2},
	# Pour: a dispenser stores its own drinks and needs no slot.
	"fountain": {"name": "Soda fountain", "fit": "top", "price": 40, "theme": "diner",
		"jobs": {"pour": BASE}, "drinks": ["soda"]},
	"two_tap_fountain": {"name": "Two-tap fountain", "fit": "top", "price": 70, "parent": "fountain",
		"step": EFFICIENT, "drinks": ["soda", "cola"]},
	"coffee_machine": {"name": "Coffee machine", "fit": "top", "price": 90, "parent": "fountain",
		"step": SPECIALIST_STEP, "jobs": {"pour": SPECIALIST}, "drinks": ["coffee"]},
	"wine_barrel": {"name": "Wine barrel", "fit": "top", "price": 45, "theme": "seaside",
		"jobs": {"pour": BASE}, "drinks": ["wine"]},
	"wine_rack": {"name": "Wine rack", "fit": "top", "price": 75, "parent": "wine_barrel",
		"step": EFFICIENT, "drinks": ["wine", "red_wine"]},
	"beer_tap": {"name": "Beer tap", "fit": "top", "price": 90, "parent": "wine_barrel",
		"step": SPECIALIST_STEP, "jobs": {"pour": SPECIALIST}, "drinks": ["ale"]},
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
	# A freezer also takes frozen kinds (ice cream, 8.6).
	"freezer": {"name": "Freezer", "fit": "tall", "price": 150, "parent": "tall_fridge",
		"step": SPECIALIST_STEP, "slots": 2, "chilled": true, "frozen": true},
	"shelf": {"name": "Wall shelf", "fit": "shelf", "price": 10, "slots": 1},
	"wide_shelf": {"name": "Wide shelf", "fit": "shelf", "price": 20, "parent": "shelf", "step": EFFICIENT,
		"slots": 2},
	"cabinet": {"name": "Wall cabinet", "fit": "cabinet", "price": 20, "slots": 1},   # tunable price
	"hood": {"name": "Hood", "fit": "hood", "price": 30,   # tunable price; a flag for PRD 9
		"blurb": "Hangs over a stove and cuts the grease it drops"},
	"extractor": {"name": "Extractor", "fit": "hood", "price": 90, "parent": "hood", "step": EFFICIENT,
		"blurb": "Cuts the stove's grease by more, and kitchen grease smells less far"},
	"hook": {"name": "Wall hook", "fit": "hook", "price": 5},   # PRD 9.4: a sponge's home (tunable price)
	# The cleaning trees (PRD 9.5). Each home names the tool it keeps ("tool", a
	# CleanTools.TOOLS id); upgrading the home swaps that tool for the new one.
	"mop_bucket": {"name": "Mop bucket", "fit": "floor", "price": 20, "tool": "mop",
		"blurb": "Mop clears a level a press, dirty after 4"},
	"sponge_mop": {"name": "Sponge-head mop", "fit": "floor", "price": 35, "parent": "mop_bucket",
		"step": EFFICIENT, "tool": "sponge_mop", "blurb": "Clears a level a press, dirty after 6"},
	"flat_mop": {"name": "Flat mop", "fit": "floor", "price": 60, "parent": "sponge_mop", "step": EFFICIENT,
		"tool": "flat_mop", "blurb": "Clears a whole cell a press, dirty after 8"},
	"scrubber": {"name": "Floor scrubber", "fit": "floor", "price": 180, "parent": "flat_mop", "step": EFFICIENT,
		"tool": "scrubber", "blurb": "Push it along: clears every cell it passes. Never dirty, slow to walk"},
	"wringer_bucket": {"name": "Wringer bucket", "fit": "floor", "price": 45, "parent": "mop_bucket",
		"step": SPECIALIST_STEP, "tool": "wringer_mop", "blurb": "Rinses itself: the mop is never dirty. A level a press"},
	"robot_dock": {"name": "Robot sweeper", "fit": "floor", "price": 300, "parent": "wringer_bucket",
		"step": SPECIALIST_STEP, "blurb": "A dock. The robot drifts to the nearest dirt and slowly cleans it. Anyone can trip on it"},
	"sponge": {"name": "Sponge", "fit": "hook", "price": 15, "tool": "sponge",
		"blurb": "On its own wall hook. Clears a level fast, dirty after 2"},
	"scourer": {"name": "Scourer", "fit": "hook", "price": 25, "parent": "sponge", "step": EFFICIENT,
		"tool": "scourer", "blurb": "Clears a level fast, dirty after 4"},
	"grease_scraper": {"name": "Grease scraper", "fit": "hook", "price": 40, "parent": "sponge",
		"step": SPECIALIST_STEP, "tool": "grease_scraper",
		"blurb": "Kitchen grease only: a whole cell a press, never dirty. No use on guest mess"},
	"spill_kit": {"name": "Spill kit", "fit": "hook", "price": 30, "parent": "sponge", "step": SPECIALIST_STEP,
		"tool": "spill_kit", "blurb": "A covered cell down to a puddle at once, three times a day. Helps a fallen guest up faster"},
}

## Catalog pieces that are kitchen nodes under another id (none since the crates went, 8.4).
const CATALOG_IDS := {}
## A base that becomes another when one more of it is placed on it: a counter placed
## on a counter is a double counter, still one cell (PRD 8, "Decided").
const STACKS := {"counter": "double_counter"}
## Tools not sold in the shop: each grows from a bare counter, a branch of the counter's
## tree, and is a tree of its own after that. Buying one stands it on the counter, which
## stays under it, so its step costs the tool's whole price.
const TOP_LINKS := {"stove": "counter"}

## Cells against a wall, which have a high layer: Vector2i -> true.
var wall_cells := {}
## Vector2i -> {"base": id, "top": id, "high": id, "stock": {"base": [boxes], "high": [boxes]}}.
## A box is a kind ("patty") or a box id ("box_patty", "ready_cheese"); one of a kind a cell.
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


## The cleaning tool a home node keeps (PRD 9.5), or "".
static func tool_of(id: String) -> String:
	return str(NODES[id].get("tool", "")) if NODES.has(id) else ""


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


## A piece whose slots take frozen kinds (the freezer).
static func freezes(id: String) -> bool:
	return NODES.has(id) and NODES[id].get("frozen", false)


## A piece that hangs in the high layer only (wall cabinet, hood).
static func is_high_only(id: String) -> bool:
	return NODES.has(id) and FITS[fit_of(id)] == ["high"]


## A piece that may go in the high layer (a shelf, a wall cabinet, a hood).
static func can_go_high(id: String) -> bool:
	return NODES.has(id) and (FITS[fit_of(id)] as Array).has("high")


## A piece that fills both wall layers (tall fridge, glass fridge, freezer).
static func is_tall(id: String) -> bool:
	return NODES.has(id) and fit_of(id) == "tall"


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


## A piece in a tree that grows from a counter (TOP_LINKS: the stove and its line): an
## upgrade of the counter, not a tool on it. It lifts, moves and sells with its counter
## as one piece, and never stands on another counter. Takes a node or a catalog id.
static func grows_from_counter(id: String) -> bool:
	var n := id if NODES.has(id) else node_of(id)
	return n != "" and TOP_LINKS.has(root_of(n))


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


## Whether an ingredient (a kind, or a box id: "box_patty", "ready_cheese") must be
## kept in a fridge slot. A ready-made box keeps the chill of its ingredient.
static func is_chilled(kind: String) -> bool:
	var k := Pantry.kind_of(kind)
	return k != "" and Pantry.ITEMS[k].get("chilled", false)


## Whether an ingredient must be kept in a freezer slot (ice cream, PRD 8.6).
static func is_frozen(kind: String) -> bool:
	var k := Pantry.kind_of(kind)
	return k != "" and Pantry.ITEMS[k].get("frozen", false)


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
## Stock already held there is kept. An empty base clears the low layer and its stock;
## a high piece stays on the wall (PRD 8.5).
func set_cell(cell: Vector2i, base: String, top := "") -> void:
	if base == "":
		if cells.has(cell) and get_piece(cell, "high") != "":
			cells[cell].base = ""
			cells[cell].top = ""
			cells[cell].stock.base = []
		else:
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
				if can_hang(cell, id):
					return layer
	return ""


## Whether a piece can hang in this cell's high layer: a wall cell, the layer free, and
## no tall piece below filling it. Whatever else stands below does not matter (a sink,
## a stove, bare floor), so the game asks this for cells the kitchen holds no base for.
func can_hang(cell: Vector2i, id: String) -> bool:
	return can_go_high(id) and is_wall(cell) and get_piece(cell, "high") == "" \
		and not is_tall(get_piece(cell, "base"))


## Hangs a piece in the high layer. Returns whether it went up.
func hang(cell: Vector2i, id: String) -> bool:
	if not can_hang(cell, id):
		return false
	_cell(cell).high = id
	return true


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
	if c.base == "" and c.high == "":
		cells.erase(cell)
	return {"id": id, "stock": held}


## A low shelf under a high shelf draws as one closet.
func is_closet(cell: Vector2i) -> bool:
	var base := get_piece(cell, "base")
	var high := get_piece(cell, "high")
	return base != "" and high != "" and fit_of(base) == "shelf" and fit_of(high) == "shelf"


## Whether hanging this piece here would make a closet (a high shelf over a low one).
func is_closet_with(cell: Vector2i, id: String) -> bool:
	var base := get_piece(cell, "base")
	return base != "" and fit_of(base) == "shelf" and NODES.has(id) and fit_of(id) == "shelf"


## Whether a hood hangs over this cell (PRD 9 reads it: a hood cuts a stove's grease).
func has_hood(cell: Vector2i) -> bool:
	return hood_at(cell) != ""


## The hood over this cell: "hood", "extractor" (its tree step, PRD 9.5) or "".
func hood_at(cell: Vector2i) -> String:
	var h := get_piece(cell, "high")
	return h if h != "" and fit_of(h) == "hood" else ""


## Whether an extractor hangs anywhere.
func has_extractor() -> bool:
	for cell: Vector2i in cells:
		if hood_at(cell) == "extractor":
			return true
	return false


## The cells with a high piece on the wall: Vector2i -> its node.
func high_cells() -> Dictionary:
	var out := {}
	for cell: Vector2i in cells:
		if get_piece(cell, "high") != "":
			out[cell] = get_piece(cell, "high")
	return out


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


## A cleaning kind (PRD 9.5): a treatment box. Never with food, never in a fridge.
static func is_cleaning(box: String) -> bool:
	return Treatments.is_box(box)


## Whether a cell holds chemicals: a treatment box in any of its slots.
func holds_cleaning(cell: Vector2i) -> bool:
	for b: String in stock(cell):
		if is_cleaning(b):
			return true
	return false


## Whether a cell holds an ingredient in any of its slots.
func holds_food(cell: Vector2i) -> bool:
	for b: String in stock(cell):
		if not is_cleaning(b):
			return true
	return false


## Why a box cannot go in this cell, or "" if it can: the no-chemicals-with-food rule
## (PRD 9.5) and the fridge rules, worded for the player.
func store_refusal(cell: Vector2i, kind: String) -> String:
	if can_store(cell, kind):
		return ""
	if slots(cell) == 0:
		return "Nowhere to store it here"
	if is_cleaning(kind):
		if holds_food(cell):
			return "No chemicals with food"
		if stock(cell).has(kind):
			return "One of each a cell"
		var plain := false
		for layer: String in ["base", "high"]:
			plain = plain or (get_piece(cell, layer) != "" and slots_of(get_piece(cell, layer)) > 0 \
				and not chills(get_piece(cell, layer)))
		return "No chemicals in a fridge" if not plain else "No free slot"
	if holds_cleaning(cell):
		return "No food with chemicals"
	if holds_kind(cell, Pantry.kind_of(kind)):
		return "One of each a cell"
	if is_frozen(kind) and not _has_slots(cell, "frozen"):
		return "Needs a freezer"
	if is_chilled(kind) and not _has_slots(cell, "chilled"):
		return "Needs a fridge"
	if is_frozen(kind):
		return "The freezer is full. Take a box out first"
	if is_chilled(kind):
		return "The fridge is full. Take a box out first"
	return "No free slot"


## Whether a piece on the cell has slots of this sort at all, full or not.
func _has_slots(cell: Vector2i, sort: String) -> bool:
	for layer: String in ["base", "high"]:
		var id := get_piece(cell, layer)
		if slots_of(id) > 0 and (freezes(id) if sort == "frozen" else chills(id)):
			return true
	return false


## The layer a kind would be stored in, or "" if there is no free slot that takes it.
## Unchilled kinds prefer unchilled slots, to leave fridge room free. Chemicals and food
## never share a cell, and chemicals never go in a fridge (PRD 9.5).
func store_layer(cell: Vector2i, kind: String) -> String:
	if not cells.has(cell):
		return ""
	var cleaning := is_cleaning(kind)
	if cleaning:
		if holds_food(cell) or stock(cell).has(kind):
			return ""
	elif holds_cleaning(cell) or holds_kind(cell, Pantry.kind_of(kind)):
		return ""
	var chilled := is_chilled(kind) or is_frozen(kind)
	var best := ""
	for layer: String in ["base", "high"]:
		var id := get_piece(cell, layer)
		if id == "" or cells[cell].stock[layer].size() >= slots_of(id):
			continue
		if cleaning and chills(id):
			continue
		if is_frozen(kind) and not freezes(id):
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


## Whether a cell holds a box of this ingredient kind, ready-made or not.
func holds_kind(cell: Vector2i, kind: String) -> bool:
	for b: String in stock(cell):
		if not is_cleaning(b) and Pantry.kind_of(b) == kind:
			return true
	return false


## The cells with a box of this kind (or box id) in them.
func cells_with(box: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if stock(cell).has(box):
			out.append(cell)
	return out


## Whether any piece in the kitchen has fridge slots.
func has_fridge() -> bool:
	for cell: Vector2i in cells:
		if chilled_slots(cell) > 0:
			return true
	return false


## The stock of a cell, to carry over while its pieces are swapped in the room.
func take_stock(cell: Vector2i) -> Dictionary:
	if not cells.has(cell):
		return {}
	return (cells[cell].stock as Dictionary).duplicate(true)


## Puts stock taken with take_stock back in a cell.
func give_stock(cell: Vector2i, held: Dictionary) -> void:
	if cells.has(cell) and not held.is_empty():
		cells[cell].stock = held


## Every box stocked anywhere in the kitchen, each once.
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
