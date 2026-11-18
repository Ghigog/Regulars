class_name CleanTools
extends RefCounted
## Cleaning tools for floor dirt (PRD 9.4): the mop and the sponge, where each lives, how
## they clear (and, once dirty, spread) dirt, and the robot sweeper's rules. Pure logic on
## a FloorMess and plain cells; the scene side is game/clean_kit.gd. The tools' trees
## (PRD 9.5) are Kitchen.NODES: each home node there names the tool it keeps ("tool").

## Each hand tool: the home it is kept in ("bucket" or "hook"; a closet takes either),
## levels cleared a press (MAX_LEVEL: the whole cell), seconds a press takes (held E
## repeats at this pace), and how many presses it cleans before it is dirty (0: never).
## "grease": kitchen grease only. "uses": presses a day, each taking a level 4 cell to
## level 2, with faster help for a fallen guest ("help"). "push": clears every cell the
## chef walks over, slowing them to "walk". (tunable)
const TOOLS := {
	"mop": {"name": "Mop", "home": "bucket", "levels": 1, "time": 0.6, "dirty_after": 4},
	"sponge_mop": {"name": "Sponge-head mop", "home": "bucket", "levels": 1, "time": 0.6, "dirty_after": 6},
	"flat_mop": {"name": "Flat mop", "home": "bucket", "levels": FloorMess.MAX_LEVEL, "time": 0.6, "dirty_after": 8},
	"scrubber": {"name": "Floor scrubber", "home": "bucket", "levels": FloorMess.MAX_LEVEL, "time": 0.6,
		"dirty_after": 0, "push": true, "walk": 0.55},
	"wringer_mop": {"name": "Wringer mop", "home": "bucket", "levels": 1, "time": 0.6, "dirty_after": 0},
	"cleaner_mop": {"name": "Mop with cleaner", "home": "bucket", "levels": FloorMess.MAX_LEVEL, "time": 0.6, "dirty_after": 4},
	"strong_mop": {"name": "Mop with strong cleaner", "home": "bucket", "levels": FloorMess.MAX_LEVEL, "time": 0.6,
		"dirty_after": 0},
	"sponge": {"name": "Sponge", "home": "hook", "levels": 1, "time": 0.3, "dirty_after": 2},
	"scourer": {"name": "Scourer", "home": "hook", "levels": 1, "time": 0.3, "dirty_after": 4},
	"grease_scraper": {"name": "Grease scraper", "home": "hook", "levels": FloorMess.MAX_LEVEL, "time": 0.3,
		"dirty_after": 0, "grease": true},
	"spill_kit": {"name": "Spill kit", "home": "hook", "levels": 2, "time": 0.6, "dirty_after": 0,
		"uses": 3, "help": 0.5},
}
## Bare hands (no tool held): holding E scrubs the cell, a level every HAND_TIME seconds.
## Every tool is faster (a press is 0.3 to 0.6 s). (tunable)
const HAND_TIME := 1.8
const HAND_LEVELS := 1

## The pieces that are homes, and the kind of home each is (a catalog type).
const HOMES := {"mop_bucket": "bucket", "hook": "hook", "sponge": "hook"}
const SPILL_LEVEL := 4   # the spill kit works on a cell this dirty only
const CLOSET := "closet"
## Where a home starts with its tool when bought: the bucket comes with a mop, and a
## sponge is sold hanging on its own hook.
const COMES_WITH := {"mop_bucket": "mop", "sponge": "sponge"}
## Rinsed here: a dirty tool comes back clean.
const RINSE_AT: Array[String] = ["mop_bucket", "sink"]

## The robot sweeper (PRD 9.4): drifts slowly to the nearest dirt it can reach and clears a
## level every few seconds. Where it stands counts as this level of dirt (it slows, like a
## puddle). (tunable)
const ROBOT_SPEED := 0.7        # metres a second (a chef walks 4.4)
const ROBOT_CLEAN_TIME := 3.0   # seconds a level
const ROBOT_LEVEL := 2
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func is_tool(id: String) -> bool:
	return TOOLS.has(id)


## A tool kept in a bucket (any mop, the scrubber): drawn as a mop. Else a hand tool.
static func is_mop(tool: String) -> bool:
	return TOOLS.has(tool) and str(TOOLS[tool].home) == "bucket"


## The tool a newly bought home starts with: its tree node's ("tool"), else COMES_WITH.
static func comes_with(piece: String) -> String:
	var t := Kitchen.tool_of(piece)
	return t if t != "" else str(COMES_WITH.get(piece, ""))


static func name_of(tool: String) -> String:
	return str(TOOLS[tool].name) if TOOLS.has(tool) else ""


## The kind of home a piece is ("bucket", "hook"), or "" for none. A closet is the cell,
## not a piece: see fits().
static func home_kind(piece: String) -> String:
	return str(HOMES.get(piece, ""))


## Whether a tool may be kept in a home of this kind.
static func fits(home: String, tool: String) -> bool:
	if not TOOLS.has(tool) or home == "":
		return false
	return home == CLOSET or str(TOOLS[tool].home) == home


static func dirty_after(tool: String) -> int:
	return int(TOOLS[tool].dirty_after)


## A tool that never gets dirty (a wringer mop, a scrubber, the scraper, a spill kit).
static func never_dirty(tool: String) -> bool:
	return TOOLS.has(tool) and dirty_after(tool) <= 0


## Seconds between presses. A dirty tool still cleans, only slower (review, item 8).
const DIRTY_SLOW := 2.0   # tunable: a dirty tool takes this many times as long a press
static func press_time(tool: String, used := 0) -> float:
	return float(TOOLS[tool].time) * (DIRTY_SLOW if is_dirty(tool, used) else 1.0)


static func is_dirty(tool: String, used: int) -> bool:
	return TOOLS.has(tool) and not never_dirty(tool) and used >= dirty_after(tool)


## Presses a day for a tool that runs out (the spill kit), else 0.
static func uses_of(tool: String) -> int:
	return int(TOOLS[tool].get("uses", 0)) if TOOLS.has(tool) else 0


static func used_up(tool: String, used: int) -> bool:
	return uses_of(tool) > 0 and used >= uses_of(tool)


static func pushes(tool: String) -> bool:
	return TOOLS.has(tool) and TOOLS[tool].get("push", false)


## The chef's speed while holding the tool (a floor scrubber is slow to walk).
static func walk_speed(tool: String) -> float:
	return float(TOOLS[tool].get("walk", 1.0)) if TOOLS.has(tool) else 1.0


## How long helping a fallen guest up takes with this tool in hand, times the usual.
static func help_factor(tool: String) -> float:
	return float(TOOLS[tool].get("help", 1.0)) if TOOLS.has(tool) else 1.0


## The count a tool's look and wear are measured against: presses before dirty, or
## uses a day; 0 for a tool that neither dirties nor runs out.
static func _wear(tool: String) -> int:
	return uses_of(tool) if uses_of(tool) > 0 else maxi(dirty_after(tool), 0)


## How clean a tool looks, 1 (clean) to 0 (dirty, or used up for the day): carried as
## the held item's quality.
static func cleanness(tool: String, used: int) -> float:
	if _wear(tool) <= 0:
		return 1.0
	return clampf(1.0 - float(used) / _wear(tool), 0.0, 1.0)


static func used_from(tool: String, cleanness_: float) -> int:
	if _wear(tool) <= 0:
		return 0
	return clampi(roundi((1.0 - cleanness_) * _wear(tool)), 0, _wear(tool))


static func rinses(piece: String) -> bool:
	return RINSE_AT.has(piece)


## Why a tool will not work on a cell it could reach, or "" if it will: the grease
## scraper is no use on guest mess; a spill kit is for a cell covered in it, while it
## has uses left today.
static func refusal(mess: FloorMess, cell: Vector2i, tool: String, used: int) -> String:
	if not TOOLS.has(tool):
		return ""
	if TOOLS[tool].get("grease", false) and not mess.is_grease(cell):
		return "The scraper is for kitchen grease, not guest mess."
	if uses_of(tool) > 0:
		if used_up(tool, used):
			return "The spill kit is used up for today."
		if mess.level(cell) < SPILL_LEVEL:
			return "The spill kit is for a spill that covers the cell."
	return ""


## One press of a tool on a cell. It clears its levels (the whole cell on a floor
## cleaner, PRD 9.5) and is a press dirtier; a dirty tool cleans as well, only slower
## (press_time), shown by its wear pip. A spill kit takes a covered cell down two levels
## and spends a use. Covered (under furniture) or clean cells, or a tool that refuses the
## cell: nothing. Returns {"did": "clean" | "refused" | "", "used": the tool's new count,
## "to": null, "why": the refusal}.
static func press(mess: FloorMess, cell: Vector2i, tool: String, used: int) -> Dictionary:
	var out := {"did": "", "used": used, "to": null, "why": ""}
	if not TOOLS.has(tool) or mess.level(cell) <= 0 or not mess.can_clean(cell):
		return out
	out.why = refusal(mess, cell, tool, used)
	if out.why != "":
		out.did = "refused"
		return out
	var levels := int(TOOLS[tool].levels)
	if mess.one_press(cell) and uses_of(tool) == 0:
		levels = FloorMess.MAX_LEVEL
	mess.clean(cell, levels)
	out.did = "clean"
	if _wear(tool) > 0:
		out.used = mini(used + 1, _wear(tool))
	return out


## One scrub by hand: clears HAND_LEVELS off a reachable dirty cell. Returns the levels
## taken off (0 under furniture or on a clean cell).
static func hand_scrub(mess: FloorMess, cell: Vector2i) -> int:
	if mess.level(cell) <= 0:
		return 0
	return mess.clean(cell, HAND_LEVELS)


## The level anyone walking over a cell feels: its dirt, or the robot (or a tool left
## lying there) as ROBOT_LEVEL, whichever is more.
static func felt_level(dirt_level: int, in_the_way: bool) -> int:
	return maxi(dirt_level, ROBOT_LEVEL) if in_the_way else dirt_level


## The robot's way to the nearest dirt it can clean, walking from `from` over `walkable`
## cells (Vector2i -> true) through `open` (a Callable(a, b) -> bool for a step between
## two side-by-side cells). Returns the cells to walk, ending on the dirty one; [] when
## it stands on dirt already or none can be reached.
static func path_to_dirt(mess: FloorMess, from: Vector2i, walkable: Dictionary, open: Callable) -> Array:
	return _search(from, walkable, open,
		func(c: Vector2i) -> bool: return mess.level(c) > 0 and mess.can_clean(c))


## The way back to `to` (the dock, which is not itself walkable): ends on `to`.
static func path_home(from: Vector2i, to: Vector2i, walkable: Dictionary, open: Callable) -> Array:
	if from == to:
		return []
	var w := walkable.duplicate()
	w[to] = true
	return _search(from, w, open, func(c: Vector2i) -> bool: return c == to)


## Breadth first over the cells, sides only (the robot does not cut corners).
static func _search(from: Vector2i, walkable: Dictionary, open: Callable, goal: Callable) -> Array:
	if goal.call(from):
		return []
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in SIDES:
			var n: Vector2i = c + d
			if came.has(n) or not walkable.has(n) or not open.call(c, n):
				continue
			came[n] = c
			if goal.call(n):
				var path := [n]
				var at: Vector2i = c
				while at != from:
					path.push_front(at)
					at = came[at]
				return path
			queue.append(n)
	return []
