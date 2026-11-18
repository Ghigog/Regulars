extends "res://test/helpers/floor_mess_case.gd"


func test_the_room_floors_are_where_dirt_can_be_and_furniture_covers_cells():
	var game = _game()
	var m: FloorMess = game.floor_dirt.mess
	assert_eq(m.floor_cells.size(), game.plan.floors.size())
	var stove: Station = game.world.find_station("stove")
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
	var g: Guest = game.seating.spawn_guest(0)
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
	assert_almost_eq(game.seating.floor_speed(Grid.center(at)), 0.65, 0.001)



func test_a_guest_walks_slower_over_dirt():
	var walked := []
	for lvl in [0, 4]:
		var game = _game()
		var g: Guest = game.seating.spawn_guest(0)
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
	var fryer: Station = game.world.add_station("fryer", Vector2i(2, 5))
	var chef: Vector2i = fryer.cell + Vector2i(1, 0)
	var landed = game.floor_dirt.prep_grease("fry", "bad", chef, fryer)
	assert_not_null(landed, "fry 0.5, doubled for a bad one")
	assert_true(landed == chef or (landed - fryer.cell).length_squared() == 1)
	assert_false(game.floor_dirt.mess.is_covered(landed))



func test_tool_mess_and_the_hood_come_from_the_kitchen():
	var game = _game()
	var stove: Station = game.stations[Vector2i(0, 3)]
	assert_eq(game.floor_dirt.grease_factors(stove), {"mess": 1.0, "hood": "hood"}, "the start's hood hangs over it (PRD 8.5)")
	game.menu_stock.clear_walls()
	assert_eq(game.floor_dirt.grease_factors(stove), {"mess": 1.0, "hood": ""})



func test_a_hood_cuts_a_stoves_grease():
	var game = _game()
	var stove: Station = game.stations[Vector2i(0, 3)]
	var before: int = game.floor_dirt.mess.total()
	for i in 40:
		game.prep_games._prep_done(0, stove, "fry", "bad")   # certain without a hood (the test below)
	var hooded: int = game.floor_dirt.mess.total() - before
	assert_lt(hooded, 30, "a hood drops grease about %d%% as often" % int(FloorMess.HOOD * 100))



func test_a_finished_prep_rolls_grease_through_the_game():
	var game = _game()
	game.menu_stock.clear_walls()   # no hood over the stove
	var stove: Station = game.world.find_station("stove")
	var before: int = game.floor_dirt.mess.total()
	for i in 40:
		game.prep_games._prep_done(0, stove, "fry", "bad")   # a certain drop each time
	assert_eq(game.floor_dirt.mess.total(), before + 40)



func test_greasy_food_is_fried_or_meat():
	var t := Tray.new()
	assert_false(FloorDirt.greasy(null))
	assert_false(FloorDirt.greasy(t))
	t.lines.append({"item": {"ingredients": ["patty"]}, "have": []})
	assert_true(FloorDirt.greasy(t) == Pantry.tags_of("patty").has("meat"))



func test_guest_mess_lands_near_the_seat_and_never_under_furniture():
	var game = _game()
	var g: Guest = game.seating.spawn_guest(0)
	g.seat = Vector2i(6, 4)
	var m: FloorMess = game.floor_dirt.mess
	for i in 60:
		var c = game.floor_dirt.meal_mess(g)
		if c != null and m.level(c) < 4:
			assert_true(maxi(absi(c.x - 6), absi(c.y - 4)) <= FloorMess.GUEST_RADIUS)
	assert_gt(m.total(), 0, "some meals leave mess")



func test_an_annoyed_guest_counts_as_more_annoyed():
	var game = _game()
	var g: Guest = game.seating.spawn_guest(0)
	var calm := FloorDirt.annoyance(g)
	g.mood.patience = 0.0
	g.mood.disgust = 0.8
	assert_gt(FloorDirt.annoyance(g), calm)



func test_a_seated_guest_is_put_off_by_dirt_they_can_see():
	var game = _game()
	var g: Guest = game.seating.spawn_guest(0)
	g.cell = Vector2i(6, 4)
	_dirty(game, Vector2i(8, 4), 2)   # a puddle: seen, no smell
	assert_true(game.floor_dirt.disgust(g, 1.0, game.SIGHT_RANGE))
	assert_gt(g.mood.disgust, 0.0)



func test_from_level_three_dirt_smells_even_out_of_sight():
	var game = _game()
	var g: Guest = game.seating.spawn_guest(0)
	g.cell = Vector2i(6, 4)
	_dirty(game, Vector2i(7, 4), 2)
	game.floor_dirt.disgust(g, 1.0, 0)   # sees nothing
	assert_eq(g.mood.disgust, 0.0, "a puddle out of sight does not smell")
	_dirty(game, Vector2i(7, 4), 1)
	game.floor_dirt.disgust(g, 1.0, 0)
	assert_gt(g.mood.disgust, 0.0, "a big puddle smells")



func test_the_critic_marks_cleanliness_down_for_a_filthy_floor():
	var game = _game()
	var g: Guest = game.seating.spawn_guest(0)
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
	game.day._end_day()
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
	game.coop.act(0, "use")
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
	game.coop.act(0, "use")   # nothing: they are on the floor
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
	game.day._end_day()
	assert_false(game.floor_dirt.is_down(game.player))
