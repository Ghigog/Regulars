class_name JobBoard
extends RefCounted
## The task board (PRD 10, section 9; milestone 10.5): every open task in service with its
## place and the duties that may do it. Helpers take the nearest, most urgent task their
## duties allow and reserve it; a chef doing a task takes it off the board; a chef can take
## anything a helper holds or is cooking, and the helper moves on. Results for helpers roll
## from skill, the tool's quality and satisfaction. Pure logic: the game fills `rebuild`
## with plain data each frame (or when anything changes) and calls `assign`.
##
## The world `rebuild` reads (every key optional, every list may be empty):
##   stations: [{id, cell: Vector2i, tool: kitchen node id, busy: bool, drinks: [kinds]}]
##       a tool on a counter. `busy`: someone is using it. `drinks`: a dispenser's own drinks
##       (absent: it pours anything).
##   storage:  [{cell, kinds: [ingredient kinds], ready: [kinds]}]   boxes of stock to fetch
##       from (PRD 8.4). `ready`: kinds boxed ready-made, which need no prep (PRD 10.7).
##   items:    [{id, kind, cell, state: "raw" | "cooking" | "held", station: id, form}]
##       ingredients out of storage and not yet made: "raw" waiting at a station, "cooking"
##       on a tool, "held" in someone's hands. Each covers one of a ticket's lacks. `kind`
##       is what it is being made into (a lemon on a juicer is lemonade); `form`, what it
##       is now ("raw:lemon"), where that differs from `HelperWork.hold_for(kind)`.
##   tickets:  [{id, cell, lacks: [kinds], wait: seconds, assembled: bool, plated: bool, started: bool,
##       unplated: int}]
##       an order on the rail. `lacks`: ingredients it still needs made (a kind twice for
##       two). With nothing lacking and food still loose, it is assembled at `cell`.
##       Until each of its items has a plate or cup set out (`plated` false), they are set
##       out first (PRD 10.7), so what is made goes straight on them instead of filling
##       the worktops. `started`: some are out already; `unplated`: how many are still to
##       set out, a worktop each.
##   dishes:   [{id, cell, cells, table, wait}]   one or two finished plates or cups on
##       worktops (`cells`) for the same table, to carry together.
##   leftovers: [{cell}]  a plate or cup set out for an order that no longer needs it:
##       scraped into the bin and put back on its stack.
##   tables:   [{id, cell, state: "order" | "clear", wait}]
##   bills:    [{id, cell, wait}]   a table ready to pay with no slip printed yet (PRD 11.4):
##       `id` is the table's number, `cell` where the bill is handed over.
##   dirt:     {Vector2i: level}           as `FloorMess.dirt`; level `DIRT_FROM` and up is a task.
##   grease:   {Vector2i: true}            dirt that is kitchen grease (the scraper's, PRD 9.5).
##   fallen:   [{id, cell, wait}]          someone down on the floor (PRD 9.3).
##   sinks:    [{cell, dishes: int}]       dirty dishes waiting.
##   bins:     [{cell, full: bool}]
##   burnt:    [{cell, duty}]              burnt food on a tool, blocking it: scraped into the
##       bin by whoever works that tool (`duty`, PRD 10.7).
##   plate_room: int                       free worktops plates could be set out on.

## How urgent each kind of task is before it waits, in points. (tunable)
const URGENCY := {
	"help_up": 6.0, "carry": 5.0, "plates": 4.5, "assemble": 4.0, "scrap": 3.8, "prep": 3.5, "bill": 3.5, "fetch": 3.0, "order": 3.0,
	"clear": 2.0, "tidy": 2.0, "dirt": 1.0, "wash": 1.5, "bin": 1.5,
}
const DIRT_FROM := 2           # dirt at this level or more is a task
const DIRT_PER_LEVEL := 0.5    # tunable: urgency a level of dirt adds over `DIRT_FROM`
const WAIT_PULL := 0.05        # tunable: urgency a second of waiting adds
const URGENCY_CELLS := 4.0     # tunable: cells of walking an urgency point is worth
const REACT_BASE := 0.5        # tunable: seconds a content helper takes to pick a new task

## A helper's prep roll. (tunable)
const GOOD_BASE := 0.5         # good chance for a five-star cook at a base tool
const GOOD_MAX := 0.9
const BAD_BASE := 0.4          # bad chance for a one-star cook at a base tool

## The duties for each task type. Prep is the tool's (`Staff.duty_of_tool`), per station.
const DUTIES := {
	"fetch": ["fetch"], "assemble": ["assemble"], "plates": ["assemble"], "tidy": ["assemble"], "carry": ["carry_trays"], "order": ["take_orders"],
	"bill": ["take_payment"], "clear": ["clear_tables"], "help_up": ["help_up"], "wash": ["wash_up"], "bin": ["empty_bin"],
}

var tasks: Dictionary = {}         # key -> task
var reserved: Dictionary = {}      # key -> helper (person id)
var held_by: Dictionary = {}       # helper -> key
var station_of: Dictionary = {}    # helper -> the station their prep task uses
var chef_keys: Dictionary = {}     # key -> true: a chef is doing it
var _stations: Dictionary = {}     # station id -> station


# ---------- Building the board ----------

## Rebuilds every open task from the world (see the top of the file). Reservations and
## chef claims carry over by key.
func rebuild(world: Dictionary) -> void:
	tasks.clear()
	_stations.clear()
	for st: Dictionary in world.get("stations", []):
		_stations[st.id] = st
	_ingredient_tasks(world)
	for t: Dictionary in world.get("dishes", []):
		_add("carry:%s" % str(t.id), "carry", t.cell, float(t.get("wait", 0.0)),
			{"cells": t.get("cells", [t.cell]), "table": t.get("table")})
	for t: Dictionary in world.get("leftovers", []):
		_add("tidy:%d,%d" % [t.cell.x, t.cell.y], "tidy", t.cell, 0.0)
	for t: Dictionary in world.get("tables", []):
		var type := "order" if t.state == "order" else "clear"
		_add("%s:%s" % [type, str(t.id)], type, t.cell, float(t.get("wait", 0.0)), {"table": t.id})
	for b: Dictionary in world.get("bills", []):
		_add("bill:%s" % str(b.id), "bill", b.cell, float(b.get("wait", 0.0)), {"table": b.id})
	var dirt: Dictionary = world.get("dirt", {})
	for cell: Vector2i in dirt:
		var level := int(dirt[cell])
		if level >= DIRT_FROM:
			var greasy: bool = (world.get("grease", {}) as Dictionary).has(cell)
			var task := _add("dirt:%d,%d" % [cell.x, cell.y], "dirt", cell, 0.0, {"level": level, "grease": greasy})
			task.urgency += DIRT_PER_LEVEL * (level - DIRT_FROM)
			task.duties = dirt_duties(level, greasy)
	for f: Dictionary in world.get("fallen", []):
		_add("help_up:%s" % str(f.id), "help_up", f.cell, float(f.get("wait", 0.0)), {"person": f.id})
	for s: Dictionary in world.get("sinks", []):
		if int(s.get("dishes", 0)) > 0:
			_add("wash:%d,%d" % [s.cell.x, s.cell.y], "wash", s.cell, 0.0, {"dishes": int(s.dishes)})
	for b: Dictionary in world.get("bins", []):
		if b.get("full", false):
			_add("bin:%d,%d" % [b.cell.x, b.cell.y], "bin", b.cell, 0.0)
	for b: Dictionary in world.get("burnt", []):
		var task := _add("scrap:%d,%d" % [b.cell.x, b.cell.y], "scrap", b.cell, 0.0, {"kind": b.get("kind", "")})
		task.duties = [b.duty] if str(b.get("duty", "")) != "" else ["fetch"]
	# A chef's claim lasts while its task does.
	for key: String in chef_keys.keys():
		if not tasks.has(key):
			chef_keys.erase(key)


## The cleaning duties that can clear dirt (PRD 10.7): a mop or a sponge anything; the
## grease scraper kitchen grease only; the spill kit a cell at `CleanTools.SPILL_LEVEL`.
static func dirt_duties(level: int, grease: bool) -> Array:
	var out := ["mop", "sponge"]
	if grease:
		out.append("scraper")
	if level >= CleanTools.SPILL_LEVEL:
		out.append("spill_kit")
	return out


func _add(key: String, type: String, cell: Vector2i, wait: float, extra := {}) -> Dictionary:
	var task := {"key": key, "type": type, "cell": cell, "wait": wait,
		"urgency": float(URGENCY[type]) + wait * WAIT_PULL, "duties": (DUTIES.get(type, []) as Array).duplicate()}
	task.merge(extra, true)
	tasks[key] = task
	return task


## Each ticket's lacks, matched to the items already out (one item covers one lack, the
## oldest ticket first): a raw item at a station is a prep; cooking or held is in hand;
## a drink is poured straight from a dispenser; anything else is fetched from storage,
## to a station that can do its job (or to the ticket, if it needs none). A kind made
## from another's stock (lemonade from lemons, PRD 8.6) is fetched as its source; a kind
## boxed ready-made needs no tool and goes straight to the ticket (PRD 10.7).
func _ingredient_tasks(world: Dictionary) -> void:
	var items: Array = (world.get("items", []) as Array).duplicate()
	var storage: Array = world.get("storage", [])
	var room := int(world.get("plate_room", 99))
	var waiting_plates := false
	for t: Dictionary in world.get("tickets", []):
		var lacks: Array = t.get("lacks", [])
		var wait := float(t.get("wait", 0.0))
		if lacks.is_empty():
			if not t.get("assembled", false):
				_add("assemble:%s" % str(t.id), "assemble", t.cell, wait, {"ticket": t.id})
			continue
		if not t.get("plated", true):
			# No more plates set out than worktops to set them on; a ticket with none and
			# no worktop free waits, rather than have food made with nowhere to go. One
			# with some out goes on cooking meanwhile.
			# The oldest ticket waiting sets out what fits, so a busy room never stalls.
			var need := maxi(1, int(t.get("unplated", 1)))
			if room >= need or (room > 0 and not waiting_plates):
				room -= mini(need, room)
				waiting_plates = true
				_add("plates:%s" % str(t.id), "plates", t.cell, wait, {"ticket": t.id})
			elif not t.get("started", false):
				continue
		for i in lacks.size():
			var kind := String(lacks[i])
			var job := Pantry.tool_of(kind) if Pantry.ITEMS.has(kind) else ""
			var item := _take_item(items, kind)
			if not item.is_empty():
				if item.state == "raw":
					_prep_task("prep:%s" % str(item.id), kind, job, t, wait, item)
				continue
			if job == "pour":
				_prep_task("pour:%s:%d" % [str(t.id), i], kind, job, t, wait, {})
				continue
			var src := Pantry.source_of(kind)
			var from := _storage_with(storage, src, src == kind)
			if from.is_empty():
				continue   # nothing to fetch: stuck until restocked
			if from.ready:
				job = "none"
			var dest: Variant = t.cell
			if job != "" and job != "none":
				var st := _best_station(job, kind)
				if st.is_empty():
					continue   # no tool in the room can do it
				dest = st.cell
			_add("fetch:%s:%d" % [str(t.id), i], "fetch", from.cell, wait,
				{"ticket": t.id, "kind": kind, "source": src, "ready": from.ready, "job": job, "dest": dest})


## The item that covers a lack of `kind`: one being made into it, else (for a kind made
## from another's stock) its source lying loose, away from any tool.
func _take_item(items: Array, kind: String) -> Dictionary:
	for i in items.size():
		if items[i].kind == kind:
			var it: Dictionary = items[i]
			items.remove_at(i)
			return it
	if Pantry.is_derived(kind):
		var src := Pantry.source_of(kind)
		for i in items.size():
			if items[i].kind == src and not items[i].has("station") and items[i].state == "raw":
				var it: Dictionary = items[i].duplicate()
				items.remove_at(i)
				it.form = str(it.get("form", HelperWork.hold_for(src)))
				return it
	return {}


## The storage holding `kind`: {cell, ready}, a ready-made box first where `ready_ok`;
## {} when nothing holds it.
func _storage_with(storage: Array, kind: String, ready_ok := true) -> Dictionary:
	if ready_ok:
		for s: Dictionary in storage:
			if (s.get("ready", []) as Array).has(kind):
				return {"cell": s.cell, "ready": true}
	for s: Dictionary in storage:
		if (s.get("kinds", []) as Array).has(kind):
			return {"cell": s.cell, "ready": false}
	return {}


## A prep task: every station that can do the job (stand-ins too), each with its duty and
## quality. A raw item waiting at a station that can do it is prepped there.
func _prep_task(key: String, kind: String, job: String, t: Dictionary, wait: float, item: Dictionary) -> void:
	var options := _options(job, kind)
	if item.has("station") and _stations.has(item.station):
		options = options.filter(func(o: Dictionary) -> bool: return o.station == item.station)
	if options.is_empty():
		return
	var duties: Array = []
	for o: Dictionary in options:
		if not duties.has(o.duty):
			duties.append(o.duty)
	var cell: Vector2i = item.cell if item.has("cell") else options[0].cell
	var task := _add(key, "prep", cell, wait, {"ticket": t.id, "kind": kind, "job": job, "options": options,
		"item": item.get("id"), "duties": duties})
	if item.has("form"):
		task.hold = item.form


## The stations that can do `job` (for `kind`, a drink from its own dispenser), best first.
func _options(job: String, kind: String) -> Array:
	var out := []
	for st: Dictionary in _stations.values():
		var q := Kitchen.quality(str(st.tool), job) if Kitchen.has_node(str(st.tool)) else 0.0
		if q <= 0.0:
			continue
		if job == "pour" and st.has("drinks") and not (st.drinks as Array).has(kind):
			continue
		out.append({"station": st.id, "cell": st.cell, "duty": Staff.duty_of_tool(str(st.tool)), "quality": q})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.quality > b.quality)
	return out


func _best_station(job: String, kind: String) -> Dictionary:
	var opts := _options(job, kind)
	for o: Dictionary in opts:
		if not _stations[o.station].get("busy", false):
			return o
	return opts[0] if not opts.is_empty() else {}


# ---------- Taking tasks ----------

## Seconds a helper waits before taking a new task: slower when unhappy (`Staff.slowness`).
static func reaction(satisfaction: float) -> float:
	return REACT_BASE * Staff.slowness(satisfaction)


## Whether a helper is on the board at all: hired, at work today, not on a break.
static func at_work(staff: Staff, person: int, day: int, t: float, day_length: float) -> bool:
	if staff.employee(person).is_empty():
		return false
	return not staff.is_day_off(person, day) and not staff.on_break(person, t, day_length)


## Gives each free helper the task that suits them best and reserves it. `helpers`:
## [{id: person, cell, idle: seconds since their last task, down: bool}]. A helper on a
## break, a day off or down on the floor is taken off the board (their task goes back).
## Returns {person: task} for the tasks handed out this call.
func assign(staff: Staff, helpers: Array, day: int, t: float, day_length: float) -> Dictionary:
	var out := {}
	for h: Dictionary in helpers:
		var person := int(h.id)
		if h.get("down", false) or not at_work(staff, person, day, t, day_length):
			release(person)
			continue
		if held_by.has(person):
			continue
		var e := staff.employee(person)
		if float(h.get("idle", 0.0)) < reaction(float(e.satisfaction)):
			continue
		var task := best_for(e.duties, h.cell)
		if task.is_empty():
			continue
		reserve(person, task)
		out[person] = task
	return out


## The open task these duties allow with the best score from `cell`: urgency (in cells)
## minus the walk. Prep tasks narrow to the stations the duties cover, and the chosen
## station goes on the task as "station" (the free one with the best quality, then nearest).
func best_for(duties: Array, cell: Vector2i) -> Dictionary:
	var best := {}
	var best_score := -INF
	for key: String in tasks:
		if reserved.has(key) or chef_keys.has(key):
			continue
		var task: Dictionary = tasks[key]
		if not _allowed(task, duties):
			continue
		var place: Vector2i = task.cell
		var picked := {}
		if task.type == "prep":
			picked = _station_for(task, duties, cell)
			if picked.is_empty():
				continue
			if task.get("item") == null:
				place = picked.cell
		var score: float = task.urgency * URGENCY_CELLS - _walk(cell, place)
		if score > best_score or (score == best_score and key < str(best.get("key", ""))):
			best_score = score
			best = task.duplicate()
			if not picked.is_empty():
				best.station = picked.station
				best.quality = picked.quality
				best.duty = picked.duty
	return best


func _allowed(task: Dictionary, duties: Array) -> bool:
	for d in task.duties:
		if duties.has(d):
			return true
	return false


func _station_for(task: Dictionary, duties: Array, from: Vector2i) -> Dictionary:
	var best := {}
	for o: Dictionary in task.options:
		if not duties.has(o.duty):
			continue
		if _stations[o.station].get("busy", false) and task.get("item") == null:
			continue
		if _station_reserved(o.station):
			continue
		if best.is_empty() or o.quality > best.quality or (o.quality == best.quality
				and _walk(from, o.cell) < _walk(from, best.cell)):
			best = o
	return best


func _station_reserved(station: Variant) -> bool:
	return station_of.values().has(station)


static func _walk(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))


func reserve(person: int, task: Dictionary) -> void:
	release(person)
	reserved[task.key] = person
	held_by[person] = task.key
	if task.has("station"):
		station_of[person] = task.station


## The helper finished (or dropped) their task.
func release(person: int) -> void:
	if held_by.has(person):
		reserved.erase(held_by[person])
		held_by.erase(person)
	station_of.erase(person)


func done(person: int) -> void:
	release(person)


## A chef starts on a task: it leaves the board. If a helper held it (carrying it or
## cooking it), they let it go and move on; returns that helper, or -1.
func chef_takes(key: String) -> int:
	var helper := int(reserved.get(key, -1))
	if helper >= 0:
		release(helper)
	chef_keys[key] = true
	return helper


## The open tasks at a cell (for a chef's E: what they are about to do).
func tasks_at(cell: Vector2i) -> Array:
	var out := []
	for task: Dictionary in tasks.values():
		if task.cell == cell:
			out.append(task)
	return out


func task_of(person: int) -> Dictionary:
	return tasks.get(held_by.get(person, ""), {})


# ---------- Results ----------

## The chance a helper's prep comes out good, and bad, from their cooking skill (1 to 5)
## and the tool's quality at the job (`Kitchen.quality`). Satisfaction acts through
## `Staff.mistake_chance` in `roll_prep`. {good, bad}
static func prep_odds(skill: float, quality: float) -> Dictionary:
	var s := clampf((skill - 1.0) / 4.0, 0.0, 1.0)
	var q := maxf(quality, 0.1)
	var good := clampf(GOOD_BASE * s * q, 0.0, GOOD_MAX)
	var bad := clampf(BAD_BASE * (1.0 - s) / q, 0.0, 1.0 - good)
	return {"good": good, "bad": bad}


## Rolls a helper's prep: "good", "plain" or "bad" (a mistake from low satisfaction is
## bad; "spite" says it was on purpose). {result, spite, quality: the ingredient's}.
## A bad result drops grease as a chef's does: pass it to `FloorMess.drop_grease`.
static func roll_prep(staff: Staff, person: int, quality: float) -> Dictionary:
	var e := staff.employee(person)
	if e.is_empty():
		return {}
	var mistake := staff.roll_mistake(person)
	var result := "bad"
	if mistake == "":
		var odds := prep_odds(float(e.skills.food), quality)
		var r := staff.rng.randf()
		result = "good" if r < odds.good else ("bad" if r < odds.good + odds.bad else "plain")
	return {"result": result, "spite": mistake == "spite", "quality": Prep.quality_of(result)}


## Rolls any other task: {ok: bool, spite: bool}. Not ok is the task's slip: a dropped
## plate, dirt left behind, an order misheard.
static func roll_task(staff: Staff, person: int) -> Dictionary:
	var mistake := staff.roll_mistake(person)
	return {"ok": mistake == "", "spite": mistake == "spite"}


## A helper's prep drops grease through the floor's own rules (PRD 9).
static func drop_grease(mess: FloorMess, job: String, result: String, cells: Array, mess_factor := 1.0,
		has_hood := false) -> Variant:
	return mess.drop_grease(job, result, cells, mess_factor, has_hood)
