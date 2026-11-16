class_name HelperWork
extends RefCounted
## How a hired helper works the room in service (PRD 10, section 9; milestone 10.6). The
## task board (`JobBoard`) says what to do; this says how: the steps of each task, how
## fast a helper walks and works, what a ticket still lacks, who chats with whom, where an
## idle helper waits, and what the day does to their satisfaction. Pure logic: the scene
## side is game/crew.gd, which walks the steps in the room.
##
## A step is {do, at?: cell, ...}. The game resolves the steps that name no cell ("deliver",
## "to_sink", "to_door", "stash") when it reaches them, since what is free changes.
##   take      at a storage cell, take `kind` out of a box
##   pick      at a station, pick up the raw `kind` lying there
##   cook      at a tool, cook the raw `kind` in hand by `job` (`in_place`: it is already there)
##   pour      at a dispenser, pour `kind`
##   deliver   take the prepped thing in hand to its ticket's tray (`assemble`: allowed to
##             add it) or else down on a free surface
##   leave     put the raw thing in hand down near `at`, for a cook
##   assemble  build ticket `ticket`'s tray from what is made (expanded by the game)
##   pick_tray at a station, pick up ticket `ticket`'s finished tray
##   serve     at a table, serve the tray in hand
##   order     at a table, take its order
##   clear     at a table, take a dirty tray off it
##   to_sink   put the dirty tray in hand in the sink
##   wash      at a sink, wash up until it is empty
##   empty_bin at a bin, take the bag out of it
##   to_door   take the rubbish bag in hand out of the front door
##   wipe      at a dirty cell, clean it with `tool`
##   help      beside someone down on the floor, help them up

## Walking: metres a second at one star, and what each further star adds (a chef walks 4.4).
const WALK_BASE := 3.0          # tunable
const WALK_PER_STAR := 0.3      # tunable: five stars walk 4.2
## Working: time multiplier at one star, less per further star (five stars: 1.0x).
const WORK_SLOW := 1.4          # tunable
const WORK_PER_STAR := 0.1      # tunable
## Seconds each kind of work takes a five-star helper. (tunable)
const TASK_SECONDS := {
	"take": 0.4, "pick": 0.3, "put": 0.3, "order": 1.2, "clear": 0.5, "wash": 1.2,
	"empty_bin": 0.6, "wipe": 0.8, "serve": 0.4, "pour": 1.6, "add": 0.3,
}
const PRESS_SECONDS := 2.2      # tunable: a press tool's job (chop, slice, grate...) at a base tool
const HEAT_REACT := 0.25        # tunable: seconds after the food is done before they lift it
const CHAT_RANGE := 2           # cells (walking distance) apart that two free helpers chat
const SERVE_JOY := 0.03         # tunable: joy a guest gets per star of serving skill over three
const SLIP_HIT := 0.05          # tunable: satisfaction lost when a helper slips
const DIRT_BOTHERS := 3         # dirt at this level or more around a helper wears them down
const DRAIN_AT_ONE := 0.01      # tunable: satisfaction a second lost at clean tolerance 1, at DIRT_BOTHERS
const GOOD_WIPE_FROM := 4.0     # cleaning skill from which a wipe clears two levels
const IDLE_CHAT_AFTER := 1.0    # seconds idle before a helper is free to chat

## The kind of work each task is, for training and for the tolerance it wears on.
const TASK_KIND := {
	"prep": "food", "fetch": "food", "assemble": "food", "tray": "food", "scrap": "food",
	"order": "service", "carry": "service", "clear": "service", "help_up": "service",
	"dirt": "clean", "wash": "clean", "bin": "clean",
}


# ---------- Pace ----------

static func walk_speed(rating: int) -> float:
	return WALK_BASE + WALK_PER_STAR * (clampi(rating, 1, 5) - 1)


## Seconds a piece of work takes: its base, stretched by a low rating and by low
## satisfaction (`Staff.slowness`).
static func work_time(base: float, rating: int, satisfaction: float) -> float:
	return base * (WORK_SLOW - WORK_PER_STAR * (clampi(rating, 1, 5) - 1)) * Staff.slowness(satisfaction)


static func task_seconds(what: String, rating: int, satisfaction: float) -> float:
	return work_time(float(TASK_SECONDS.get(what, 0.5)), rating, satisfaction)


## Seconds a press tool's job takes: a better tool is quicker.
static func press_seconds(quality: float, rating: int, satisfaction: float) -> float:
	return work_time(PRESS_SECONDS / clampf(quality, 0.5, 2.0), rating, satisfaction)


## How many levels of dirt one wipe clears, from cleaning skill (1 to 5), with `tool` (a
## flat mop clears a whole cell, PRD 9.5) and on a cell laid with cleaner (`one_press`:
## whatever its level).
static func wipe_levels(skill: float, tool := "", one_press := false) -> int:
	var levels := 2 if skill >= GOOD_WIPE_FROM else 1
	if CleanTools.TOOLS.has(tool):
		levels = maxi(levels, int(CleanTools.TOOLS[tool].levels))
		if one_press and CleanTools.uses_of(tool) == 0:
			return FloorMess.MAX_LEVEL
	elif one_press:
		return FloorMess.MAX_LEVEL
	return levels


## The joy (or letdown, below three stars) a guest gets from being served by them.
static func serve_joy(skill: float) -> float:
	return (skill - 3.0) * SERVE_JOY


## Satisfaction lost over `delta` seconds of working beside dirt at `level`: tolerance 1
## loses `DRAIN_AT_ONE` a second, tolerance 5 nothing.
static func work_drain(clean_tolerance: float, level: int, delta: float) -> float:
	if level < DIRT_BOTHERS:
		return 0.0
	var care := clampf((5.0 - clean_tolerance) / 4.0, 0.0, 1.0)
	return DRAIN_AT_ONE * care * (1.0 + 0.5 * (level - DIRT_BOTHERS)) * delta


# ---------- Steps ----------

## The steps of a task as the board hands it out (`JobBoard.best_for`). `duties`: the
## helper's. `dest_duty`: for a fetch, the duty of the tool it goes to (the game reads
## it from the room), so a fetcher who also cooks there cooks it, and one who does not
## leaves it by the tool for a cook.
static func steps(task: Dictionary, duties: Array, dest_duty := "") -> Array:
	var may_assemble := duties.has("assemble")
	match str(task.get("type", "")):
		"fetch":
			var kind := str(task.kind)
			var hold := hold_for(kind)
			var out: Array = [{"do": "take", "at": task.cell, "kind": str(task.get("source", kind)),
				"ready": task.get("ready", false)}]
			var job := str(task.get("job", ""))
			if job == "" or job == "none":
				out.append({"do": "deliver", "ticket": task.ticket, "assemble": may_assemble})
			elif dest_duty != "" and duties.has(dest_duty):
				out.append({"do": "cook", "at": task.dest, "job": job, "kind": kind, "hold": hold, "ticket": task.ticket})
				out.append({"do": "deliver", "ticket": task.ticket, "assemble": may_assemble})
			else:
				out.append({"do": "leave", "at": task.dest})
			return out
		"prep":
			var at: Vector2i = task.get("station", task.cell)
			var hold := str(task.get("hold", hold_for(str(task.kind))))
			var deliver := {"do": "deliver", "ticket": task.ticket, "assemble": may_assemble}
			if str(task.get("job", "")) == "pour" and task.get("item") == null:
				return [{"do": "pour", "at": at, "kind": task.kind}, deliver]
			if task.cell == at:
				return [{"do": "cook", "at": at, "job": task.job, "kind": task.kind, "hold": hold, "in_place": true, "ticket": task.ticket}, deliver]
			return [{"do": "pick", "at": task.cell, "kind": task.kind, "hold": hold},
				{"do": "cook", "at": at, "job": task.job, "kind": task.kind, "hold": hold, "ticket": task.ticket}, deliver]
		"assemble":
			return [{"do": "assemble", "ticket": task.ticket}]
		"tray":
			return [{"do": "start_tray", "ticket": task.ticket}]
		"scrap":
			return [{"do": "pick", "at": task.cell, "kind": task.kind, "state": "burnt"}, {"do": "bin"}]
		"carry":
			return [{"do": "pick_tray", "at": task.cell, "ticket": task.tray}, {"do": "serve", "at": task.table}]
		"order":
			return [{"do": "order", "at": task.cell}]
		"clear":
			return [{"do": "clear", "at": task.cell}, {"do": "to_sink"}]
		"help_up":
			return [{"do": "help", "at": task.cell, "person": task.person}]
		"dirt":
			return [{"do": "wipe", "at": task.cell, "tool": clean_tool(duties)}]
		"wash":
			return [{"do": "wash", "at": task.cell}]
		"bin":
			return [{"do": "empty_bin", "at": task.cell}, {"do": "to_door"}]
	return []


## What a helper holds to make `kind` at its tool (PRD 10.7): its own raw form, or for a
## kind made from another's stock that stock as it comes out of the box (a raw lemon for
## lemonade, a scoop of ice cream, which needs no prep, for a milkshake).
static func hold_for(kind: String) -> String:
	var src := Pantry.source_of(kind)
	if src != kind and not Pantry.needs_prep(src):
		return Tray.kind("prep", src)
	return Tray.kind("raw", src)


## The cleaning tool a helper wipes with: their first cleaning duty, a mop before a sponge.
static func clean_tool(duties: Array) -> String:
	for t: String in Staff.CLEAN_TOOLS:
		if duties.has(t):
			return t
	return ""


## What to do with what is in hand when a task is dropped: a tool goes back, a dirty tray
## to the sink, a bag out of the door, anything else down on a free surface. "" for empty hands.
static func stash_for(held: String) -> String:
	if held == "":
		return ""
	if held.begins_with("tool:"):
		return "drop"
	match held:
		"dirty_tray":
			return "to_sink"
		"rubbish_bag":
			return "to_door"
	if held.begins_with("burnt:"):
		return "bin"
	return "stash"


# ---------- Tickets ----------

## What each ticket still lacks once what is already made is counted: `tickets` oldest
## first, [{id, needs: [kinds] not yet on its tray}]; `made`: prepped kinds lying about or
## in hand, not on any tray. A made thing covers the oldest ticket that needs it.
## Returns {ticket id: [kinds]}.
static func ticket_lacks(tickets: Array, made: Array) -> Dictionary:
	var pool := made.duplicate()
	var out := {}
	for t: Dictionary in tickets:
		var lacks: Array = []
		for k in t.needs:
			var i := pool.find(k)
			if i >= 0:
				pool.remove_at(i)
			else:
				lacks.append(k)
		out[t.id] = lacks
	return out


# ---------- Idle: waiting and chatting ----------

## Who chats with whom: free helpers [{id, cell}] within `CHAT_RANGE` of each other, the
## closest pairs first, each helper in one pair at most. Returns [[a, b]].
static func chat_pairs(free: Array) -> Array:
	var pairs := []
	for i in free.size():
		for j in range(i + 1, free.size()):
			var d := _walk(free[i].cell, free[j].cell)
			if d <= CHAT_RANGE:
				pairs.append([d, free[i].id, free[j].id])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var used := {}
	var out := []
	for p: Array in pairs:
		if used.has(p[1]) or used.has(p[2]):
			continue
		used[p[1]] = true
		used[p[2]] = true
		out.append([p[1], p[2]])
	return out


## Where an idle helper waits: a free floor cell beside a desk, not `taken` by another
## helper, the one nearest `from`. `open`: cell -> true for floor anyone can stand on.
## null when there is none.
static func wait_cell(desks: Array, open: Dictionary, taken: Dictionary, from: Vector2i) -> Variant:
	var best: Variant = null
	var best_d := INF
	for d: Vector2i in desks:
		for side: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var c: Vector2i = d + side
			if not open.has(c) or taken.has(c):
				continue
			var dist := _walk(from, c)
			if dist < best_d:
				best_d = dist
				best = c
	return best


static func _walk(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))
