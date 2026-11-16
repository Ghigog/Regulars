extends GutTest
## Unit tests for sim/floor_mess.gd (PRD 9.1).


func _room(w: int = 5, h: int = 5, seed_value: int = 1) -> FloorMess:
	var cells := []
	for y in h:
		for x in w:
			cells.append(Vector2i(x, y))
	return FloorMess.new(cells, seed_value)


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


func test_slip_walkout_from_opinion():
	assert_almost_eq(FloorMess.slip_walkout_chance(0.0), 0.9, 0.001)
	assert_almost_eq(FloorMess.slip_walkout_chance(1.0), 0.1, 0.001)
	assert_almost_eq(FloorMess.slip_walkout_chance(0.5), 0.5, 0.001)
	assert_almost_eq(FloorMess.slip_walkout_chance(2.0), 0.1, 0.001, "clamped")


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


# ---------- In the room (PRD 9.2) ----------

func _game():
	var game = load("res://game/main.tscn").instantiate()
	game.first_night = false   # straight into day 1
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])   # keeps the day open
	game.test_kitchen()
	game.floor_dirt.mess.rng.seed = 7
	game.step(0.01)   # the dirt takes the room's floors and furniture
	return game


func _dirty(game, cell: Vector2i, lvl: int) -> void:
	for i in lvl:
		game.floor_dirt.mess.add_dirt(cell)


func test_the_room_floors_are_where_dirt_can_be_and_furniture_covers_cells():
	var game = _game()
	var m: FloorMess = game.floor_dirt.mess
	assert_eq(m.floor_cells.size(), game.plan.floors.size())
	var stove: Station = game.find_station("stove")
	assert_true(m.is_floor(stove.cell))
	assert_true(m.is_covered(stove.cell), "furniture stands on it")
	assert_false(m.is_covered(game.player.cell()))


func test_a_chef_walking_off_a_dirty_cell_tracks_a_level_and_leaves_footprints():
	var game = _game()
	var from: Vector2i = game.player.cell()
	_dirty(game, from, 2)
	game.step(0.01)
	var to := from + Vector2i(1, 0)
	assert_false(game.floor_dirt.mess.is_covered(to), "the test needs open floor to the right")
	game.player.position = Grid.center(to)
	game.step(0.01)
	assert_eq(game.floor_dirt.mess.level(from), 1)
	assert_eq(game.floor_dirt.mess.level(to), 1)
	assert_eq(game.floor_dirt.prints.get(to), Vector2i(1, 0), "footprints the way they walked")


func test_guests_track_dirt_too():
	var game = _game()
	var g: Guest = game.spawn_guest(0)
	var from := Vector2i(6, 5)
	g.position = Grid.center(from)
	_dirty(game, from, 3)
	game.floor_dirt.step_feet([[g, from]])
	game.floor_dirt.step_feet([[g, from + Vector2i(0, 1)]])
	assert_eq(game.floor_dirt.mess.level(from), 2)
	assert_eq(game.floor_dirt.mess.level(from + Vector2i(0, 1)), 1)


func test_dirt_underfoot_slows_chefs_and_guests():
	var game = _game()
	var here: Vector2i = game.player.cell()
	assert_almost_eq(game.player.speed(), Player.SPEED, 0.001)
	_dirty(game, here, 4)
	assert_almost_eq(game.player.speed(), Player.SPEED * 0.5, 0.001, "the whole cell: half speed")
	var at := Vector2i(6, 5)
	_dirty(game, at, 3)
	assert_almost_eq(game.floor_speed(Grid.center(at)), 0.65, 0.001)


func test_a_guest_walks_slower_over_dirt():
	var walked := []
	for lvl in [0, 4]:
		var game = _game()
		var g: Guest = game.spawn_guest(0)
		var start := Vector2i(6, 5)
		g.position = Grid.center(start)
		g.cell = start
		_dirty(game, start, lvl)
		g.path.assign([Vector2i(5, 5)])
		g.goal = Grid.center(Vector2i(5, 5))
		g._advance(0.1)
		walked.append(g.position.distance_to(Grid.center(start)))
	assert_almost_eq(walked[1], walked[0] * 0.5, 0.001)


func test_a_bad_fry_always_drops_grease_beside_the_fryer():
	var game = _game()
	var fryer: Station = game.add_station("fryer", Vector2i(2, 5))
	var chef: Vector2i = fryer.cell + Vector2i(1, 0)
	var landed = game.floor_dirt.prep_grease("fry", "bad", chef, fryer)
	assert_not_null(landed, "fry 0.5, doubled for a bad one")
	assert_true(landed == chef or (landed - fryer.cell).length_squared() == 1)
	assert_false(game.floor_dirt.mess.is_covered(landed))


func test_tool_mess_and_the_hood_read_as_one_and_none_until_prd_8():
	var game = _game()
	assert_eq(game.floor_dirt.grease_factors(game.find_station("stove")), {"mess": 1.0, "hood": false})


func test_a_finished_prep_rolls_grease_through_the_game():
	var game = _game()
	var stove: Station = game.find_station("stove")
	var before: int = game.floor_dirt.mess.total()
	for i in 40:
		game._prep_done(0, stove, "fry", "bad")   # a certain drop each time
	assert_eq(game.floor_dirt.mess.total(), before + 40)


func test_greasy_food_is_fried_or_meat():
	var t := Tray.new()
	assert_false(FloorDirt.greasy(null))
	assert_false(FloorDirt.greasy(t))
	t.lines.append({"item": {"ingredients": ["patty"]}, "have": []})
	assert_true(FloorDirt.greasy(t) == Pantry.tags_of("patty").has("meat"))


func test_guest_mess_lands_near_the_seat_and_never_under_furniture():
	var game = _game()
	var g: Guest = game.spawn_guest(0)
	g.seat = Vector2i(6, 4)
	var m: FloorMess = game.floor_dirt.mess
	for i in 60:
		var c = game.floor_dirt.meal_mess(g)
		if c != null and m.level(c) < 4:
			assert_true(maxi(absi(c.x - 6), absi(c.y - 4)) <= FloorMess.GUEST_RADIUS)
	assert_gt(m.total(), 0, "some meals leave mess")


func test_an_annoyed_guest_counts_as_more_annoyed():
	var game = _game()
	var g: Guest = game.spawn_guest(0)
	var calm := FloorDirt.annoyance(g)
	g.mood.patience = 0.0
	g.mood.disgust = 0.8
	assert_gt(FloorDirt.annoyance(g), calm)


func test_a_seated_guest_is_put_off_by_dirt_they_can_see():
	var game = _game()
	var g: Guest = game.spawn_guest(0)
	g.cell = Vector2i(6, 4)
	_dirty(game, Vector2i(8, 4), 2)   # a puddle: seen, no smell
	assert_true(game.floor_dirt.disgust(g, 1.0, game.SIGHT_RANGE))
	assert_gt(g.mood.disgust, 0.0)


func test_from_level_three_dirt_smells_even_out_of_sight():
	var game = _game()
	var g: Guest = game.spawn_guest(0)
	g.cell = Vector2i(6, 4)
	_dirty(game, Vector2i(7, 4), 2)
	game.floor_dirt.disgust(g, 1.0, 0)   # sees nothing
	assert_eq(g.mood.disgust, 0.0, "a puddle out of sight does not smell")
	_dirty(game, Vector2i(7, 4), 1)
	game.floor_dirt.disgust(g, 1.0, 0)
	assert_gt(g.mood.disgust, 0.0, "a big puddle smells")


func test_the_critic_marks_cleanliness_down_for_a_filthy_floor():
	var game = _game()
	var g: Guest = game.spawn_guest(0)
	g.cell = Vector2i(6, 4)
	game.critic_guest = g
	for c in [Vector2i(7, 4), Vector2i(8, 4), Vector2i(7, 5), Vector2i(8, 5)]:
		_dirty(game, c, 4)
	for i in 30:
		game.floor_dirt.disgust(g, 1.0, game.SIGHT_RANGE)
	assert_lt(Critic.clean_rating(g.mood.disgust, g.mood.disgust_level()), 5)


func test_each_level_is_drawn_as_its_own_shape_and_cleared_when_clean():
	var game = _game()
	var counts := []
	for lvl in range(1, 5):
		var n := FloorDirt.cell_look(Vector2i(5, 5), lvl, Vector2i.ZERO)
		counts.append(n.get_child(0).get_child_count())
		n.free()
	assert_eq(counts, [3, 8, 13, 4], "drops, a rimmed puddle, a big one with a glint, the whole cell")
	_dirty(game, Vector2i(6, 5), 2)
	game.floor_dirt.redraw()
	assert_eq(game.floor_dirt.get_child_count(), 1)
	var drawn: Node = game.floor_dirt.get_child(0)
	game.floor_dirt.mess.dirt.erase(Vector2i(6, 5))
	game.floor_dirt.redraw()
	assert_true(drawn.is_queued_for_deletion(), "a clean cell is drawn bare")


func test_dirt_stays_overnight():
	var game = _game()
	_dirty(game, Vector2i(6, 5), 3)
	game._end_day()
	game.step(0.01)
	assert_eq(game.floor_dirt.mess.level(Vector2i(6, 5)), 3, "no cleaning until the mop (9.4)")
