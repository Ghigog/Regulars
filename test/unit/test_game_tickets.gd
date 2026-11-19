extends "res://test/helpers/game_case.gd"


# ---------- Tickets, plates and cups (PRD 1) ----------

func test_a_one_item_order_goes_from_ticket_to_paid_bill():
	var g := _ordered_guest()
	var rail: int = game.hud.ticket_rail.get_child_count()   # the order column
	assert_eq(rail, 1, "the ticket is in the order column")
	_cook_burger()
	assert_string_contains(game.cooking.prompt_for(g.table), "Serve")
	game.cooking.use_station(g.table)
	var before: int = game.ledger.money
	_eat_and_pay(g)
	assert_eq(game.ledger.money - before - int(game.ledger.today.tips), 8, "the slip's total, paid as written")



func test_a_three_item_order_is_one_bill():
	game.world.add_station("fountain", Vector2i(2, 5))
	game.world.add_station("cups", Vector2i(1, 6))
	var side: Dictionary = game.menu.add("side", ["bun"], "Bread")
	var drink: Dictionary = game.menu.add("drink", ["soda"], "Soda")
	game.town.people[0].likes = ["bun", "soda"]
	var g := _ordered_guest()
	assert_eq(g.order.side.id, side.id, "a liked side is added")
	assert_eq(g.order.drink.id, drink.id, "and a liked drink")
	# The side and the drink first, one in each hand: a bun put down and plated, a cup poured.
	game.cooking.use_station(game.menu_stock.storage_of("bun"))
	game.cooking.use_station(_the_pass())
	_use("plates")
	assert_eq(game.cooking.use_station(_the_pass()), "Plate it", "a bun alone is the side")
	assert_eq(game.cooking.use_station(_the_pass()), "Pick up")
	_use("cups")
	_pour(game.world.find_station("fountain"), Prep.POUR_GOOD + 0.05)
	assert_eq(game.player.dishes.size(), 2)
	assert_eq(game.cooking.use_station(g.table), "Serve %s" % g.info.name)
	assert_eq(g.state, "waiting", "the main is still to come")
	assert_eq(game.player.held, "")
	assert_eq(game.serving.tray_for_ticket(int(g.order.ticket)).served_count(), 2)
	_cook_burger()
	game.cooking.use_station(g.table)
	assert_eq(g.state, "eating")
	_eat_and_pay(g)
	assert_eq(int(game.ledger.today.sales), 13, "one bill for the whole order, as the slip says")
	assert_eq(g.table.dirty, 3, "two plates and a cup left behind")
	assert_eq(g.table.dirty_cups, 1)



func test_food_only_combines_into_what_the_menu_makes():
	game.player.set_held("prep:patty", 1.0)
	game.cooking.use_station(_the_pass())
	game.player.set_held("prep:cheese", 1.0)
	assert_eq(game.cooking.use_station(_the_pass()), "Nothing on the menu has patty with cheese")
	assert_eq(game.player.held, "prep:cheese", "kept in hand")
	game.player.set_held("prep:bun", 1.0)
	assert_eq(game.cooking.use_station(_the_pass()), "Add bun")
	game.player.set_held("prep:bun", 1.0)
	assert_eq(game.cooking.use_station(_the_pass()), "One bun is enough")
	game.player.set_held("burnt:patty")
	assert_eq(game.cooking.use_station(_the_pass()), "That's burnt. Bin it")



func test_a_half_made_plate_says_what_it_needs():
	var g := _ordered_guest()
	game.cooking.use_station(game.menu_stock.storage_of("bun"))
	game.cooking.use_station(_the_pass())
	_use("plates")
	game.cooking.use_station(_the_pass())
	game.cooking.use_station(_the_pass())
	assert_eq(game.cooking.use_station(g.table), "Needs patty")
	assert_eq(g.state, "waiting")



func test_turn_switches_a_two_tap_fountain():
	var tap: Station = game.world.add_station("two_tap_fountain", Vector2i(2, 5))
	var taps: Array[String] = game.menu_stock.dispenser_drinks(tap)
	assert_eq(taps.size(), 2)
	game.player.position = Grid.center(Vector2i(2, 4))
	game.player.look(Vector2i(0, 1))
	game.coop.act(0, "turn")
	assert_eq(tap.tap, 1, "Turn moves it on")
	game.coop.act(0, "turn")
	assert_eq(tap.tap, 0, "and round again")



func test_a_ticket_is_torn_off_when_its_guest_walks_out():
	game.world.add_station("cups", Vector2i(1, 6))
	game.world.add_station("fountain", Vector2i(2, 5))
	game.menu.add("drink", ["soda"], "Soda")
	game.town.people[0].likes = ["soda"]
	var g := _ordered_guest()
	_use("cups")
	_pour(game.world.find_station("fountain"), Prep.POUR_GOOD + 0.05)
	game.cooking.use_station(g.table)
	assert_eq(game.serving.tray_for_ticket(int(g.order.ticket)).served_count(), 1, "the drink is served first")
	var table: Station = g.table
	g.mood.patience = 0.0
	_run(0.5)
	assert_eq(game.tickets.size(), 0)
	assert_eq(table.dirty, 1, "the drink they left is a dirty cup")
	assert_eq(table.dirty_cups, 1)



func test_a_guest_who_finds_no_main_keeps_friends_company():
	game.town.people[1].dislikes = ["patty"]
	var pair: Array[Guest] = game.seating.spawn_group([0, 1])
	_run(14.0)
	game.cooking.use_station(pair[0].table)
	assert_eq(pair[0].state, "waiting")
	assert_eq(pair[1].state, "company", "nothing they would eat, and no drink on the menu")
	assert_eq(game.tickets.size(), 1)
	_cook_burger()
	game.cooking.use_station(pair[0].table)
	_eat_and_pay(pair[0])
	assert_eq(pair[1].state, "leaving", "they go with their friend")
	assert_eq(game.ledger.strikes(), 0)



func test_chopping_all_three_on_the_notch_is_good_and_speeds_the_chef():
	var board := _tool("board", Vector2i(2, 5), "crate_lettuce")
	game.cooking.use_station(game.menu_stock.storage_of("lettuce"))
	assert_eq(game.player.held, "raw:lettuce")
	assert_eq(game.cooking.use_station(board), "Chop")
	assert_eq(game.player.held, "", "the lettuce goes on the board")
	assert_false(game.prep_games.prep_of(0).is_empty())
	_chop(3)
	assert_true(game.prep_games.prep_of(0).is_empty(), "the minigame is over")
	assert_eq(game.player.held, "prep:lettuce")
	assert_eq(game.player.held_quality, Prep.GOOD)
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.BURST_SPEED, 0.01, "a good result is a burst")
	_run(Prep.BOOST_TIME + 0.1)
	assert_eq(game.player.speed(), Player.SPEED, "for one second")



func test_a_bad_chop_slows_the_chef_and_a_plain_one_does_neither():
	var board := _tool("board", Vector2i(2, 5), "crate_onion")
	game.cooking.use_station(game.menu_stock.storage_of("onion"))
	game.cooking.use_station(board)
	_chop(0)
	assert_eq(game.player.held_quality, Prep.BAD)
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.PENALTY_SPEED, 0.01, "a bad result slows")
	_run(Prep.BOOST_TIME + 0.1)
	assert_eq(game.player.speed(), Player.SPEED)
	game.player.set_held("")
	game.cooking.use_station(game.menu_stock.storage_of("onion"))
	game.cooking.use_station(board)
	_chop(2)
	assert_eq(game.player.held_quality, Prep.PLAIN)
	assert_eq(game.player.speed(), Player.SPEED, "plain does neither")



func test_the_chef_stands_still_and_back_gives_the_ingredient_back_raw():
	var board := _tool("board", Vector2i(2, 5), "crate_tomato")
	game.cooking.use_station(game.menu_stock.storage_of("tomato"))
	game.cooking.use_station(board)
	var at: Vector3 = game.player.position
	_axis(JOY_AXIS_LEFT_X, 1.0)
	for i in 4:
		game._process(0.05)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	assert_eq(game.player.position, at, "no walking off mid-chop")
	game.coop.act(0, "back")
	assert_true(game.prep_games.prep_of(0).is_empty())
	assert_eq(game.player.held, "raw:tomato")
	assert_eq(board.item, "")



func test_slicing_to_the_count_is_good_and_over_it_is_plain():
	var slicer := _tool("slicer", Vector2i(2, 5), "crate_cheese")
	for presses: int in [Prep.SLICE_COUNT, Prep.SLICE_COUNT + 2, Prep.SLICE_COUNT - 1]:
		game.player.set_held("")
		game.cooking.use_station(game.menu_stock.storage_of("cheese"))
		assert_eq(game.cooking.use_station(slicer), "Slice")
		for k in presses:
			game.coop.act(0, "use")
			game.step(0.05)
		_run(Prep.slice_time(slicer.q("slice")))   # a slicer is a specialist: more time (PRD 8.3)
		assert_eq(game.player.held, "prep:cheese")
		assert_eq(game.player.held_quality, {Prep.SLICE_COUNT: Prep.GOOD, Prep.SLICE_COUNT + 2: Prep.PLAIN}.get(presses, Prep.BAD), "%d presses" % presses)



func test_a_tool_refuses_what_it_does_not_prep():
	var board := _tool("board", Vector2i(2, 5), "crate_patty")
	game.cooking.use_station(game.menu_stock.storage_of("patty"))
	assert_eq(game.cooking.use_station(board, true), "Put down", "a thing the tool cannot use rests on its surface")
	board.set_item(Tray.kind("prep", "lettuce"))
	assert_eq(game.cooking.use_station(board, true), "Patty doesn't go on the chopping board", "the surface is taken")



func test_pouring_into_the_top_band_is_good_and_overflowing_is_bad():
	var fountain: Station = game.world.add_station("fountain", Vector2i(2, 5))
	var cups: Station = game.world.add_station("cups", Vector2i(1, 6))
	game.menu.add("drink", ["soda"], "Soda")
	for row: Array in [[0.9, Prep.GOOD], [0.7, Prep.PLAIN], [2.0, Prep.BAD]]:   # 2.0: never let go, it overflows
		game.player.set_held("")
		game.cooking.use_station(cups)
		_pour(fountain, row[0])
		assert_eq(game.player.held, "dishes")
		assert_eq(game.player.dishes[0].qs[0], row[1])



func test_fries_rest_on_the_rack_before_they_can_be_picked_up():
	var fryer := _tool("fryer", Vector2i(2, 5), "crate_potato")
	game.cooking.use_station(game.menu_stock.storage_of("potato"))
	assert_eq(game.cooking.use_station(fryer), "Fry")
	_run(Prep.FRY_GOOD + 0.5)
	assert_eq(game.cooking.use_station(fryer), "Lift basket")
	assert_eq(game.player.held, "", "lifted onto the rack, not into the hands")
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.BURST_SPEED, 0.01, "lifted in the window")
	assert_eq(game.cooking.use_station(fryer, true), "Still draining")
	_run(Prep.FRY_REST + 0.1)
	assert_eq(game.cooking.use_station(fryer), "Pick up")
	assert_eq(game.player.held, "prep:potato")
	assert_eq(game.player.held_quality, Prep.GOOD)



func test_fries_left_in_burn_and_slow_the_chef():
	var fryer := _tool("fryer", Vector2i(2, 5), "crate_potato")
	game.cooking.use_station(game.menu_stock.storage_of("potato"))
	game.cooking.use_station(fryer)
	_run(Prep.heat_times("fry", fryer.q("fry"))[3] + 0.5)   # a fryer is a specialist: slower to burn
	game.cooking.use_station(fryer)
	assert_eq(game.player.held, "burnt:potato")
	game.floor_dirt.mess.dirt.clear()   # a bad fry may drop grease, which slows the chef too (PRD 9)
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.PENALTY_SPEED, 0.01)



func test_boiling_waits_when_done_and_never_gives_a_burst():
	var pot := _tool("pot", Vector2i(2, 5), "crate_corn")
	game.cooking.use_station(game.menu_stock.storage_of("corn"))
	assert_eq(game.cooking.use_station(pot), "Boil")
	assert_eq(game.cooking.use_station(pot, true), "Still boiling")
	_run(Prep.BOIL_TIME + 20.0)
	assert_eq(game.cooking.use_station(pot), "Take out")
	assert_eq(game.player.held, "prep:corn")
	assert_eq(game.player.held_quality, Prep.PLAIN)
	assert_eq(game.player.speed(), Player.SPEED)



func test_a_good_grill_gives_a_burst():
	game.cooking.use_station(game.menu_stock.storage_of("patty"))
	_use("stove")
	_run(Prep.GRILL_DONE + 0.5)
	_use("stove")
	assert_eq(game.player.held_quality, Prep.GOOD)
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.BURST_SPEED, 0.01)
