class_name SaveGame
## The saved game: one file, written at the start of each night (PRD: the build phase),
## read back by Continue on the title screen. A save is plain data (Variants stored as
## text), taken from the world by `capture` and put back by `restore_world` (the room,
## before the interface exists) and `restore_after` (what needs the helpers up).
## What is not kept is whatever only matters inside a day: guests, trays, cooking.

const PATH := "user://regulars_save.dat"
const VERSION := 1

const LEDGER := ["money", "xp", "day", "reputation", "today", "history"]
const MENU := ["items", "retired", "_next"]
const STAFF := ["posts", "cvs", "employees", "extra_duties", "_next_post", "_next_cv"]
const CRITIC := ["critic_idx", "next_visit", "known", "last_review", "_boost", "_boost_from", "_boost_to", "reviews"]
const TOWN := ["people", "taste_seed"]
## What a station keeps from night to night, beside its place and look.
const PIECE := ["tier", "facing", "base", "pass_look", "node", "stacked", "count", "dirty", "dirty_cups", "dirty_age", "tap", "kit_tool", "kit_used"]


static func exists(path := PATH) -> bool:
	return not read(path).is_empty()


static func delete(path := PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func write(data: Dictionary, path := PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(var_to_str(data))
	return true


## The saved game, or {} when there is none or it cannot be read.
static func read(path := PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = str_to_var(FileAccess.get_file_as_string(path))
	if data is Dictionary and int(data.get("version", 0)) == VERSION and data.has("ledger") and data.has("plan"):
		return data
	return {}


## What the title screen says about a save: "Day 4, theme name, $120".
static func blurb(data: Dictionary) -> String:
	var t: Dictionary = Scenery.THEMES.get(str(data.get("theme", "")), {})
	return "Day %d  ·  $%d  ·  %s" % [int(data.ledger.day), int(data.ledger.money), str(t.get("name", ""))]


static func _take(obj: Object, fields: Array) -> Dictionary:
	var out := {}
	for f: String in fields:
		out[f] = _copy(obj.get(f))
	return out


static func _put(obj: Object, fields: Array, data: Dictionary) -> void:
	for f: String in fields:
		if not data.has(f):
			continue
		var cur = obj.get(f)
		var v = _copy(data[f])
		if cur is Array:
			(cur as Array).assign(v)   # typed arrays keep their type
		else:
			obj.set(f, v)


static func _copy(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v


## Everything that carries over to the night, as data. `g` is the game (main.gd).
static func capture(g: Node3D) -> Dictionary:
	var pieces: Array[Dictionary] = []
	for layer: Dictionary in [g.stations, g.highs]:
		for c: Vector2i in layer:
			var st: Station = layer[c]
			var p := _take(st, PIECE)
			p["type"] = st.type
			p["cell"] = c
			p["high"] = st.high
			p["till"] = st.has_node("till")
			if st.has_node("till"):
				p["till_facing"] = int(st.get_node("till").get_meta("facing", 0))
			pieces.append(p)
	var screens := {}
	for e: Vector3i in g.wall_nodes:
		screens[e] = int(g.wall_nodes[e].get_meta("tier", 1))
	var rugs := {}
	for a: Vector2i in g.rugs:
		rugs[a] = int(g.rugs[a].get_meta("facing", 0))
	var stock := {}
	for c: Vector2i in g.kitchen.cells:
		stock[c] = g.kitchen.take_stock(c)
	return {
		"version": VERSION,
		"theme": Scenery.theme_id,
		"ledger": _take(g.ledger, LEDGER),
		"menu": _take(g.menu, MENU),
		"staff": _take(g.staff, STAFF).merged({"rng": g.staff.rng.state}),
		"critic": _take(g.critic, CRITIC),
		"town": _take(g.town, TOWN).merged({"rng": g.town.rng.state}),
		"plan": _take(g.plan, ["floors", "built", "openings", "finishes"]),
		"pieces": pieces,
		"stock": stock,
		"screens": screens,
		"rugs": rugs,
		"treat_laid": g.treat_laid.duplicate(true),
		"treat_off": g.treat_off.duplicate(true),
		"flyers_out": g.flyers_out,
		"dirt": g.floor_dirt.mess.dirt.duplicate(true),
		"grease": g.floor_dirt.mess.grease.duplicate(true),
	}


## The saved theme, to set before the scene (and so the room) is built.
static func theme_of(data: Dictionary) -> String:
	return str(data.get("theme", ""))


## The people, books and room as saved, put in place of the starting ones. Runs in the
## game's _ready where the starting layout would be built; the interface is not up yet.
static func restore_world(g: Node3D, d: Dictionary) -> void:
	_put(g.ledger, LEDGER, d.ledger)
	_put(g.menu, MENU, d.menu)
	_put(g.staff, STAFF, d.staff)
	g.staff.rng.state = int(d.staff.rng)
	_put(g.critic, CRITIC, d.critic)
	_put(g.town, TOWN, d.town)
	g.town.rng.state = int(d.town.rng)
	_put(g.plan, ["floors", "built", "openings", "finishes"], d.plan)
	for e: Vector3i in d.screens:
		var n: Node3D = g.world.add_wall(Vector2i(e.x, e.y), e.z, 0.9 + 0.1 * int(d.screens[e]))
		n.set_meta("tier", int(d.screens[e]))
		g.wall_nodes[e] = n
	g.world._sync_grid()
	g.world._rebuild_room()
	for a: Vector2i in d.rugs:
		g.placing.add_rug(a, int(d.rugs[a]))
	# Floor pieces first, then what hangs above them.
	var ordered: Array = (d.pieces as Array).filter(func(p: Dictionary) -> bool: return not p.high)
	ordered.append_array((d.pieces as Array).filter(func(p: Dictionary) -> bool: return p.high))
	for p: Dictionary in ordered:
		_place(g, p)
	for p: Dictionary in ordered:
		if p.till:
			var host: Station = g.paying._till_host(p.cell)
			if host != null:
				BuildStations.register(host, int(p.get("till_facing", 0)))
	for c: Vector2i in d.stock:
		g.kitchen.give_stock(c, (d.stock[c] as Dictionary).duplicate(true))
		g.world._show_boxes(c)
	g.treat_laid = d.treat_laid.duplicate(true)
	g.treat_off = d.treat_off.duplicate(true)
	g.flyers_out = bool(d.flyers_out)


static func _place(g: Node3D, p: Dictionary) -> void:
	var st: Station
	if p.type == "trays":
		p.type = "plates"   # saved before the plate stack was the tray stack
	if p.high:
		st = g.world.add_high(p.node if p.node != "" else p.type, p.cell)
	else:
		st = g.world.add_station(p.type, p.cell, int(p.tier), int(p.facing), str(p.base), bool(p.pass_look), str(p.node))
	st.stacked = bool(p.stacked)
	st.count = int(p.count)
	st.dirty = int(p.dirty)
	st.dirty_cups = int(p.get("dirty_cups", 0))
	st.dirty_age = float(p.dirty_age)
	st.tap = int(p.tap)
	st.kit_tool = str(p.kit_tool)
	st.kit_used = int(p.kit_used)
	st.refresh()


## What needs the helpers: the cleaning tools back in their homes, the floor's dirt.
static func restore_after(g: Node3D, d: Dictionary) -> void:
	for st: Station in g.stations.values() + g.highs.values():
		if st.kit_tool != "":
			g.clean_kit.show_home(st)
	g.floor_dirt.sync_room()
	g.floor_dirt.mess.dirt = d.dirt.duplicate(true)
	g.floor_dirt.mess.grease = d.grease.duplicate(true)
	g.floor_dirt.sync_room()
	g.floor_dirt.redraw()
