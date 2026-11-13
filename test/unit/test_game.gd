extends GutTest
## Drives the real game scene headlessly through its public methods.

var game


func before_each():
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false   # straight into day 1
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	# One guest far in the future keeps the day open while a test works.
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])


func _run(seconds: float) -> void:
	for i in int(seconds / 0.1):
		game.step(0.1)


func _use(type: String) -> void:
	game.use_station(game.find_station(type))


func _cook_burger() -> void:
	_use("fridge")
	_use("stove")
	_run(Station.COOK_TIME + 0.5)
	_use("plates")
	_use("stove")


func test_cooking_makes_a_burger():
	_cook_burger()
	assert_eq(game.player.held, "burger")
	assert_eq(game.find_station("plates").count, 3)


func test_patty_left_on_stove_burns():
	_use("fridge")
	_use("stove")
	_run(Station.BURN_TIME + 1.0)
	assert_eq(game.find_station("stove").item, "burnt_patty")
	_use("stove")
	assert_true(game.player.carrying_something_gross())


func test_guest_is_seated_served_and_pays():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	assert_eq(g.state, "waiting")
	_cook_burger()
	game.use_station(g.table)
	assert_eq(g.state, "eating")
	assert_eq(game.player.held, "")
	var table: Station = g.table
	_run(Guest.EAT_TIME + 0.5)
	assert_gt(game.ledger.money, 50 + game.BILL - 1)
	assert_eq(table.dirty, 1)
	assert_gt(float(game.town.people[0].affinity), 0.0, "a good visit makes them like the place")


func test_half_price_calms_an_impatient_guest_and_costs_half_the_bill():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	assert_eq(game.prompt_for(g.table), "", "no discount for a guest who is still happy to wait")
	g.mood.patience = 0.3
	assert_string_contains(game.prompt_for(g.table), "Half price")
	game.use_station(g.table)
	assert_gt(g.mood.patience, 0.6)
	assert_gt(float(game.town.people[0].affinity), 0.0, "kindness is remembered")
	assert_eq(game.prompt_for(g.table), "", "only once")
	_cook_burger()
	game.use_station(g.table)
	_run(Guest.EAT_TIME + 0.5)
	assert_eq(int(game.ledger.today.sales), 6)


func test_free_meal_follows_half_price_for_a_guest_still_fed_up():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	g.mood.patience = 0.2
	assert_string_contains(game.prompt_for(g.table), "Half price", "the smaller apology comes first")
	game.use_station(g.table)
	assert_eq(game.prompt_for(g.table), "", "half price calmed them for now")
	g.mood.patience = 0.1
	assert_string_contains(game.prompt_for(g.table), "Free meal")
	game.use_station(g.table)
	assert_true(g.mood.comped)
	assert_eq(game.prompt_for(g.table), "", "only once")
	assert_true(g.mood.thoughts.has("On the house? That's really kind"))
	_cook_burger()
	game.use_station(g.table)
	_run(Guest.EAT_TIME + 0.5)
	assert_eq(int(game.ledger.today.sales), 0)


func test_a_disgusted_guest_can_be_offered_a_free_meal_straight_away():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	g.mood.disgust = 0.5
	assert_string_contains(game.prompt_for(g.table), "Free meal")


func test_a_guest_who_expects_a_deal_is_let_down_by_full_price():
	game.town.people[0].deals = Town.EXPECT_AT
	var g: Guest = game.spawn_guest(0)
	assert_true(g.mood.thoughts.has("They usually knock something off"))
	_run(12.0)
	_cook_burger()
	game.use_station(g.table)
	_run(Guest.EAT_TIME + 0.5)
	assert_true(g.mood.thoughts.has("Full price this time? Hm"))
	assert_eq(int(game.town.people[0].deals), Town.EXPECT_AT - 1)


func test_flyers_cost_money_once_a_night_and_are_used_up_next_day():
	assert_false(game.buy_flyers(), "not during service")
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.phase, game.Phase.SUMMARY)
	assert_false(game.buy_flyers(), "not on the receipt: they are in the shop")
	game.open_build()
	assert_true(game.buy_flyers())
	assert_eq(game.ledger.money, 50 - Town.FLYER_PRICE)
	assert_false(game.buy_flyers(), "one batch a night")
	game.start_day()
	assert_false(game.flyers_out)
	assert_eq(int(game.ledger.today.spent), Town.FLYER_PRICE)


func _to_build() -> void:
	game.arrivals.clear()
	_run(0.2)
	game.open_build()


func test_upgraded_piece_is_bought_from_the_catalog():
	_to_build()
	game.ledger.money = 100
	assert_false(game.pick_catalog("plant", 2), "tier 2 needs level 2")
	game.ledger.xp = 100
	assert_true(game.pick_catalog("plant", 2))
	assert_true(game.place(Vector3i(2, 4, 0)))
	assert_eq(game.stations[Vector2i(2, 4)].tier, 2)
	assert_eq(game.ledger.money, 60)
	assert_eq(int(game.hand.tier), 2, "still in hand while there is money for another")
	assert_true(game.place(Vector3i(3, 4, 0)))
	assert_true(game.hand.is_empty(), "$20 left will not buy a third")


func test_shop_filters_as_you_search_and_browses_with_the_keys():
	_to_build()
	game.open_shop()
	assert_true(game.shopping)
	assert_eq(game.hud._category, "Kitchen", "there is no All tab")
	assert_eq(game.hud._cards.get_child_count(), 4)
	game.hud.set_search("fern")
	assert_eq(game.hud._cards.get_child_count(), 3, "a search looks through every category")
	game.hud.set_search("zzz")
	assert_eq(game.hud._cards.get_child_count(), 1, "only the nothing-matches line")
	game.hud._set_category("Kitchen")
	assert_eq(game.hud._search, "", "picking a category ends the search")
	assert_eq(game.hud._cards.get_child_count(), 4)
	game.hud.shop_move(-1)
	assert_eq(game.hud._shop_index, 3, "left from the first wraps to the last")
	game.hud.shop_category(1)
	assert_eq(game.hud._category, "Dining")
	game.close_shop()
	assert_null(game.hud._shop)
	game.start_day()
	assert_null(game.hud.build_bar)


func test_buying_in_the_shop_puts_the_piece_in_hand_and_shuts_it():
	_to_build()
	game.open_shop()
	assert_false(game.buy({"id": "stove", "tier": 1}), "level 3 and $80")
	assert_true(game.shopping)
	assert_true(game.buy({"id": "counter", "tier": 1}))
	assert_false(game.shopping)
	assert_eq(game.hand.id, "counter")
	game.open_shop()
	assert_true(game.buy(game.FLYERS))
	assert_true(game.flyers_out)
	assert_true(game.shopping, "flyers are not carried, so the shop stays open")


func test_furniture_is_carried_and_put_down_in_front_of_the_chef():
	_to_build()
	game.player.position = Grid.center(Vector2i(8, 2))
	game.player.look(Vector2i(0, 1))            # facing the table at (8, 3)
	assert_eq(game.build_action(), "Pick up")
	game.build_interact()
	assert_eq(game.hand.id, "table")
	assert_eq(game.build_action(), "Put down")
	game.build_interact()
	assert_true(game.hand.is_empty())
	assert_true(game.stations.has(Vector2i(8, 3)))
	game.player.look(Vector2i(0, -1))
	assert_eq(game.build_action(), "", "nothing in front and not at the door")


func test_a_carried_fern_shows_which_seats_it_would_reach():
	_to_build()
	assert_eq(game.range_of("plant", 2), 4)
	assert_eq(game.range_of("table"), 0)
	var seat: Vector2i = game.stations[Vector2i(8, 3)].seats[0]
	assert_eq(game.seats_reached(seat + Vector2i(0, -1), 3)[seat], Decor.BESIDE)
	assert_eq(game.seats_reached(seat - Vector2i(3, 0), 3)[seat], Decor.IN_VIEW)
	assert_eq(game.seats_reached(seat - Vector2i(4, 0), 3)[seat], 0.0, "four cells is out of reach")
	assert_true(game.pick_catalog("plant"))
	game._update_range()
	assert_gt(game._range_marks.get_child_count(), 1, "the wash and a disc for every seat")
	game.cancel_hand()
	game._update_range()
	assert_eq(game._range_key, "")


func test_chef_is_pushed_clear_of_a_piece_put_down_too_close_or_on_top():
	_to_build()
	game.player.position = Vector3(2.5, 0, 3.9)          # hard against the edge of (2, 4)
	game.player.look(Vector2i(0, 1))
	assert_true(game.pick_catalog("counter"))
	game.build_interact()
	assert_true(game.stations.has(Vector2i(2, 4)))
	assert_true(game.player.stuck(), "overlapping the new counter")
	for i in 30:
		game.player.move(Vector2.ZERO, 0.016)
	assert_false(game.player.stuck())
	assert_eq(game.player.cell(), Vector2i(2, 3), "nudged back into the same cell")
	game.cancel_hand()
	game.add_station("counter", Vector2i(2, 3))          # dropped right on top of the chef
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
	assert_true(fresh.hud.title_open(), "the title comes first")
	fresh.play()
	assert_eq(fresh.phase, fresh.Phase.BUILD)
	assert_false(fresh.door_open)
	assert_true(fresh.arrivals.is_empty())
	assert_true(fresh.pick_catalog("counter"), "the room can be changed before anyone comes")
	fresh.cancel_hand()
	fresh.player.position = Grid.center(Vector2i(9, 4))
	fresh.build_interact()
	assert_eq(fresh.phase, fresh.Phase.SERVICE)
	assert_eq(fresh.ledger.day, 1)
	assert_false(fresh.arrivals.is_empty())


func test_flipping_the_door_card_opens_the_day():
	_to_build()
	assert_false(game.door_open, "the card says closed overnight")
	game.player.position = Grid.center(Vector2i(2, 3))
	assert_false(game.use_door(), "too far from the doorway")
	game.player.position = Grid.center(Vector2i(9, 4))
	game.player.look(Vector2i(1, 0))
	assert_eq(game.build_action(), "Open up")
	game.build_interact()
	assert_eq(game.phase, game.Phase.SERVICE)
	assert_true(game.door_open)


func test_closing_early_turns_new_guests_away_but_keeps_those_inside():
	game.spawn_guest(0)
	game.player.position = Grid.center(Vector2i(9, 4))
	assert_eq(game.door_action(), "", "too early in the day")
	game.clock = game.day_length() * 0.6
	assert_false(game.arrivals.is_empty())
	assert_eq(game.door_action(), "Close early")
	assert_true(game.use_door())
	assert_true(game.arrivals.is_empty())
	assert_false(game.door_open)
	assert_eq(game.guests.size(), 1)
	_run(0.2)
	assert_eq(game.phase, game.Phase.SERVICE, "the day runs on until the last guest leaves")
	assert_eq(game.door_action(), "", "already closed")


func test_catalog_piece_is_paid_for_when_placed_and_gated_by_level():
	_to_build()
	assert_false(game.pick_catalog("stove"), "level 3 and $80")
	assert_true(game.pick_catalog("counter"))
	assert_eq(game.ledger.money, 50, "picking is free")
	assert_false(game.place(Vector3i(9, 4, 0)), "that would block the doorway")
	assert_false(game.place(Vector3i(0, 2, 0)), "a stove is already there")
	assert_true(game.place(Vector3i(2, 4, 0)))
	assert_eq(game.ledger.money, 35)
	assert_eq(game.stations[Vector2i(2, 4)].type, "counter")
	game.start_day()
	assert_eq(game.phase, game.Phase.SERVICE)
	assert_true(game.hand.is_empty())
	assert_false(game.place(Vector3i(3, 4, 0)), "no building during service")


func test_partition_snaps_to_the_nearest_edge_and_hides_a_dirty_table():
	_to_build()
	assert_true(game.pick_catalog("screen"))
	assert_eq(game.snap(Vector3(5.9, 0, 3.5)), Vector3i(6, 3, 1))
	assert_eq(game.snap(Vector3(5.5, 0, 3.1)), Vector3i(5, 3, 0))
	assert_true(game.place(Vector3i(6, 3, 1)))
	assert_false(game.grid.has_los(Vector2i(5, 3), Vector2i(6, 3)))
	assert_eq(game.ledger.money, 40)


func test_moving_a_piece_is_free_and_cancel_puts_it_back():
	_to_build()
	var bin: Station = game.find_station("bin")
	assert_true(game.pick_up(Vector3(0.5, 0, 5.5)))
	assert_false(game.stations.has(Vector2i(0, 5)))
	assert_false(game.grid.blocked.has(Vector2i(0, 5)))
	assert_false(game.place(Vector3i(1, 0, 0)), "a stove is there")
	assert_true(game.place(Vector3i(2, 5, 0)))
	assert_eq(bin.cell, Vector2i(2, 5))
	assert_eq(game.stations[Vector2i(2, 5)], bin)
	assert_eq(game.ledger.money, 50)
	assert_true(game.pick_up(Vector3(2.5, 0, 5.5)))
	game.cancel_hand()
	assert_eq(bin.cell, Vector2i(2, 5), "back where it was picked up")
	assert_true(bin.visible)
	assert_false(game.pick_up(Vector3(3.5, 0, 5.5)), "nothing there")


func test_carried_piece_goes_back_when_the_day_opens():
	_to_build()
	var fridge: Station = game.find_station("fridge")
	assert_true(game.pick_up(Vector3(0.5, 0, 2.5)))
	game.start_day()
	assert_eq(game.stations[Vector2i(0, 2)], fridge)
	assert_true(fridge.visible)


func test_turned_table_has_seats_above_and_below():
	_to_build()
	var table: Station = game.stations[Vector2i(8, 3)]
	assert_true(game.pick_up(Vector3(8.5, 0, 3.5)))
	assert_false(game.grid.reserved.has(Vector2i(7, 3)), "its seats come up with it")
	game.rotate_hand()
	assert_true(game.place(Vector3i(8, 3, 0)))
	assert_eq(table.seats, [Vector2i(8, 2), Vector2i(8, 4)] as Array[Vector2i])
	assert_true(game.grid.reserved.has(Vector2i(8, 4)))
	game.start_day()
	var cells: Array = []
	var all: Array[Guest] = []
	for n in 3:
		all.append_array(game.spawn_group([n * 2, n * 2 + 1]))
	_run(14.0)
	for g in all:
		cells.append(g.cell)
	assert_true(cells.has(Vector2i(8, 2)) and cells.has(Vector2i(8, 4)), "guests use the turned seats")


func test_selling_refunds_half_but_not_the_last_stove_or_fixtures():
	_to_build()
	assert_true(game.pick_up(Vector3(9.5, 0, 0.5)))        # the fern
	assert_eq(game.sell_value(), 10)
	assert_true(game.sell_hand())
	assert_eq(game.ledger.money, 60)
	assert_false(game.stations.has(Vector2i(9, 0)))
	assert_true(game.pick_up(Vector3(0.5, 0, 2.5)))        # the fridge
	assert_false(game.sell_hand(), "fixtures are not for sale")
	game.cancel_hand()
	assert_true(game.pick_up(Vector3(0.5, 0, 3.5)))        # one of two stoves
	assert_true(game.sell_hand())
	assert_eq(game.ledger.money, 100)
	assert_true(game.pick_up(Vector3(0.5, 0, 4.5)))
	assert_eq(game.sell_block(), "Your last stove")
	assert_false(game.sell_hand())
	game.cancel_hand()
	assert_eq(game.find_station("stove").cell, Vector2i(0, 4))


func test_partition_can_be_picked_up_moved_and_sold():
	_to_build()
	assert_true(game.pick_catalog("screen"))
	assert_true(game.place(Vector3i(6, 3, 1)))
	game.cancel_hand()
	assert_true(game.pick_up(Vector3(6.05, 0, 3.5)))
	assert_false(game.grid.walls.has(Vector3i(6, 3, 1)))
	assert_true(game.place(Vector3i(6, 4, 1)))
	assert_true(game.grid.walls.has(Vector3i(6, 4, 1)))
	assert_true(game.pick_up(Vector3(6.05, 0, 4.5)))
	assert_true(game.sell_hand())
	assert_eq(game.ledger.money, 45)
	assert_false(game.pick_up(Vector3(9.95, 0, 2.5)), "the entrance wall is not yours to move")


func test_new_table_seats_guests():
	_to_build()
	game.ledger.money = 100
	game.ledger.xp = 100
	assert_true(game.pick_catalog("table"))
	assert_false(game.place(Vector3i(9, 5, 0)), "no room for the right-hand seat")
	assert_true(game.place(Vector3i(2, 4, 0)))
	assert_true(game.grid.reserved.has(Vector2i(1, 4)))
	assert_eq(game.ledger.money, 60)


func test_washing_a_dirty_plate_returns_it_to_the_stack():
	var table: Station = game.stations[Vector2i(6, 1)]
	table.dirty = 1
	game.use_station(table)
	assert_eq(game.player.held, "dirty_plate")
	_use("sink")
	assert_eq(game.player.held, "")
	assert_eq(game.find_station("sink").dirty, 1, "it soaks until washed")
	assert_eq(game.find_station("plates").count, 4)
	_use("sink")
	assert_eq(game.find_station("sink").dirty, 0)
	assert_eq(game.find_station("plates").count, 5)
	assert_eq(game.use_station(game.find_station("sink"), true), "", "nothing left to wash")


func test_bin_fills_overflows_and_is_emptied_out_the_front():
	var bin: Station = game.find_station("bin")
	for i in Station.BIN_HOLDS:
		assert_false(bin.overflowing())
		game.player.set_held("burnt_patty")
		game.use_station(bin)
	assert_eq(bin.count, Station.BIN_HOLDS)
	assert_true(bin.overflowing())
	game.player.set_held("burger")
	assert_eq(game.use_station(bin), "Scrape off", "a full bin still takes scraps")
	assert_eq(bin.count, Station.BIN_HOLDS + 1)
	game.player.set_held("")
	assert_eq(game.use_station(bin), "Empty bin")
	assert_eq(bin.count, 0)
	assert_eq(game.player.held, "rubbish_bag")
	assert_true(game.player.carrying_something_gross())
	assert_eq(game.door_action(), "", "the bag goes out of the front door")
	game.player.position = game.DOORWAY
	assert_eq(game.door_action(), "Take out rubbish")
	assert_true(game.use_door())
	assert_eq(game.player.held, "")
	assert_true(game.door_open, "taking the rubbish out leaves the door as it was")


func _gross_kinds() -> Array:
	game._collect_gross()
	return game._gross.map(func(s): return s.kind)


func test_a_piled_sink_and_an_overflowing_bin_are_gross():
	var sink: Station = game.find_station("sink")
	var bin: Station = game.find_station("bin")
	sink.dirty = Station.SINK_PILED - 1
	bin.count = Station.BIN_HOLDS - 1
	var kinds := _gross_kinds()
	assert_false(kinds.has("sink"), "a plate or two soaking is fine")
	assert_false(kinds.has("overflow"))
	assert_true(kinds.has("bin"), "the bin is still a bin")
	sink.dirty = Station.SINK_PILED
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
	var bin: Station = game.find_station("bin")
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
	var g: Guest = game.spawn_guest(1)
	_run(80.0)
	assert_eq(game.ledger.strikes(), 1)
	assert_lt(float(game.town.people[1].affinity), 0.0)
	assert_false(is_instance_valid(g) and g.state == "waiting")


func test_dirty_table_disgusts_guests_unless_a_wall_hides_it():
	game.stations.erase(Vector2i(0, 5))   # no bin, so only the plate is in question
	var g: Guest = game.spawn_guest(2)
	_run(12.0)
	assert_eq(g.state, "waiting")
	var other: Station = game.stations[Vector2i(6, 5)] if g.table.cell != Vector2i(6, 5) else game.stations[Vector2i(6, 1)]
	other.dirty = 1
	_run(2.0)
	var fresh: float = g.mood.disgust
	assert_lt(fresh, 0.01, "a plate just finished hardly registers")
	assert_false(g.mood.thoughts.has("Nobody has cleared that table"))
	other.dirty_age = 40.0
	_run(2.0)
	var seen: float = g.mood.disgust
	assert_gt(seen - fresh, fresh * 8.0, "one left sitting is far worse")
	assert_true(g.mood.thoughts.has("Nobody has cleared that table"))
	for c: Vector2i in [g.cell, g.cell + Vector2i(1, 0), g.cell + Vector2i(0, 1)]:
		game.grid.walls[Vector3i(c.x, c.y, 0)] = true
		game.grid.walls[Vector3i(c.x, c.y, 1)] = true
	_run(2.0)
	assert_eq(g.mood.disgust, seen, "boxed in: nothing gross in view")


func _seat_at(table_cell: Vector2i, left: bool) -> Guest:
	# Fill tables with pairs until a guest lands on the wanted seat.
	var want := table_cell + Vector2i(-1 if left else 1, 0)
	for i in 3:
		var pair: Array[Guest] = game.spawn_group([i * 2, i * 2 + 1])
		_run(12.0)
		for g in pair:
			if g.cell == want and g.state == "waiting":
				return g
	return null


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
	_use("fridge")
	_use("stove")
	_run(2.0)
	assert_gt(g.mood.joy, joy)
	assert_true(g.mood.thoughts.has("I can watch the chef at work"))
	for guest: Guest in game.guests:
		guest.mood.patience = 1.0
	_run(Station.BURN_TIME)
	assert_true(g.mood.thoughts.has("Something is burning in there"))


func test_guest_card_opens_on_the_nearest_guest_and_closes_when_they_go():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	var at: Vector2 = game.cam.unproject_position(g.position + Vector3(0, 0.8, 0))
	assert_eq(game.guest_at(at + Vector2(10, 5)), g)
	assert_null(game.guest_at(at + Vector2(300, 0)))
	game.inspect(g)
	assert_not_null(game.hud.guest_card)
	g.mood.think("A test thought")
	game.hud.update_status()
	assert_string_contains(game.hud._guest_thoughts.text, "A test thought")
	assert_eq(game.hud._guest_state.text, "Waiting for food")
	g.mood.patience = 0.0
	_run(30.0)
	assert_null(game.inspected, "the card closes when the guest has gone")


func test_walkout_starts_a_grudge_and_the_guest_returns_short_tempered():
	var g: Guest = game.spawn_guest(3)
	_run(12.0)
	g.mood.patience = 0.0
	_run(1.0)
	assert_true(game.town.holds_grudge(3, game.ledger.day + 1))
	assert_true(game.town.people[3].sore)
	var back: Guest = game.spawn_guest(3)
	assert_almost_eq(back.mood.patience, 0.75, 0.001)
	assert_true(back.mood.thoughts.has("Last time was a disaster. One more chance"))


func test_overcooked_meat_is_worth_less():
	assert_eq(Station.quality_at(Station.COOK_TIME - 0.1), 0.0)
	assert_eq(Station.quality_at(Station.COOK_TIME + 1.0), 1.0)
	assert_lt(Station.quality_at(Station.BURN_TIME - 0.5), 0.6)
	_use("fridge")
	_use("stove")
	_run(Station.BURN_TIME - 1.0)
	_use("plates")
	_use("stove")
	assert_eq(game.player.held, "burger")
	assert_lt(game.player.held_quality, 0.7)
	var g: Guest = game.spawn_guest(4)
	_run(12.0)
	game.use_station(g.table)
	assert_lt(g.mood.savour, 0.7)
	assert_eq(g.mood.latest_thought(), "A bit dry, this")


func test_prompt_names_the_action_without_doing_it():
	var fridge: Station = game.find_station("fridge")
	assert_eq(game.prompt_for(fridge), "Take meat")
	assert_eq(game.player.held, "")
	_use("fridge")
	assert_eq(game.prompt_for(fridge), "")
	assert_eq(game.prompt_for(game.find_station("stove")), "Cook")


func test_music_follows_day_night_and_closing():
	assert_eq(game.music_id, "day")
	assert_true(game._music.playing)
	assert_true((game._music.stream as AudioStreamMP3).loop)
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.music_id, "night")
	game.open_build()
	assert_eq(game.music_id, "night", "the build phase keeps the night track")
	game.start_day()
	assert_eq(game.music_id, "day")
	for i in Ledger.MAX_STRIKES:
		game.ledger.record_walkout()
	_run(0.2)
	assert_eq(game.music_id, "closed")
	assert_false((game._music.stream as AudioStreamMP3).loop, "the closing track plays once")


func test_days_are_endless_and_get_harder():
	game.arrivals.clear()
	_run(1.0)
	assert_eq(game.phase, game.Phase.SUMMARY)
	assert_eq(game.ledger.day, 2)
	var patience_day_2: float = game.table_patience()
	game.start_day()
	assert_eq(game.phase, game.Phase.SERVICE)
	var expected := 0
	for a: Dictionary in game.arrivals:
		expected += (a.group as Array).size()
	assert_gte(expected, 5)
	game.ledger.day = 9
	assert_lt(game.table_patience(), patience_day_2)


func test_three_walkouts_end_the_run():
	for i in 3:
		game.spawn_guest(i)
	for g: Guest in game.guests.duplicate():
		game.walk_out(g)
	_run(0.1)
	assert_eq(game.phase, game.Phase.CLOSED)
	game.start_day()
	assert_eq(game.phase, game.Phase.CLOSED, "a closed restaurant stays closed")


func test_patty_passes_through_five_looks():
	assert_eq(Station.patty_look(0.0), "raw")
	assert_eq(Station.patty_look(Station.COOK_TIME - 0.1), "nearly")
	assert_eq(Station.patty_look(Station.COOK_TIME + 0.1), "perfect")
	assert_eq(Station.patty_look(Station.PERFECT_END + 0.5), "dry")
	assert_eq(Station.patty_look(Station.BURN_TIME), "burnt")
	# The look never promises more than the quality delivers.
	assert_eq(Station.quality_at(Station.COOK_TIME - 0.1), 0.0)
	assert_eq(Build.look_for("cooked_patty", Station.quality_at(Station.PERFECT_END + 2.0)), "dry")


func test_a_group_takes_a_whole_table_and_singles_do_not_share():
	var pair: Array[Guest] = game.spawn_group([0, 1])
	var solo_a: Guest = game.spawn_guest(5)
	var solo_b: Guest = game.spawn_guest(9)
	var late: Guest = game.spawn_guest(11)
	_run(14.0)
	assert_eq(pair[0].table, pair[1].table, "the pair sits together")
	assert_ne(solo_a.table, solo_b.table, "two singles do not share")
	assert_ne(solo_a.table, pair[0].table)
	assert_eq(late.state, "queue", "three tables, three groups: the fourth waits outside")
	assert_eq(game.max_party(), 2)


func test_a_group_walking_out_is_one_strike():
	var pair: Array[Guest] = game.spawn_group([0, 1])
	_run(12.0)
	pair[0].mood.patience = 0.0
	_run(0.2)
	assert_eq(game.ledger.strikes(), 1)
	assert_true(pair[0].stormed and pair[1].stormed, "they leave together")
	assert_true(game.town.people[1].sore, "and both hold the grudge")


func test_chef_can_serve_from_beside_the_guest_without_facing_the_table():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
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
	_use("fridge")
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


# ---------------------------------------------------------------- building the room

func test_floor_tool_grows_the_room_and_charges_per_tile():
	_to_build()
	game.ledger.money = 100
	assert_true(game.pick_catalog("floor_planks"))
	assert_true(game.grid.is_blocked(Vector2i(5, -1)), "bare ground behind the dining room")
	assert_eq(game.finish_drag(Vector3(4.5, 0, -0.5), Vector3(7.5, 0, -1.5), false), 8)
	assert_eq(game.ledger.money, 60)
	assert_false(game.grid.is_blocked(Vector2i(5, -1)), "now floor")
	assert_true(game.grid.reachable(Vector2i(5, 1), Vector2i(5, -2)), "the old back wall came down")
	assert_eq(game.hand.id, "floor_planks", "still in hand for more")
	assert_eq(game.finish_drag(Vector3(4.5, 0, -3.5), Vector3(7.5, 0, -3.5), false), 0, "nothing past the edge of the lot")
	assert_true(game.place(Vector3i(3, 1, 0)), "laid beside the room one at a time")
	assert_true(game.remove_at(Vector3i(3, 1, 0)))
	assert_eq(game.ledger.money, 60, "taking a tile up pays it back")
	assert_false(game.remove_at(Vector3i(9, 4, 0)), "never the floor inside the front door")
	assert_false(game.remove_at(Vector3i(6, 1, 0)), "nor under a table")


func test_walls_divide_the_room_but_never_shut_anyone_in():
	_to_build()
	game.ledger.money = 500
	game.pick_catalog("floor_planks")
	game.finish_drag(Vector3(4.5, 0, -0.5), Vector3(9.5, 0, -1.5), false)
	assert_true(game.pick_catalog("wall"))
	var built: int = game.finish_drag(Vector3(4, 0, 0), Vector3(10, 0, 0), false)
	assert_eq(built, 6)
	assert_false(game.grid.reachable(Vector2i(5, 1), Vector2i(5, -1)), "the back room is walled off")
	assert_false(game.grid.has_los(Vector2i(5, 1), Vector2i(5, -1)))
	# A wall across the front of a table's seats would cut them off: refused.
	var seat: Vector2i = game.find_station("table").seats[0]
	var shut := 0
	for e in Floorplan.cell_edges(seat):
		if game.can_place(e):
			game.place(e)
			shut += 1
	assert_true(game.grid.reachable(game.DOOR, seat), "the seat can still be reached")
	assert_lt(shut, 4)


func test_doors_and_archways_open_walls_and_warn_when_unusable():
	_to_build()
	game.ledger.money = 500
	assert_true(game.pick_catalog("door"))
	var back := Vector3i(6, 0, 0)
	assert_true(game.place(back), "a door can go in the back wall before there is a room behind it")
	assert_false(game.opening_usable(back), "it leads onto bare ground")
	assert_eq(game.ledger.money, 480)
	game.pick_catalog("floor_planks")
	assert_true(game.place(Vector3i(6, -1, 0)))
	assert_false(game.plan.openings.has(back), "laying floor past an outer door merges the rooms")
	assert_eq(game.ledger.money, 495, "and the door is paid back")
	game.pick_catalog("wall")
	assert_true(game.place(back))
	game.pick_catalog("arch")
	assert_true(game.place(back))
	assert_true(game.opening_usable(back))
	assert_true(game.grid.has_los(Vector2i(6, 0), Vector2i(6, -1)), "an archway lets guests see through")
	assert_true(game.remove_at(back))
	game.pick_catalog("door")
	assert_true(game.place(back))
	assert_true(game.grid.reachable(Vector2i(6, 0), Vector2i(6, -1)))
	assert_false(game.grid.has_los(Vector2i(6, 0), Vector2i(6, -1)), "a door does not")
	# A door with a stove in front of it cannot be used.
	assert_true(game.place(Vector3i(0, 3, 1)))
	assert_false(game.opening_usable(Vector3i(0, 3, 1)))
	assert_false(game.plan.has_floor(Vector2i(-1, 3)))


func _mouse(at: Vector3, button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = game.cam.unproject_position(at)
	game._unhandled_input(e)


func test_mouse_drags_lay_floor_and_right_drags_take_it_up():
	_to_build()
	game.cam.position = game._frame[0] + game.CAM_OFFSET   # settled, as after a frame or two
	game.cam.size = game._frame[1]
	game.ledger.money = 100
	game.pick_catalog("floor_tile")
	_mouse(Vector3(0.5, 0, 1.5), MOUSE_BUTTON_LEFT, true)
	assert_eq(game.build_action().begins_with("Lay"), true, "the prompt counts the drag")
	_mouse(Vector3(3.5, 0, 0.5), MOUSE_BUTTON_LEFT, false)
	assert_eq(game.plan.kind(Vector2i(0, 0)), "tile", "the corner behind the kitchen is floored")
	assert_eq(game.ledger.money, 60)
	_mouse(Vector3(0.5, 0, 0.5), MOUSE_BUTTON_RIGHT, true)
	_mouse(Vector3(1.5, 0, 0.5), MOUSE_BUTTON_RIGHT, false)
	assert_false(game.plan.has_floor(Vector2i(1, 0)))
	assert_eq(game.ledger.money, 70)


# ---------------------------------------------------------------- controller and touch

func _pad(button: int, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	game.controls._input(e)
	Input.flush_buffered_events()   # deliver the key it sent now, not on some later frame


func test_the_last_device_used_sets_the_mode_and_the_hints():
	assert_eq(game.controls.mode, "keys")
	_pad(JOY_BUTTON_B, true)
	_pad(JOY_BUTTON_B, false)
	assert_eq(game.controls.mode, "pad")
	assert_eq(game.hud._prompt_key_label.text, "A", "the prompt shows the pad's button")
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(700, 300)
	touch.pressed = true
	game.controls._input(touch)
	assert_eq(game.controls.mode, "touch")
	assert_false(game.hud._prompt_key.visible, "no keycap on touch: the Use button says it")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	game.controls._input(key)
	assert_eq(game.controls.mode, "keys")
	assert_eq(game.hud._prompt_key_label.text, "E")


func test_left_stick_walks_the_chef():
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = 1.0
	game.controls._input(e)
	assert_eq(game.controls.stick(), Vector2(1, 0))
	var from: Vector3 = game.player.position
	for i in 10:
		game._process(0.05)
	assert_gt(game.player.position.distance_to(from), 0.5, "the chef walked")
	e.axis_value = 0.1
	game.controls._input(e)
	assert_eq(game.controls.stick(), Vector2.ZERO, "inside the dead zone")


func test_pad_buttons_press_the_matching_keys():
	_to_build()
	game.ledger.money = 100
	_pad(JOY_BUTTON_Y, true)
	_pad(JOY_BUTTON_Y, false)
	assert_true(game.shopping, "Y opens the shop")
	_pad(JOY_BUTTON_B, true)
	_pad(JOY_BUTTON_B, false)
	assert_false(game.shopping, "B closes it")
	assert_true(game.pick_catalog("plant"))
	_pad(JOY_BUTTON_RIGHT_SHOULDER, true)
	_pad(JOY_BUTTON_RIGHT_SHOULDER, false)
	assert_eq(int(game.hand.facing), 1, "a shoulder button turns the piece")


func test_touch_joystick_and_buttons_never_reach_the_room():
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = game.controls._stick_home()
	game.controls._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.position = touch.position + Vector2(200, 0)
	game.controls._input(drag)
	assert_almost_eq(game.controls.stick().x, 1.0, 0.01, "dragged to the right edge")
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = touch.position
	game.controls._input(mouse)
	assert_true(game.controls.owns_pointer(), "the mouse made from that touch is swallowed")
	touch.pressed = false
	game.controls._input(touch)
	assert_eq(game.controls.stick(), Vector2.ZERO, "let go")
	var ids := []
	for b: Array in game.controls.buttons():
		ids.append(b[0])
	assert_has(ids, "use", "a Use button during service")


func test_booth_and_table_for_four_are_sold_under_dining():
	var dining: Array = Catalog.search("", "Dining").map(func(bp: Dictionary) -> String: return bp.id)
	assert_has(dining, "booth")
	assert_has(dining, "table4")
	assert_eq(Catalog.price_of("booth"), 60)
	assert_eq(Catalog.price_of("table4"), 90)
	var cat := Catalog.new()
	assert_false(cat.can_buy("table4", 500, 2), "a table for four needs level 3")
	assert_true(cat.can_buy("table4", 500, 3))
	assert_true(cat.can_buy("booth", 500, 2))
	assert_eq(Catalog.search("four").size(), 3, "every tier of the table for four turns up")


func test_seats_of_a_booth_turn_and_a_table_for_four_has_one_each_side():
	var c := Vector2i(5, 5)
	assert_eq(Station.seats_for("booth", c, 0), [Vector2i(4, 5), Vector2i(6, 5)] as Array[Vector2i])
	assert_eq(Station.seats_for("booth", c, 1), [Vector2i(5, 4), Vector2i(5, 6)] as Array[Vector2i])
	for facing in 4:
		var seats := Station.seats_for("table4", c, facing)
		assert_eq(seats.size(), 4)
		for s in [Vector2i(4, 5), Vector2i(6, 5), Vector2i(5, 4), Vector2i(5, 6)]:
			assert_has(seats, s)


## Sells the table at (6, 5) and puts `id` there instead.
func _swap_front_table(id: String, facing := 0) -> Station:
	_to_build()
	game.ledger.money = 500
	game.ledger.xp = 500
	assert_true(game.pick_up(Vector3(6.5, 0, 5.5)))
	assert_true(game.sell_hand())
	assert_true(game.pick_catalog(id))
	for i in facing:
		game.rotate_hand()
	assert_true(game.place(Vector3i(6, 5, 0)))
	game.cancel_hand()
	return game.stations[Vector2i(6, 5)]


func test_buying_and_placing_a_table_for_four_reserves_four_seats():
	_to_build()
	game.ledger.money = 500
	game.ledger.xp = 500
	assert_true(game.pick_catalog("table4"))
	assert_false(game.can_place(Vector3i(5, 3, 0)), "a seat would sit on the pass")
	assert_false(game.can_place(Vector3i(8, 2, 0)), "a seat would sit on another table")
	assert_false(game.can_place(Vector3i(9, 6, 0)), "a seat would be outside")
	game.cancel_hand()
	var t := _swap_front_table("table4")
	assert_eq(t.seats.size(), 4)
	for s in t.seats:
		assert_true(game.grid.reserved.has(s))
	assert_eq(game.max_party(), 4)
	assert_true(game.grid.reachable(game.DOOR, Vector2i(6, 6)), "every seat can be reached")


func test_a_booth_turns_with_its_seats_and_refused_spots_stay_refused():
	var b := _swap_front_table("booth", 1)
	assert_eq(b.seats, [Vector2i(6, 4), Vector2i(6, 6)] as Array[Vector2i])
	assert_false(game.grid.reserved.has(Vector2i(5, 5)))
	assert_true(game.pick_up(Vector3(6.5, 0, 5.5)))
	game.rotate_hand()
	assert_true(game.place(Vector3i(6, 5, 0)))
	assert_eq(b.seats, [Vector2i(5, 5), Vector2i(7, 5)] as Array[Vector2i])
	assert_true(game.pick_catalog("booth"))
	assert_false(game.can_place(Vector3i(9, 4, 0)), "a seat would be on the pavement")
	game.rotate_hand()
	assert_false(game.can_place(Vector3i(9, 4, 0)), "turned, a seat lands on the table at (8, 3)'s seat")
	game.cancel_hand()
	# A wall may not shut the booth's seats off from the door.
	game.pick_catalog("wall")
	for e in Floorplan.cell_edges(Vector2i(7, 5)):
		if game.can_place(e):
			game.place(e)
	assert_true(game.grid.reachable(game.DOOR, Vector2i(7, 5)))


func test_a_group_of_four_sits_together_at_the_table_for_four():
	var t := _swap_front_table("table4")
	game.start_day()
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	var four: Array[Guest] = game.spawn_group([0, 1, 2, 3])
	var pair: Array[Guest] = game.spawn_group([4, 5])
	_run(16.0)
	for g in four:
		assert_eq(g.table, t, "the four share the table for four")
		assert_has(t.seats, g.seat)
	assert_ne(pair[0].table, t, "a pair takes a table for two, leaving the big one")
	assert_eq(pair[0].table, pair[1].table)


func test_a_booth_seats_a_pair_and_is_cosy():
	var b := _swap_front_table("booth")
	game.start_day()
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	var pairs: Array[Guest] = []
	for n in 3:
		pairs.append_array(game.spawn_group([n * 2, n * 2 + 1]))
	_run(16.0)
	var at_booth := pairs.filter(func(g: Guest) -> bool: return g.table == b)
	assert_eq(at_booth.size(), 2, "three pairs, three tables: one pair gets the booth")
	var at_table: Guest = pairs.filter(func(g: Guest) -> bool: return g.table != b)[0]
	assert_almost_eq(at_booth[0].mood.joy - at_table.mood.joy, game.BOOTH_DELIGHT, 0.001, "benches are cosier than chairs")


func test_rug_lies_flat_and_is_moved_and_sold_like_a_fern():
	_to_build()
	game.ledger.money = 100
	assert_not_null(game.rug_at(Vector2i(8, 4)), "the first rug lies under the middle table")
	assert_false(game.grid.is_blocked(Vector2i(8, 4)), "anyone can walk over it")
	assert_true(game.pick_up(Vector3(8.5, 0, 3.5)))
	assert_eq(game.hand.id, "table", "what stands on a rug is picked up first")
	game.cancel_hand()
	assert_true(game.pick_up(Vector3(8.5, 0, 4.5)))
	assert_eq(game.hand.id, "rug")
	assert_null(game.rug_at(Vector2i(8, 4)))
	game.rotate_hand()
	assert_eq(game.rug_cells(Vector2i(6, 3), 1).size(), 6)
	assert_true(game.rug_cells(Vector2i(6, 3), 1).has(Vector2i(7, 2)), "turned, it runs toward +x")
	assert_false(game.can_place(Vector3i(9, 3, 0)), "not half off the floor")
	assert_true(game.place(Vector3i(6, 3, 0)))
	assert_eq(game.ledger.money, 100, "moving is free")
	assert_not_null(game.rug_at(Vector2i(7, 4)))
	assert_true(game.pick_catalog("rug"))
	assert_false(game.can_place(Vector3i(7, 3, 0)), "not on top of another rug")
	assert_true(game.place(Vector3i(6, 0, 0)), "under a table is fine")
	assert_eq(game.ledger.money, 75)
	game.cancel_hand()
	assert_true(game.pick_catalog("floor_planks"))
	assert_false(game.remove_at(Vector3i(7, 4, 0)), "no lifting the floor out from under a rug")
	game.cancel_hand()
	assert_true(game.pick_up(Vector3(5.5, 0, 0.5)))
	assert_true(game.sell_hand())
	assert_eq(game.ledger.money, 87, "half back")
	assert_eq(game.rugs.size(), 1)


func test_paint_and_paper_go_on_walls_and_come_off_for_a_refund():
	_to_build()
	game.ledger.money = 200
	game.ledger.xp = 300
	assert_true(game.pick_catalog("paint"))
	assert_true(game.on_edge("paint"))
	assert_eq(game.finish_drag(Vector3(5, 0, 0), Vector3(8, 0, 0), false), 3, "a row along the back wall")
	assert_eq(game.ledger.money, 185)
	assert_eq(game.plan.finishes.get(Vector3i(6, 0, 0), ""), "paint")
	assert_true(game.pick_catalog("paper_rose"))
	assert_true(game.place(Vector3i(6, 0, 0)))
	assert_eq(game.ledger.money, 170, "$20 for the paper, $5 back for the paint under it")
	assert_true(game.remove_at(Vector3i(6, 0, 0)))
	assert_eq(game.ledger.money, 190)
	assert_false(game.remove_at(Vector3i(6, 0, 0)), "nothing left to strip")
	game.cancel_hand()
	assert_true(game._room.get_child_count() > 0, "the room redraws with its paint")


func test_decor_cheers_a_guest_once_by_how_close_it_is():
	_to_build()
	game.stations[Vector2i(9, 0)].tier = 1
	var on_rug: Vector2i = Vector2i(7, 4)        # the first rug lies under the middle table
	var sees_rug := Vector2i(5, 3)              # two cells off, in sight
	assert_not_null(game.rug_at(on_rug))
	assert_null(game.rug_at(sees_rug))
	var on: float = game.decor_bonus(on_rug).joy
	var seen: float = game.decor_bonus(sees_rug).joy
	gut.p("decor on the rug %.3f, only seeing it %.3f" % [on, seen])
	assert_gt(on, seen, "sitting on the rug beats seeing it")
	assert_eq(game.decor_bonus(on_rug).best, "rug")
	game.plan.floors[sees_rug] = "marble"
	assert_almost_eq(game.decor_bonus(sees_rug).joy - seen, Catalog.joy_of("floor_marble"), 0.0001)
	game.plan.finishes[Vector3i(5, 0, 0)] = "paint"
	game.plan.finishes[Vector3i(6, 0, 0)] = "paper_stripe"
	var near_wall: Array = game.decor_near(Vector2i(5, 1)).filter(func(n: Dictionary) -> bool: return n.id == "paper_stripe")
	assert_eq(near_wall.size(), 1, "the paper is beside the seat")
	assert_eq(int(near_wall[0].dist), 1)
	# Once, on sitting, not every second; and again only if the room changes.
	var g: Guest = game.spawn_guest(0)
	g.seat = on_rug
	g.cell = on_rug
	g.mood.joy = 0.2
	on = game.decor_bonus(on_rug).joy        # the marble is in view of the rug now
	game.cheer_with_decor(g)
	assert_almost_eq(g.mood.joy, 0.2 + on, 0.0001)
	assert_true(g.mood.thoughts.has("Such a cosy rug"))
	game.apply_surroundings(g, 1.0)
	game.cheer_with_decor(g)
	assert_almost_eq(g.mood.joy, 0.2 + on, 0.0001, "no more joy while they sit")
	game.pick_up(Vector3(7.5, 0, 4.5))
	game.sell_hand()
	game.cheer_with_decor(g)
	assert_almost_eq(g.mood.joy, 0.2 + game.decor_bonus(on_rug).joy, 0.0001, "the rug went, and its cheer with it")


func test_seated_guests_get_the_decor_bonus_as_they_sit():
	var g := _seat_at(Vector2i(8, 3), true)     # seat (7, 3), on the rug
	assert_not_null(g)
	if g == null:
		return
	assert_gt(g.decor, 0.0)
	assert_almost_eq(g.decor, game.decor_bonus(g.seat).joy, 0.0001)


# ---------------------------------------------------------------- options screen

func after_each():
	get_tree().paused = false   # a failed options test must not freeze the rest


## A key press as the keyboard (or a controller, through Controls) sends it,
## delivered at once rather than on the next frame.
func _key(key: Key, pressed := true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.keycode = key
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _tap(key: Key) -> void:
	_key(key)
	_key(key, false)


func _tap_pad(button: int) -> void:
	_pad(button, true)
	Input.flush_buffered_events()
	_pad(button, false)
	Input.flush_buffered_events()


func test_options_screen_works_from_the_keyboard():
	var hud = game.hud
	var saved: Dictionary = hud.options.duplicate()
	hud.options.sfx = 0.5
	hud.options.music = 0.5
	_tap(KEY_O)
	assert_true(hud.options_open())
	assert_true(get_tree().paused, "the game waits")
	assert_eq(hud._options_row(), hud._options_tab_row, "the tabs are chosen first")
	_tap(KEY_DOWN)
	_tap(KEY_RIGHT)
	assert_almost_eq(float(hud.options.sfx), 0.6, 0.001, "right turns the sound effects up")
	_tap(KEY_DOWN)
	_tap(KEY_LEFT)
	_tap(KEY_LEFT)
	assert_almost_eq(float(hud.options.music), 0.3, 0.001, "left turns the music down")
	_tap(KEY_DOWN)
	_tap(KEY_DOWN)
	assert_eq(hud._options_row(), hud._options_done, "down stops at Done")
	_tap(KEY_UP)
	_tap(KEY_UP)
	_tap(KEY_UP)
	_tap(KEY_RIGHT)
	assert_eq(hud._options_tab, "graphics", "right on the tabs switches tab")
	var tilt: bool = hud.options.tilt_shift
	_tap(KEY_DOWN)
	_tap(KEY_E)
	assert_eq(bool(hud.options.tilt_shift), not tilt, "E presses the switch")
	_tap(KEY_ENTER)
	assert_eq(bool(hud.options.tilt_shift), tilt, "so does Enter")
	hud.options.merge(saved, true)   # leave the player's own settings file as it was
	_tap(KEY_ESCAPE)
	assert_false(hud.options_open())
	assert_false(get_tree().paused)


func test_options_screen_works_with_a_controller():
	var hud = game.hud
	var saved: Dictionary = hud.options.duplicate()
	hud.options.sfx = 0.5
	_tap_pad(JOY_BUTTON_START)
	assert_true(hud.options_open(), "Start opens the options")
	assert_eq(game.controls.mode, "pad")
	assert_true(hud._options_keys.visible, "the key line shows for a pad")
	assert_string_contains(hud._options_keys.text, "D-pad")
	_tap_pad(JOY_BUTTON_DPAD_DOWN)
	_tap_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_almost_eq(float(hud.options.sfx), 0.6, 0.001, "the d-pad turns a slider")
	var e := InputEventJoypadMotion.new()   # the stick browses too
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = 1.0
	game.controls._input(e)
	game.controls._process(0.01)
	Input.flush_buffered_events()
	assert_almost_eq(float(hud.options.sfx), 0.7, 0.001, "a flick of the stick is one notch")
	e.axis_value = 0.0
	game.controls._input(e)
	game.controls._process(0.01)
	Input.flush_buffered_events()
	_tap_pad(JOY_BUTTON_DPAD_DOWN)
	_tap_pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(hud._options_row(), hud._options_done)
	hud.options.merge(saved, true)
	_tap_pad(JOY_BUTTON_A)
	assert_false(hud.options_open(), "A on Done closes")
	_tap_pad(JOY_BUTTON_START)
	assert_true(hud.options_open())
	_tap_pad(JOY_BUTTON_B)
	assert_false(hud.options_open(), "and so does B")


func test_arrows_do_not_walk_the_chef_while_options_are_open():
	_tap(KEY_O)
	var from: Vector3 = game.player.position
	_key(KEY_RIGHT)
	for i in 10:
		game._process(0.05)
	_key(KEY_RIGHT, false)
	assert_almost_eq(game.player.position.distance_to(from), 0.0, 0.001, "the chef stays put")
	_tap(KEY_ESCAPE)
	assert_false(game.hud.options_open())


func test_options_on_touch_have_big_targets_and_no_highlight():
	game.controls.set_mode("touch")
	game.hud.toggle_options()
	var hud = game.hud
	assert_false(hud._options_keys.visible, "no key line on touch")
	assert_gte(hud._options_done.custom_minimum_size.y, 64.0, "Done fits a thumb")
	var slider: HSlider = hud._options_rows[1].get_meta("slider")
	assert_gte(slider.get_theme_icon("grabber").get_width(), 44, "so does a slider's grabber")
	var ids: Array = game.controls.buttons().map(func(b: Array) -> String: return b[0])
	assert_eq(ids, ["options"], "only the Menu button stays over the card")
	assert_false(game.controls._stick_shown())
	hud.toggle_options()


# ---------------------------------------------------------------- title screen

func test_title_play_starts_the_first_night_from_the_keyboard():
	game.open_title()
	assert_true(game.hud.title_open())
	assert_eq(game.phase, game.Phase.TITLE)
	assert_eq(game.music_id, "title", "Intro plays on the title")
	_run(2.0)
	assert_eq(game.phase, game.Phase.TITLE, "nothing happens behind the title")
	_tap(KEY_DOWN)
	_tap(KEY_UP)
	assert_eq(game.hud.title.sel, 0, "Play is chosen")
	_tap(KEY_ENTER)
	assert_false(game.hud.title_open())
	assert_eq(game.phase, game.Phase.BUILD, "the night before day 1")
	assert_false(game.door_open)


func test_title_play_with_a_controller():
	game.open_title()
	_tap_pad(JOY_BUTTON_A)
	assert_false(game.hud.title_open(), "A presses Play")
	assert_eq(game.phase, game.Phase.BUILD)


func test_title_settings_opens_the_options_and_comes_back():
	game.open_title()
	_tap(KEY_DOWN)
	_tap(KEY_E)
	assert_true(game.hud.options_open(), "Settings opens the options")
	_tap(KEY_DOWN)
	assert_true(game.hud.title_open())
	assert_eq(game.hud.title.sel, 1, "the arrows belong to the options meanwhile")
	_tap(KEY_ESCAPE)
	assert_false(game.hud.options_open())
	assert_true(game.hud.title_open(), "back on the title")
	assert_eq(game.phase, game.Phase.TITLE)


func test_title_quit_where_quitting_is_a_thing():
	game.allow_quit = false
	game.open_title()
	var names: Array = game.hud.title.buttons.map(func(b: Button) -> String: return b.text)
	if not Title.can_quit():
		assert_false(names.has("Quit"), "no Quit on phones or the web")
		return
	assert_eq(names, ["Play", "Settings", "Quit"])
	_tap(KEY_DOWN)
	_tap(KEY_DOWN)
	_tap(KEY_DOWN)
	assert_eq(game.hud.title.sel, 2, "down stops at Quit")
	_tap(KEY_SPACE)
	assert_true(game.quit_asked)
