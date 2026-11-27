extends GutTest
## EPIC-85-T10: a save from before single pieces turns each old set into its pieces.


func _old(type: String, cell: Vector2i, facing := 0, tier := 1) -> Dictionary:
	return {"type": type, "node": "", "cell": cell, "facing": facing, "tier": tier, "dirty": 2, "dirty_cups": 1, "dirty_age": 3.0, "high": false}


func _kinds(out: Array) -> Dictionary:
	var d := {}
	for p: Dictionary in out:
		d[p.cell] = p
	return d


func test_a_table_for_two_becomes_a_tile_and_two_facing_chairs():
	var out := Save._split_sets([_old("table", Vector2i(6, 1), 0, 3)])
	var by := _kinds(out)
	assert_eq(out.size(), 3)
	assert_eq(by[Vector2i(6, 1)].type, "table")
	assert_eq(by[Vector2i(6, 1)].dirty, 2, "the mess stays on the table")
	assert_eq(by[Vector2i(5, 1)].type, "chair")
	assert_eq(by[Vector2i(5, 1)].tier, 3, "the seats keep the tier")
	assert_eq(by[Vector2i(5, 1)].dirty, 0)
	var pieces := []
	for p: Dictionary in out:
		pieces.append({"type": p.type, "cell": p.cell, "facing": p.facing, "number": pieces.size()})
	assert_eq(TableJoins.tables(pieces)[0].seats, 2)


func test_a_turned_booth_becomes_booth_seats_above_and_below():
	var by := _kinds(Save._split_sets([_old("booth", Vector2i(4, 4), 1)]))
	assert_eq(by[Vector2i(4, 3)].type, "booth_seat")
	assert_eq(by[Vector2i(4, 5)].type, "booth_seat")


func test_a_table_for_four_and_a_stool_face_their_table():
	for set: Dictionary in [_old("table4", Vector2i(5, 5)), _old("stool", Vector2i(5, 5), 3)]:
		var pieces := []
		for p: Dictionary in Save._split_sets([set]):
			pieces.append({"type": p.type, "cell": p.cell, "facing": p.facing, "number": pieces.size()})
		var t := TableJoins.tables(pieces)
		assert_eq(t.size(), 1)
		assert_eq(t[0].seats, 4 if set.type == "table4" else 1, set.type)
	assert_eq(Save._split_sets([_old("stool", Vector2i(5, 5), 3)])[1].cell, Vector2i(5, 6))


func test_other_pieces_pass_through():
	var c := {"type": "counter", "cell": Vector2i(1, 1), "facing": 0}
	assert_eq(Save._split_sets([c]), [c])
