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


func test_tool_mess_and_the_hood_come_from_the_kitchen():
	var game = _game()
	var stove: Station = game.stations[Vector2i(0, 3)]
	assert_eq(game.floor_dirt.grease_factors(stove), {"mess": 1.0, "hood": "hood"}, "the start's hood hangs over it (PRD 8.5)")
	game.clear_walls()
	assert_eq(game.floor_dirt.grease_factors(stove), {"mess": 1.0, "hood": ""})


func test_a_hood_cuts_a_stoves_grease():
	var game = _game()
	var stove: Station = game.stations[Vector2i(0, 3)]
	var before: int = game.floor_dirt.mess.total()
	for i in 40:
		game._prep_done(0, stove, "fry", "bad")   # certain without a hood (the test below)
	var hooded: int = game.floor_dirt.mess.total() - before
	assert_lt(hooded, 30, "a hood drops grease about %d%% as often" % int(FloorMess.HOOD * 100))


func test_a_finished_prep_rolls_grease_through_the_game():
	var game = _game()
	game.clear_walls()   # no hood over the stove
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


# ---------- Slipping in the room (9.3) ----------

func test_getting_up_times():
	assert_eq(FloorMess.help_time(true), 1.0)
	assert_eq(FloorMess.help_time(false), 6.0)
	assert_eq(FloorMess.get_up_alone_time(false), 20.0)
	assert_eq(FloorMess.get_up_alone_time(true), 4.0)
	assert_true(FloorMess.within_witness(Vector2i(3, 3), Vector2i(4, 4)))
	assert_false(FloorMess.within_witness(Vector2i(3, 3), Vector2i(5, 3)))


func _guest_at(game, idx: int, c: Vector2i) -> Guest:
	var g: Guest = game.spawn_guest(idx)
	g.position = Grid.center(c)
	g.cell = c
	g.path.clear()
	g.goal = g.position
	return g


func test_stepping_onto_a_level_four_cell_in_service_can_slip():
	var game = _game()
	var g := _guest_at(game, 0, Vector2i(6, 5))
	var a := Vector2i(6, 5)
	var b := Vector2i(6, 6)
	var fd: FloorDirt = game.floor_dirt
	for i in 200:
		fd.step_feet([[g, a]], true)
		fd.mess.dirt[b] = 4
		fd.step_feet([[g, b]], true)
		if fd.is_down(g):
			break
	assert_true(fd.is_down(g), "a quarter of steps onto level 4 slip")
	assert_eq(fd.down[g].cell, b)


func test_no_slips_below_level_four_or_outside_service():
	var game = _game()
	var g := _guest_at(game, 0, Vector2i(6, 5))
	var fd: FloorDirt = game.floor_dirt
	for i in 100:
		fd.mess.dirt.clear()
		fd.step_feet([[g, Vector2i(6, 5)]], true)
		fd.mess.dirt[Vector2i(6, 6)] = 3
		fd.step_feet([[g, Vector2i(6, 6)]], true)
		fd.step_feet([[g, Vector2i(6, 5)]], false)
		fd.mess.dirt[Vector2i(6, 6)] = 4
		fd.step_feet([[g, Vector2i(6, 6)]], false)
	assert_false(fd.is_down(g))


func test_a_fallen_guest_feels_it_and_witnesses_within_a_cell_are_put_off():
	var game = _game()
	var g := _guest_at(game, 0, Vector2i(6, 5))
	var near := _guest_at(game, 1, Vector2i(7, 6))
	var far := _guest_at(game, 2, Vector2i(9, 5))
	var joy: float = g.mood.joy
	var near_joy: float = near.mood.joy
	game.floor_dirt.slip(g, Vector2i(6, 5))
	assert_almost_eq(g.mood.joy, maxf(0.0, joy - FloorMess.SLIP_JOY), 0.001)
	assert_true(g.mood.thoughts.has(FloorMess.SLIP_THOUGHT))
	assert_almost_eq(near.mood.joy, near_joy - FloorMess.WITNESS_JOY, 0.001)
	assert_true(near.mood.thoughts.has(FloorMess.WITNESS_THOUGHT))
	assert_false(far.mood.thoughts.has(FloorMess.WITNESS_THOUGHT), "two cells off: did not see")


func test_a_fallen_guest_tracks_nothing_and_does_not_walk():
	var game = _game()
	var a := Vector2i(6, 5)
	var g := _guest_at(game, 0, a)
	var fd: FloorDirt = game.floor_dirt
	fd.step_feet([[g, a]])
	fd.slip(g, a)
	_dirty(game, a, 3)
	fd.step_feet([[g, a + Vector2i(0, 1)]])
	assert_eq(fd.mess.level(a), 3)
	assert_eq(fd.mess.level(a + Vector2i(0, 1)), 0)
	g.state = "to_seat"
	g.path.assign([Vector2i(5, 5)])
	var at := g.position
	g.tick(0.5)
	assert_eq(g.position, at, "down on the cell")


func test_left_alone_a_guest_gets_up_after_twenty_seconds_angrier():
	var game = _game()
	var g := _guest_at(game, 0, Vector2i(6, 5))
	var fd: FloorDirt = game.floor_dirt
	fd.slip(g, Vector2i(6, 5))
	for i in 199:
		fd.tick_slips(0.1)
	assert_true(fd.is_down(g), "still down at 19.9 s")
	var joy: float = g.mood.joy
	fd.tick_slips(0.2)
	assert_false(fd.is_down(g))
	assert_true(g.mood.thoughts.has(FloorMess.ALONE_THOUGHT))
	assert_lt(g.mood.joy, joy + 0.0001)


func test_a_chef_helps_a_fallen_guest_up_with_e_in_a_second():
	var game = _game()
	var c := Vector2i(6, 5)
	var g := _guest_at(game, 0, c)
	var ch: Player = game.player
	ch.position = Grid.center(c + Vector2i(0, 1))
	assert_false(game.grid.is_blocked(c + Vector2i(0, 1)), "the test needs open floor below")
	var fd: FloorDirt = game.floor_dirt
	fd.slip(g, c)
	assert_eq(fd.help_target(ch), g)
	game.act(0, "use")
	assert_eq(fd.helping(ch), g)
	var at := ch.position
	ch.move(Vector2(1, 0), 0.2)
	assert_eq(ch.position, at, "the chef stays put while helping")
	fd.tick_slips(0.9)
	assert_true(fd.is_down(g))
	fd.tick_slips(0.2)
	assert_false(fd.is_down(g))
	assert_null(fd.helping(ch))
	assert_true(g.mood.thoughts.has(FloorMess.HELPED_THOUGHT))


func test_a_chef_too_far_away_cannot_help():
	var game = _game()
	var g := _guest_at(game, 0, Vector2i(6, 5))
	game.player.position = Grid.center(Vector2i(2, 3))
	game.floor_dirt.slip(g, Vector2i(6, 5))
	assert_null(game.floor_dirt.help_target(game.player))


func test_an_unseated_guest_nearby_helps_up_in_six_seconds():
	var game = _game()
	var c := Vector2i(6, 5)
	var g := _guest_at(game, 0, c)
	var o := _guest_at(game, 1, c + Vector2i(1, 0))
	o.state = "to_seat"
	var fd: FloorDirt = game.floor_dirt
	fd.slip(g, c)
	fd.tick_slips(0.1)
	assert_eq(o.helping, g, "the friend comes over")
	for i in 58:
		fd.tick_slips(0.1)
	assert_true(fd.is_down(g), "still down just short of six seconds")
	fd.tick_slips(0.2)
	assert_false(fd.is_down(g))
	assert_null(o.helping, "free to go on")


func test_a_seated_guest_does_not_get_up_to_help():
	var game = _game()
	var c := Vector2i(6, 5)
	var g := _guest_at(game, 0, c)
	var o := _guest_at(game, 1, c + Vector2i(1, 0))
	o.state = "waiting"
	game.floor_dirt.slip(g, c)
	game.floor_dirt.tick_slips(0.1)
	assert_null(o.helping)


func test_a_chef_takes_over_from_a_helping_guest():
	var game = _game()
	var c := Vector2i(6, 5)
	var g := _guest_at(game, 0, c)
	var o := _guest_at(game, 1, c + Vector2i(1, 0))
	o.state = "to_seat"
	var fd: FloorDirt = game.floor_dirt
	fd.slip(g, c)
	fd.tick_slips(0.1)
	game.player.position = Grid.center(c + Vector2i(0, 1))
	assert_true(fd.help_up(game.player))
	assert_null(o.helping)
	fd.tick_slips(1.05)
	assert_false(fd.is_down(g))


func test_a_slip_costs_mood_but_is_never_a_strike():
	var game = _game()
	var c := Vector2i(6, 5)
	var fd: FloorDirt = game.floor_dirt
	var walkouts: int = game.ledger.strikes()
	for k in 10:
		var g := _guest_at(game, k, c)
		game.town.people[k].affinity = -1.0
		g.mood.joy = 0.5
		g.mood.patience = 0.6
		g.state = "to_seat"
		var joy: float = g.mood.joy
		fd.slip(g, c)
		fd.get_up(g, k % 2 == 0)
		assert_lt(g.mood.joy, joy, "it hurts")
		assert_false(g.stormed, "but nobody walks out over it")
	assert_eq(game.ledger.strikes(), walkouts, "and it is never a strike")


func test_a_chef_slips_cannot_move_and_gets_up_alone_after_four_seconds():
	var game = _game()
	var ch: Player = game.player
	var fd: FloorDirt = game.floor_dirt
	fd.slip(ch, ch.cell())
	var at := ch.position
	ch.move(Vector2(1, 0), 0.2)
	assert_eq(ch.position, at)
	game.act(0, "use")   # nothing: they are on the floor
	for i in 39:
		fd.tick_slips(0.1)
	assert_true(fd.is_down(ch))
	fd.tick_slips(0.2)
	assert_false(fd.is_down(ch))


func test_the_other_chef_helps_a_fallen_chef_up():
	var game = _game()
	var one: Player = game.player
	var c: Vector2i = one.cell()
	var two: Player = game.add_chef(c + Vector2i(1, 0))
	var fd: FloorDirt = game.floor_dirt
	fd.slip(one, c)
	assert_null(fd.help_target(one), "not themselves")
	assert_true(fd.help_up(two))
	fd.tick_slips(1.05)
	assert_false(fd.is_down(one))


func test_a_fallen_guest_is_drawn_down_with_stars_and_a_help_bar():
	var game = _game()
	var c := Vector2i(6, 5)
	var g := _guest_at(game, 0, c)
	var fd: FloorDirt = game.floor_dirt
	fd.slip(g, c)
	var mark: Node3D = fd.down[g].mark
	assert_eq(mark.get_parent(), g)
	assert_false(mark.get_node("bar").visible, "no help yet")
	game.player.position = Grid.center(c + Vector2i(0, 1))
	fd.help_up(game.player)
	fd.tick_slips(0.5)
	assert_true(mark.get_node("bar").visible)
	g.tick(0.1)
	assert_eq(g._body.face, "dazed")
	fd.tick_slips(0.6)
	assert_true(mark.is_queued_for_deletion())


func test_the_end_of_the_day_gets_everyone_up():
	var game = _game()
	game.floor_dirt.slip(game.player, game.player.cell())
	game._end_day()
	assert_false(game.floor_dirt.is_down(game.player))


# ---------------------------------------------------------------- 9.4 cleaning tools (sim)

func test_a_mop_clears_a_level_a_press_and_is_dirty_after_four():
	var m := _room()
	var c := Vector2i(2, 2)
	for i in 4:
		m.add_dirt(c)
	var used := 0
	for i in 4:
		var r := CleanTools.press(m, c, "mop", used)
		assert_eq(r.did, "clean")
		used = r.used
		assert_eq(m.level(c), 3 - i)
	assert_true(CleanTools.is_dirty("mop", used), "dirty after 4 levels")
	assert_false(CleanTools.is_dirty("mop", 3))


func test_a_dirty_mop_cleans_slower_and_never_spreads():
	var m := _room()
	var c := Vector2i(2, 2)
	m.add_dirt(c)
	m.add_dirt(c)
	var dirty := CleanTools.dirty_after("mop")
	var r := CleanTools.press(m, c, "mop", dirty)
	assert_eq(r.did, "clean", "a dirty mop still cleans")
	assert_eq(m.total(), 1, "a level off, nothing landing beside it")
	assert_null(r.to)
	assert_gt(CleanTools.press_time("mop", dirty), CleanTools.press_time("mop", 0), "only slower")


func test_a_sponge_is_dirty_after_two_and_quicker_than_a_mop():
	var m := _room()
	var c := Vector2i(1, 1)
	for i in 3:
		m.add_dirt(c)
	var used := 0
	for i in 2:
		used = CleanTools.press(m, c, "sponge", used).used
	assert_true(CleanTools.is_dirty("sponge", used))
	assert_eq(m.level(c), 1)
	assert_lt(CleanTools.press_time("sponge"), CleanTools.press_time("mop"))


func test_tools_do_nothing_on_clean_or_covered_cells():
	var m := _room()
	var c := Vector2i(2, 2)
	assert_eq(CleanTools.press(m, c, "mop", 0).did, "", "nothing to clean")
	m.add_dirt(c)
	m.set_covered([c])
	assert_eq(CleanTools.press(m, c, "mop", 0).did, "", "under furniture")
	assert_eq(m.level(c), 1)
	m.set_covered([])
	assert_eq(CleanTools.press(m, c, "mop", 0).did, "clean", "once the furniture is moved")


func test_where_each_tool_lives():
	assert_true(CleanTools.fits("bucket", "mop"))
	assert_false(CleanTools.fits("bucket", "sponge"))
	assert_true(CleanTools.fits("hook", "sponge"))
	assert_false(CleanTools.fits("hook", "mop"))
	assert_true(CleanTools.fits(CleanTools.CLOSET, "mop"), "a closet holds either")
	assert_true(CleanTools.fits(CleanTools.CLOSET, "sponge"))
	assert_true(CleanTools.rinses("mop_bucket"))
	assert_true(CleanTools.rinses("sink"))
	for used in 5:
		assert_eq(CleanTools.used_from("mop", CleanTools.cleanness("mop", used)), mini(used, 4))


func test_the_robot_finds_the_nearest_dirt_round_walls_and_furniture():
	var m := _room(6, 6)
	var walk := {}
	for c in m.floor_cells:
		walk[c] = true
	walk.erase(Vector2i(1, 0))   # furniture
	var wall := Vector3i(1, 1, 1)   # a wall between (0, 1) and (1, 1)
	var open := func(a: Vector2i, b: Vector2i) -> bool:
		return not (a + b == Vector2i(1, 2) and absi(a.x - b.x) == 1)
	m.add_dirt(Vector2i(2, 0))
	m.add_dirt(Vector2i(5, 5))
	var path := CleanTools.path_to_dirt(m, Vector2i(0, 0), walk, open)
	assert_eq(path.back(), Vector2i(2, 0), "the nearest dirt")
	assert_false(path.has(Vector2i(1, 0)), "round the furniture")
	assert_eq(path.size(), 6, "and round the wall: down, along and back up")
	assert_eq(CleanTools.path_to_dirt(m, Vector2i(2, 0), walk, open), [], "already on it")
	var home := CleanTools.path_home(Vector2i(3, 0), Vector2i(1, 0), walk, open)
	assert_eq(home.back(), Vector2i(1, 0), "the dock itself is furniture, but home")
	assert_eq(wall.x, 1)


func test_the_robot_or_a_tool_in_the_way_feels_like_level_two():
	assert_eq(CleanTools.felt_level(0, true), CleanTools.ROBOT_LEVEL)
	assert_eq(CleanTools.felt_level(3, true), 3)
	assert_eq(CleanTools.felt_level(1, false), 1)


# ---------------------------------------------------------------- 9.4 in the room

## The chef stands at `c` looking along `dir`; returns the cell in front.
func _stand(game, c: Vector2i, dir := Vector2i(0, 1)) -> Vector2i:
	assert_false(game.grid.is_blocked(c), "the test needs open floor at %s" % c)
	game.player.position = Grid.center(c)
	game.player.look(dir)
	return c + dir


func _bucket(game, c: Vector2i) -> Station:
	var st: Station = game.add_station("mop_bucket", c)
	game.clean_kit.on_built(st, "mop_bucket")
	game.step(0.01)
	return st


func _wall_cell(game) -> Vector2i:
	for c: Vector2i in game.kitchen.wall_cells:
		if not game.stations.has(c) and game.kitchen.can_hang(c, "hook"):
			return c
	return Vector2i(-99, -99)


func test_the_shop_sells_the_cleaning_pieces():
	for id in ["mop_bucket", "hook", "sponge", "robot_dock"]:
		assert_eq(Catalog.ITEMS[id].category, "Kitchen", id)
		assert_true(Catalog.sold_in(id, "diner") and Catalog.sold_in(id, "seaside"), id)
	assert_eq(Catalog.price_of("mop_bucket"), 35, "the sponge's whole way up to it")
	assert_eq(Catalog.price_of("sponge"), 15)
	assert_eq(Catalog.price_of("robot_dock"), 315)
	assert_lt(Catalog.price_of("hook"), Catalog.price_of("sponge"), "a hook is cheap")


func test_e_takes_the_mop_from_its_bucket_and_puts_it_back_rinsed():
	var game = _game()
	var c := Vector2i(7, 2)
	var b := _bucket(game, c + Vector2i(-1, 0))
	assert_eq(b.kit_tool, "mop", "a bucket comes with its mop")
	_stand(game, c, Vector2i(-1, 0))
	assert_eq(game.use_station(b, true), "Take mop")
	game.act(0, "use")
	assert_eq(game.player.held, "tool:mop")
	assert_eq(b.kit_tool, "")
	game.player.set_held("tool:mop", CleanTools.cleanness("mop", 3))
	assert_eq(game.use_station(b, true), "Put mop back")
	game.act(0, "use")
	assert_eq(game.player.held, "")
	assert_eq(b.kit_tool, "mop")
	assert_eq(b.kit_used, 0, "the bucket rinses it")


func test_hands_are_full_while_holding_a_tool():
	var game = _game()
	CleanKit.hold(game.player, "mop", 0)
	for st: Station in game.stations.values():
		assert_eq(game.use_station(st, true), "", "nothing at the %s" % st.type)


func test_e_at_a_dirty_cell_in_front_clears_a_level_and_held_e_repeats():
	var game = _game()
	var front := _stand(game, Vector2i(7, 2))
	for i in 3:
		game.floor_dirt.mess.add_dirt(front)
	CleanKit.hold(game.player, "mop", 0)
	assert_eq(game.clean_kit.floor_action(game.player), "Mop")
	game.act(0, "use")
	assert_eq(game.floor_dirt.mess.level(front), 2)
	game.act(0, "use")
	assert_eq(game.floor_dirt.mess.level(front), 2, "a press takes 0.6 s")
	game.clean_kit.tick(0.61)
	game.clean_kit.hold_use(game.player, true)
	assert_eq(game.floor_dirt.mess.level(front), 1, "held E goes again")
	game.clean_kit.tick(0.3)
	game.clean_kit.hold_use(game.player, true)
	assert_eq(game.floor_dirt.mess.level(front), 1)
	assert_eq(CleanKit.held_used(game.player), 2)


func test_a_dirty_mop_is_slow_until_rinsed_at_a_sink():
	var game = _game()
	var front := _stand(game, Vector2i(7, 2))
	game.floor_dirt.mess.add_dirt(front)
	CleanKit.hold(game.player, "mop", 4)
	assert_string_contains(game.clean_kit.floor_action(game.player), "slow")
	var before: int = game.floor_dirt.mess.total()
	game.act(0, "use")
	assert_eq(game.floor_dirt.mess.total(), before - 1, "it still mops")
	var sink: Station = game.find_station("sink")
	assert_eq(game.use_station(sink, true), "Rinse mop")
	game.use_station(sink)
	assert_eq(CleanKit.held_used(game.player), 0)
	assert_eq(game.player.held, "tool:mop", "still in hand, clean")


func test_dirt_straight_ahead_beats_putting_the_mop_back():
	var game = _game()
	var c := Vector2i(7, 2)
	var b := _bucket(game, c + Vector2i(-1, 0))
	b.kit_tool = ""
	var front := _stand(game, c)
	game.floor_dirt.mess.add_dirt(front)
	CleanKit.hold(game.player, "mop", 0)
	game.act(0, "use")
	assert_eq(game.floor_dirt.mess.level(front), 0)
	assert_eq(game.player.held, "tool:mop")


func test_a_sponge_hangs_on_its_hook():
	var game = _game()
	var w := _wall_cell(game)
	assert_ne(w, Vector2i(-99, -99), "the test needs a free wall cell")
	var h: Station = game.add_high("hook", w)
	game.clean_kit.on_built(h, "sponge")
	assert_eq(h.kit_tool, "sponge")
	assert_eq(game.clean_kit.home_at(w), h)
	assert_eq(game.use_station(h, true), "Take sponge")
	game.use_station(h)
	assert_eq(game.player.held, "tool:sponge")
	CleanKit.hold(game.player, "mop", 0)
	assert_eq(game.use_station(h, true), "", "a mop does not hang on a hook")
	CleanKit.hold(game.player, "sponge", 2)
	game.use_station(h)
	assert_eq(h.kit_tool, "sponge")
	assert_eq(h.kit_used, 2, "a hook does not rinse")


func test_a_closet_holds_a_mop_or_a_sponge():
	var game = _game()
	var w := _wall_cell(game)
	var low: Station = game.add_station("shelf", w)
	var high: Station = game.add_high("shelf", w)
	assert_true(game.kitchen.is_closet(w))
	assert_eq(game.clean_kit.home_at(w), high)
	CleanKit.hold(game.player, "mop", 1)
	assert_eq(game.use_station(low, true), "Put mop back")
	game.use_station(low)
	assert_eq(high.kit_tool, "mop")
	assert_eq(game.use_station(low, true), "Take mop")


func test_a_tool_put_down_elsewhere_lies_in_the_way():
	var game = _game()
	var front := _stand(game, Vector2i(7, 2))
	CleanKit.hold(game.player, "sponge", 1)
	assert_eq(game.clean_kit.floor_action(game.player), "Put sponge down")
	game.act(0, "use")
	assert_eq(game.player.held, "")
	assert_true(game.clean_kit.lying.has(front))
	game.step(0.01)
	assert_almost_eq(game.floor_speed(Grid.center(front)), FloorMess.speed_of(2), 0.001, "in the way")
	assert_eq(game.clean_kit.floor_action(game.player), "Pick up sponge")
	game.act(0, "use")
	assert_eq(game.player.held, "tool:sponge")
	assert_eq(CleanKit.held_used(game.player), 1, "as dirty as it was")
	assert_false(game.clean_kit.lying.has(front))


func test_at_night_moving_furniture_uncovers_dirt_to_mop():
	var game = _game()
	var table: Station = game.stations[Vector2i(6, 5)]
	var under := table.cell
	game.floor_dirt.mess.add_dirt(under)
	game.arrivals.clear()
	game.step(0.1)
	game.open_build()
	game.step(0.01)
	_stand(game, under + Vector2i(0, -1))
	CleanKit.hold(game.player, "mop", 0)
	assert_false(game.floor_dirt.mess.can_clean(under), "covered while the table stands there")
	game.build_interact()
	assert_eq(game.floor_dirt.mess.level(under), 1)
	assert_true(game.player.hand.is_empty(), "hands full: the table is not picked up with a mop in them")
	assert_false(game.pick_up(Grid.center(under)))
	game.player.set_held("")
	assert_true(game.pick_up(Grid.center(under)))
	game.step(0.01)
	assert_true(game.floor_dirt.mess.can_clean(under))
	game.player.hand = {}   # the table set aside for the test
	CleanKit.hold(game.player, "mop", 0)
	assert_eq(game._kit_action(game.player), "Mop")
	game.build_interact()
	assert_eq(game.floor_dirt.mess.level(under), 0)


func test_the_robot_drifts_to_dirt_cleans_it_slowly_and_docks():
	var game = _game()
	var dock: Station = game.add_station("robot_dock", Vector2i(7, 2))
	var dirt := Vector2i(7, 4)
	game.floor_dirt.mess.add_dirt(dirt)
	game.floor_dirt.mess.add_dirt(dirt)
	game.step(0.01)
	assert_true(game.clean_kit.is_docked(dock))
	for i in 60:
		game.step(0.05)   # 3 s: two cells at 0.7 m/s
	var r: Dictionary = game.clean_kit.robots[dock]
	assert_eq(Grid.to_cell(r.pos), dirt, "drifted to the dirt")
	assert_true(game.floor_dirt.in_way.has(dirt), "anyone can trip on it")
	assert_eq(game.floor_dirt.mess.level(dirt), 2)
	for i in 70:
		game.step(0.05)
	assert_eq(game.floor_dirt.mess.level(dirt), 1, "a level every few seconds")
	for i in 200:
		game.step(0.05)
	assert_eq(game.floor_dirt.mess.level(dirt), 0)
	assert_true(game.clean_kit.is_docked(dock), "back to charge when done")


func test_the_robot_goes_home_at_the_end_of_the_day():
	var game = _game()
	var dock: Station = game.add_station("robot_dock", Vector2i(7, 2))
	game.floor_dirt.mess.add_dirt(Vector2i(7, 5))
	for i in 30:
		game.step(0.05)
	assert_false(game.clean_kit.is_docked(dock))
	game._end_day()
	assert_true(game.clean_kit.is_docked(dock))


func test_bought_at_night_a_sponge_hangs_on_its_own_hook_and_a_bucket_holds_a_mop():
	var game = _game()
	game.arrivals.clear()
	game.step(0.1)
	game.open_build()
	game.ledger.money = 200
	var w := _wall_cell(game)
	assert_true(game.pick_catalog("sponge"))
	assert_true(game.can_place(Vector3i(w.x, w.y, 0)), "a sponge goes on a wall")
	assert_true(game.place(Vector3i(w.x, w.y, 0)))
	var h: Station = game.highs[w]
	assert_eq(h.type, "hook")
	assert_eq(h.kit_tool, "sponge")
	game.cancel_hand()
	var spot := Vector2i(7, 2)
	assert_true(game.pick_catalog("mop_bucket"))
	assert_true(game.place(Vector3i(spot.x, spot.y, 0)))
	assert_eq((game.stations[spot] as Station).kit_tool, "mop")
	assert_eq(game.ledger.money, 200 - 15 - 35)


# ---------- 9.5: floor treatments ----------

func test_the_treatment_tree_and_its_prices_a_cell():
	assert_true(Treatments.is_root("cleaner"))
	var kids := Treatments.children("cleaner")
	kids.sort()
	assert_eq(kids, ["finish", "primer", "strong_cleaner"] as Array[String])
	assert_eq(Treatments.step("strong_cleaner"), Kitchen.EFFICIENT)
	assert_eq(Treatments.step("primer"), Kitchen.SPECIALIST_STEP)
	assert_eq(Treatments.parent("sealing_primer"), "primer")
	assert_eq(Treatments.parent("high_gloss"), "finish")
	for k: String in Treatments.ITEMS:
		assert_true(Catalog.ITEMS.has(Treatments.box_id(k)) and Catalog.ITEMS.has(Treatments.tool_id(k)), k)
		assert_eq(Treatments.key_of(Treatments.box_id(k)), k)
		assert_eq(Treatments.key_of(Treatments.tool_id(k)), k)
		assert_true(Kitchen.is_cleaning(Treatments.box_id(k)))
		assert_almost_eq(Catalog.joy_of(Treatments.tool_id(k)), Treatments.joy(k), 0.001, "the catalog's joy is the treatment's")
	assert_eq(Treatments.key_of("box_bun"), "")
	assert_false(Kitchen.is_cleaning("box_bun"))


func test_a_box_climbs_its_tree_like_any_piece():
	assert_eq(Upgrades.key_of("box_cleaner"), "box_cleaner")
	assert_true(Upgrades.has_tree("box_cleaner"))
	assert_eq(Upgrades.parent("box_sealing_primer"), "box_primer")
	assert_eq(Upgrades.step_price("box_primer"), 40)
	assert_eq(Upgrades.step_price("box_sealing_primer"), 50, "the new worth less the old")
	assert_true(Upgrades.can_buy("box_cleaner", "box_finish", 60, 1))
	assert_false(Upgrades.can_buy("box_cleaner", "box_high_gloss", 999, 9), "no skipping steps")
	var lay := Upgrades.layout("box_cleaner")
	assert_eq(lay.size(), 6)
	assert_eq(lay["box_strong_cleaner"], Vector2i(1, 0), "the efficient step runs on along the row")
	assert_true(Upgrades.blurb("box_primer").contains("$3 a night"), "its box's flat fee")
	var shop := Catalog.search("", "Pantry")
	assert_eq(shop.any(func(bp: Dictionary) -> bool: return bp.id == "box_cleaner"), Treatments.ON_SALE,
		"the cleaner's box is sold only while treatments are (parked: liquids are in the mop bucket)")
	for id: String in ["box_primer", "box_finish", "treat_cleaner"]:
		assert_false(shop.any(func(bp: Dictionary) -> bool: return bp.id == id) \
			or Catalog.search("", "Build").any(func(bp: Dictionary) -> bool: return bp.id == id), id + " is not in the catalog's list")


func test_a_nights_laying_costs_its_price_a_cell_while_on_and_boxed():
	var laid := {Vector2i(0, 0): "cleaner", Vector2i(1, 0): "cleaner", Vector2i(2, 0): "cleaner",
		Vector2i(0, 1): "primer", Vector2i(1, 1): "primer"}
	var boxed := {"cleaner": true, "primer": true}
	assert_eq(Treatments.night_cost(laid, {}, boxed), Treatments.fee_of("cleaner") + Treatments.fee_of("primer"),
		"each stocked box's flat fee, however many tiles")
	assert_eq(Treatments.night_cost(laid, {"primer": true}, boxed), Treatments.fee_of("cleaner"), "switched off: not restocked")
	assert_eq(Treatments.night_cost(laid, {}, {"cleaner": true}), Treatments.fee_of("cleaner"), "no box stored: not laid")
	var lines := Treatments.night_lines(laid, {}, {"cleaner": true})
	assert_eq(lines.primer, {"cells": 2, "fee": 0, "on": false})
	assert_eq(lines.cleaner, {"cells": 3, "fee": Treatments.fee_of("cleaner"), "on": true})
	assert_eq(Treatments.night_cost({}, {}, {"finish": true}), Treatments.fee_of("finish"), "a box stocked costs its fee with no tiles laid")
	var many := {}
	for x in 20:
		many[Vector2i(x, 0)] = "cleaner"
	assert_eq(Treatments.night_cost(many, {}, {"cleaner": true}), Treatments.fee_of("cleaner"), "twenty tiles cost the same")
	for k: String in Treatments.ITEMS:
		assert_between(Treatments.fee_of(k), 2, 8, k + ": in line with the food boxes")
	assert_eq(Treatments.active(laid, {"cleaner": true}, boxed).keys().size(), 2, "only the primer's cells tomorrow")


func test_a_primer_stops_some_new_dirt_but_not_dirt_tracked_in():
	var m := _room(5, 5, 3)
	var c := Vector2i(2, 2)
	m.treat[c] = "primer"
	var landed := 0
	for i in 200:
		if m.add_dirt(c) != null:
			landed += 1
		m.dirt.clear()
	assert_between(landed, 90, 150, "about three in five land (40%% stopped): %d" % landed)
	m.treat[c] = "sealing_primer"
	landed = 0
	for i in 200:
		if m.add_dirt(c) != null:
			landed += 1
		m.dirt.clear()
	assert_between(landed, 55, 110, "about two in five land (60%% stopped): %d" % landed)
	m.add_dirt(Vector2i(1, 2), false)
	for i in 20:
		m.dirt[Vector2i(1, 2)] = 1
		m.dirt.erase(c)
		assert_true(m.track(Vector2i(1, 2), c))
		assert_eq(m.level(c), 1, "tracked dirt always lands")


func test_a_strong_cleaner_keeps_its_dirt_off_feet():
	var m := _room()
	var c := Vector2i(2, 2)
	m.add_dirt(c)
	m.treat[c] = "strong_cleaner"
	assert_false(m.track(c, Vector2i(3, 2)))
	assert_eq(m.level(c), 1)
	m.treat[c] = "cleaner"
	assert_true(m.track(c, Vector2i(3, 2)), "a plain cleaner does not stop it")


func test_a_finish_speeds_everyone_and_shows_its_dirt_more():
	var m := _room()
	var c := Vector2i(2, 2)
	m.treat[c] = "finish"
	assert_almost_eq(m.speed_at(c), 1.1, 0.001)
	m.add_dirt(c)
	m.add_dirt(c)
	assert_almost_eq(m.speed_at(c), FloorMess.speed_of(2) * 1.1, 0.001, "it offsets the slowing")
	assert_almost_eq(m.sight_disgust([c]), FloorMess.sight_disgust_of(2) * 1.25, 0.001, "dirt shows more on a shine")
	m.treat[c] = "high_gloss"
	assert_almost_eq(m.speed_at(c), FloorMess.speed_of(2) * 1.2, 0.001)
	assert_gt(Treatments.joy("high_gloss"), Treatments.joy("finish"))


func test_on_a_cleaner_a_mop_clears_the_whole_cell_in_one_press():
	var m := _room()
	var c := Vector2i(2, 2)
	for i in 4:
		m.add_dirt(c)
	m.treat[c] = "cleaner"
	var r := CleanTools.press(m, c, "mop", 0)
	assert_eq(r.did, "clean")
	assert_eq(m.level(c), 0)
	assert_eq(r.used, 1, "one press, one step dirtier")
	for i in 4:
		m.add_dirt(c)
	CleanTools.press(m, c, "spill_kit", 0)
	assert_eq(m.level(c), 2, "a spill kit still takes a covered cell to a puddle")


# ---------- 9.5: the cleaning trees ----------

func test_the_cleaning_and_hood_trees_are_the_prds():
	var want := {"mop_bucket": ["sponge", Kitchen.EFFICIENT, 35],
		"sponge_mop": ["mop_bucket", Kitchen.EFFICIENT, 50], "flat_mop": ["sponge_mop", Kitchen.EFFICIENT, 75],
		"scrubber": ["flat_mop", Kitchen.EFFICIENT, 195], "wringer_bucket": ["mop_bucket", Kitchen.SPECIALIST_STEP, 60],
		"cleaner_bucket": ["mop_bucket", Kitchen.SPECIALIST_STEP, 60], "strong_bucket": ["cleaner_bucket", Kitchen.EFFICIENT, 100],
		"robot_dock": ["wringer_bucket", Kitchen.SPECIALIST_STEP, 315], "scourer": ["sponge", Kitchen.EFFICIENT, 25],
		"grease_scraper": ["sponge", Kitchen.SPECIALIST_STEP, 40], "spill_kit": ["sponge", Kitchen.SPECIALIST_STEP, 30],
		"extractor": ["hood", Kitchen.EFFICIENT, 90]}
	for n: String in want:
		assert_eq(Kitchen.parent_of(n), want[n][0], n)
		assert_eq(Kitchen.step_of(n), want[n][1], n)
		assert_eq(Kitchen.price_of(n), want[n][2], n)
	assert_eq(Kitchen.price_of("mop_bucket"), Catalog.price_of("mop_bucket"))
	assert_eq(Kitchen.price_of("sponge"), Catalog.price_of("sponge"))
	for n: String in Kitchen.NODES:
		var t := Kitchen.tool_of(n)
		if t != "":
			assert_true(CleanTools.TOOLS.has(t), "%s keeps a real tool" % n)
			assert_eq(CleanTools.TOOLS[t].home, "bucket" if Kitchen.fit_of(n) == "floor" else "hook", n)
	assert_eq(Kitchen.tool_of("robot_dock"), "", "the dock keeps the robot, not a hand tool")
	assert_true(Upgrades.has_tree("mop_bucket") and Upgrades.has_tree("sponge") and Upgrades.has_tree("hood"))
	assert_eq(Catalog.search("robot").size(), 0, "the robot is bought up the wringer bucket's tree")


func test_each_mop_up_the_tree_lasts_longer_or_does_more():
	assert_eq(CleanTools.dirty_after("sponge_mop"), 6)
	assert_eq(CleanTools.dirty_after("flat_mop"), 8)
	var m := _room()
	var c := Vector2i(2, 2)
	for i in 4:
		m.add_dirt(c)
	CleanTools.press(m, c, "flat_mop", 0)
	assert_eq(m.level(c), 0, "a flat mop clears a whole cell a press")
	for t: String in ["wringer_mop", "scrubber", "grease_scraper", "spill_kit"]:
		assert_true(CleanTools.never_dirty(t), t)
		assert_false(CleanTools.is_dirty(t, 99), t)
	assert_true(CleanTools.pushes("scrubber"))
	assert_lt(CleanTools.walk_speed("scrubber"), 1.0, "slow to walk")
	assert_eq(CleanTools.walk_speed("mop"), 1.0)
	assert_true(CleanTools.is_mop("scrubber") and not CleanTools.is_mop("spill_kit"))
	assert_eq(CleanTools.comes_with("sponge_mop"), "sponge_mop")
	assert_eq(CleanTools.comes_with("mop_bucket"), "mop")


func test_the_grease_scraper_clears_kitchen_grease_only():
	var m := _room()
	var g := Vector2i(1, 1)
	var guest := Vector2i(3, 3)
	m.rng.seed = 1
	while m.level(g) < 3:
		m.drop_grease("fry", "bad", [g])
	assert_true(m.is_grease(g), "prep grease is marked")
	m.add_dirt(guest)
	assert_false(m.is_grease(guest), "a guest's mess is not")
	var r := CleanTools.press(m, guest, "grease_scraper", 0)
	assert_eq(r.did, "refused")
	assert_true(r.why.contains("grease"))
	assert_eq(m.level(guest), 1)
	r = CleanTools.press(m, g, "grease_scraper", 0)
	assert_eq(r.did, "clean")
	assert_eq(m.level(g), 0, "a whole cell a press")
	assert_false(m.is_grease(g), "a clean cell holds no grease")
	m.add_dirt(g, true, true)
	m.track(g, guest)
	assert_true(m.is_grease(guest), "grease tracked across stays grease")


func test_a_spill_kit_is_for_a_covered_cell_three_times_a_day():
	var m := _room()
	var c := Vector2i(2, 2)
	for i in 3:
		m.add_dirt(c)
	var r := CleanTools.press(m, c, "spill_kit", 0)
	assert_eq(r.did, "refused", "not for a level 3 puddle")
	var used := 0
	for k in 3:
		m.add_dirt(c)
		m.add_dirt(c)   # back up to 4
		r = CleanTools.press(m, c, "spill_kit", used)
		assert_eq(r.did, "clean")
		assert_eq(m.level(c), 2)
		used = r.used
	assert_true(CleanTools.used_up("spill_kit", used))
	m.add_dirt(c)
	m.add_dirt(c)
	assert_eq(CleanTools.press(m, c, "spill_kit", used).did, "refused", "used up for today")
	assert_lt(CleanTools.help_factor("spill_kit"), 1.0, "helps a fallen guest up faster")


func test_an_extractor_cuts_grease_more_than_a_hood_and_its_smell():
	assert_almost_eq(FloorMess.hood_factor("extractor"), 0.15, 0.001)
	assert_almost_eq(FloorMess.hood_factor("hood"), FloorMess.hood_factor(true), 0.001)
	assert_almost_eq(FloorMess.hood_factor(""), 1.0, 0.001)
	assert_lt(FloorMess.grease_chance("fry", "plain", 1.0, "extractor"), FloorMess.grease_chance("fry", "plain", 1.0, "hood"))
	var m := _room(9, 9)
	var g := Vector2i(4, 4)
	for i in 3:
		m.add_dirt(g, true, true)
	var far := g + Vector2i(FloorMess.SMELL_RADIUS, 0)
	assert_gt(m.smell_disgust(far), 0.0)
	m.extractor = true
	assert_eq(m.smell_disgust(far), 0.0, "kitchen grease smells a cell less far")
	assert_gt(m.smell_disgust(g + Vector2i(1, 0)), 0.0)


# ---------- 9.5: chemicals never with food ----------

func test_chemicals_and_food_never_share_a_cell_and_chemicals_stay_out_of_fridges():
	var k := Kitchen.new()
	k.set_cell(Vector2i(0, 0), "counter")
	k.set_cell(Vector2i(1, 0), "counter")
	k.set_cell(Vector2i(2, 0), "fridge")
	assert_true(k.store(Vector2i(0, 0), "box_bun"))
	assert_false(k.can_store(Vector2i(0, 0), "box_cleaner"))
	assert_true(k.store(Vector2i(1, 0), "box_cleaner"))
	assert_false(k.can_store(Vector2i(2, 0), "box_cleaner"), "never in a fridge")
	assert_eq(k.store_refusal(Vector2i(2, 0), "box_cleaner"), "No chemicals in a fridge")
	assert_true(k.holds_cleaning(Vector2i(1, 0)))
	assert_false(k.holds_food(Vector2i(1, 0)))
	k.unstore(Vector2i(0, 0), "box_bun")
	k.set_cell(Vector2i(0, 0), "double_counter")
	assert_true(k.store(Vector2i(0, 0), "box_bun"))
	assert_eq(k.store_refusal(Vector2i(0, 0), "box_primer"), "No chemicals with food", "not even in the other slot")
	k.set_cell(Vector2i(1, 0), "double_counter")
	assert_eq(k.store_refusal(Vector2i(1, 0), "box_bun"), "No food with chemicals")
	assert_true(k.store(Vector2i(1, 0), "box_primer"), "two chemicals share happily")
	assert_eq(k.store_refusal(Vector2i(1, 0), "box_primer"), "One of each a cell")


# ---------- 9.5: in the room ----------

func _night(game) -> void:
	game.arrivals.clear()
	game.step(0.1)
	game.open_build()
	game.ledger.money = 1000


## A bare counter at a free cell for a box; its cell.
func _shelf_for(game, c := Vector2i(7, 2)) -> Vector2i:
	game.add_station("counter", c)
	return c


func test_a_treatment_box_is_stored_away_from_food_and_stocks_no_food():
	var game = _game()
	_night(game)
	var food: Vector2i = game.storage_of(game.fixed_main().bread).cell
	assert_true(game.pick_catalog("box_cleaner"))
	assert_false(game.can_place(Vector3i(food.x, food.y, 0)), "not in with the bread")
	game.player.demo_hover = Grid.center(food)
	assert_eq(game.build_action(), "No chemicals with food")
	var c := _shelf_for(game)
	var before: int = game.kitchen_stock().size()
	assert_true(game.place(Vector3i(c.x, c.y, 0)))
	assert_true(game.kitchen.stock(c).has("box_cleaner"))
	assert_eq(game.kitchen_stock().size(), before, "chemicals stock no food")
	assert_eq(game.treat_boxed(), {"cleaner": true})
	game.player.demo_hover = Vector3.INF
	_stand(game, c + Vector2i(0, 1), Vector2i(0, -1))
	assert_eq(game.use_station(game.stations[c], true), "", "nothing to take out of a box of chemicals")


func test_laid_at_night_a_treatment_is_paid_at_the_door_each_night_while_on():
	var game = _game()
	_night(game)
	var base: int = game.night_cost()
	assert_false(game.shop_items("", "Build").any(func(bp: Dictionary) -> bool: return bp.id == "treat_cleaner"),
		"no box stored: nothing to lay")
	game.kitchen.store(_shelf_for(game), "box_cleaner")
	assert_true(game.shop_items("", "Build").any(func(bp: Dictionary) -> bool: return bp.id == "treat_cleaner"))
	assert_true(game.pick_catalog("treat_cleaner"))
	var money: int = game.ledger.money
	assert_eq(game.finish_drag(Grid.center(Vector2i(4, 2)), Grid.center(Vector2i(5, 3)), false), 4)
	assert_eq(game.ledger.money, money, "laying is free")
	assert_eq(game.treat_laid.size(), 4)
	var fee := Treatments.fee_of("cleaner")
	assert_eq(game.night_cost(), base + fee, "the stocked box's flat fee: the tiles add nothing")
	assert_true(game.stock_lines().any(func(l: Dictionary) -> bool: return l.name == "Floor cleaner box, 4 tiles" and l.fee == fee))
	assert_eq(game.floor_dirt.sheen_cells().size(), 4, "a sheen where it is laid")
	game.rotate_hand()
	assert_true(game.treat_off.has("cleaner"), "turning the tool switches it off")
	assert_eq(game.night_cost(), base, "switched off: the box is not restocked")
	assert_true(game.stock_lines().any(func(l: Dictionary) -> bool: return l.name == "Floor cleaner box, 4 tiles, off" and l.fee == 0))
	game.rotate_hand()
	assert_eq(game.night_cost(), base + fee)
	assert_eq(game.finish_drag(Grid.center(Vector2i(5, 3)), Grid.center(Vector2i(5, 3)), true), 1, "a right-drag lifts it")
	assert_eq(game.night_cost(), base + fee, "fewer tiles, the same fee")
	game.cancel_hand()
	money = game.ledger.money
	game.start_day()
	assert_eq(game.ledger.money, money - base - fee)
	assert_eq(game.floor_dirt.mess.treat.size(), 3, "laid for the day")
	game.floor_dirt.mess.add_dirt(Vector2i(4, 2))
	game.floor_dirt.mess.add_dirt(Vector2i(4, 2))
	assert_true(game.floor_dirt.mess.one_press(Vector2i(4, 2)))
	game._end_day()
	assert_eq(game.floor_dirt.mess.treat.size(), 0, "it lasts one day of service")
	assert_eq(game.treat_laid.size(), 3, "and is re-laid tomorrow")


func test_without_its_box_a_treatment_is_not_relaid():
	var game = _game()
	_night(game)
	var base: int = game.night_cost()
	var c := _shelf_for(game)
	game.kitchen.store(c, "box_finish")
	game.treat_laid = {Vector2i(4, 2): "finish", Vector2i(4, 3): "finish"}
	assert_eq(game.night_cost(), base + Treatments.fee_of("finish"), "the finish box's flat fee")
	game.kitchen.unstore(c, "box_finish")
	assert_eq(game.night_cost(), base)
	assert_true(game.stock_lines().any(func(l: Dictionary) -> bool: return l.name.ends_with("no box")))
	game.start_day()
	assert_true(game.floor_dirt.mess.treat.is_empty())


func test_a_finish_in_force_cheers_guests_like_a_fine_floor():
	var game = _game()
	var seat := Vector2i(4, 2)
	var before: float = game.decor_bonus(seat).joy
	game.floor_dirt.mess.treat = {seat: "high_gloss"}
	assert_gt(game.decor_bonus(seat).joy, before)
	assert_eq(game.decor_bonus(seat).best, "treat_high_gloss")


func test_a_box_picked_up_climbs_its_tree_and_the_laid_cells_follow():
	var game = _game()
	_night(game)
	var c := _shelf_for(game)
	game.kitchen.store(c, "box_cleaner")
	game.treat_laid = {Vector2i(4, 2): "cleaner"}
	assert_true(game.pick_up(Grid.center(c)))
	assert_eq(game.player.hand.id, "box_cleaner")
	assert_eq(game.hand_key(), "box_cleaner")
	assert_true(game.strip_choices().any(func(c: Dictionary) -> bool: return c.get("key", "") == "box_primer"),
		"the strip along the bottom offers the box's next steps")
	var money: int = game.ledger.money
	assert_true(game.buy_upgrade("box_primer"))
	assert_eq(game.ledger.money, money - 40)
	assert_eq(game.player.hand.id, "box_primer")
	assert_eq(game.treat_laid[Vector2i(4, 2)], "primer")
	game.close_shop()
	assert_true(game.place(Vector3i(c.x, c.y, 0)))
	assert_true(game.kitchen.stock(c).has("box_primer"))


func test_a_mop_bucket_climbs_to_a_flat_mop_and_its_mop_comes_too():
	var game = _game()
	_night(game)
	var c := Vector2i(7, 2)
	var b := _bucket(game, c)
	assert_true(game.pick_up(Grid.center(c)))
	game.open_shop()
	assert_true(game.buy_upgrade("sponge_mop"))
	assert_true(game.buy_upgrade("flat_mop"))
	var up: Station = game.player.hand.node
	assert_eq(up.node, "flat_mop")
	assert_eq(up.type, "mop_bucket", "still a bucket in the room")
	assert_eq(up.kit_tool, "flat_mop")
	assert_false(is_instance_valid(b) and not b.is_queued_for_deletion())
	game.close_shop()
	assert_true(game.place(Vector3i(c.x, c.y, 0)))
	assert_eq((game.stations[c] as Station).kit_tool, "flat_mop")


func test_with_its_mop_out_the_bucket_upgrade_swaps_the_mop_in_hand():
	var game = _game()
	_night(game)
	var c := Vector2i(7, 2)
	var b := _bucket(game, c)
	game.clean_kit.keep(b, "", 0)
	var holder: Player = game.add_chef(Vector2i(4, 4))   # chef 2 has the mop out
	CleanKit.hold(holder, "mop", 3)
	assert_true(game.pick_up(Grid.center(c)))
	game.open_shop()
	assert_true(game.buy_upgrade("wringer_bucket"))
	assert_eq(CleanKit.held_tool(holder), "wringer_mop")


func test_the_wringer_bucket_grows_into_the_robot_sweepers_dock():
	var game = _game()
	_night(game)
	var c := Vector2i(7, 2)
	_bucket(game, c)
	assert_true(game.pick_up(Grid.center(c)))
	game.open_shop()
	assert_true(game.buy_upgrade("wringer_bucket"))
	assert_eq((game.player.hand.node as Station).kit_tool, "wringer_mop")
	assert_true(game.buy_upgrade("robot_dock"))
	var dock: Station = game.player.hand.node
	assert_eq(dock.type, "robot_dock")
	assert_eq(dock.kit_tool, "")
	game.close_shop()
	assert_true(game.place(Vector3i(c.x, c.y, 0)))
	game.step(0.01)
	assert_true(game.clean_kit.robots.has(game.stations[c]), "its robot is out")


func test_a_hooks_tree_is_its_tools():
	var game = _game()
	_night(game)
	var w := _wall_cell(game)
	var h: Station = game.add_high("hook", w)
	game.clean_kit.on_built(h, "sponge")
	assert_true(game.pick_up(Grid.center(w)))
	assert_eq(game.hand_key(), "sponge")
	assert_true(game.strip_choices().any(func(c: Dictionary) -> bool: return c.get("key", "") == "spill_kit"))
	assert_true(game.buy_upgrade("spill_kit"))
	assert_eq(h.kit_tool, "spill_kit")
	assert_eq(game.hand_key(), "spill_kit")
	game.close_shop()
	assert_true(game.place(Vector3i(w.x, w.y, 0)))
	assert_eq((game.highs[w] as Station).kit_tool, "spill_kit")


func test_a_hood_upgraded_to_an_extractor_cuts_more_grease():
	var game = _game()
	_night(game)
	game.clear_walls()
	var w := _wall_cell(game)
	game.add_high("hood", w)
	assert_true(game.pick_up(Grid.center(w)))
	game.open_shop()
	assert_true(game.buy_upgrade("extractor"))
	game.close_shop()
	assert_true(game.place(Vector3i(w.x, w.y, 0)))
	assert_eq(game.kitchen.hood_at(w), "extractor")
	assert_eq((game.highs[w] as Station).type, "hood", "it draws as a hood")
	game.start_day()
	assert_true(game.floor_dirt.mess.extractor)


func test_a_floor_scrubber_cleans_each_cell_it_is_pushed_over_slowly():
	var game = _game()
	var c := Vector2i(7, 2)
	_stand(game, c)
	_dirty(game, c, 3)
	var speed: float = game.player.speed()
	CleanKit.hold(game.player, "scrubber", 0)
	assert_lt(game.player.speed(), speed, "slow to push")
	game.clean_kit.tick(0.01)
	assert_eq(game.floor_dirt.mess.level(c), 0, "the cell it stands on, cleared")
	assert_eq(CleanKit.held_used(game.player), 0, "never dirty")


func test_the_scraper_on_guest_mess_says_why_and_a_spill_kit_refills_each_day():
	var game = _game()
	var front := _stand(game, Vector2i(7, 2))
	_dirty(game, front, 4)
	CleanKit.hold(game.player, "grease_scraper", 0)
	assert_eq(game.floor_dirt.mess.is_grease(front), false)
	assert_eq(game.clean_kit.press(game.player), "refused")
	assert_eq(game.floor_dirt.mess.level(front), 4)
	CleanKit.hold(game.player, "spill_kit", 3)
	assert_true(CleanTools.used_up("spill_kit", CleanKit.held_used(game.player)))
	game.clean_kit.start_day()
	assert_eq(CleanKit.held_used(game.player), 0, "three uses again")
	game.clean_kit.tick(1.0)
	assert_eq(game.clean_kit.press(game.player), "clean")
	assert_eq(game.floor_dirt.mess.level(front), 2)


func test_the_sponge_grows_into_a_mop_bucket_and_then_a_cleaner_in_its_pail():
	var game = _game()
	_night(game)
	game.ledger.money = 500
	var w := _wall_cell(game)
	var h: Station = game.add_high("hook", w)
	game.clean_kit.on_built(h, "sponge")
	assert_true(game.pick_up(Grid.center(w)))
	assert_true(game.strip_choices().any(func(c: Dictionary) -> bool: return c.get("key", "") == "mop_bucket"),
		"the sponge's strip offers the mop bucket")
	assert_true(game.buy_upgrade("mop_bucket"))
	assert_eq(game.ledger.money, 500 - Upgrades.step_price("mop_bucket"))
	var b: Station = game.player.hand.node
	assert_eq(b.type, "mop_bucket", "off the wall: a bucket in hand")
	assert_eq(b.kit_tool, "mop", "with its mop")
	var keys: Array = game.strip_choices().map(func(c: Dictionary) -> String: return str(c.get("key", "")))
	assert_has(keys, "sponge_mop", "better mops")
	assert_has(keys, "cleaner_bucket", "or a liquid in the pail")
	assert_true(game.buy_upgrade("cleaner_bucket"))
	assert_eq((game.player.hand.node as Station).kit_tool, "cleaner_mop")
	assert_eq(int(CleanTools.TOOLS.cleaner_mop.levels), FloorMess.MAX_LEVEL, "a whole cell a press")
	var spot := Vector2i(7, 2)
	assert_true(game.place(Vector3i(spot.x, spot.y, 0)))
	assert_eq((game.stations[spot] as Station).kit_tool, "cleaner_mop")
	assert_false(game.highs.has(w), "the hook is gone")
