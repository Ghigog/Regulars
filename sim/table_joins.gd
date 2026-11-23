class_name TableJoins
extends RefCounted
## Which pieces make one table. Two tables for two on neighbouring cells along
## their long axis, turned the same way, count as one table for four. Pieces
## are plain dictionaries {type, cell: Vector2i, facing: int, number: int}.
## A table in the result is {"pieces": Array of piece numbers, "seats": int}.

const PAIR_SEATS := 4


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
