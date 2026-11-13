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
		var dist := int(n.dist)
		if Catalog.is_finish(id) or id == "plant":
			dist = maxi(dist, 1)
		var v := Catalog.joy_of(id, tier) * band(dist, reach(id, tier))
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
