class_name GameTables
extends RefCounted
## The room's tables: which dining pieces make one table (TableJoins), worked out again
## whenever a piece is placed, turned, lifted or sold. A party sits at one table, named by
## its lead half: the piece with the lowest table number.

var game: Game
var list: Array[Dictionary] = []   # TableJoins.runs of the room: {pieces: numbers, seats}
var cards: Array[Label3D] = []     # the seat-count card at each table's centre, one per run

const CARD_HEIGHT := 0.95          # just above the table top


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
	_draw_cards()
	_redraw_joins()


## Tells every table tile which sides touch another tile, and the tile nearest each
## table's middle where its one candle stands; every booth seat which sides have a
## booth seat beside it facing the same way. Each piece redraws only when that changed.
func _redraw_joins() -> void:
	var pieces := []
	var by_number := {}
	for st: Station in game.stations.values():
		if st.type in ["table", "booth_seat", "chair"]:
			by_number[pieces.size() + 1] = st
			pieces.append({"type": st.type, "cell": st.cell, "facing": st.facing, "number": pieces.size() + 1})
	var candles := {}   # tile -> where its candle stands, for the tiles that hold one
	for t in TableJoins.tables(pieces):
		var mid := Vector2.ZERO
		for n in t.pieces:
			mid += Vector2((by_number[n] as Station).cell)
		mid /= t.pieces.size()
		var best: Station = null
		for n in t.pieces:
			var st: Station = by_number[n]
			if best == null or Vector2(st.cell).distance_to(mid) < Vector2(best.cell).distance_to(mid):
				best = st
		candles[best] = (mid - Vector2(best.cell)).clampf(-0.5, 0.5)
	for st: Station in by_number.values():
		if st.type == "chair":
			continue
		var mask := 0
		for f in 4:
			var nb: Station = game.stations.get(st.cell + TableJoins.FACE[f])
			if nb != null and nb.type == st.type and (st.type == "table" or nb.facing == st.facing):
				mask |= 1 << f
		st.set_joined(mask, candles.get(st, Vector2.INF))


## One card per table, at the middle of its pieces, saying how many it seats.
func _draw_cards() -> void:
	for c in cards:
		c.queue_free()
	cards.clear()
	for t in list:
		var mid := Vector3.ZERO
		for n in t.pieces:
			mid += game.paying.table_by_number(int(n)).position
		mid /= t.pieces.size()
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.font = Hud.lettering()
		l.font_size = 40
		l.pixel_size = 0.006
		l.outline_size = 12
		l.modulate = Color(Build.TRIM)
		l.outline_modulate = Color(Build.PAPER)
		l.text = str(t.seats)
		l.position = Vector3(mid.x, CARD_HEIGHT, mid.z)
		game.add_child(l)
		cards.append(l)


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
