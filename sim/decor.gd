class_name Decor
extends RefCounted
## How decor cheers a guest. Like RollerCoaster Tycoon scenery, it is a flat joy bonus
## worked out when the guest sits down, from what is near their seat, not joy per second.
## Each piece gives its Catalog "joy" scaled by how close it is: on it (the floor or rug
## under the seat), beside it (within a cell) or only in view (further off, in sight).
## Each kind of piece counts once, at its best, and the kinds add up to CAP.

const ON := 1.0        # the floor or rug under the seat
const BESIDE := 0.5    # within a cell: the next tile, the wall the seat is against, a fern alongside
const IN_VIEW := 0.2   # further off, but in sight and within reach
const VIEW_RANGE := 3  # cells a floor, rug or wall finish can be seen from
const CAP := 0.35      # the most joy decor can add, however much there is
const FERN_REACH := 2  # a fern is seen from 2 + its tier cells
const THOUGHTS := {
	"floor_parquet": "What a fine floor",
	"floor_marble": "What a fine floor",
	"rug": "Such a cosy rug",
	"paint": "Lovely walls in here",
	"paper_stripe": "What pretty wallpaper",
	"paper_rose": "What pretty wallpaper",
	"plant": "That fern is rather nice",
}


## The share of a piece's joy that reaches a seat `dist` cells away (Chebyshev).
static func band(dist: int, reach := VIEW_RANGE) -> float:
	if dist <= 0:
		return ON
	if dist == 1:
		return BESIDE
	return IN_VIEW if dist <= reach else 0.0


## The marks a carried piece puts on each seat, by the share it would give (see mark).
const MARK_ON := "on"          # the seat is on it: full joy
const MARK_BESIDE := "beside"  # half
const MARK_VIEW := "view"      # a fifth
const MARK_NONE := "none"      # not reached
const FULL_EPS := 0.0001       # how close to CAP a seat counts as already full


## Cells apart, counting diagonals as one step (Chebyshev).
static func dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## How far the nearest of a piece's `cells` is from `seat`, counting only cells
## within `reach` that the seat can see (partitions block it). -1 when none is.
## This is the one sight rule for decor: the bonus and the reach marks both use it.
static func nearest(grid: Grid, seat: Vector2i, cells: Array, reach: int) -> int:
	var best := -1
	for c: Vector2i in cells:
		var d := dist(seat, c)
		if d <= reach and (best < 0 or d < best) and (c == seat or grid.has_los(seat, c)):
			best = d
	return best


## The share of a piece's joy a seat gets when the nearest cell of it it can see is
## `d` away (-1: none). Nobody sits on a wall or a fern, so those are at best beside.
static func share(id: String, d: int, tier := 1) -> float:
	if d < 0:
		return 0.0
	if Catalog.is_finish(id) or id == "plant":
		d = maxi(d, 1)
	return band(d, reach(id, tier))


## The share a seat gets from one piece covering `cells` (a stretch of floor, a
## rug's six cells, the floor either side of a finished wall, a fern's own cell).
static func share_from(grid: Grid, seat: Vector2i, id: String, cells: Array, tier := 1) -> float:
	return share(id, nearest(grid, seat, cells, reach(id, tier)), tier)


## The cells a wall finish is seen through: the floor either side of each edge.
## A seat on the far side of a wall cannot see this side's floor, so each face
## only cheers its own side.
static func finish_cells(plan: Floorplan, edges: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for e: Vector3i in edges:
		for side in Floorplan.sides(e):
			if plan.has_floor(side) and not out.has(side):
				out.append(side)
	return out


## Which mark a seat gets for a share: on, beside, in view or not reached.
static func mark(s: float) -> String:
	if s >= ON:
		return MARK_ON
	if s >= BESIDE:
		return MARK_BESIDE
	return MARK_VIEW if s > 0.0 else MARK_NONE


## Whether a seat already gets all the decor joy there is, so more gains nothing.
static func is_full(near: Array) -> bool:
	return float(bonus(near).joy) >= CAP - FULL_EPS


## How far a piece can be seen from, in cells.
static func reach(id: String, tier := 1) -> int:
	return FERN_REACH + tier if id == "plant" else VIEW_RANGE


## `near` is what a seat can see: {"id", "dist", "tier" (optional)}, with dist in cells
## from the seat (0 is under it). Nobody sits on a wall, so a finish is at best beside.
## Returns {"joy": the bonus, "best": the id that gave most, or ""}.
static func bonus(near: Array) -> Dictionary:
	var best := {}
	for n: Dictionary in near:
		var id: String = n.id
		var tier := int(n.get("tier", 1))
		var v := Catalog.joy_of(id, tier) * share(id, int(n.dist), tier)
		if v > float(best.get(id, 0.0)):
			best[id] = v
	var total := 0.0
	var top := ""
	for id: String in best:
		total += best[id]
		if top == "" or best[id] > best[top]:
			top = id
	return {"joy": minf(CAP, total), "best": top}


static func thought(id: String) -> String:
	return THOUGHTS.get(id, "")
