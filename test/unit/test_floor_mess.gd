extends "res://test/helpers/floor_mess_case.gd"


# ---------- Levels and overflow ----------

func test_new_dirt_grows_a_cell_by_one_up_to_four():
	var m := _room()
	var c := Vector2i(2, 2)
	assert_eq(m.level(c), 0)
	for i in 4:
		assert_eq(m.add_dirt(c), c)
	assert_eq(m.level(c), 4)



func test_dirt_off_the_floor_lands_nowhere():
	var m := _room()
	assert_null(m.add_dirt(Vector2i(9, 9)))
	assert_eq(m.total(), 0)



func test_full_cell_overflows_to_a_neighbour():
	var m := _room()
	var c := Vector2i(2, 2)
	for i in 4:
		m.add_dirt(c)
	var landed = m.add_dirt(c)
	assert_not_null(landed)
	assert_ne(landed, c)
	var d: Vector2i = landed - c
	assert_true(maxi(absi(d.x), absi(d.y)) == 1, "one of the eight neighbours")
	assert_eq(m.level(c), 4)
	assert_eq(m.total(), 5)



func test_overflow_reaches_under_furniture():
	# A 2x1 strip: the full cell's only neighbour is under a table.
	var m := FloorMess.new([Vector2i(0, 0), Vector2i(1, 0)], 3)
	m.set_covered([Vector2i(1, 0)])
	for i in 5:
		m.add_dirt(Vector2i(0, 0))
	assert_eq(m.level(Vector2i(1, 0)), 1, "overflow lands under the table")



func test_overflow_spreads_on_when_neighbours_full():
	var m := FloorMess.new([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], 5)
	for i in 4:
		m.add_dirt(Vector2i(0, 0))
		m.add_dirt(Vector2i(1, 0))
	assert_eq(m.add_dirt(Vector2i(0, 0)), Vector2i(2, 0))



func test_overflow_lost_when_everything_is_full():
	var m := FloorMess.new([Vector2i(0, 0), Vector2i(1, 0)], 5)
	for i in 4:
		m.add_dirt(Vector2i(0, 0))
		m.add_dirt(Vector2i(1, 0))
	assert_null(m.add_dirt(Vector2i(0, 0)))
	assert_eq(m.total(), 8)



func test_overflow_is_deterministic_for_a_seed():
	var a := _room(5, 5, 42)
	var b := _room(5, 5, 42)
	for i in 12:
		a.add_dirt(Vector2i(2, 2))
		b.add_dirt(Vector2i(2, 2))
	assert_eq(a.dirt, b.dirt)



# ---------- Cleaning ----------

func test_clean_takes_levels_off():
	var m := _room()
	var c := Vector2i(1, 1)
	for i in 3:
		m.add_dirt(c)
	assert_eq(m.clean(c), 1)
	assert_eq(m.level(c), 2)
	assert_eq(m.clean(c, 5), 2)
	assert_eq(m.level(c), 0)
	assert_eq(m.clean(c), 0)



func test_cannot_clean_under_furniture_until_moved():
	var m := _room()
	var c := Vector2i(1, 1)
	m.add_dirt(c)
	m.set_covered([c])
	assert_false(m.can_clean(c))
	assert_eq(m.clean(c), 0)
	assert_eq(m.level(c), 1)
	m.set_covered([])
	assert_eq(m.clean(c), 1)



# ---------- Tracking ----------

func test_stepping_off_dirt_carries_one_level():
	var m := _room()
	var a := Vector2i(1, 1)
	var b := Vector2i(2, 1)
	m.add_dirt(a)
	m.add_dirt(a)
	assert_true(m.track(a, b))
	assert_eq(m.level(a), 1)
	assert_eq(m.level(b), 1)



func test_clean_feet_track_nothing():
	var m := _room()
	assert_false(m.track(Vector2i(1, 1), Vector2i(2, 1)))
	assert_eq(m.total(), 0)



func test_tracking_onto_a_full_cell_overflows():
	var m := _room()
	var a := Vector2i(1, 2)
	var b := Vector2i(2, 2)
	m.add_dirt(a)
	for i in 4:
		m.add_dirt(b)
	m.track(a, b)
	assert_eq(m.level(a), 0)
	assert_eq(m.level(b), 4)
	assert_eq(m.total(), 5, "the carried level spilled to a neighbour")



# ---------- Speed and slipping ----------

func test_speed_by_level():
	assert_eq(FloorMess.speed_of(0), 1.0)
	assert_almost_eq(FloorMess.speed_of(1), 0.9, 0.001)
	assert_almost_eq(FloorMess.speed_of(2), 0.8, 0.001)
	assert_almost_eq(FloorMess.speed_of(3), 0.65, 0.001)
	assert_almost_eq(FloorMess.speed_of(4), 0.5, 0.001)
	var m := _room()
	m.add_dirt(Vector2i(0, 0))
	assert_almost_eq(m.speed_at(Vector2i(0, 0)), 0.9, 0.001)



func test_slip_only_at_level_four():
	for lvl in 4:
		assert_eq(FloorMess.slip_chance(lvl), 0.0)
	assert_eq(FloorMess.slip_chance(4), FloorMess.SLIP_CHANCE)
	assert_eq(FloorMess.slip_chance(4, true), FloorMess.SLIP_CHANCE_CHEF)
	assert_lt(FloorMess.SLIP_CHANCE_CHEF, FloorMess.SLIP_CHANCE)



func test_slip_rolls_follow_the_chance():
	var m := _room(5, 5, 7)
	var c := Vector2i(2, 2)
	assert_false(m.rolls_slip(c), "clean floor never slips")
	for i in 4:
		m.add_dirt(c)
	var slips := 0
	for i in 2000:
		if m.rolls_slip(c):
			slips += 1
	assert_between(slips, 400, 600, "about a quarter")



# ---------- Disgust ----------

func test_sight_disgust_rises_with_level():
	for lvl in range(1, 5):
		assert_gt(FloorMess.sight_disgust_of(lvl), FloorMess.sight_disgust_of(lvl - 1))
	var m := _room()
	m.add_dirt(Vector2i(0, 0))
	m.add_dirt(Vector2i(1, 0))
	m.add_dirt(Vector2i(1, 0))
	var seen := m.sight_disgust([Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 3)])
	assert_almost_eq(seen, FloorMess.SIGHT_DISGUST[1] + FloorMess.SIGHT_DISGUST[2], 0.0001)



func test_smell_only_from_level_three_within_radius():
	var m := _room(8, 8)
	var c := Vector2i(1, 1)
	m.add_dirt(c)
	m.add_dirt(c)
	assert_eq(m.smell_disgust(c), 0.0, "a puddle does not smell")
	m.add_dirt(c)
	assert_almost_eq(m.smell_disgust(Vector2i(3, 3)), FloorMess.SMELL_DISGUST[3], 0.0001)
	assert_eq(m.smell_disgust(Vector2i(4, 1)), 0.0, "out of the radius")
	m.add_dirt(c)
	assert_gt(m.smell_disgust(Vector2i(3, 3)), FloorMess.SMELL_DISGUST[3], "stronger at 4")



func test_disgust_at_adds_sight_and_smell():
	var m := _room()
	var c := Vector2i(2, 2)
	for i in 3:
		m.add_dirt(c)
	assert_almost_eq(m.disgust_at(Vector2i(2, 3), [c]),
			FloorMess.SIGHT_DISGUST[3] + FloorMess.SMELL_DISGUST[3], 0.0001)
	assert_almost_eq(m.disgust_at(Vector2i(2, 3), []), FloorMess.SMELL_DISGUST[3], 0.0001,
			"smelt, unseen")



# ---------- Kitchen grease ----------

func test_grease_by_tool():
	assert_almost_eq(FloorMess.grease_chance("fry"), 0.5, 0.001)
	assert_almost_eq(FloorMess.grease_chance("grill"), 0.3, 0.001)
	assert_almost_eq(FloorMess.grease_chance("boil"), 0.15, 0.001)
	assert_almost_eq(FloorMess.grease_chance("chop"), 0.1, 0.001)
	assert_almost_eq(FloorMess.grease_chance("slice"), 0.1, 0.001)
	assert_almost_eq(FloorMess.grease_chance("pour"), 0.1, 0.001)
	assert_eq(FloorMess.grease_chance("none"), 0.0)



func test_grease_prep_hood_and_mess_factors():
	assert_almost_eq(FloorMess.grease_chance("grill", "bad"), 0.6, 0.001)
	assert_almost_eq(FloorMess.grease_chance("grill", "spoiled"), 0.6, 0.001)
	assert_almost_eq(FloorMess.grease_chance("grill", "good"), 0.15, 0.001)
	assert_almost_eq(FloorMess.grease_chance("grill", "plain", 1.0, true), 0.09, 0.001)
	assert_almost_eq(FloorMess.grease_chance("grill", "plain", 1.5), 0.45, 0.001)
	assert_eq(FloorMess.grease_chance("fry", "bad", 1.5), 1.0, "clamped")
	assert_eq(FloorMess.hood_factor(), 1.0, "no hood until PRD 8")



func test_grease_lands_on_given_cells():
	var m := _room(9, 9, 11)
	var near := [Vector2i(4, 4), Vector2i(5, 4)]
	var hits := 0
	for i in 20:
		if m.drop_grease("fry", "plain", near) != null:
			hits += 1
	assert_between(hits, 5, 15, "about half")
	assert_eq(m.total(), hits)
	for c in m.dirt:
		var d: Vector2i = c - Vector2i(4, 4)
		assert_true(maxi(absi(d.x), absi(d.y)) <= 3, "near the station, overflow aside")
	assert_null(m.drop_grease("fry", "plain", []))



# ---------- Guest mess ----------

func test_guest_mess_chance():
	assert_almost_eq(FloorMess.guest_mess_chance(0.0), 0.15, 0.001)
	assert_almost_eq(FloorMess.guest_mess_chance(1.0), 0.3, 0.001)
	assert_almost_eq(FloorMess.guest_mess_chance(0.0, true), 0.3, 0.001)
	assert_almost_eq(FloorMess.guest_mess_chance(0.0, false, true), 0.225, 0.001)
	assert_almost_eq(FloorMess.guest_mess_chance(1.0, true, true), 0.9, 0.001)



func test_guest_mess_lands_free_cells_near_the_seat():
	var m := _room(9, 9, 13)
	var seat := Vector2i(4, 4)
	m.set_covered([seat, Vector2i(5, 4)])
	var cells := m.guest_landing_cells(seat)
	assert_eq(cells.size(), 23, "5x5 less the two covered")
	assert_false(cells.has(seat))
	for i in 15:
		m.drop_guest_mess(seat, 1.0, true, true)
	for c in m.dirt:
		var d: Vector2i = c - seat
		assert_true(maxi(absi(d.x), absi(d.y)) <= 2)
	assert_eq(m.level(seat), 0, "never lands under furniture directly")
	assert_gt(m.total(), 0)
