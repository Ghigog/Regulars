class_name Upgrades
extends RefCounted
## The upgrade trees as the tree screen shows and sells them (PRD 8.3). A piece's place
## in a tree is a key: a kitchen node id ("range", "fridge") for kitchen pieces, or
## "<catalog id>@<tier>" for a catalog piece sold in tiers (a fern, a jukebox, a table),
## whose short tree is one efficient step per tier. A node is bought only from its
## parent, for the new price less the old. Pure: no scene dependencies.

const TIER_SEP := "@"
## What each job is called in a node's line.
const JOB_WORDS := {"grill": "grilling", "fry": "frying", "boil": "boiling", "chop": "chopping",
	"slice": "slicing", "pour": "pouring"}


## The key of a piece in the room: its kitchen node, or its tier in a tiered piece's
## short tree. "" for a piece with no tree.
static func key_of(id: String, tier := 1, node := "") -> String:
	if node != "" and Kitchen.has_node(node):
		return node
	var n := Kitchen.node_of(id)
	if n != "":
		return n
	if Catalog.ITEMS.has(id) and int(Catalog.ITEMS[id].tiers) > 1:
		return "%s%s%d" % [id, TIER_SEP, clampi(tier, 1, int(Catalog.ITEMS[id].tiers))]
	return ""


static func is_tiered(key: String) -> bool:
	return key.contains(TIER_SEP)


## For a tiered key, the catalog id; for a node, the catalog piece it behaves as.
static func catalog_id(key: String) -> String:
	if is_tiered(key):
		return key.get_slice(TIER_SEP, 0)
	return Kitchen.family_of(key)


static func tier_of(key: String) -> int:
	return int(key.get_slice(TIER_SEP, 1)) if is_tiered(key) else 1


static func _tier_key(id: String, tier: int) -> String:
	return "%s%s%d" % [id, TIER_SEP, tier]


static func parent(key: String) -> String:
	if is_tiered(key):
		var t := tier_of(key)
		return _tier_key(catalog_id(key), t - 1) if t > 1 else ""
	return Kitchen.parent_of(key)


static func children(key: String) -> Array[String]:
	if is_tiered(key):
		var out: Array[String] = []
		if tier_of(key) < int(Catalog.ITEMS[catalog_id(key)].tiers):
			out.append(_tier_key(catalog_id(key), tier_of(key) + 1))
		return out
	return Kitchen.children_of(key)


static func root(key: String) -> String:
	while parent(key) != "":
		key = parent(key)
	return key


## Whether a piece has anywhere to go or come from: a tree with more than its root.
static func has_tree(key: String) -> bool:
	return key != "" and not children(root(key)).is_empty()


## Kitchen.EFFICIENT, Kitchen.SPECIALIST_STEP, or "" for a root. A tier is efficient.
static func step(key: String) -> String:
	if is_tiered(key):
		return Kitchen.EFFICIENT if tier_of(key) > 1 else ""
	return Kitchen.step_of(key)


## The piece's whole price (what it is worth when sold).
static func price(key: String) -> int:
	if is_tiered(key):
		return Catalog.price_of(catalog_id(key), tier_of(key))
	return Kitchen.price_of(key)


## What buying this node from its parent costs: the new price less the old.
static func step_price(key: String) -> int:
	var up := parent(key)
	return price(key) - (price(up) if up != "" else 0)


## The level a node needs. Tiers keep the catalog's rule (one more a tier); kitchen
## nodes need the level of the piece they grow from.
static func level(key: String) -> int:
	if is_tiered(key):
		return Catalog.level_of(catalog_id(key), tier_of(key))
	var id := catalog_id(root(key))
	return int(Catalog.ITEMS[id].level) if Catalog.ITEMS.has(id) else 1


static func name_of(key: String) -> String:
	if is_tiered(key):
		return Catalog.label({"id": catalog_id(key), "tier": tier_of(key)})
	return str(Kitchen.NODES[key].name)


## Quality per job ({} for a tiered piece, which does no prep).
static func jobs(key: String) -> Dictionary:
	return {} if is_tiered(key) else Kitchen.jobs_of(key)


## A short line on what the node is: its trade for a specialist, its gain for a step.
static func blurb(key: String) -> String:
	if is_tiered(key):
		return Catalog.blurb_of(catalog_id(key), tier_of(key))
	var n: Dictionary = Kitchen.NODES[key]
	var bits: Array[String] = []
	if Kitchen.is_auto(key):
		bits.append("Plays itself")
	if n.has("pans"):
		bits.append("%d at once" % int(n.pans))
	if n.has("slots"):
		bits.append("Holds %d kind%s%s" % [int(n.slots), "" if int(n.slots) == 1 else "s", ", chilled" if n.get("chilled", false) else ""])
	if n.has("drinks"):
		var names: Array[String] = []
		for d: String in n.drinks:
			names.append(Pantry.name_of(d) if Pantry.ITEMS.has(d) else d.replace("_", " ").capitalize())
		bits.append(" and ".join(names))
	if n.has("tags"):
		bits.append("Some guests like it %s" % ", ".join(n.tags))
	var jobs := Kitchen.jobs_of(key)
	var by := {"much": [], "better": [], "good": [], "pinch": []}
	for job: String in jobs:
		var q: float = jobs[job]
		var band := "much" if q >= Kitchen.SPECIALIST - 0.01 else ("better" if q > Kitchen.BASE + 0.01 \
				else ("good" if q >= Kitchen.BASE - 0.01 else "pinch"))
		by[band].append(str(JOB_WORDS.get(job, job)))
	var words := {"much": "Much better at %s", "better": "Better at %s", "good": "Good at %s", "pinch": "%s at a pinch"}
	var lines: Array[String] = []
	for band: String in ["much", "better", "good", "pinch"]:
		if not by[band].is_empty():
			var line: String = words[band] % " and ".join(by[band])
			lines.append(line[0].to_upper() + line.substr(1))
	return ".  ".join(lines + bits)


## Whether `to` can be bought for a piece that is `from` now: only a child, with the
## money for the step and the level for it.
static func can_buy(from: String, to: String, money: int, lvl: int) -> bool:
	return parent(to) == from and money >= step_price(to) and lvl >= level(to)


## Where each node of a tree sits on the screen: key -> Vector2i(column, row). The root
## is at (0, 0). An efficient step goes straight on along its parent's row; a
## specialist forks to a new row below, under every row its elder siblings used.
static func layout(root_key: String) -> Dictionary:
	var out := {}
	var rows := [0]   # the next free row, shared through the walk
	_lay(root_key, 0, 0, out, rows)
	return out


static func _lay(key: String, col: int, row: int, out: Dictionary, rows: Array) -> void:
	out[key] = Vector2i(col, row)
	var kids := children(key)
	var straight := true
	for k: String in kids:   # the efficient step first, on this row
		if step(k) == Kitchen.EFFICIENT and straight:
			straight = false
			_lay(k, col + 1, row, out, rows)
	for k: String in kids:
		if out.has(k):
			continue
		rows[0] += 1
		_lay(k, col + 1, rows[0], out, rows)


## The size of a tree's layout: Vector2i(columns, rows).
static func extent(lay: Dictionary) -> Vector2i:
	var e := Vector2i.ZERO
	for k: String in lay:
		e = Vector2i(maxi(e.x, lay[k].x + 1), maxi(e.y, lay[k].y + 1))
	return e
