extends "res://test/helpers/game_case.gd"


func test_a_bun_on_a_cooked_patty_is_plated():
	_ordered_guest()
	assert_eq(game.tickets.size(), 1, "taking the order puts a ticket on the rail")
	game.cooking.use_station(game.menu_stock.storage_of("patty"))
	_use("stove")
	_run(Station.COOK_TIME + 0.5)
	_use("stove")
	game.cooking.use_station(_the_pass())
	game.cooking.use_station(game.menu_stock.storage_of("bun"))
	assert_eq(game.cooking.use_station(_the_pass()), "Add bun", "a bun goes on a cooked patty")
	assert_eq(_the_pass().item, "dish")
	assert_eq(_the_pass().dish.vessel, "", "a loose stack, not yet plated")
	_use("dish_rack")
	assert_eq(game.player.held, "dishes")
	assert_eq(game.cooking.use_station(_the_pass(), true), "Plate it")
	game.cooking.use_station(_the_pass())
	assert_eq(game.player.dishes.size(), 0, "the plate went down under the burger")
	assert_eq(_the_pass().dish.vessel, Dish.PLATE)
	assert_true(_the_pass().dish.is_ready(game.menu.items))
	assert_eq(game.cooking.use_station(_the_pass()), "Pick up")
	assert_eq(game.player.dishes.size(), 1)
	assert_eq(game.world.find_station("dish_rack").count, Station.PLATES - 1)



func test_a_plate_on_the_pass_takes_food_in_any_order():
	_ordered_guest()
	_use("dish_rack")
	assert_eq(game.cooking.use_station(_the_pass()), "Put down")
	game.cooking.use_station(game.menu_stock.storage_of("bun"))
	assert_eq(game.cooking.use_station(_the_pass()), "Add bun")
	game.player.set_held("raw:patty")
	assert_eq(game.cooking.use_station(_the_pass()), "Patty needs grilling first")
	assert_eq(game.player.held, "raw:patty", "kept in hand")
	game.player.set_held("prep:patty", 1.0)
	assert_eq(game.cooking.use_station(_the_pass()), "Add patty")
	assert_true(_the_pass().dish.is_ready(game.menu.items))
	assert_eq(game.cooking.use_station(_the_pass()), "Pick up")
	assert_eq(game.player.held, "dishes")



func test_an_unplated_burger_is_not_served():
	var g := _ordered_guest()
	game.player.set_held("prep:patty", 1.0)
	game.cooking.use_station(_the_pass())
	game.player.set_held("prep:bun", 1.0)
	game.cooking.use_station(_the_pass())
	game.player.set_held("")
	assert_eq(game.cooking.use_station(_the_pass()), "Pick up", "a loose burger can be picked up")
	assert_eq(game.cooking.use_station(g.table), "Put it on a plate first")
	assert_eq(g.state, "waiting")



func test_two_plates_in_the_hands_four_on_a_tray():
	assert_eq(_use_says("dish_rack"), "Take plate")
	assert_eq(_use_says("dish_rack"), "Put back", "an empty plate in hand goes back")
	var full := func() -> Dish:
		var d := Dish.make(Dish.PLATE)
		d.add("prep:bun", 1.0)
		d.add("prep:patty", 1.0)
		return d
	game.player.set_held("dishes", 1.0, [full.call()])
	assert_eq(_use_says("dish_rack"), "Take plate", "a second plate beside a full one")
	game.player.set_held("dishes", 1.0, [full.call(), full.call()])
	assert_eq(_use_says("dish_rack"), "Your hands are full")
	var trays: Station = game.world.add_station("tray_stack", Vector2i(2, 5))
	assert_eq(game.cooking.use_station(trays), "Take tray")
	assert_true(game.player.on_tray)
	assert_eq(game.player.dishes.size(), 2, "the plates in hand go on the tray")
	game.player.set_held("dishes", 1.0, [full.call(), full.call(), full.call()], true)
	assert_eq(_use_says("dish_rack"), "Take plate")
	assert_eq(game.player.dishes.size(), 4)
	assert_eq(_use_says("dish_rack"), "Put back")
	assert_eq(game.cooking.use_station(trays, true), "Too much to hold without the tray")
	game.player.set_held("dishes", 1.0, [full.call(), full.call()], true)
	assert_eq(game.cooking.use_station(trays), "Put tray back")
	assert_false(game.player.on_tray)
	assert_eq(game.player.dishes.size(), 2)



func test_a_drink_needs_a_cup():
	var fountain: Station = game.world.add_station("fountain", Vector2i(2, 5))
	game.menu.add("drink", ["soda"], "Soda")
	assert_eq(game.cooking.use_station(fountain), "Bring a cup for the soda")
	game.player.set_held("dishes", 1.0, [Dish.make(Dish.PLATE)])
	assert_eq(game.cooking.use_station(fountain), "Bring a cup")
	var cups: Station = game.world.add_station("cups", Vector2i(1, 6))
	game.player.set_held("")
	assert_eq(game.cooking.use_station(cups), "Take cup")
	_pour(fountain, 0.9)
	var cup: Dish = game.player.dishes[0]
	assert_eq(cup.ings, ["soda"] as Array[String])
	assert_eq(cup.qs[0], Prep.GOOD)
	assert_true(cup.is_ready(game.menu.items))



func test_patty_left_on_stove_burns():
	game.cooking.use_station(game.menu_stock.storage_of("patty"))
	_use("stove")
	_run(Station.BURN_TIME + 1.0)
	assert_eq(game.world.find_station("stove").item, "burnt:patty")
	_use("stove")
	assert_true(game.player.carrying_something_gross())
	assert_eq(game.cooking.use_station(_the_pass()), "", "a burnt patty is not put down on the pass")



func test_guest_is_seated_served_and_pays():
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	assert_eq(g.state, "ordering")
	_order(g)
	assert_eq(g.state, "waiting")
	_cook_burger()
	game.cooking.use_station(g.table)
	assert_eq(g.state, "eating")
	assert_eq(game.player.held, "")
	var table: Station = g.table
	_eat_and_pay(g)
	assert_eq(g.bill_base, 8, "the Burger: bun 2 and patty 6")
	assert_gt(game.ledger.money, 50 + g.mood.scaled_price(g.bill_base) - 1)
	assert_eq(table.dirty, 1, "a dirty plate is left behind")
	assert_eq(game.tickets.size(), 0, "the ticket is done")
	assert_gt(float(game.town.people[0].affinity), 0.0, "a good visit makes them like the place")



func test_half_price_calms_an_impatient_guest_and_costs_half_the_bill():
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	_order(g)
	assert_eq(game.cooking.prompt_for(g.table), "", "no discount for a guest who is still happy to wait")
	g.mood.patience = 0.3
	assert_string_contains(game.cooking.prompt_for(g.table), "half price")
	game.cooking.use_station(g.table)
	assert_false(g.mood.discounted, "one press gives nothing away")
	game.serving._tick_deal(game.player, false, 0.1)
	assert_false(g.mood.discounted, "let go early: nothing")
	_deal(g)
	assert_gt(g.mood.patience, 0.6)
	assert_gt(float(game.town.people[0].affinity), 0.0, "kindness is remembered")
	assert_eq(game.cooking.prompt_for(g.table), "", "only once")
	_cook_burger()
	game.cooking.use_station(g.table)
	_eat_and_pay(g)
	assert_eq(int(game.ledger.today.sales), ceili(g.bill_base / 2.0), "half of the slip's total: what the slip says, less the deal")



func test_free_meal_follows_half_price_for_a_guest_still_fed_up():
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	_order(g)
	g.mood.patience = 0.2
	assert_string_contains(game.cooking.prompt_for(g.table), "half price", "the smaller apology comes first")
	_deal(g)
	assert_eq(game.cooking.prompt_for(g.table), "", "half price calmed them for now")
	g.mood.patience = 0.1
	assert_string_contains(game.cooking.prompt_for(g.table), "free meal")
	_deal(g)
	assert_true(g.mood.comped)
	assert_eq(game.cooking.prompt_for(g.table), "", "only once")
	assert_true(g.mood.thoughts.has("On the house? That's really kind"))
	_cook_burger()
	game.cooking.use_station(g.table)
	_eat_and_pay(g)
	assert_eq(int(game.ledger.today.sales), 0)



func test_a_disgusted_guest_can_be_offered_a_free_meal_straight_away():
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	_order(g)
	g.mood.disgust = 0.5
	assert_string_contains(game.cooking.prompt_for(g.table), "free meal")



func test_a_guest_who_expects_a_deal_is_let_down_by_full_price():
	game.town.people[0].deals = Town.EXPECT_AT
	var g: Guest = game.seating.spawn_guest(0)
	assert_true(g.mood.thoughts.has("They usually knock something off"))
	_run(12.0)
	_order(g)
	_cook_burger()
	game.cooking.use_station(g.table)
	_eat_and_pay(g)
	assert_true(g.mood.thoughts.has("Full price this time? Hm"))
	assert_eq(int(game.town.people[0].deals), Town.EXPECT_AT - 1)



func test_flyers_cost_money_once_a_night_and_are_used_up_next_day():
	assert_false(game.room_edit.buy_flyers(), "not during service")
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.phase, game.Phase.SUMMARY)
	assert_false(game.room_edit.buy_flyers(), "not on the receipt: they are in the shop")
	game.session.open_build()
	assert_true(game.room_edit.buy_flyers())
	assert_eq(game.ledger.money, 150 - Town.FLYER_PRICE)
	assert_false(game.room_edit.buy_flyers(), "one batch a night")
	game.day.start_day()
	assert_false(game.flyers_out)
	assert_eq(int(game.ledger.today.spent), Town.FLYER_PRICE)



func test_upgraded_piece_is_bought_from_the_catalog():
	_to_build()
	game.ledger.money = 100
	assert_false(game.placing.pick_catalog("plant", 2), "tier 2 needs level 2")
	game.ledger.xp = 100
	assert_true(game.placing.pick_catalog("plant", 2))
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_eq(game.stations[Vector2i(2, 5)].tier, 2)
	assert_eq(game.ledger.money, 60)
	assert_eq(int(game.hand.tier), 2, "still in hand while there is money for another")
	assert_true(game.placing.place(Vector3i(3, 4, 0)))
	assert_true(game.hand.is_empty(), "$20 left will not buy a third")



func test_shop_filters_as_you_search_and_browses_with_the_keys():
	_to_build()
	game.session.open_shop()
	assert_true(game.shopping)
	assert_eq(game.hud._category, "Furniture", "there is no All tab")
	var all: Array[Dictionary] = game.session.shop_items("", "Furniture")
	var kitchen: int = all.size()
	assert_eq(all.filter(func(bp: Dictionary) -> bool: return not bp.get("locked", false)).size(), kitchen,
		"only what can be bought tonight")
	assert_eq(game.hud._cards.get_child_count(), kitchen)
	game.hud.set_search("fern")
	var ferns: int = game.session.shop_items("fern").size()
	assert_gt(ferns, 0)
	assert_eq(game.hud._cards.get_child_count(), ferns, "a search looks through every category")
	game.hud.set_search("zzz")
	assert_eq(game.hud._cards.get_child_count(), 1, "only the nothing-matches line")
	game.hud._set_category("Furniture")
	assert_eq(game.hud._search, "", "picking a category ends the search")
	assert_eq(game.hud._cards.get_child_count(), kitchen)
	game.hud.shop_ui.shop_move(-1)
	assert_eq(game.hud._shop_index, kitchen - 1, "left from the first wraps to the last")
	game.hud.shop_ui.shop_category(1)
	assert_eq(game.hud._category, "Tools", "Furniture, Tools, Ingredients, Build")
	game.hud.shop_ui.shop_category(1)
	assert_eq(game.hud._category, "Ingredients", "boxes are bought here and put in a counter")
	game.session.close_shop()
	assert_null(game.hud._shop)
	game.day.start_day()
	assert_null(game.hud.build_bar)



func test_buying_in_the_shop_puts_the_piece_in_hand_and_shuts_it():
	_to_build()
	game.session.open_shop()
	assert_false(game.placing.buy({"id": "table4", "tier": 1}), "level 3 and $90")
	assert_true(game.shopping)
	assert_true(game.placing.buy({"id": "counter", "tier": 1}))
	assert_false(game.shopping)
	assert_eq(game.hand.id, "counter")
	game.session.open_shop()
	assert_true(game.placing.buy(game.FLYERS))
	assert_true(game.flyers_out)
	assert_true(game.shopping, "flyers are not carried, so the shop stays open")



func test_furniture_is_carried_and_put_down_in_front_of_the_chef():
	_to_build()
	game.player.position = Grid.center(Vector2i(8, 2))
	game.player.look(Vector2i(0, 1))            # facing the table at (8, 3)
	assert_eq(game.room_edit.build_action(), "Pick up")
	game.room_edit.build_interact()
	assert_eq(game.hand.id, "table", "E lifts it")
	assert_eq(game.room_edit.build_action(), "Put down")
	game.room_edit.build_interact()
	assert_true(game.hand.is_empty())
	assert_true(game.stations.has(Vector2i(8, 3)))
	game.player.position = Grid.center(Vector2i(9, 6))
	assert_eq(game.room_edit.build_action(), "", "nothing within reach and not at the door")



func test_a_carried_fern_shows_which_seats_it_would_reach():
	_to_build()
	assert_eq(game.decor.range_of("plant", 2), 4)
	assert_eq(game.decor.range_of("table"), 0)
	var seat: Vector2i = game.stations[Vector2i(8, 3)].seats[0]
	assert_eq(game.decor.seats_reached(seat + Vector2i(0, -1), 3)[seat], Decor.BESIDE)
	assert_eq(game.decor.seats_reached(seat - Vector2i(3, 0), 3)[seat], Decor.IN_VIEW)
	assert_eq(game.decor.seats_reached(seat - Vector2i(4, 0), 3)[seat], 0.0, "four cells is out of reach")
	assert_true(game.placing.pick_catalog("plant"))
	game.decor._update_range()
	assert_gt(game._range_marks.get_child_count(), 1, "the wash and a disc for every seat")
	game.placing.cancel_hand()
	game.decor._update_range()
	assert_eq(game._range_key, "")



func test_chef_is_pushed_clear_of_a_piece_put_down_too_close_or_on_top():
	_to_build()
	game.player.position = Vector3(2.5, 0, 3.9)          # hard against the edge of (2, 4)
	game.player.look(Vector2i(0, 1))
	assert_true(game.placing.pick_catalog("counter"))
	game.room_edit.build_interact()
	assert_true(game.stations.has(Vector2i(2, 4)))
	assert_true(game.player.stuck(), "overlapping the new counter")
	for i in 30:
		game.player.move(Vector2.ZERO, 0.016)
	assert_false(game.player.stuck())
	assert_eq(game.player.cell(), Vector2i(2, 3), "nudged back into the same cell")
	game.placing.cancel_hand()
	game.world.add_station("counter", Vector2i(2, 3))          # dropped right on top of the chef
	assert_true(game.player.stuck())
	for i in 60:
		game.player.move(Vector2.ZERO, 0.016)
	assert_false(game.player.stuck())
	assert_false(game.grid.is_blocked(game.player.cell()))



func test_game_opens_on_the_title_then_the_night_before_day_one():
	var fresh = load("res://game/main.tscn").instantiate()
	fresh.get_script()._title_seen = false   # as on a fresh launch
	add_child_autofree(fresh)
	fresh.set_process(false)
	fresh.theme_path = THEME_TEST_PATH
	assert_true(fresh.hud.options_ui.title_open(), "the title comes first")
	fresh.session.play()
	assert_true(fresh.hud.options_ui.title.themes_open, "Play turns the card over to the themes")
	fresh.session.choose_theme("diner")
	assert_eq(fresh.phase, fresh.Phase.BUILD)
	assert_false(fresh.door_open)
	assert_true(fresh.arrivals.is_empty())
	assert_true(fresh.placing.pick_catalog("counter"), "the room can be changed before anyone comes")
	fresh.placing.cancel_hand()
	fresh.player.position = Grid.center(Vector2i(9, 4))
	assert_eq(fresh.menu_stock.night_hint(), fresh.NIGHT_HINTS[1], "the starter kitchen is built: next, the menu")
	assert_not_null(fresh.world.find_station("stove"), "night zero starts with a stove")
	assert_not_null(fresh.menu_stock.storage_of(fresh.world.fixed_main().grill), "and a fridge with the grilled kind")
	assert_not_null(fresh.world.find_station("cups"), "and a cup stack")
	fresh.room_edit.build_interact()
	assert_eq(fresh.phase, fresh.Phase.BUILD, "no menu yet: the door card stays shut")
	assert_eq(fresh.hud.toast.text, fresh.NIGHT_ZERO_BLOCK)
	fresh.menu_stock.test_kitchen()
	assert_eq(fresh.menu_stock.night_hint(), fresh.NIGHT_HINTS[2])
	fresh.room_edit.build_interact()
	assert_eq(fresh.phase, fresh.Phase.SERVICE)
	assert_eq(fresh.ledger.money, 150 - fresh.menu_stock.night_cost(), "the stock was paid")
	assert_eq(fresh.ledger.day, 1)
	assert_false(fresh.arrivals.is_empty())



func test_flipping_the_door_card_opens_the_day():
	_to_build()
	assert_false(game.door_open, "the card says closed overnight")
	game.player.position = Grid.center(Vector2i(2, 3))
	assert_false(game.day.use_door(), "too far from the doorway")
	game.player.position = Grid.center(Vector2i(9, 4))
	game.player.look(Vector2i(1, 0))
	assert_eq(game.room_edit.build_action(), "Open up")
	game.room_edit.build_interact()
	assert_eq(game.phase, game.Phase.SERVICE)
	assert_true(game.door_open)



func test_closing_early_turns_new_guests_away_but_keeps_those_inside():
	game.seating.spawn_guest(0)
	game.player.position = Grid.center(Vector2i(9, 4))
	assert_eq(game.day.door_action(), "", "too early in the day")
	game.clock = game.day.day_length() * 0.6
	assert_false(game.arrivals.is_empty())
	assert_eq(game.day.door_action(), "Close early")
	assert_true(game.day.use_door())
	assert_true(game.arrivals.is_empty())
	assert_false(game.door_open)
	assert_eq(game.guests.size(), 1)
	_run(0.2)
	assert_eq(game.phase, game.Phase.SERVICE, "the day runs on until the last guest leaves")
	assert_eq(game.day.door_action(), "", "already closed")



func test_catalog_piece_is_paid_for_when_placed_and_gated_by_level():
	_to_build()
	assert_false(game.placing.pick_catalog("table4"), "level 3 and $90")
	assert_true(game.placing.pick_catalog("counter"))
	assert_eq(game.ledger.money, 150, "picking is free")
	assert_false(game.placing.place(Vector3i(9, 4, 0)), "that would block the doorway")
	assert_false(game.placing.place(Vector3i(0, 2, 0)), "a stove is already there")
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_eq(game.ledger.money, 135)
	assert_eq(game.stations[Vector2i(2, 5)].type, "counter")
	game.day.start_day()
	assert_eq(game.phase, game.Phase.SERVICE)
	assert_true(game.hand.is_empty())
	assert_false(game.placing.place(Vector3i(3, 4, 0)), "no building during service")



func test_partition_snaps_to_the_nearest_edge_and_hides_a_dirty_table():
	_to_build()
	assert_true(game.placing.pick_catalog("screen"))
	assert_eq(game.placing.snap(Vector3(5.9, 0, 3.5)), Vector3i(6, 3, 1))
	assert_eq(game.placing.snap(Vector3(5.5, 0, 3.1)), Vector3i(5, 3, 0))
	assert_true(game.placing.place(Vector3i(6, 3, 1)))
	assert_false(game.grid.has_los(Vector2i(5, 3), Vector2i(6, 3)))
	assert_eq(game.ledger.money, 140)



func test_moving_a_piece_is_free_and_cancel_puts_it_back():
	_to_build()
	var bin: Station = game.world.find_station("bin")
	assert_true(game.placing.pick_up(Vector3(0.5, 0, 5.5)))
	assert_false(game.stations.has(Vector2i(0, 5)))
	assert_false(game.grid.blocked.has(Vector2i(0, 5)))
	assert_false(game.placing.place(Vector3i(1, 0, 0)), "a stove is there")
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_eq(bin.cell, Vector2i(2, 5))
	assert_eq(game.stations[Vector2i(2, 5)], bin)
	assert_eq(game.ledger.money, 150)
	assert_true(game.placing.pick_up(Vector3(2.5, 0, 5.5)))
	game.placing.cancel_hand()
	assert_eq(bin.cell, Vector2i(2, 5), "back where it was picked up")
	assert_true(bin.visible)
	assert_false(game.placing.pick_up(Vector3(3.5, 0, 5.5)), "nothing there")



func test_carried_piece_goes_back_when_the_day_opens():
	_to_build()
	var crate: Station = game.menu_stock.storage_of("patty")
	assert_true(game.placing.pick_up(Vector3(0.5, 0, 2.5)))
	game.day.start_day()
	assert_eq(game.stations[Vector2i(0, 2)], crate)
	assert_true(crate.visible)



func test_turned_table_has_seats_above_and_below():
	_to_build()
	var table: Station = game.stations[Vector2i(8, 3)]
	assert_true(game.placing.pick_up(Vector3(8.5, 0, 3.5)))
	assert_false(game.grid.reserved.has(Vector2i(7, 3)), "its seats come up with it")
	game.placing.rotate_hand()
	assert_true(game.placing.place(Vector3i(8, 3, 0)))
	assert_eq(table.seats, [Vector2i(8, 2), Vector2i(8, 4)] as Array[Vector2i])
	assert_true(game.grid.reserved.has(Vector2i(8, 4)))
	game.day.start_day()
	var cells: Array = []
	var all: Array[Guest] = []
	for n in 3:
		all.append_array(game.seating.spawn_group([n * 2, n * 2 + 1]))
	_run(14.0)
	for g in all:
		cells.append(g.cell)
	assert_true(cells.has(Vector2i(8, 2)) and cells.has(Vector2i(8, 4)), "guests use the turned seats")



func test_selling_refunds_half_of_anything_the_last_stove_and_the_fixtures_too():
	_to_build()
	assert_true(game.placing.pick_up(Vector3(9.5, 0, 0.5)))        # the fern
	assert_eq(game.placing.sell_value(), 10)
	assert_true(game.placing.sell_hand())
	assert_eq(game.ledger.money, 160)
	assert_false(game.stations.has(Vector2i(9, 0)))
	assert_true(game.placing.pick_up(Vector3(2.5, 0, 2.5)))        # the tray stack
	assert_true(game.placing.sell_hand(), "the start's pieces sell too")
	assert_eq(game.ledger.money, 160 + Catalog.price_of("dish_rack") / 2)
	var stoves: Array = game.stations.values().filter(func(st: Station) -> bool: return st.type == "stove")
	assert_eq(stoves.size(), 2)
	var at: Vector3 = Grid.center(stoves[0].cell)
	game.highs.erase(stoves[0].cell)   # whatever hangs over it is not this test's
	assert_true(game.placing.pick_up(at))
	assert_eq(game.hand.id, "stove", "a stove, its counter with it")
	assert_eq(game.placing.sell_value(), (Kitchen.price_of("stove") + Kitchen.price_of("counter")) / 2, "a stove is its counter upgraded")
	assert_true(game.placing.sell_hand())
	assert_false(game.stations.has(stoves[0].cell), "no counter left behind")
	game.highs.erase(stoves[1].cell)
	assert_true(game.placing.pick_up(Grid.center(stoves[1].cell)))
	assert_true(game.placing.sell_hand(), "every station can be sold, even the last stove")
	assert_null(game.world.find_station("stove"))



func test_partition_can_be_picked_up_moved_and_sold():
	_to_build()
	assert_true(game.placing.pick_catalog("screen"))
	assert_true(game.placing.place(Vector3i(6, 3, 1)))
	game.placing.cancel_hand()
	assert_true(game.placing.pick_up(Vector3(6.05, 0, 3.5)))
	assert_false(game.grid.walls.has(Vector3i(6, 3, 1)))
	assert_true(game.placing.place(Vector3i(6, 4, 1)))
	assert_true(game.grid.walls.has(Vector3i(6, 4, 1)))
	game.ledger.day += 1   # a later night: no same-night return
	assert_true(game.placing.pick_up(Vector3(6.05, 0, 4.5)))
	assert_true(game.placing.sell_hand())
	assert_eq(game.ledger.money, 145)
	assert_false(game.placing.pick_up(Vector3(9.95, 0, 2.5)), "the entrance wall is not yours to move")



func test_new_table_seats_guests():
	_to_build()
	game.ledger.money = 100
	game.ledger.xp = 100
	assert_true(game.placing.pick_catalog("table"))
	assert_false(game.placing.place(Vector3i(9, 5, 0)), "no room for the right-hand seat")
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_true(game.grid.reserved.has(Vector2i(1, 5)))
	assert_eq(game.ledger.money, 60)



func _hold_wash(secs: float) -> void:
	var t := 0.0
	while t < secs:
		game.cooking._tick_wash(game.player, true, 0.1)
		t += 0.1


func _face_at(st: Station) -> void:
	game.player.position = st.position + Vector3(0, 0, 1)
	game.player.look(Vector2i(0, -1))


func test_washing_a_dirty_plate_is_a_hold_then_a_rack():
	var table: Station = game.stations[Vector2i(6, 1)]
	table.dirty = 3
	table.dirty_cups = 1
	assert_eq(game.cooking.use_station(table), "Clear plates")
	_use("sink")
	game.cooking.use_station(table)
	_use("sink")
	var sink: Station = game.world.find_station("sink")
	assert_eq(sink.dirty, 3, "they soak until washed")
	assert_eq(game.player.held, "")
	_face_at(sink)
	assert_eq(game.cooking.use_station(sink, true), "Wash")
	game.cooking.use_station(sink)
	_hold_wash(game.cooking.WASH_HOLD / 2.0)
	game.cooking._tick_wash(game.player, false, 0.1)
	assert_eq(sink.dirty, 3, "letting go cancels")
	game.cooking.use_station(sink)
	_hold_wash(game.cooking.WASH_HOLD + 0.2)
	assert_eq(sink.dirty, 2, "one dish a hold")
	assert_eq(game.player.held, "dishes")
	assert_eq(game.player.dishes.size(), 1)
	var rack: Station = game.world.find_station("dish_rack")
	rack.count = Station.RACK_CAPACITY - 1
	assert_eq(game.cooking.use_station(rack), "Put back")
	assert_eq(rack.count, Station.RACK_CAPACITY)
	game.cooking.use_station(sink)
	_hold_wash(game.cooking.WASH_HOLD + 0.2)
	assert_eq(game.cooking.use_station(rack, true), "The rack is full")
	game.cooking.use_station(rack)
	assert_eq(rack.count, Station.RACK_CAPACITY, "a ninth is refused")
	assert_eq(game.player.held, "dishes", "the plate stays in hand")
	game.player.dishes.clear()
	game.player.set_held("", 1.0, [], false)
	assert_eq(game.cooking.use_station(rack), "Take plate")
	assert_eq(rack.count, Station.RACK_CAPACITY - 1)
	assert_eq(game.player.held, "dishes")


func test_a_new_kitchen_has_a_dish_rack_with_plates_and_no_plate_stack():
	var rack: Station = game.world.find_station("dish_rack")
	assert_eq(rack.cell, Vector2i(2, 2))
	assert_eq(rack.count, Station.PLATES)
	assert_true(game.world.find_station("sink").racked, "the sink counts as racked")
	assert_false(Catalog.ITEMS.has("plates"), "no plate stack to buy")
	assert_false("plates" in Catalog.TOOLS_TAB)


func test_the_rack_refuses_a_cup_and_an_empty_rack_says_to_wash_up():
	var rack: Station = game.world.find_station("dish_rack")
	game.player.set_held("dishes", 1.0, [Dish.make(Dish.CUP)])
	assert_eq(game.cooking.use_station(rack, true), "Cups go on the cup stack")
	game.player.set_held("")
	rack.count = 0
	assert_eq(game.cooking.use_station(rack, true), "No clean plates. Wash some up")


func test_dirty_dishes_can_be_put_down_on_a_counter():
	var table: Station = game.stations[Vector2i(6, 1)]
	table.dirty = 2
	game.cooking.use_station(table)
	assert_eq(game.player.dishes.size(), 2)
	var counter := _the_pass()
	assert_eq(game.cooking.use_station(counter), "Put down")
	assert_eq(game.player.dishes.size(), 1)
	assert_true(counter.item != "", "a dirty plate stands on the counter")
	assert_eq(game.cooking.use_station(counter), "Pick up")
	assert_eq(game.player.dishes.size(), 2)


func test_bin_fills_overflows_and_is_emptied_out_the_front():
	var bin: Station = game.world.find_station("bin")
	for i in Station.BIN_HOLDS:
		assert_false(bin.overflowing())
		game.player.set_held("burnt:patty")
		game.cooking.use_station(bin)
	assert_eq(bin.count, Station.BIN_HOLDS)
	assert_true(bin.overflowing())
	var d := Dish.make(Dish.PLATE)
	d.add("prep:bun", 1.0)
	game.player.set_held("dishes", 1.0, [d])
	assert_eq(game.cooking.use_station(bin), "Scrape off", "a full bin still takes scraps")
	assert_true(d.is_empty(), "the plate is kept, its food binned")
	assert_eq(game.player.dishes, [d] as Array[Dish])
	assert_eq(bin.count, Station.BIN_HOLDS + 1)
	game.player.set_held("")
	assert_eq(game.cooking.use_station(bin), "Empty bin")
	assert_eq(bin.count, 0)
	assert_eq(game.player.held, "rubbish_bag")
	assert_true(game.player.carrying_something_gross())
	assert_eq(game.day.door_action(), "", "the bag does not go out of the front door")
	game.player.position = game.DOORWAY
	assert_eq(game.day.door_action(), "", "no drop at the door either")
	game.player.position = Grid.center(Scenery.outside_bin_cell() - Vector2i(1, 0))
	assert_eq(game.day.door_action(), "Take out rubbish")
	assert_true(game.day.use_door())
	assert_eq(game.player.held, "")
	assert_true(game.door_open, "taking the rubbish out leaves the door as it was")



func test_a_piled_sink_and_an_overflowing_bin_are_gross():
	var sink: Station = game.world.find_station("sink")
	var bin: Station = game.world.find_station("bin")
	var piled := Station.piled_at(sink.racked)
	sink.dirty = piled - 1
	bin.count = Station.BIN_HOLDS - 1
	var kinds := _gross_kinds()
	assert_false(kinds.has("sink"), "a plate or two soaking is fine")
	assert_false(kinds.has("overflow"))
	assert_true(kinds.has("bin"), "the bin is still a bin")
	sink.dirty = piled
	bin.count = Station.BIN_HOLDS
	kinds = _gross_kinds()
	assert_true(kinds.has("sink"))
	assert_true(kinds.has("overflow"))
	assert_false(kinds.has("bin"), "overflowing replaces the plain bin")
	_run(3.0)
	assert_almost_eq(sink.dirty_age, 3.0, 0.15, "the mess ages from when it piled up")
	assert_almost_eq(bin.dirty_age, 3.0, 0.15)
	sink.dirty = 0
	_run(0.1)
	assert_eq(sink.dirty_age, 0.0)



func test_overflowing_bin_disgusts_guests_across_the_room_unless_a_wall_hides_it():
	var g := _seat_at(Vector2i(6, 1), false)          # seat (7, 1): out of the plain bin's range
	assert_not_null(g)
	if g == null:
		return
	g.mood.patience = 1.0
	_run(4.0)
	var before: float = g.mood.disgust
	assert_false(g.mood.thoughts.has("The bin is overflowing"))
	var bin: Station = game.world.find_station("bin")
	bin.count = Station.BIN_HOLDS
	bin.dirty_age = 30.0
	g.mood.patience = 1.0
	_run(2.0)
	assert_true(g.mood.thoughts.has("The bin is overflowing"))
	var seen: float = g.mood.disgust
	assert_gt(seen, before)
	game.grid.walls[Vector3i(0, 5, 0)] = true
	game.grid.walls[Vector3i(1, 5, 1)] = true
	game.grid.walls[Vector3i(0, 6, 0)] = true
	g.mood.patience = 1.0
	_run(2.0)
	assert_eq(g.mood.disgust, seen, "walled off: out of sight")



func test_ignored_guest_walks_out_and_counts_as_a_strike():
	var g: Guest = game.seating.spawn_guest(1)
	_run(80.0)
	assert_eq(game.ledger.strikes(), 1)
	assert_lt(float(game.town.people[1].affinity), 0.0)
	assert_false(is_instance_valid(g) and g.seated_waiting())



func test_guest_who_finds_nothing_walks_on_without_a_strike_and_is_counted():
	game.town.people[1].dislikes = ["patty"]
	game.town.people[2].dislikes = ["patty"]
	var party: Array[Guest] = game.seating.spawn_group([1, 2])
	assert_eq(party[0].state, "browse")
	assert_false(game.queue.has(party[0]), "they never join the line")
	_run(30.0)
	assert_eq(game.ledger.strikes(), 0, "not a walkout")
	assert_eq(int(game.ledger.today.found_nothing), 2)
	assert_lt(float(game.town.people[1].affinity), 0.0)
	assert_eq(game.town.people[1].grudges, 0)
	assert_false(game.guests.has(party[0]), "gone up the street")
	assert_eq(int(game.ledger.end_day().found_nothing), 2, "the receipt counts them")



func test_one_with_nothing_stays_with_a_group_that_has_a_main():
	game.town.people[1].dislikes = ["patty"]
	var party: Array[Guest] = game.seating.spawn_group([1, 2])
	assert_eq(party[0].state, "queue", "the group goes in")
	assert_true(party[0].planned.main.is_empty())
	assert_true(party[0].mood.thoughts.has(Menu.NOTHING_THOUGHT))
	assert_eq(int(game.ledger.today.found_nothing), 1)



func test_one_who_wants_nothing_shows_no_notepad_and_orders_nothing():
	game.town.people[1].dislikes = ["patty"]
	var party: Array[Guest] = game.seating.spawn_group([1, 2])
	var g := party[0]
	var none := Menu.COURSES.all(func(c: String) -> bool: return (g.planned.get(c, {}) as Dictionary).is_empty())
	assert_eq(g.orders_nothing, none, "decided at the door")
	assert_eq(game.serving.order_for(g), g.planned, "nothing is chosen afresh when the order is taken")
	assert_false(party[1].orders_nothing, "the friend with a main waves for the order")



func test_food_in_hand_is_plated_at_the_plate_stack():
	var plates: Station = game.world.find_station("dish_rack")
	var n := plates.count
	var food := Tray.kind("prep", "bun")
	game.player.set_held(food)
	assert_eq(game.cooking.prompt_for(plates), "Plate it")
	game.cooking.use_station(plates, false, game.player)
	assert_eq(game.player.held, "dishes", "a plate in hand now")
	assert_eq(plates.count, n - 1, "off the stack")
	assert_false(game.player.dishes[0].is_empty(), "with the food on it")



func test_a_meal_with_a_liked_ingredient_says_so():
	game.town.people[2].likes = ["patty"]
	var g: Guest = game.seating.spawn_guest(2)
	_run(12.0)
	game.serving.take_orders(g.table)
	game.serving.serve(g, game.serving.full_tray_for(g))
	assert_true(g.mood.thoughts.has(Menu.LIKED_THOUGHT))
	assert_true(g.liked_meal)



func test_dirty_table_disgusts_guests_unless_a_wall_hides_it():
	game.stations.erase(Vector2i(0, 5))   # no bin, so only the plate is in question
	var g: Guest = game.seating.spawn_guest(2)
	_run(12.0)
	assert_eq(g.state, "ordering")
	var other: Station = game.stations[Vector2i(6, 5)] if g.table.cell != Vector2i(6, 5) else game.stations[Vector2i(6, 1)]
	other.dirty = 1
	_run(2.0)
	var fresh: float = g.mood.disgust
	assert_lt(fresh, 0.01, "a plate just finished hardly registers")
	assert_false(g.mood.thoughts.has("Nobody has cleared that table"))
	other.dirty_age = 40.0
	_run(2.0)
	var seen: float = g.mood.disgust
	assert_gt(seen - fresh, fresh * 3.0, "one left sitting is far worse")
	assert_true(g.mood.thoughts.has("Nobody has cleared that table"))
	for c: Vector2i in [g.cell, g.cell + Vector2i(1, 0), g.cell + Vector2i(0, 1)]:
		game.grid.walls[Vector3i(c.x, c.y, 0)] = true
		game.grid.walls[Vector3i(c.x, c.y, 1)] = true
	_run(2.0)
	assert_eq(g.mood.disgust, seen, "boxed in: nothing gross in view")



func test_bin_bothers_only_nearby_guests_until_a_partition_hides_it():
	var near := _seat_at(Vector2i(6, 5), true)        # seat (5, 5), five cells from the bin
	assert_not_null(near)
	if near == null:
		return
	near.mood.patience = 1.0
	_run(8.0)   # it takes a little while in view before it bothers them
	assert_true(near.mood.thoughts.has("I can see the bin from my seat"))
	var far: Guest = null
	for g: Guest in game.guests:
		if g.cell.x > 5:
			far = g
	assert_not_null(far)
	assert_false(far.mood.thoughts.has("I can see the bin from my seat"), "too far away to mind")
	# Box the bin in on its two open sides.
	var before: float = near.mood.disgust
	game.grid.walls[Vector3i(0, 5, 0)] = true
	game.grid.walls[Vector3i(1, 5, 1)] = true
	game.grid.walls[Vector3i(0, 6, 0)] = true
	near.mood.patience = 1.0
	_run(2.0)
	assert_eq(near.mood.disgust, before)



func test_guests_enjoy_watching_the_stove_unless_it_is_burning():
	var g := _seat_at(Vector2i(6, 1), false)          # seat (7, 1): the bin is out of range
	assert_not_null(g)
	if g == null:
		return
	var joy: float = g.mood.joy
	game.cooking.use_station(game.menu_stock.storage_of("patty"))
	_use("stove")
	_run(2.0)
	assert_gt(g.mood.joy, joy)
	assert_true(g.mood.thoughts.has("I can watch the chef at work"))
	for guest: Guest in game.guests:
		guest.mood.patience = 1.0
	_run(Station.BURN_TIME)
	assert_true(g.mood.thoughts.has("Something is burning in there"))



func test_guest_card_opens_on_the_nearest_guest_and_closes_when_they_go():
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	var at: Vector2 = game.cam.unproject_position(g.position + Vector3(0, 0.8, 0))
	assert_eq(game.day.guest_at(at + Vector2(10, 5)), g)
	assert_null(game.day.guest_at(at + Vector2(300, 0)))
	game.day.inspect(g)
	assert_not_null(game.hud.guest_card)
	g.mood.think("A test thought")
	game.hud.update_status()
	assert_string_contains(game.hud._guest_thoughts.text, "A test thought")
	assert_eq(game.hud._guest_state.text, "Waiting to order")
	g.mood.patience = 0.0
	_run(30.0)
	assert_null(game.inspected, "the card closes when the guest has gone")



func test_walkout_starts_a_grudge_and_the_guest_returns_short_tempered():
	var g: Guest = game.seating.spawn_guest(3)
	_run(12.0)
	g.mood.patience = 0.0
	_run(1.0)
	assert_true(game.town.holds_grudge(3, game.ledger.day + 1))
	assert_true(game.town.people[3].sore)
	var back: Guest = game.seating.spawn_guest(3)
	assert_almost_eq(back.mood.patience, 0.75, 0.001)
	assert_true(back.mood.thoughts.has("Last time was a disaster. One more chance"))



func test_overcooked_meat_is_worth_less():
	assert_eq(Station.quality_at(Station.NEARLY_TIME - 0.1), 0.0, "still raw")
	assert_eq(Station.quality_at(Station.COOK_TIME - 0.1), Prep.PLAIN, "underdone is plain")
	assert_eq(Station.quality_at(Station.COOK_TIME + 1.0), Prep.GOOD)
	assert_lt(Station.quality_at(Station.BURN_TIME - 0.5), 0.5)
	var g := _ordered_guest(4)
	_cook_burger(Station.BURN_TIME - 1.0)
	assert_eq(game.player.held, "dishes")
	assert_lt(game.player.dishes[0].quality(), 0.7, "a dried-out patty and a plain bun")
	game.cooking.use_station(g.table)
	assert_lt(g.mood.savour, 0.7)
	assert_true(g.mood.thoughts.has("A bit off, this"))



func test_prompt_names_the_action_without_doing_it():
	var crate: Station = game.menu_stock.storage_of("patty")
	assert_eq(game.cooking.prompt_for(crate), "Take patty")
	assert_eq(game.player.held, "")
	game.cooking.use_station(game.menu_stock.storage_of("patty"))
	assert_eq(game.cooking.prompt_for(crate), "Put back")
	assert_eq(game.cooking.prompt_for(game.world.find_station("stove")), "Grill")
	assert_eq(game.cooking.prompt_for(game.menu_stock.storage_of("bun")), "Put down", "hands are full: it goes on the counter's top")



func test_music_follows_day_night_and_closing():
	assert_eq(game.music_id, "day")
	assert_true(game._music.playing)
	assert_true((game._music.stream as AudioStreamMP3).loop)
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.music_id, "night")
	game.session.open_build()
	assert_eq(game.music_id, "night", "the build phase keeps the night track")
	game.day.start_day()
	assert_eq(game.music_id, "day")
	game.ledger.reputation = 0.0
	_run(0.2)
	assert_eq(game.music_id, "closed")
	assert_false((game._music.stream as AudioStreamMP3).loop, "the closing track plays once")



func test_days_are_endless_and_get_harder():
	game.arrivals.clear()
	_run(1.0)
	assert_eq(game.phase, game.Phase.SUMMARY)
	assert_eq(game.ledger.day, 2)
	var patience_day_2: float = game.day.table_patience()
	game.day.start_day()
	assert_eq(game.phase, game.Phase.SERVICE)
	var expected := 0
	for a: Dictionary in game.arrivals:
		expected += (a.group as Array).size()
	assert_gte(expected, Town.crowd_floor(2))
	game.ledger.day = 9
	assert_lt(game.day.table_patience(), patience_day_2)



func test_walkouts_that_empty_the_reputation_meter_end_the_run():
	game.ledger.reputation = 2.5 * Ledger.REP_WALKOUT
	for i in 3:
		game.seating.spawn_guest(i)
	for g: Guest in game.guests.duplicate():
		game.paying.walk_out(g)
	_run(0.1)
	assert_eq(game.phase, game.Phase.CLOSED)
	game.day.start_day()
	assert_eq(game.phase, game.Phase.CLOSED, "a closed restaurant stays closed")



func test_patty_passes_through_five_looks():
	assert_eq(Station.patty_look(0.0), "raw")
	assert_eq(Station.patty_look(Station.COOK_TIME - 0.1), "nearly")
	assert_eq(Station.patty_look(Station.COOK_TIME + 0.1), "perfect")
	assert_eq(Station.patty_look(Station.PERFECT_END + 0.5), "dry")
	assert_eq(Station.patty_look(Station.BURN_TIME), "burnt")
	# The look never promises more than the quality delivers.
	assert_eq(Station.quality_at(Station.NEARLY_TIME - 0.1), 0.0)
	assert_eq(BuildFood.look_for("prep:patty", Station.quality_at(Station.PERFECT_END + 2.0)), "dry")



func test_a_group_takes_a_whole_table_and_singles_do_not_share():
	var pair: Array[Guest] = game.seating.spawn_group([0, 1])
	var solo_a: Guest = game.seating.spawn_guest(5)
	var solo_b: Guest = game.seating.spawn_guest(9)
	var late: Guest = game.seating.spawn_guest(11)
	_run(14.0)
	assert_eq(pair[0].table, pair[1].table, "the pair sits together")
	assert_ne(solo_a.table, solo_b.table, "two singles do not share")
	assert_ne(solo_a.table, pair[0].table)
	assert_eq(late.state, "queue", "three tables, three groups: the fourth waits outside")
	assert_eq(game.seating.max_party(), 4, "groups of four come whatever the room holds")



func test_a_group_walking_out_is_one_strike():
	var pair: Array[Guest] = game.seating.spawn_group([0, 1])
	_run(12.0)
	pair[0].mood.patience = 0.0
	_run(0.2)
	assert_eq(game.ledger.strikes(), 1)
	assert_true(pair[0].stormed and pair[1].stormed, "they leave together")
	assert_true(game.town.people[1].sore, "and both hold the grudge")



func test_chef_can_serve_from_beside_the_guest_without_facing_the_table():
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	_order(g)
	_cook_burger()
	# Diagonally off the table, right next to the seated guest, looking away.
	game.player.position = Grid.center(g.seat + Vector2i(0, 1)) + Vector3(0, 0, -0.1)
	game.player.look(Vector2i(0, 1))
	assert_eq(game.player.target_cell(), g.table.cell)
	# Across the room it is out of reach.
	game.player.position = Grid.center(Vector2i(2, 5))
	assert_false(game.stations.has(game.player.target_cell()) and game.player.target_cell() == g.table.cell)



func test_chef_aims_at_the_station_most_in_front():
	# Holding meat at (1, 3): stoves at (0, 3) and, diagonally, (0, 4) can both take it.
	game.cooking.use_station(game.menu_stock.storage_of("patty"))
	game.player.position = Grid.center(Vector2i(1, 3))
	game.player.look(Vector2i(-1, 0))
	assert_eq(game.player.target_cell(), Vector2i(0, 3), "the nearer one")
	# One key moves diagonally from this camera; the chef still finds the stove.
	game.player.move(Vector2(0, 1), 0.0)
	assert_eq(game.player.target_cell(), Vector2i(0, 3))
	# Nearness, not facing, decides: looking away still reaches it.
	game.player.look(Vector2i(1, 0))
	assert_eq(game.player.target_cell(), Vector2i(0, 3))
	# Standing by the far stove's corner picks that one instead.
	game.player.position = Grid.center(Vector2i(1, 4)) + Vector3(0, 0, 0.2)
	assert_eq(game.player.target_cell(), Vector2i(0, 4))
	# With nothing useful in reach, nothing is targeted.
	game.player.position = Grid.center(Vector2i(2, 5))
	assert_false(game.stations.has(game.player.target_cell()))
