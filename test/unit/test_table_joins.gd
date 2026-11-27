extends GutTest
## Tables built of tiles and the choice of table for a group.


func _p(n: int, cell: Vector2i, facing := 0, type := "table") -> Dictionary:
	return {"type": type, "cell": cell, "facing": facing, "number": n}


func _seats(tables: Array) -> Array:
	return tables.map(func(t): return t.seats)


func test_pick_prefers_fewest_seats_then_fewer_tiles_then_number():
	var tables := [
		{"pieces": [1, 2], "seats": 4},
		{"pieces": [3], "seats": 2},
		{"pieces": [4], "seats": 4},
		{"pieces": [5], "seats": 1},
	]
	assert_eq(TableJoins.pick(1, tables, []), 3)
	assert_eq(TableJoins.pick(2, tables, []), 1)
	assert_eq(TableJoins.pick(3, tables, []), 2, "one tile beats two for the same seats")
	assert_eq(TableJoins.pick(4, tables, []), 2)
	assert_eq(TableJoins.pick(2, tables, [3, 4]), 0, "only the pair is free")


func test_pick_with_only_the_big_table_free_and_nothing_free():
	var tables := [{"pieces": [1, 2], "seats": 4}, {"pieces": [3], "seats": 2}]
	assert_eq(TableJoins.pick(2, tables, [3]), 0)
	assert_eq(TableJoins.pick(2, tables, [2]), 1, "a table with a taken tile is not free")
	assert_eq(TableJoins.pick(4, tables, [1]), -1)
	assert_eq(TableJoins.pick(5, tables, []), -1)


func test_fits_ever_counts_taken_tables():
	var tables := [{"pieces": [1, 2], "seats": 4}]
	assert_true(TableJoins.fits_ever(4, tables))
	assert_false(TableJoins.fits_ever(5, tables))


# --- Tables built from tiles and the seats facing them ---

func _row_with_six_chairs() -> Array:
	var ps := [_p(1, Vector2i(0, 0)), _p(2, Vector2i(1, 0)), _p(3, Vector2i(2, 0))]
	for i in 3:
		ps.append(_p(10 + i, Vector2i(i, -1), 1, "chair"))  # faces (i, 0)
		ps.append(_p(20 + i, Vector2i(i, 1), 3, "booth_seat"))
	return ps


func test_row_of_three_tiles_with_six_chairs_is_one_table_of_six():
	var t := TableJoins.tables(_row_with_six_chairs())
	assert_eq(t.size(), 1)
	assert_eq(t[0].seats, 6)
	assert_eq(t[0].pieces, [1, 2, 3])


func test_l_shape_is_one_table():
	var t := TableJoins.tables([_p(1, Vector2i(0, 0)), _p(2, Vector2i(1, 0)), _p(3, Vector2i(1, 1))])
	assert_eq(t.size(), 1)
	assert_eq(t[0].pieces, [1, 2, 3])


func test_chair_turned_away_counts_for_nothing():
	var ps := [_p(1, Vector2i(0, 0)), _p(2, Vector2i(-1, 0), 0, "chair")]  # faces (-2,0)
	assert_eq(TableJoins.tables(ps)[0].seats, 0)
	assert_eq(TableJoins.unseated(ps), [2])
	assert_eq(TableJoins.unseated([_p(1, Vector2i(0, 0)), _p(2, Vector2i(-1, 0), 2, "chair")]), [])


func test_bridging_tile_merges_two_tables():
	var ps := [_p(1, Vector2i(0, 0)), _p(2, Vector2i(2, 0)),
		_p(3, Vector2i(0, -1), 1, "chair"), _p(4, Vector2i(2, -1), 1, "chair")]
	assert_eq(_seats(TableJoins.tables(ps)), [1, 1])
	ps.append(_p(5, Vector2i(1, 0)))
	var t := TableJoins.tables(ps)
	assert_eq(t.size(), 1)
	assert_eq(t[0].seats, 2)


func test_face_toward_picks_adjacent_tile():
	assert_eq(TableJoins.face_toward(Vector2i(0, -1), [Vector2i(0, 0)]), 1)
	assert_eq(TableJoins.face_toward(Vector2i(5, 5), [Vector2i(0, 0)]), -1)


func test_lone_guest_gets_one_seat_table_before_two_seat_table():
	var ps := [_p(1, Vector2i(0, 0)), _p(2, Vector2i(5, 0)), _p(3, Vector2i(6, 0)),
		_p(4, Vector2i(0, -1), 1, "chair"),
		_p(5, Vector2i(5, -1), 1, "chair"), _p(6, Vector2i(6, -1), 1, "chair")]
	var t := TableJoins.tables(ps)
	assert_eq(_seats(t), [1, 2])
	assert_eq(TableJoins.pick(1, t, []), 0)
	assert_eq(TableJoins.pick(1, t, [1]), 1)
