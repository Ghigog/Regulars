extends GutTest
## Combined tables and the choice of table for a group.


func _p(n: int, cell: Vector2i, facing := 0, type := "table") -> Dictionary:
	return {"type": type, "cell": cell, "facing": facing, "number": n}


func _seats(tables: Array) -> Array:
	return tables.map(func(t): return t.seats)


func test_pair_along_long_axis_for_both_turns():
	var a := TableJoins.runs([_p(1, Vector2i(3, 3)), _p(2, Vector2i(3, 4))])
	assert_eq(a.size(), 1)
	assert_eq(a[0].seats, 4)
	assert_eq(a[0].pieces, [1, 2])
	var b := TableJoins.runs([_p(1, Vector2i(3, 3), 1), _p(2, Vector2i(4, 3), 1)])
	assert_eq(_seats(b), [4])


func test_side_by_side_across_the_short_axis_do_not_join():
	assert_eq(_seats(TableJoins.runs([_p(1, Vector2i(3, 3)), _p(2, Vector2i(4, 3))])), [2, 2])


func test_run_of_three_is_a_pair_and_a_lone_table():
	var t := TableJoins.runs([_p(1, Vector2i(0, 0)), _p(2, Vector2i(0, 1)), _p(3, Vector2i(0, 2))])
	assert_eq(_seats(t), [4, 2])
	assert_eq(t[1].pieces, [3])


func test_run_pairs_in_table_number_order():
	# Number 1 sits in the middle: it takes the lower-numbered neighbour.
	var t := TableJoins.runs([_p(1, Vector2i(0, 1)), _p(2, Vector2i(0, 0)), _p(3, Vector2i(0, 2))])
	assert_eq(t[0].pieces, [1, 2])
	assert_eq(t[1].pieces, [3])


func test_run_of_four_is_two_pairs():
	var t := TableJoins.runs([_p(1, Vector2i(0, 0)), _p(2, Vector2i(0, 1)), _p(3, Vector2i(0, 2)), _p(4, Vector2i(0, 3))])
	assert_eq(_seats(t), [4, 4])


func test_l_shape_stays_separate():
	assert_eq(_seats(TableJoins.runs([_p(1, Vector2i(2, 2)), _p(2, Vector2i(2, 3), 1)])), [2, 2])


func test_t_shape_stays_separate():
	var t := TableJoins.runs([_p(1, Vector2i(2, 2)), _p(2, Vector2i(2, 3), 1), _p(3, Vector2i(3, 3), 1), _p(4, Vector2i(1, 3), 1)])
	# 2,3,4 are a run of three along x: one pair and a lone; 1 is turned the other way.
	assert_eq(_seats(t), [2, 4, 2])


func test_table_beside_booth_or_table4_does_not_join():
	var t := TableJoins.runs([_p(1, Vector2i(0, 0)), _p(2, Vector2i(0, 1), 0, "booth"), _p(3, Vector2i(0, 2), 0, "table4")])
	assert_eq(_seats(t), [2, 2, 4])


func test_tiers_may_differ():
	var a := _p(1, Vector2i(0, 0))
	var b := _p(2, Vector2i(0, 1))
	a["tier"] = 1
	b["tier"] = 3
	assert_eq(_seats(TableJoins.runs([a, b])), [4])


func test_pick_prefers_fewest_seats_then_single_then_number():
	var tables := [
		{"pieces": [1, 2], "seats": 4},
		{"pieces": [3], "seats": 2},
		{"pieces": [4], "seats": 4},
		{"pieces": [5], "seats": 1},
	]
	assert_eq(TableJoins.pick(1, tables, []), 3)
	assert_eq(TableJoins.pick(2, tables, []), 1)
	assert_eq(TableJoins.pick(3, tables, []), 2, "single four beats the joined pair")
	assert_eq(TableJoins.pick(4, tables, []), 2)
	assert_eq(TableJoins.pick(2, tables, [3, 4]), 0, "only the pair is free")


func test_pick_with_only_the_pair_free_and_nothing_free():
	var tables := [{"pieces": [1, 2], "seats": 4}, {"pieces": [3], "seats": 2}]
	assert_eq(TableJoins.pick(2, tables, [3]), 0)
	assert_eq(TableJoins.pick(2, tables, [2]), 1, "a pair with a taken half is not free")
	assert_eq(TableJoins.pick(4, tables, [1]), -1)
	assert_eq(TableJoins.pick(5, tables, []), -1)


func test_fits_ever_counts_taken_tables():
	var tables := [{"pieces": [1, 2], "seats": 4}]
	assert_true(TableJoins.fits_ever(4, tables))
	assert_false(TableJoins.fits_ever(5, tables))
