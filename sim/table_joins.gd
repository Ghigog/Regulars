class_name TableJoins
extends RefCounted
## Which pieces make one table. Two tables for two on neighbouring cells along
## their long axis, turned the same way, count as one table for four. Pieces
## are plain dictionaries {type, cell: Vector2i, facing: int, number: int}.
## A table in the result is {"pieces": Array of piece numbers, "seats": int}.

const PAIR_SEATS := 4
## A seat turned f faces cell + FACE[f] (the reverse of Station.seats_for's stool).
const FACE: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1)]
const SEAT_TYPES := ["chair", "booth_seat"]


## Tables made of "table" tiles touching edge to edge (any shape). A table is
## {"pieces": tile numbers, "seats": int, "chairs": seat numbers}, ordered by
## lowest tile number. A seat belongs to the table whose tile it faces.
static func tables(pieces: Array) -> Array[Dictionary]:
	var tiles := {}  # cell -> number
	var numbers: Array = []
	for p in pieces:
		if p.type == "table":
			tiles[p.cell] = int(p.number)
			numbers.append(int(p.number))
	numbers.sort()
	var group_of := {}  # cell -> index in out
	var out: Array[Dictionary] = []
	var by_number := {}
	for p in pieces:
		if p.type == "table":
			by_number[int(p.number)] = p.cell
	for n in numbers:
		var start: Vector2i = by_number[n]
		if group_of.has(start):
			continue
		var idx := out.size()
		var members: Array = []
		var queue: Array[Vector2i] = [start]
		group_of[start] = idx
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			members.append(int(tiles[c]))
			for f in FACE:
				var nb: Vector2i = c + f
				if tiles.has(nb) and not group_of.has(nb):
					group_of[nb] = idx
					queue.append(nb)
		members.sort()
		out.append({"pieces": members, "seats": 0, "chairs": []})
	var seats: Array = pieces.filter(func(p): return p.type in SEAT_TYPES)
	seats.sort_custom(func(a, b): return int(a.number) < int(b.number))
	for s in seats:
		var target: Vector2i = s.cell + FACE[int(s.facing) % 4]
		if group_of.has(target):
			var t: Dictionary = out[group_of[target]]
			t.chairs.append(int(s.number))
			t.seats = t.chairs.size()
	return out


## The facing that turns a seat at `cell` to an edge-adjacent tile, or -1.
static func face_toward(cell: Vector2i, tile_cells: Array) -> int:
	for f in 4:
		if (cell + FACE[f]) in tile_cells:
			return f
	return -1


## Numbers of seats that face no Table tile.
static func unseated(pieces: Array) -> Array:
	var cells := []
	for p in pieces:
		if p.type == "table":
			cells.append(p.cell)
	var out := []
	for p in pieces:
		if p.type in SEAT_TYPES and not ((p.cell + FACE[int(p.facing) % 4]) in cells):
			out.append(int(p.number))
	return out


## The tables of the room, ordered by their lowest piece number.
static func runs(pieces: Array) -> Array[Dictionary]:
	var sorted := pieces.duplicate()
	sorted.sort_custom(func(a, b): return int(a.number) < int(b.number))
	var joinable := {}  # cell -> piece, for tables for two only
	for p in sorted:
		if p.type == "table":
			joinable[p.cell] = p
	var paired := {}  # number -> true
	var out: Array[Dictionary] = []
	for p in sorted:
		var n := int(p.number)
		if paired.has(n):
			continue
		var mate = null
		if p.type == "table":
			mate = _lowest_free_neighbour(p, joinable, paired)
		if mate != null:
			paired[n] = true
			paired[int(mate.number)] = true
			out.append({"pieces": [n, int(mate.number)], "seats": PAIR_SEATS})
		else:
			out.append({"pieces": [n], "seats": Station.seats_for(p.type, p.cell, int(p.facing)).size()})
	return out


static func _lowest_free_neighbour(p: Dictionary, joinable: Dictionary, paired: Dictionary):
	var step := Vector2i(0, 1) if int(p.facing) % 2 == 0 else Vector2i(1, 0)
	var best = null
	for c in [p.cell + step, p.cell - step]:
		var q = joinable.get(c)
		if q == null or paired.has(int(q.number)) or int(q.number) == int(p.number):
			continue
		if int(q.facing) % 2 != int(p.facing) % 2:
			continue
		if best == null or int(q.number) < int(best.number):
			best = q
	return best


## Index in `tables` of the free table for a group of `count`, or -1. `taken`
## holds piece numbers in use; a table with any of them in use is not free.
## Fewest seats wins, then a single piece over a joined pair, then lower number.
static func pick(count: int, tables: Array, taken: Array) -> int:
	var best := -1
	for i in tables.size():
		var t: Dictionary = tables[i]
		if int(t.seats) < count or _is_taken(t, taken):
			continue
		if best < 0 or _key(t) < _key(tables[best]):
			best = i
	return best


## True when some table, free or taken, has room for `count`.
static func fits_ever(count: int, tables: Array) -> bool:
	for t in tables:
		if int(t.seats) >= count:
			return true
	return false


static func _is_taken(t: Dictionary, taken: Array) -> bool:
	for n in t.pieces:
		if n in taken:
			return true
	return false


static func _key(t: Dictionary) -> Array:
	return [int(t.seats), t.pieces.size(), int(t.pieces.min())]
