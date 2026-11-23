class_name GameTables
extends RefCounted
## The room's tables: which dining pieces make one table (TableJoins), worked out again
## whenever a piece is placed, turned, lifted or sold. A party sits at one table, named by
## its lead half: the piece with the lowest table number.

var game: Game
var list: Array[Dictionary] = []   # TableJoins.runs of the room: {pieces: numbers, seats}


func _init(game_: Game) -> void:
	game = game_


## Works the joins out again from game.stations.
func rebuild() -> void:
	var pieces := []
	var dining := game.paying.dining_tables()
	for i in dining.size():
		var st: Station = dining[i]
		pieces.append({"type": st.type, "cell": st.cell, "facing": st.facing, "number": i + 1})
	list = TableJoins.runs(pieces)


func _run_of(st: Station) -> Dictionary:
	var n := game.paying.table_number(st)
	for t in list:
		if n in t.pieces:
			return t
	return {}


## Any half of a table -> its lead half.
func lead(st: Station) -> Station:
	var t := _run_of(st)
	return st if t.is_empty() else game.paying.table_by_number(int(t.pieces.min()))


## Every piece that makes up the table led by `lead_st`, lead first.
func halves(lead_st: Station) -> Array[Station]:
	var out: Array[Station] = []
	var t := _run_of(lead_st)
	if t.is_empty():
		return [lead_st]
	var nums: Array = t.pieces.duplicate()
	nums.sort()
	for n in nums:
		out.append(game.paying.table_by_number(int(n)))
	return out


## All chairs of all halves, the lead's first.
func seats_of(lead_st: Station) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h in halves(lead_st):
		out.append_array(h.seats)
	return out


## The half whose chair this is.
func half_of_seat(lead_st: Station, seat: Vector2i) -> Station:
	for h in halves(lead_st):
		if seat in h.seats:
			return h
	return lead_st
