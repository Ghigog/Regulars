class_name CleanTools
extends RefCounted
## Cleaning tools for floor dirt (PRD 9.4): the mop and the sponge, where each lives, how
## they clear (and, once dirty, spread) dirt, and the robot sweeper's rules. Pure logic on
## a FloorMess and plain cells; the scene side is game/clean_kit.gd. The tools' trees and
## treatments are 9.5.

## Each hand tool: the home it is kept in ("bucket" or "hook"; a closet takes either),
## levels cleared a press, seconds a press takes (held E repeats at this pace), and how
## many levels it clears before it is dirty. (tunable)
const TOOLS := {
	"mop": {"name": "Mop", "home": "bucket", "levels": 1, "time": 0.6, "dirty_after": 4},
	"sponge": {"name": "Sponge", "home": "hook", "levels": 1, "time": 0.3, "dirty_after": 2},
}
## The pieces that are homes, and the kind of home each is.
const HOMES := {"mop_bucket": "bucket", "hook": "hook"}
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


static func press_time(tool: String) -> float:
	return float(TOOLS[tool].time)


static func is_dirty(tool: String, used: int) -> bool:
	return TOOLS.has(tool) and used >= dirty_after(tool)


## How clean a tool looks, 1 (clean) to 0 (dirty): carried as the held item's quality.
static func cleanness(tool: String, used: int) -> float:
	return clampf(1.0 - float(used) / dirty_after(tool), 0.0, 1.0)


static func used_from(tool: String, cleanness_: float) -> int:
	return clampi(roundi((1.0 - cleanness_) * dirty_after(tool)), 0, dirty_after(tool))


static func rinses(piece: String) -> bool:
	return RINSE_AT.has(piece)


## One press of a tool on a cell. A clean tool clears its levels and gets dirtier by
## what it cleared; a dirty one spreads instead: the cell keeps its dirt and a level
## lands on a free floor cell beside it. Covered (under furniture) or clean cells: nothing.
## Returns {"did": "clean" | "spread" | "", "used": the tool's new count, "to": the cell
## the spread landed on, or null}.
static func press(mess: FloorMess, cell: Vector2i, tool: String, used: int) -> Dictionary:
	var out := {"did": "", "used": used, "to": null}
	if not TOOLS.has(tool) or mess.level(cell) <= 0 or not mess.can_clean(cell):
		return out
	if is_dirty(tool, used):
		var around := []
		for d in FloorMess.NEIGHBOURS:
			var c: Vector2i = cell + d
			if mess.is_floor(c) and not mess.is_covered(c):
				around.append(c)
		if not around.is_empty():
			out.to = mess.add_dirt(around[mess.rng.randi() % around.size()])
		out.did = "spread"
		return out
	var off := mess.clean(cell, int(TOOLS[tool].levels))
	out.did = "clean"
	out.used = mini(used + off, dirty_after(tool))
	return out


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
