class_name Floorplan
extends RefCounted
## The shape of the restaurant: which cells have a floor, the walls the player has
## put up between floors, and the doors and archways cut into walls.
## The outer walls are never stored: any edge with floor on one side only is one,
## so laying floor moves them out and lifting floor brings them back in.
## Edges are Vector3i(x, y, axis) as in Grid: axis 0 is the north edge of cell
## (x, y), axis 1 its west edge.

const KINDS: Array[String] = ["tile", "planks"]
const OPENINGS: Array[String] = ["door", "arch"]   # plus "entrance", the front door, which is fixed

var lot: Rect2i       # where floor may be laid
var floors := {}      # Vector2i -> "tile" | "planks"
var built := {}       # Vector3i edge -> true: walls the player put up between two floors
var openings := {}    # Vector3i edge -> "door" | "arch" | "entrance"


func _init(lot_: Rect2i) -> void:
	lot = lot_


## The two cells either side of an edge: the one it belongs to (south or east,
## the side nearer the camera) first, then the one behind it.
static func sides(edge: Vector3i) -> Array[Vector2i]:
	var a := Vector2i(edge.x, edge.y)
	return [a, a + (Vector2i(0, -1) if edge.z == 0 else Vector2i(-1, 0))]


## The four edges round a cell: north, south, west, east.
static func cell_edges(c: Vector2i) -> Array[Vector3i]:
	return [Vector3i(c.x, c.y, 0), Vector3i(c.x, c.y + 1, 0), Vector3i(c.x, c.y, 1), Vector3i(c.x + 1, c.y, 1)]


func has_floor(c: Vector2i) -> bool:
	return floors.has(c)


func kind(c: Vector2i) -> String:
	return floors.get(c, "")


## Fills a rectangle with one kind of floor, no questions asked (for setting up).
func fill(r: Rect2i, k: String) -> void:
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			floors[Vector2i(x, y)] = k


## A wall stands on an edge with floor on one side only, or where one was built.
func is_wall(edge: Vector3i) -> bool:
	var s := sides(edge)
	var fa := has_floor(s[0])
	var fb := has_floor(s[1])
	return fa != fb or (fa and built.has(edge))


## Every wall edge: the outline of the floor and the walls built inside it.
func walls() -> Array[Vector3i]:
	var seen := {}
	for c: Vector2i in floors:
		for e in cell_edges(c):
			if not seen.has(e) and is_wall(e):
				seen[e] = true
	var out: Array[Vector3i] = []
	out.assign(seen.keys())
	return out


## Walls nobody can walk through: every wall without a door or archway in it.
func solid_walls() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for e in walls():
		if not openings.has(e):
			out.append(e)
	return out


## Openings that let people through but not their gaze.
func doors() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for e: Vector3i in openings:
		if openings[e] == "door":
			out.append(e)
	return out


# ---------------------------------------------------------------- floors

## Can floor of this kind go here? It must be on the lot and either touch the
## floor already laid, or replace a floor of another kind.
func can_lay(c: Vector2i, k: String) -> bool:
	if not lot.has_point(c) or not KINDS.has(k):
		return false
	if has_floor(c):
		return kind(c) != k
	for d in Grid.DIRS:
		if has_floor(c + d):
			return true
	return false


## Which of these cells would take floor, in an order where each touches floor
## laid before it. Changes nothing.
func lay_order(cells: Array[Vector2i], k: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var pending := cells.duplicate()
	var added := {}
	var progress := true
	while progress and not pending.is_empty():
		progress = false
		var rest: Array[Vector2i] = []
		for c: Vector2i in pending:
			var ok := false
			if lot.has_point(c) and KINDS.has(k):
				if has_floor(c):
					ok = kind(c) != k
				else:
					for d in Grid.DIRS:
						if has_floor(c + d) or added.has(c + d):
							ok = true
							break
			if ok:
				out.append(c)
				added[c] = true
				progress = true
			else:
				rest.append(c)
		pending = rest
	return out


## Lays one floor. Walls between it and the floor beside it come down, and any
## door or archway in them goes too: returned as {edge: "door" | "arch"} so they
## can be refunded.
func lay(c: Vector2i, k: String) -> Dictionary:
	floors[c] = k
	return _tidy(c)


## Lifts one floor. Its built walls are now outer walls (or nothing), so they are
## forgotten; openings left on no wall go. Returns the openings removed, as lay does.
func lift(c: Vector2i) -> Dictionary:
	floors.erase(c)
	return _tidy(c)


func _tidy(c: Vector2i) -> Dictionary:
	var gone := {}
	for e in cell_edges(c):
		var s := sides(e)
		if not (has_floor(s[0]) and has_floor(s[1])):
			built.erase(e)
		if openings.has(e) and not is_wall(e):
			gone[e] = openings[e]
			openings.erase(e)
	return gone


# ---------------------------------------------------------------- walls and openings

## A wall can be built on an edge between two floors that has none yet.
func can_build(edge: Vector3i) -> bool:
	var s := sides(edge)
	return has_floor(s[0]) and has_floor(s[1]) and not built.has(edge)


func build(edge: Vector3i) -> void:
	built[edge] = true


## Takes down a built wall. Returns its opening, if it had one, so it can be refunded.
func unbuild(edge: Vector3i) -> String:
	built.erase(edge)
	var had: String = openings.get(edge, "")
	openings.erase(edge)
	return had


## A door or archway can go in any wall that has nothing in it yet, as long as
## both sides are on the lot (one may still be bare ground, to be floored later).
func can_open(edge: Vector3i, what: String) -> bool:
	if not OPENINGS.has(what) or not is_wall(edge) or openings.has(edge):
		return false
	for c in sides(edge):
		if not lot.has_point(c):
			return false
	return true


## Can people get through this opening? Both sides must be floor. (Whether
## furniture is in the way is for the grid to say.)
func opening_has_floor(edge: Vector3i) -> bool:
	var s := sides(edge)
	return has_floor(s[0]) and has_floor(s[1])


## Whether a straight run of edges along a line, from lattice point `a` to `b`,
## runs along x (axis 0) or z (axis 1); the longer way wins. Returns the edges.
static func line(a: Vector2i, b: Vector2i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if absi(b.x - a.x) >= absi(b.y - a.y):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x)):
			out.append(Vector3i(x, a.y, 0))
	else:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y)):
			out.append(Vector3i(a.x, y, 1))
	return out


## Every cell in the rectangle with corners at cells `a` and `b`.
static func rect_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			out.append(Vector2i(x, y))
	return out


## The smallest rectangle round every floor.
func bounds() -> Rect2i:
	var r := Rect2i()
	var first := true
	for c: Vector2i in floors:
		if first:
			r = Rect2i(c, Vector2i.ONE)
			first = false
		else:
			r = r.expand(c).expand(c + Vector2i.ONE)
	return r
