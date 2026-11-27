extends "res://test/helpers/floor_mess_case.gd"


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
	assert_true(CleanTools.fits("store", "sponge"))
	assert_false(CleanTools.fits("store", "mop"))
	for piece in ["shelf", "wide_shelf", "cabinet"]:
		assert_eq(CleanTools.home_kind(piece), "store", piece)
	assert_eq(CleanTools.home_kind("hook"), "", "no wall hooks any more")
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



func test_the_shop_sells_the_cleaning_pieces():
	for id in ["mop_bucket", "sponge", "robot_dock"]:
		assert_eq(Catalog.ITEMS[id].category, "Kitchen", id)
		assert_true(Catalog.sold_in(id, "diner") and Catalog.sold_in(id, "seaside"), id)
	assert_eq(Catalog.price_of("mop_bucket"), 35, "the sponge's whole way up to it")
	assert_eq(Catalog.price_of("sponge"), 15)
	assert_eq(Catalog.price_of("robot_dock"), 315)
	assert_false(Catalog.ITEMS.has("hook"), "no wall hook for sale")
	assert_false(Kitchen.NODES.has("hook"))
	assert_false(Catalog.TOOLS_TAB.has("hook"))
	assert_false("hook" in Catalog.ITEMS.sponge.blurb.to_lower(), "the sponge's blurb has no hook")



func test_e_takes_the_mop_from_its_bucket_and_puts_it_back_rinsed():
	var game = _game()
	var c := Vector2i(7, 2)
	var b := _bucket(game, c + Vector2i(-1, 0))
	assert_eq(b.kit_tool, "mop", "a bucket comes with its mop")
	_stand(game, c, Vector2i(-1, 0))
	assert_eq(game.cooking.use_station(b, true), "Take mop")
	game.coop.act(0, "use")
	assert_eq(game.player.held, "tool:mop")
	assert_eq(b.kit_tool, "")
	game.player.set_held("tool:mop", CleanTools.cleanness("mop", 3))
	assert_eq(game.cooking.use_station(b, true), "Put mop back")
	game.coop.act(0, "use")
	assert_eq(game.player.held, "")
	assert_eq(b.kit_tool, "mop")
	assert_eq(b.kit_used, 0, "the bucket rinses it")



func test_hands_are_full_while_holding_a_tool():
	var game = _game()
	CleanKit.hold(game.player, "mop", 0)
	for st: Station in game.stations.values():
		assert_eq(game.cooking.use_station(st, true), "", "nothing at the %s" % st.type)



func test_e_at_a_dirty_cell_in_front_clears_a_level_and_held_e_repeats():
	var game = _game()
	var front := _stand(game, Vector2i(7, 2))
	for i in 3:
		game.floor_dirt.mess.add_dirt(front)
	CleanKit.hold(game.player, "mop", 0)
	assert_eq(game.clean_kit.floor_action(game.player), "Mop")
	game.coop.act(0, "use")
	assert_eq(game.floor_dirt.mess.level(front), 2)
	game.coop.act(0, "use")
	assert_eq(game.floor_dirt.mess.level(front), 2, "a press takes 0.6 s")
	game.clean_kit.tick(0.61)
	game.clean_kit.hold_use(game.player, true)
	assert_eq(game.floor_dirt.mess.level(front), 1, "held E goes again")
	game.clean_kit.tick(0.3)
	game.clean_kit.hold_use(game.player, true)
	assert_eq(game.floor_dirt.mess.level(front), 1)
	assert_eq(CleanKit.held_used(game.player), 2)



func test_held_e_with_bare_hands_scrubs_slower_than_a_tool():
	var game = _game()
	var front := _stand(game, Vector2i(7, 2))
	for i in 2:
		game.floor_dirt.mess.add_dirt(front)
	assert_null(game.world.station_at(game.player.target_cell()), "nothing stands in front")
	assert_eq(game.clean_kit.floor_action(game.player), "Hold to scrub")
	game.coop.act(0, "use")
	assert_eq(game.floor_dirt.mess.level(front), 2, "a tap by hand does nothing yet")
	game.clean_kit.hold_use(game.player, true, CleanTools.HAND_TIME * 0.6)
	assert_eq(game.floor_dirt.mess.level(front), 2)
	assert_string_starts_with(game.clean_kit.floor_action(game.player), "Scrubbing")
	game.clean_kit.hold_use(game.player, true, CleanTools.HAND_TIME * 0.5)
	assert_eq(game.floor_dirt.mess.level(front), 1, "held long enough, a level comes off")
	game.clean_kit.hold_use(game.player, false, 0.1)
	game.clean_kit.hold_use(game.player, true, CleanTools.HAND_TIME * 2)
	assert_eq(game.floor_dirt.mess.level(front), 1, "letting go stops the scrub: E starts it again")
	for t: Dictionary in CleanTools.TOOLS.values():
		assert_lt(float(t.time), CleanTools.HAND_TIME, "%s is faster than hands" % t.name)



func test_dirty_cells_send_motes_up_more_when_dirtier():
	var low := FloorDirt.cell_look(Vector2i(5, 5), 1, Vector2i.ZERO)
	var high := FloorDirt.cell_look(Vector2i(5, 5), 4, Vector2i.ZERO)
	var a: CPUParticles3D = low.get_node("motes")
	var b: CPUParticles3D = high.get_node("motes")
	assert_lt(a.amount, b.amount)
	assert_gt(a.initial_velocity_min * a.lifetime, 1.2, "they rise over a counter")
	low.free()
	high.free()



func test_a_dirty_mop_is_slow_until_rinsed_at_a_sink():
	var game = _game()
	var front := _stand(game, Vector2i(7, 2))
	game.floor_dirt.mess.add_dirt(front)
	CleanKit.hold(game.player, "mop", 4)
	assert_string_contains(game.clean_kit.floor_action(game.player), "slow")
	var before: int = game.floor_dirt.mess.total()
	game.coop.act(0, "use")
	assert_eq(game.floor_dirt.mess.total(), before - 1, "it still mops")
	var sink: Station = game.world.find_station("sink")
	assert_eq(game.cooking.use_station(sink, true), "Rinse mop")
	game.cooking.use_station(sink)
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
	game.coop.act(0, "use")
	assert_eq(game.floor_dirt.mess.level(front), 0)
	assert_eq(game.player.held, "tool:mop")



func test_a_sponge_is_kept_on_a_shelf():
	var game = _game()
	var w := _wall_cell(game)
	assert_ne(w, Vector2i(-99, -99), "the test needs a free wall cell")
	var h: Station = game.clean_kit.shelve(w, "sponge")
	assert_eq(h.kit_tool, "sponge")
	assert_null(game.clean_kit.home_at(w, game.player), "a shelf is reached, not walked up to")
	game.player.set_meta("reach", true)   # holding Reach
	assert_eq(game.clean_kit.home_at(w, game.player), h)
	assert_eq(game.cooking.use_station(h, true), "Take sponge")
	game.cooking.use_station(h)
	assert_eq(game.player.held, "tool:sponge")
	CleanKit.hold(game.player, "mop", 0)
	assert_eq(game.cooking.use_station(h, true), "", "a mop is not kept on a shelf")
	CleanKit.hold(game.player, "sponge", 2)
	game.cooking.use_station(h)
	assert_eq(h.kit_tool, "sponge")
	assert_eq(h.kit_used, 2, "a shelf does not rinse")


func test_a_shelf_keeping_a_sponge_moves_with_it_at_night():
	var game = _game()
	game.arrivals.clear()
	game.step(0.1)
	game.session.open_build()
	game.step(0.01)
	var w := _wall_cell(game)
	var h: Station = game.clean_kit.shelve(w, "sponge")
	h.kit_used = 1
	assert_true(game.placing.pick_up(Grid.center(w), null, false, "high"))
	assert_false(game.highs.has(w), "the old wall cell is empty")
	assert_eq(game.kitchen.tool_at(w), "", "the kitchen no longer counts the tool there")
	var to := Vector2i(-99, -99)
	for c: Vector2i in game.kitchen.wall_cells:
		if c != w and not game.stations.has(c) and not game.highs.has(c) and game.kitchen.can_hang(c, "shelf"):
			to = c
			break
	assert_true(game.placing.place(Vector3i(to.x, to.y, 0)))
	var moved: Station = game.highs[to]
	assert_eq(moved.kit_tool, "sponge")
	assert_eq(moved.kit_used, 1)
	assert_eq(game.kitchen.tool_at(to), "sponge")


func test_a_tool_put_down_elsewhere_lies_in_the_way():
	var game = _game()
	var front := _stand(game, Vector2i(7, 2))
	CleanKit.hold(game.player, "scourer", 1)
	assert_eq(game.clean_kit.floor_action(game.player), "Put scourer down")
	game.coop.act(0, "use")
	assert_eq(game.player.held, "")
	assert_true(game.clean_kit.lying.has(front))
	game.step(0.01)
	assert_almost_eq(game.seating.floor_speed(Grid.center(front)), FloorMess.speed_of(2), 0.001, "in the way")
	assert_eq(game.clean_kit.floor_action(game.player), "Pick up scourer")
	game.coop.act(0, "use")
	assert_eq(game.player.held, "tool:scourer")
	assert_eq(CleanKit.held_used(game.player), 1, "as dirty as it was")
	assert_false(game.clean_kit.lying.has(front))



func test_at_night_moving_furniture_uncovers_dirt_to_mop():
	var game = _game()
	var table: Station = game.stations[Vector2i(6, 5)]
	var under := table.cell
	game.floor_dirt.mess.add_dirt(under)
	game.arrivals.clear()
	game.step(0.1)
	game.session.open_build()
	game.step(0.01)
	_stand(game, under + Vector2i(0, -1))
	CleanKit.hold(game.player, "mop", 0)
	assert_false(game.floor_dirt.mess.can_clean(under), "covered while the table stands there")
	game.room_edit.build_interact()
	assert_eq(game.floor_dirt.mess.level(under), 1)
	assert_true(game.player.hand.is_empty(), "hands full: the table is not picked up with a mop in them")
	assert_false(game.placing.pick_up(Grid.center(under)))
	game.player.set_held("")
	assert_true(game.placing.pick_up(Grid.center(under)))
	game.step(0.01)
	assert_true(game.floor_dirt.mess.can_clean(under))
	game.player.hand = {}   # the table set aside for the test
	CleanKit.hold(game.player, "mop", 0)
	assert_eq(game.room_edit._kit_action(game.player), "Mop")
	game.room_edit.build_interact()
	assert_eq(game.floor_dirt.mess.level(under), 0)



func test_the_robot_drifts_to_dirt_cleans_it_slowly_and_docks():
	var game = _game()
	var dock: Station = game.world.add_station("robot_dock", Vector2i(7, 2))
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
	var dock: Station = game.world.add_station("robot_dock", Vector2i(7, 2))
	game.floor_dirt.mess.add_dirt(Vector2i(7, 5))
	for i in 30:
		game.step(0.05)
	assert_false(game.clean_kit.is_docked(dock))
	game.day._end_day()
	assert_true(game.clean_kit.is_docked(dock))



func test_bought_at_night_a_sponge_goes_into_the_hands_and_a_bucket_holds_a_mop():
	var game = _game()
	game.arrivals.clear()
	game.step(0.1)
	game.session.open_build()
	game.ledger.money = 200
	assert_true(game.placing.pick_catalog("sponge"))
	assert_eq(CleanKit.held_tool(game.player), "sponge", "a tool in hand, not a placed piece")
	assert_true(game.player.hand.is_empty())
	assert_eq(game.ledger.money, 185)
	CleanKit.hold(game.player, "sponge", 0)
	game.player.set_held("")
	var spot := Vector2i(7, 2)
	assert_true(game.placing.pick_catalog("mop_bucket"))
	assert_true(game.placing.place(Vector3i(spot.x, spot.y, 0)))
	assert_eq((game.stations[spot] as Station).kit_tool, "mop")
	assert_eq(game.ledger.money, 200 - 15 - 35)


func test_only_the_sponge_is_counter_only_and_speeds_the_wash():
	assert_true(CleanTools.counter_only("sponge"))
	for t in ["scourer", "grease_scraper", "spill_kit", "mop"]:
		assert_false(CleanTools.counter_only(t), t)
	assert_eq(CleanTools.wash_factor(true), CleanTools.SPONGE_WASH)
	assert_eq(CleanTools.wash_factor(false), 1.0)
