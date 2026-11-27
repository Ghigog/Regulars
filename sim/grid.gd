class_name Grid
extends RefCounted
## Tile grid for the restaurant: furniture blocks cells, walls sit on cell edges.
## Cell (x, y) covers world x..x+1 and z..z+1.

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var size: Vector2i
var origin := Vector2i.ZERO   # the lowest cell; the grid may reach into negative cells
var blocked := {}   # Vector2i -> true: furniture, nobody can stand here
var reserved := {}  # Vector2i -> true: seats and doorways, walkable but not buildable
var walls := {}     # Vector3i(x, y, axis) -> true; axis 0 = north edge of the cell, 1 = west edge
var doors := {}     # Vector3i edge -> true: people walk through, but nobody sees through
var outside := {}   # Vector2i -> true: bare ground with no floor, nobody can stand here


func _init(w: int, h: int, from := Vector2i.ZERO) -> void:
	size = Vector2i(w, h)
	origin = from


static func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


static func center(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0, c.y + 0.5)


static func edge_between(a: Vector2i, b: Vector2i) -> Vector3i:
	if a.x == b.x:
		return Vector3i(a.x, maxi(a.y, b.y), 0)
	return Vector3i(maxi(a.x, b.x), a.y, 1)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= origin.x and c.y >= origin.y and c.x < origin.x + size.x and c.y < origin.y + size.y


## Cells outside the room a chef may stand on: the doorway and the open pavement rows.
## From `pavement_from` on (the kerb tile and the road) a chef cannot stand. Guests
## are not held to this; they use `is_blocked` alone.
var pavement_from := 1 << 30   # the first column a chef cannot stand in


func is_blocked(c: Vector2i) -> bool:
	return not in_bounds(c) or blocked.has(c) or outside.has(c)


## Like `is_blocked`, for a chef: also the kerb tile and beyond.
func chef_blocked(c: Vector2i) -> bool:
	return is_blocked(c) or c.x >= pavement_from


func edge_open(a: Vector2i, b: Vector2i) -> bool:
	return not walls.has(edge_between(a, b))


## Open to the eye: no wall and no door.
func sight_open(a: Vector2i, b: Vector2i) -> bool:
	var e := edge_between(a, b)
	return not walls.has(e) and not doors.has(e)


func can_step(a: Vector2i, b: Vector2i) -> bool:
	return not is_blocked(b) and edge_open(a, b)


## Breadth-first path. Excludes `from`, includes `to`. Empty when unreachable or from == to.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from == to or is_blocked(to):
		return result
	var came := {from: from}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if cur == to:
			break
		for d in DIRS:
			var n: Vector2i = cur + d
			if not came.has(n) and can_step(cur, n):
				came[n] = cur
				frontier.append(n)
	if not came.has(to):
		return result
	var c := to
	while c != from:
		result.push_front(c)
		c = came[c]
	return result


func reachable(from: Vector2i, to: Vector2i) -> bool:
	return from == to or not find_path(from, to).is_empty()


## Line of sight between two cell centres. Only walls block sight; furniture is low.
func has_los(a: Vector2i, b: Vector2i) -> bool:
	return _line_open(a, b, sight_open)


## Whether a chef at `a` can reach cell `b`: the same line walk as has_los, but only walls
## and partitions stop a hand. A doorway, an archway or a door edge lets it through.
func reach_open(a: Vector2i, b: Vector2i) -> bool:
	return _line_open(a, b, edge_open)


## Walks the line between two cell centres; `open` says whether the edge between two
## neighbouring cells lets it through.
func _line_open(a: Vector2i, b: Vector2i, open: Callable) -> bool:
	var from := Vector2(a) + Vector2(0.5, 0.5)
	var to := Vector2(b) + Vector2(0.5, 0.5)
	var steps := maxi(1, int(from.distance_to(to) * 10.0))
	var prev := a
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / steps)
		var cur := Vector2i(floori(p.x), floori(p.y))
		if cur == prev:
			continue
		if cur.x == prev.x or cur.y == prev.y:
			if not open.call(prev, cur):
				return false
		else:
			var m1 := Vector2i(cur.x, prev.y)
			var m2 := Vector2i(prev.x, cur.y)
			var r1: bool = open.call(prev, m1) and open.call(m1, cur)
			var r2: bool = open.call(prev, m2) and open.call(m2, cur)
			if not (r1 or r2):
				return false
		prev = cur
	return true


# ---------------------------------------------------------------- building

## Every cell that can be walked to from `from`.
func flood(from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_back()
		for d in DIRS:
			var n: Vector2i = cur + d
			if not seen.has(n) and can_step(cur, n):
				seen[n] = true
				frontier.append(n)
	return seen


## The cells someone is cut off from: each `must_reach` cell the door's flood misses, and each
## `must_touch` cell (furniture) with no open side that flood reaches.
func cut_off(door: Vector2i, must_reach: Array[Vector2i], must_touch: Array[Vector2i]) -> Array[Vector2i]:
	var seen := flood(door)
	var out: Array[Vector2i] = []
	for c in must_reach:
		if not seen.has(c):
			out.append(c)
	for c in must_touch:
		if not _touchable(seen, c):
			out.append(c)
	return out


## A station can be used from a flooded cell beside it with no wall between, or across a
## corner when at least one of the two L-paths around it has no wall.
func _touchable(seen: Dictionary, c: Vector2i) -> bool:
	for d in DIRS:
		if seen.has(c + d) and edge_open(c, c + d):
			return true
	for dx in [-1, 1]:
		for dy in [-1, 1]:
			var n := c + Vector2i(dx, dy)
			if seen.has(n) and reach_open(n, c):
				return true
	return false


## True when everyone can still get about: nobody is cut off (see `cut_off`).
func layout_ok(door: Vector2i, must_reach: Array[Vector2i], must_touch: Array[Vector2i]) -> bool:
	return cut_off(door, must_reach, must_touch).is_empty()


## True when `after` lists a cell that `before` did not: the change made the room worse.
static func _adds_cut_off(before: Array[Vector2i], after: Array[Vector2i]) -> bool:
	for c in after:
		if not before.has(c):
			return true
	return false


## Why furniture cannot go on `c` (with `seats` beside it): "" when it fits, "off_lot" (outside
## the area or on bare ground), "taken" (blocked or reserved), "shut_in" (it would cut off
## someone the door reaches now; a room that is already broken does not count against the spot).
func block_refusal(c: Vector2i, seats: Array[Vector2i], area: Rect2i, door: Vector2i,
		must_reach: Array[Vector2i], must_touch: Array[Vector2i]) -> String:
	var cells: Array[Vector2i] = [c]
	cells.append_array(seats)
	for s in cells:
		if not area.has_point(s) or outside.has(s):
			return "off_lot"
	for s in cells:
		if blocked.has(s) or reserved.has(s):
			return "taken"
	var reach := must_reach + seats
	var touch := must_touch + ([c] as Array[Vector2i])
	var before := cut_off(door, reach, touch)
	blocked[c] = true
	var after := cut_off(door, reach, touch)
	blocked.erase(c)
	return "shut_in" if _adds_cut_off(before, after) else ""


## Can furniture go on `c` (with `seats` beside it) inside `area` without cutting anyone off?
func can_place_block(c: Vector2i, seats: Array[Vector2i], area: Rect2i, door: Vector2i,
		must_reach: Array[Vector2i], must_touch: Array[Vector2i]) -> bool:
	return block_refusal(c, seats, area, door, must_reach, must_touch) == ""


## Why a wall cannot go on this edge (x, y, axis); it must lie between two cells of `area`.
## "" when it fits, else "off_lot", "taken" (a wall is already there) or "shut_in".
func wall_refusal(edge: Vector3i, area: Rect2i, door: Vector2i,
		must_reach: Array[Vector2i], must_touch: Array[Vector2i]) -> String:
	var a := Vector2i(edge.x, edge.y)
	var b := a + (Vector2i(0, -1) if edge.z == 0 else Vector2i(-1, 0))
	if not area.has_point(a) or not area.has_point(b) or outside.has(a) or outside.has(b):
		return "off_lot"
	if walls.has(edge):
		return "taken"
	var before := cut_off(door, must_reach, must_touch)
	walls[edge] = true
	var after := cut_off(door, must_reach, must_touch)
	walls.erase(edge)
	return "shut_in" if _adds_cut_off(before, after) else ""


## Can a wall go on this edge (x, y, axis)? It must lie between two cells of `area`.
func can_place_wall(edge: Vector3i, area: Rect2i, door: Vector2i,
		must_reach: Array[Vector2i], must_touch: Array[Vector2i]) -> bool:
	return wall_refusal(edge, area, door, must_reach, must_touch) == ""
