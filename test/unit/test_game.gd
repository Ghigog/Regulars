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
	game.test_kitchen()   # the old burger line and a one-Burger menu; a run starts empty
	_neutral_tastes()


## Nobody dislikes anything, so every guest orders from the test menu.
func _neutral_tastes() -> void:
	for p in game.town.people:
		p.likes = []
		p.dislikes = []


func _run(seconds: float) -> void:
	for i in int(seconds / 0.1):
		game.step(0.1)


func _use(type: String) -> void:
	game.use_station(game.find_station(type))


func _the_pass() -> Station:
	return game.stations[Vector2i(4, 4)]


## Builds a Burger tray on the pass for the oldest ticket without one, grilling the
## patty for `grill` seconds, and leaves the chef holding it (if it is finished).
func _cook_burger(grill := Station.COOK_TIME + 0.5) -> void:
	_use("trays")
	game.use_station(_the_pass())        # the tray goes down and takes the ticket
	_use("crate_patty")
	_use("stove")
	_run(grill)
	_use("stove")
	game.use_station(_the_pass())        # patty on
	_use("crate_bun")
	game.use_station(_the_pass())        # bun on
	game.use_station(_the_pass())        # picked up, finished


## A guest sat at a table with their order taken.
func _ordered_guest(idx := 0) -> Guest:
	var g: Guest = game.spawn_guest(idx)
	_run(12.0)
	_order(g)
	return g


func test_cooking_fills_a_tray_for_the_ticket():
	var g := _ordered_guest()
	assert_eq(game.tickets.size(), 1, "taking the order puts a ticket on the rail")
	_cook_burger()
	assert_eq(game.player.held, "tray")
	assert_true(game.player.tray.is_complete())
	assert_eq(game.player.tray.ticket, int(g.order.ticket))
	assert_eq(game.find_station("trays").count, Station.TRAYS - 1)


func test_patty_left_on_stove_burns():
	_use("crate_patty")
	_use("stove")
	_run(Station.BURN_TIME + 1.0)
	assert_eq(game.find_station("stove").item, "burnt:patty")
	_use("stove")
	assert_true(game.player.carrying_something_gross())
	assert_eq(game.use_station(_the_pass()), "", "a burnt patty is not put down on the pass")


## The chef takes the order at the guest's table.
func _order(g: Guest) -> void:
	assert_string_contains(game.prompt_for(g.table), "Take")
	game.use_station(g.table)


func test_guest_is_seated_served_and_pays():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	assert_eq(g.state, "ordering")
	_order(g)
	assert_eq(g.state, "waiting")
	_cook_burger()
	game.use_station(g.table)
	assert_eq(g.state, "eating")
	assert_eq(game.player.held, "")
	var table: Station = g.table
	_run(g.eat_time + 0.5)
	assert_eq(g.bill_base, 8, "the Burger: bun 2 and patty 6")
	assert_gt(game.ledger.money, 50 + g.mood.scaled_price(g.bill_base) - 1)
	assert_eq(table.dirty, 1, "a dirty tray is left behind")
	assert_eq(game.tickets.size(), 0, "the ticket is done")
	assert_gt(float(game.town.people[0].affinity), 0.0, "a good visit makes them like the place")


func test_half_price_calms_an_impatient_guest_and_costs_half_the_bill():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	_order(g)
	assert_eq(game.prompt_for(g.table), "", "no discount for a guest who is still happy to wait")
	g.mood.patience = 0.3
	assert_string_contains(game.prompt_for(g.table), "Half price")
	game.use_station(g.table)
	assert_gt(g.mood.patience, 0.6)
	assert_gt(float(game.town.people[0].affinity), 0.0, "kindness is remembered")
	assert_eq(game.prompt_for(g.table), "", "only once")
	_cook_burger()
	game.use_station(g.table)
	_run(g.eat_time + 0.5)
	assert_eq(int(game.ledger.today.sales), ceili(g.mood.scaled_price(g.bill_base) / 2.0), "half of the mood-scaled bill")


func test_free_meal_follows_half_price_for_a_guest_still_fed_up():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	_order(g)
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
	_run(g.eat_time + 0.5)
	assert_eq(int(game.ledger.today.sales), 0)


func test_a_disgusted_guest_can_be_offered_a_free_meal_straight_away():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	_order(g)
	g.mood.disgust = 0.5
	assert_string_contains(game.prompt_for(g.table), "Free meal")


func test_a_guest_who_expects_a_deal_is_let_down_by_full_price():
	game.town.people[0].deals = Town.EXPECT_AT
	var g: Guest = game.spawn_guest(0)
	assert_true(g.mood.thoughts.has("They usually knock something off"))
	_run(12.0)
	_order(g)
	_cook_burger()
	game.use_station(g.table)
	_run(g.eat_time + 0.5)
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
	assert_eq(game.ledger.money, 150 - Town.FLYER_PRICE)
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
	var kitchen: int = Catalog.search("", "Kitchen", Scenery.theme_id).size()
	assert_eq(game.hud._cards.get_child_count(), kitchen)
	game.hud.set_search("fern")
	assert_eq(game.hud._cards.get_child_count(), 3, "a search looks through every category")
	game.hud.set_search("zzz")
	assert_eq(game.hud._cards.get_child_count(), 1, "only the nothing-matches line")
	game.hud._set_category("Kitchen")
	assert_eq(game.hud._search, "", "picking a category ends the search")
	assert_eq(game.hud._cards.get_child_count(), kitchen)
	game.hud.shop_move(-1)
	assert_eq(game.hud._shop_index, kitchen - 1, "left from the first wraps to the last")
	game.hud.shop_category(1)
	assert_eq(game.hud._category, "Dining")
	game.close_shop()
	assert_null(game.hud._shop)
	game.start_day()
	assert_null(game.hud.build_bar)


func test_buying_in_the_shop_puts_the_piece_in_hand_and_shuts_it():
	_to_build()
	game.open_shop()
	assert_false(game.buy({"id": "table4", "tier": 1}), "level 3 and $90")
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
	assert_eq(fresh.night_hint(), fresh.NIGHT_HINTS[0], "the kitchen starts empty")
	assert_null(fresh.find_station("stove"))
	fresh.build_interact()
	assert_eq(fresh.phase, fresh.Phase.BUILD, "no menu yet: the door card stays shut")
	assert_eq(fresh.hud.toast.text, fresh.NIGHT_ZERO_BLOCK)
	fresh.test_kitchen()
	assert_eq(fresh.night_hint(), fresh.NIGHT_HINTS[2])
	fresh.build_interact()
	assert_eq(fresh.phase, fresh.Phase.SERVICE)
	assert_eq(fresh.ledger.money, 150 - fresh.night_cost(), "the stock was paid")
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
	assert_false(game.pick_catalog("table4"), "level 3 and $90")
	assert_true(game.pick_catalog("counter"))
	assert_eq(game.ledger.money, 150, "picking is free")
	assert_false(game.place(Vector3i(9, 4, 0)), "that would block the doorway")
	assert_false(game.place(Vector3i(0, 2, 0)), "a stove is already there")
	assert_true(game.place(Vector3i(2, 4, 0)))
	assert_eq(game.ledger.money, 135)
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
	assert_eq(game.ledger.money, 140)


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
	assert_eq(game.ledger.money, 150)
	assert_true(game.pick_up(Vector3(2.5, 0, 5.5)))
	game.cancel_hand()
	assert_eq(bin.cell, Vector2i(2, 5), "back where it was picked up")
	assert_true(bin.visible)
	assert_false(game.pick_up(Vector3(3.5, 0, 5.5)), "nothing there")


func test_carried_piece_goes_back_when_the_day_opens():
	_to_build()
	var crate: Station = game.find_station("crate_patty")
	assert_true(game.pick_up(Vector3(0.5, 0, 2.5)))
	game.start_day()
	assert_eq(game.stations[Vector2i(0, 2)], crate)
	assert_true(crate.visible)


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
	assert_eq(game.ledger.money, 160)
	assert_false(game.stations.has(Vector2i(9, 0)))
	assert_true(game.pick_up(Vector3(2.5, 0, 2.5)))        # the tray stack
	assert_false(game.sell_hand(), "fixtures are not for sale")
	game.cancel_hand()
	assert_true(game.pick_up(Vector3(0.5, 0, 3.5)))        # one of two stoves
	assert_true(game.sell_hand())
	assert_eq(game.ledger.money, 160 + Catalog.price_of("stove") / 2)
	assert_true(game.pick_up(Vector3(0.5, 0, 4.5)))
	assert_true(game.sell_hand(), "every station can be sold, even the last stove")
	assert_null(game.find_station("stove"))


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
	assert_eq(game.ledger.money, 145)
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


func test_washing_a_dirty_tray_returns_it_to_the_stack():
	var table: Station = game.stations[Vector2i(6, 1)]
	table.dirty = 1
	game.use_station(table)
	assert_eq(game.player.held, "dirty_tray")
	_use("sink")
	assert_eq(game.player.held, "")
	assert_eq(game.find_station("sink").dirty, 1, "it soaks until washed")
	assert_eq(game.find_station("trays").count, 4)
	_use("sink")
	assert_eq(game.find_station("sink").dirty, 0)
	assert_eq(game.find_station("trays").count, 5)
	assert_eq(game.use_station(game.find_station("sink"), true), "", "nothing left to wash")


func test_bin_fills_overflows_and_is_emptied_out_the_front():
	var bin: Station = game.find_station("bin")
	for i in Station.BIN_HOLDS:
		assert_false(bin.overflowing())
		game.player.set_held("burnt:patty")
		game.use_station(bin)
	assert_eq(bin.count, Station.BIN_HOLDS)
	assert_true(bin.overflowing())
	var t := Tray.new()
	t.assign(99, [game.menu.items[0]])
	t.add("prep:bun", 1.0)
	game.player.set_held("tray", 1.0, t)
	assert_eq(game.use_station(bin), "Scrape off", "a full bin still takes scraps")
	assert_true(t.is_empty(), "the tray is kept, its food binned")
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
	assert_false(is_instance_valid(g) and g.seated_waiting())


func test_guest_who_finds_nothing_walks_on_without_a_strike_and_is_counted():
	game.town.people[1].dislikes = ["patty"]
	game.town.people[2].dislikes = ["patty"]
	var party: Array[Guest] = game.spawn_group([1, 2])
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
	var party: Array[Guest] = game.spawn_group([1, 2])
	assert_eq(party[0].state, "queue", "the group goes in")
	assert_true(party[0].planned.main.is_empty())
	assert_true(party[0].mood.thoughts.has(Menu.NOTHING_THOUGHT))
	assert_eq(int(game.ledger.today.found_nothing), 1)


func test_a_meal_with_a_liked_ingredient_says_so():
	game.town.people[2].likes = ["patty"]
	var g: Guest = game.spawn_guest(2)
	_run(12.0)
	game.take_orders(g.table)
	game.serve(g, game.full_tray_for(g))
	assert_true(g.mood.thoughts.has(Menu.LIKED_THOUGHT))
	assert_true(g.liked_meal)


func test_dirty_table_disgusts_guests_unless_a_wall_hides_it():
	game.stations.erase(Vector2i(0, 5))   # no bin, so only the plate is in question
	var g: Guest = game.spawn_guest(2)
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
			if g.cell == want and g.seated_waiting():
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
	_use("crate_patty")
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
	assert_eq(game.hud._guest_state.text, "Waiting to order")
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
	assert_eq(Station.quality_at(Station.NEARLY_TIME - 0.1), 0.0, "still raw")
	assert_eq(Station.quality_at(Station.COOK_TIME - 0.1), Prep.PLAIN, "underdone is plain")
	assert_eq(Station.quality_at(Station.COOK_TIME + 1.0), Prep.GOOD)
	assert_lt(Station.quality_at(Station.BURN_TIME - 0.5), 0.5)
	var g := _ordered_guest(4)
	_cook_burger(Station.BURN_TIME - 1.0)
	assert_eq(game.player.held, "tray")
	assert_lt(game.player.tray.quality(), 0.7, "a dried-out patty and a plain bun")
	game.use_station(g.table)
	assert_lt(g.mood.savour, 0.7)
	assert_true(g.mood.thoughts.has("A bit off, this"))


func test_prompt_names_the_action_without_doing_it():
	var crate: Station = game.find_station("crate_patty")
	assert_eq(game.prompt_for(crate), "Take patty")
	assert_eq(game.player.held, "")
	_use("crate_patty")
	assert_eq(game.prompt_for(crate), "Put back")
	assert_eq(game.prompt_for(game.find_station("stove")), "Grill")
	assert_eq(game.prompt_for(game.find_station("crate_bun")), "", "hands are full")


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
	assert_eq(Station.quality_at(Station.NEARLY_TIME - 0.1), 0.0)
	assert_eq(Build.look_for("prep:patty", Station.quality_at(Station.PERFECT_END + 2.0)), "dry")


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
	_use("crate_patty")
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


# ---------------------------------------------------------------- input per player

## A controller button, delivered straight to Controls (no fake keys, no frames).
func _pad(button: int, pressed: bool, device := 0) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = pressed
	game.controls._input(e)


func _tap_pad(button: int, device := 0) -> void:
	_pad(button, true, device)
	_pad(button, false, device)


func _axis(axis: int, value: float, device := 0) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = axis
	e.axis_value = value
	game.controls._input(e)


func test_the_last_device_used_sets_the_mode_and_the_hints():
	assert_eq(game.controls.mode, "keys")
	_tap_pad(JOY_BUTTON_B)
	assert_eq(game.controls.mode, "pad")
	assert_eq(game.controls.input_of(0).source, "pad:0")
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


func test_left_stick_and_d_pad_walk_the_chef():
	_axis(JOY_AXIS_LEFT_X, 1.0)
	assert_eq(game.controls.move(0), Vector2(1, 0))
	var from: Vector3 = game.player.position
	for i in 10:
		game._process(0.05)
	assert_gt(game.player.position.distance_to(from), 0.5, "the chef walked")
	_axis(JOY_AXIS_LEFT_X, 0.1)
	assert_eq(game.controls.move(0), Vector2.ZERO, "inside the dead zone")
	_pad(JOY_BUTTON_DPAD_UP, true)
	assert_eq(game.controls.move(0), Vector2(0, 1), "the d-pad walks too")
	_pad(JOY_BUTTON_DPAD_UP, false)
	assert_eq(game.controls.move(0), Vector2.ZERO)


func test_pad_buttons_become_actions_for_the_phase():
	_to_build()
	game.ledger.money = 100
	_tap_pad(JOY_BUTTON_Y)
	assert_true(game.shopping, "Y opens the shop")
	_tap_pad(JOY_BUTTON_B)
	assert_false(game.shopping, "B closes it")
	assert_true(game.pick_catalog("plant"))
	_tap_pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(int(game.hand.facing), 1, "a shoulder button turns the piece")
	_tap_pad(JOY_BUTTON_B)
	assert_true(game.hand.is_empty(), "B puts it back")


func test_a_confirms_the_receipt_and_y_opens_the_town_book():
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.phase, game.Phase.SUMMARY)
	_tap_pad(JOY_BUTTON_Y)
	assert_true(game.hud._town_open, "Y opens the town book")
	_tap_pad(JOY_BUTTON_Y)
	_tap_pad(JOY_BUTTON_A)
	assert_eq(game.phase, game.Phase.BUILD, "A carries on to the build phase")


func test_holding_use_with_a_floor_tool_paves_ahead_on_any_device():
	_to_build()
	game.ledger.money = 100
	assert_true(game.pick_catalog("floor_planks"))
	game.player.position = Grid.center(Vector2i(5, 0))
	game.player.look(Vector2i(0, -1))
	_pad(JOY_BUTTON_A, true)
	assert_true(game.plan.has_floor(Vector2i(5, -1)), "the press lays the first board")
	assert_true(game.controls.holding(0, "use"))
	game.player.position = Grid.center(Vector2i(6, 0))
	game._paint_held(0)
	assert_true(game.plan.has_floor(Vector2i(6, -1)), "held, it keeps laying")
	_pad(JOY_BUTTON_A, false)
	assert_false(game.controls.holding(0, "use"))
	game.player.position = Grid.center(Vector2i(7, 0))
	game._paint_held(0)
	assert_false(game.plan.has_floor(Vector2i(7, -1)), "let go, it stops")


func test_each_device_is_routed_to_the_player_it_is_seated_to():
	var c: Controls = game.controls
	assert_eq(c.owner_of("pad:3"), 0, "with one chef, every device is player one's")
	c.seat("pad:1", 1)
	assert_eq(c.players.size(), 2)
	_axis(JOY_AXIS_LEFT_X, 1.0, 1)
	_pad(JOY_BUTTON_A, true, 1)
	assert_eq(c.input_of(1).mode, "pad")
	assert_eq(c.move(1), Vector2(1, 0), "player two steers")
	assert_true(c.holding(1, "use"))
	assert_eq(c.mode, "keys", "player one's hints are unchanged")
	assert_eq(c.move(0), Vector2.ZERO, "and player one stands still")
	assert_false(c.holding(0, "use"))
	_pad(JOY_BUTTON_A, false, 1)
	_tap_pad(JOY_BUTTON_START, 1)
	assert_true(game.hud.options_open(), "the options screen is shared")
	game.hud.toggle_options()


func test_touch_joystick_and_buttons_never_reach_the_room():
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = game.controls._stick_home()
	game.controls._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.position = touch.position + Vector2(200, 0)
	game.controls._input(drag)
	assert_almost_eq(game.controls.move(0).x, 1.0, 0.01, "dragged to the right edge")
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = touch.position
	game.controls._input(mouse)
	assert_true(game.controls.owns_pointer(), "the mouse made from that touch is swallowed")
	touch.pressed = false
	game.controls._input(touch)
	assert_eq(game.controls.move(0), Vector2.ZERO, "let go")
	var ids := []
	for b: Array in game.controls.buttons():
		ids.append(b[0])
	assert_has(ids, "use", "a Use button during service")


func test_touch_buttons_press_and_hold_their_action():
	_to_build()
	game.ledger.money = 100
	game.controls.set_mode("touch")
	var shop: Array = game.controls.buttons().filter(func(b: Array) -> bool: return b[0] == "shop")[0]
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = shop[2]
	game.controls._input(touch)
	assert_true(game.shopping, "Shop opens the shop")
	touch.pressed = false
	game.controls._input(touch)
	game.close_shop()
	assert_true(game.pick_catalog("floor_planks"))
	var use: Array = game.controls.buttons().filter(func(b: Array) -> bool: return b[0] == "use")[0]
	touch.position = use[2]
	touch.pressed = true
	game.controls._input(touch)
	assert_true(game.controls.holding(0, "use"), "Use is held while the finger stays")
	touch.pressed = false
	game.controls._input(touch)
	assert_false(game.controls.holding(0, "use"))


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


## The share of `id` a seat really gets, from decor_near once a piece is placed.
func _placed_share(seat: Vector2i, id: String) -> float:
	var best := 0.0
	for n: Dictionary in game.decor_near(seat):
		if n.id == id:
			best = maxf(best, Decor.share(id, int(n.dist), int(n.get("tier", 1))))
	return best


## Checks every seat's mark against what it gets once placed; returns the marks seen.
func _marks_tell_the_truth(marks: Dictionary, id: String) -> Dictionary:
	var seen := {}
	for s: Vector2i in marks:
		assert_eq(marks[s].share, _placed_share(s, id), "%s at %s" % [id, s])
		seen[marks[s].mark] = true
	return seen


func test_a_marble_drag_shows_every_seat_it_would_cheer():
	_to_build()
	game.ledger.xp = 500
	game.ledger.money = 1000
	assert_true(game.pick_catalog("floor_marble"))
	var drag := {"from": Vector3(6.5, 0, 2.5), "remove": false}
	var pr: Dictionary = game.piece_reach(game.hand, Vector3(9.5, 0, 4.5), drag)
	assert_eq(pr.area, Rect2i(), "no pale square for a floor")
	var marks: Dictionary = game.reach_marks(pr)
	for s: Vector2i in [Vector2i(7, 3), Vector2i(9, 3)]:
		assert_eq(marks[s].mark, Decor.MARK_ON, "every seat on the rectangle")
	assert_eq(marks[Vector2i(7, 1)].mark, Decor.MARK_BESIDE)
	assert_eq(game.piece_reach(game.hand, Vector3(9.5, 0, 4.5), {"from": drag.from, "remove": true}), {},
		"nothing for a removing drag")
	# A narrower strip, really laid: on, in view and out of reach all match.
	drag = {"from": Vector3(9.5, 0, 3.5), "remove": false}
	marks = game.reach_marks(game.piece_reach(game.hand, Vector3(9.5, 0, 4.5), drag))
	assert_gt(game.finish_drag(drag.from, Vector3(9.5, 0, 4.5), false), 0)
	var seen := _marks_tell_the_truth(marks, "floor_marble")
	for m in [Decor.MARK_ON, Decor.MARK_VIEW, Decor.MARK_NONE]:
		assert_true(seen.has(m), "the strip reaches seats %s (seen %s)" % [m, seen.keys()])
	game.cancel_hand()
	assert_true(game.pick_catalog("floor_tile"))
	assert_eq(game.piece_reach(game.hand, Vector3(6.5, 0, 2.5), {}), {}, "plain tile shows nothing")


func test_a_carried_rug_shows_its_reach_truly():
	_to_build()
	assert_true(game.pick_up(Vector3(8.5, 0, 4.5)))   # the old rug goes, so only the new one counts
	assert_true(game.sell_hand())
	game.ledger.money = 100
	assert_true(game.pick_catalog("rug"))
	var pr: Dictionary = game.piece_reach(game.hand, Vector3(6.5, 0, 1.5), {})
	assert_true(pr.area.has_point(Vector2i(9, 3)), "the rug keeps a square, VIEW_RANGE round it")
	var marks: Dictionary = game.reach_marks(pr)
	assert_true(game.place(Vector3i(6, 1, 0)))
	var seen := _marks_tell_the_truth(marks, "rug")
	for m in [Decor.MARK_ON, Decor.MARK_BESIDE, Decor.MARK_VIEW]:
		assert_true(seen.has(m), "the rug reaches seats %s (seen %s)" % [m, seen.keys()])
	game.cancel_hand()
	game._update_range()
	assert_eq(game._range_key, "", "nothing in hand, no marks")


func test_paint_marks_the_seats_against_the_wall_and_in_view():
	_to_build()
	game.ledger.xp = 500
	game.ledger.money = 1000
	assert_true(game.pick_catalog("paper_rose"))
	var drag := {"from": Vector3(4, 0, 0), "remove": false}
	var pr: Dictionary = game.piece_reach(game.hand, Vector3(10, 0, 0), drag)
	assert_eq(pr.area, Rect2i(), "no pale square for a wall")
	var marks: Dictionary = game.reach_marks(pr)
	assert_eq(marks[Vector2i(5, 1)].mark, Decor.MARK_BESIDE, "against the wall")
	assert_gt(game.finish_drag(drag.from, Vector3(10, 0, 0), false), 0)
	var seen := _marks_tell_the_truth(marks, "paper_rose")
	assert_true(seen.has(Decor.MARK_VIEW) and seen.has(Decor.MARK_NONE), "seen %s" % [seen.keys()])
	assert_false(seen.has(Decor.MARK_ON), "nobody sits on a wall")
	game._drag = drag
	game._demo_hover = Vector3(10, 0, 0)
	game._update_range()
	assert_gt(game._range_marks.get_child_count(), 5, "a mark for every seat")


func test_a_seat_at_the_decor_cap_is_marked_full():
	_to_build()
	game.ledger.xp = 500
	game.ledger.money = 1000
	assert_true(game.pick_catalog("floor_marble"))
	assert_eq(game.finish_drag(Vector3(9.5, 0, 3.5), Vector3(9.5, 0, 3.5), false), 1)
	assert_true(Decor.is_full(game.decor_near(Vector2i(9, 3))), "on the rug and on marble")
	assert_true(game.pick_catalog("paint"))
	var marks: Dictionary = game.reach_marks(game.piece_reach(game.hand, Vector3(10, 0, 3.5), {}))
	assert_gt(marks[Vector2i(9, 3)].share, 0.0)
	assert_true(marks[Vector2i(9, 3)].full, "more decor adds nothing there")
	assert_false(marks[Vector2i(5, 1)].full)


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
	Scenery.theme_id = "diner"   # a seaside test must not leak its theme


## A key press as the keyboard sends it, delivered at once rather than on the
## next frame.
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
	_axis(JOY_AXIS_LEFT_X, 1.0)   # the stick browses too
	game.controls._process(0.01)
	game.controls._process(0.01)
	assert_almost_eq(float(hud.options.sfx), 0.7, 0.001, "a flick of the stick is one notch")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	game.controls._process(0.01)
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


func test_a_tool_in_hand_draws_its_ghost_every_frame_without_errors():
	_to_build()
	game.ledger.money = 100
	for id in ["floor_tile", "wall", "door", "arch", "paint"]:
		assert_true(game.pick_catalog(id), id)
		game._demo_hover = Vector3(3.5, 0, 1.5)
		game._update_ghost()   # no drag: the one spot under the hover point
		assert_not_null(game._tool_ghost, "%s shows a ghost" % id)
		game._drag = {"from": Vector3(0.5, 0, 1.5), "remove": false}
		game._update_ghost()   # mid-drag: every spot along it
		game._drag = {}
		game.cancel_hand()


func _closest_pair(list: Array) -> float:
	var worst := 99.0
	for i in list.size():
		for j in range(i + 1, list.size()):
			var d: Vector3 = list[i].position - list[j].position
			worst = minf(worst, Vector2(d.x, d.z).length())
	return worst


func test_everyone_in_line_has_their_own_place_and_the_line_moves_up():
	for i in 14:
		game.spawn_guest(i)
	_run(15.0)
	assert_gt(game.queue.size(), 6, "more guests than tables, so a long line")
	var spots := {}
	for i in game.queue.size():
		var g: Guest = game.queue[i]
		assert_almost_eq(g.position.distance_to(game.queue_spot(i)), 0.0, 0.01, "%s stands in their place" % g.info.name)
		spots[g.goal] = true
	assert_eq(spots.size(), game.queue.size(), "no two share a place")
	assert_gt(_closest_pair(game.queue), game.QUEUE_GAP - 0.01)
	var second: Guest = game.queue[1]
	game.walk_out(game.queue[0])
	_run(3.0)
	assert_eq(game.queue[0], second)
	assert_almost_eq(second.position.distance_to(game.queue_spot(0)), 0.0, 0.01, "the line steps up")


func test_a_group_comes_in_single_file_not_stacked():
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	for i in 6:
		game.spawn_guest(i)    # the tables fill, so the four have to queue too
	var four: Array[Guest] = game.spawn_group([6, 7, 8, 9])
	var worst := 99.0
	for i in 120:
		game.step(0.1)
		worst = minf(worst, _closest_pair(four))
	assert_gt(worst, 0.5, "friends keep a little apart all the way to the line")


func test_a_rush_never_walks_guests_through_one_another():
	game.arrivals.assign([{"time": 0.3, "group": [0, 1]}, {"time": 0.6, "idx": 2},
		{"time": 0.9, "group": [3, 4, 5]}, {"time": 1.2, "idx": 6}, {"time": 1.5, "group": [7, 8]},
		{"time": 1.8, "group": [9, 10, 11, 12]}, {"time": 2.1, "idx": 13}])
	var worst := 99.0
	for i in 900:
		game.step(0.1)
		if i % 50 == 0:
			for g: Guest in game.guests.duplicate():
				if g.state == "ordering":
					game.take_orders(g.table)
				if g.state == "waiting":
					game.serve(g, game.full_tray_for(g))
		worst = minf(worst, _closest_pair(game.guests))
	assert_gt(worst, 0.3, "people step round or wait, never pass through")
	assert_eq(game.guests.size(), 0, "nobody is left stuck on the pavement")


func test_a_seated_guest_waits_to_order_with_a_notepad_bubble():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	assert_eq(g.state, "ordering")
	assert_true(g.order.is_empty())
	assert_eq(g._order.get_meta("icon"), "order", "the bubble asks for the chef")
	assert_eq(game.prompt_for(g.table), "Take order")
	_order(g)
	assert_eq(g.state, "waiting")
	assert_eq(g.order.main.name, "Burger", "an order is data on the guest: menu items and a ticket")
	assert_true(g.order.side.is_empty() and g.order.drink.is_empty(), "the test menu has no side or drink")
	assert_eq(int(g.order.ticket), int(game.tickets[0].id))
	_run(0.2)
	assert_eq(g._order.get_meta("icon"), "dish:bun,patty", "the bubble shows what they ordered")


func test_waiting_to_order_drains_patience_faster_than_waiting_for_food():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	g.mood.patience = 0.9
	_run(2.0)
	var ordering_drop: float = 0.9 - g.mood.patience
	assert_gt(ordering_drop, 0.0)
	_order(g)
	g.mood.patience = 0.9
	_run(2.0)
	var food_drop: float = 0.9 - g.mood.patience
	assert_gt(ordering_drop, food_drop * 1.1, "being ignored at the table wears thin quicker")


func test_an_ignored_guest_walks_out_before_ordering():
	var g: Guest = game.spawn_guest(1)
	_run(12.0)
	assert_eq(g.state, "ordering")
	g.mood.patience = 0.01
	_run(1.0)
	assert_eq(game.ledger.strikes(), 1)


func test_a_group_orders_together_in_one_go():
	var pair: Array[Guest] = game.spawn_group([0, 1])
	_run(14.0)
	assert_eq(pair[0].state, "ordering")
	assert_eq(pair[1].state, "ordering")
	assert_eq(game.prompt_for(pair[0].table), "Take 2 orders")
	game.use_station(pair[0].table)
	for g in pair:
		assert_eq(g.state, "waiting")
		assert_eq(g.order.main.name, "Burger")
	assert_eq(game.tickets.size(), 2, "a ticket each")
	assert_eq(game.prompt_for(pair[0].table), "", "nothing left to take")


func test_serving_a_guest_who_has_not_ordered_is_refused():
	var g: Guest = game.spawn_guest(0)
	_run(12.0)
	_use("trays")
	assert_eq(game.prompt_for(g.table), "Take order first")
	game.use_station(g.table)
	assert_eq(g.state, "ordering", "still waiting to order")
	assert_eq(game.player.held, "tray", "the chef keeps the tray")
	_use("trays")    # put it back, take the order, then cook
	game.take_orders(g.table)
	_cook_burger()
	assert_string_contains(game.prompt_for(g.table), "Serve")
	game.use_station(g.table)
	assert_eq(g.state, "eating")


func test_guest_card_says_waiting_to_order():
	assert_eq(Hud.STATE_WORDS.ordering, "Waiting to order")


func _serve_one(idx: int, joy: float, patience: float) -> Guest:
	var g: Guest = game.spawn_guest(idx)
	_run(12.0)
	_order(g)
	_cook_burger()
	g.mood.joy = joy
	g.mood.patience = patience
	g.mood.disgust = 0.0
	game.use_station(g.table)
	return g


func test_a_comfortable_guest_eats_longer_and_pays_more():
	var cosy := _serve_one(0, 1.0, 1.0)
	assert_true(cosy.mood.thoughts.has(GuestMood.COSY_THOUGHTS[0]))
	var start := int(game.ledger.today.sales)
	_run(Guest.EAT_TIME + 0.5)
	assert_eq(cosy.state, "eating", "still lingering after the plain eating time")
	_run(cosy.eat_time)
	var cosy_paid := int(game.ledger.today.sales) - start
	var rushed := _serve_one(1, 0.0, 0.1)
	assert_true(rushed.mood.thoughts.has(GuestMood.HURRIED_THOUGHTS[1]))
	assert_lt(rushed.eat_time, cosy.eat_time)
	start = int(game.ledger.today.sales)
	_run(rushed.eat_time + 0.5)
	assert_eq(rushed.state, "leaving")
	var rushed_paid := int(game.ledger.today.sales) - start
	assert_gt(cosy_paid, cosy.bill_base)
	assert_lt(rushed_paid, rushed.bill_base)


# ---------- Night cleaning (PRD 5) ----------

func _face(cell: Vector2i, dir: Vector2i) -> void:
	game.player.position = Grid.center(cell)
	game.player.look(dir)


func _face_table() -> void:
	_face(Vector2i(8, 2), Vector2i(0, 1))   # the table at (8, 3)


func _face_sink() -> void:
	_face(Vector2i(3, 3), Vector2i(0, -1))  # the sink at (3, 2)


func _dirty_table(plates := 1) -> Station:
	var t: Station = game.stations[Vector2i(8, 3)]
	t.dirty = plates
	t.refresh()
	return t


func test_mess_carries_over_from_one_day_to_the_next():
	var t := _dirty_table()
	var sink: Station = game.find_station("sink")
	var bin: Station = game.find_station("bin")
	sink.dirty = Station.SINK_PILED
	bin.count = Station.BIN_HOLDS
	_run(1.0)
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.phase, game.Phase.SUMMARY)
	var ages := [t.dirty_age, sink.dirty_age, bin.dirty_age]
	assert_gt(float(ages[0]), 0.9)
	game.open_build()
	_run(1.0)
	game.start_day()
	assert_eq(t.dirty, 1)
	assert_eq(sink.dirty, Station.SINK_PILED)
	assert_eq(bin.count, Station.BIN_HOLDS)
	assert_eq([t.dirty_age, sink.dirty_age, bin.dirty_age], ages, "yesterday's mess is already old")
	game.step(0.01)
	var kinds := []
	for s in game._gross:
		kinds.append(s.kind)
	assert_true(kinds.has("plate"))
	assert_true(kinds.has("sink"))
	assert_true(kinds.has("overflow"))


func test_night_cleaning_clears_a_table_and_washes_up():
	_to_build()
	var t := _dirty_table(2)
	var sink: Station = game.find_station("sink")
	var plates: Station = game.find_station("trays")
	var stack := plates.count
	_face_table()
	assert_eq(game.build_action(), "Clear table", "cleaning comes before picking up")
	game.build_interact()
	assert_eq(game.player.held, "dirty_tray")
	assert_eq(t.dirty, 1)
	assert_eq(game.build_action(), "", "a plate in hand: nothing is picked up")
	assert_true(game.dirty_note().contains("a table"))
	_face_sink()
	assert_eq(game.build_action(), "Put in sink")
	game.build_interact()
	assert_eq(game.player.held, "")
	assert_eq(sink.dirty, 1)
	assert_eq(game.build_action(), "Wash up")
	game.build_interact()
	assert_eq(sink.dirty, 0)
	assert_eq(plates.count, stack + 1)


func test_night_cleaning_takes_the_bag_out():
	_to_build()
	var bin: Station = game.find_station("bin")
	bin.count = Station.BIN_HOLDS
	_face(Vector2i(1, 5), Vector2i(-1, 0))
	assert_eq(game.build_action(), "Take the bag out")
	assert_eq(game.dirty_note(), "Still dirty: the bin.")
	game.build_interact()
	assert_eq(game.player.held, "rubbish_bag")
	assert_eq(bin.count, 0)
	assert_eq(game.dirty_note(), "", "nothing left once the bag is out of the bin")


func test_a_messy_table_cannot_be_moved_or_sold_until_cleared():
	_to_build()
	_dirty_table()
	var spot := Grid.center(Vector2i(8, 3))
	assert_false(game.pick_up(spot), "clean it first")
	assert_true(game.hand.is_empty())
	_face_table()
	game.build_interact()
	assert_false(game.pick_up(spot), "not with a dirty plate in hand")
	_face_sink()
	game.build_interact()
	assert_true(game.pick_up(spot))
	assert_true(game.sell_hand())


func test_the_shop_stays_shut_while_carrying_a_dirty_tray():
	_to_build()
	_dirty_table()
	_face_table()
	game.build_interact()
	game.open_shop()
	assert_false(game.shopping)
	assert_false(game.pick_catalog("plant"))
	game.cancel_hand()
	assert_eq(game.player.held, "dirty_tray", "Back does nothing to a carried plate")


func test_mess_does_not_age_at_night_and_a_carried_plate_goes_into_service():
	_to_build()
	var sink: Station = game.find_station("sink")
	sink.dirty = Station.SINK_PILED
	sink.dirty_age = 5.0
	_dirty_table()
	_run(2.0)
	assert_eq(sink.dirty_age, 5.0)
	_face_table()
	game.build_interact()
	game.start_day()
	assert_eq(game.player.held, "dirty_tray")


# ---------- Tickets and trays (PRD 1) ----------

func test_a_one_item_tray_goes_from_ticket_to_paid_bill():
	var g := _ordered_guest()
	var rail: int = game.hud.ticket_rail.get_child_count()
	assert_eq(rail, 1, "the ticket is on the rail")
	_cook_burger()
	assert_string_contains(game.prompt_for(g.table), "Serve")
	game.use_station(g.table)
	var before: int = game.ledger.money
	_run(g.eat_time + 0.5)
	assert_eq(game.ledger.money - before - int(game.ledger.today.tips), g.mood.scaled_price(8))


func test_a_three_item_tray_is_one_bill():
	game.add_station("crate_soda", Vector2i(2, 5))
	var side: Dictionary = game.menu.add("side", ["bun"], "Bread")
	var drink: Dictionary = game.menu.add("drink", ["soda"], "Soda")
	game.town.people[0].likes = ["bun", "soda"]
	var g := _ordered_guest()
	assert_eq(g.order.side.id, side.id, "a liked side is added")
	assert_eq(g.order.drink.id, drink.id, "and a liked drink")
	# Tray down, then each piece in any order: the bun goes to the main first.
	_use("trays")
	game.use_station(_the_pass())
	var t: Tray = _the_pass().tray
	for k in ["crate_bun", "crate_soda", "crate_bun"]:
		if k == "crate_soda":
			_pour(game.find_station(k), Prep.POUR_GOOD + 0.05)
		else:
			_use(k)
		game.use_station(_the_pass())
	assert_eq(game.use_station(_the_pass(), true), "Needs patty")
	_use("crate_patty")
	_use("stove")
	_run(Station.COOK_TIME + 0.5)
	_use("stove")
	game.use_station(_the_pass())
	assert_true(t.is_complete())
	assert_eq(t.price(), 8 + 2 + 3)
	game.use_station(_the_pass())
	game.use_station(g.table)
	_run(g.eat_time + 0.5)
	assert_eq(int(game.ledger.today.sales), g.mood.scaled_price(13), "one bill for the whole tray")


func test_a_tray_refuses_what_its_ticket_does_not_need_or_raw_food():
	var g := _ordered_guest()
	_use("trays")
	game.use_station(_the_pass())
	game.player.set_held("raw:patty")
	assert_eq(game.use_station(_the_pass()), "Patty needs grilling first")
	assert_eq(game.player.held, "raw:patty", "kept in hand")
	game.player.set_held("prep:cheese")
	assert_eq(game.use_station(_the_pass()), "No cheese on this ticket")
	game.player.set_held("prep:bun")
	assert_eq(game.use_station(_the_pass()), "Add bun")
	game.player.set_held("prep:bun")
	assert_eq(game.use_station(_the_pass()), "No bun on this ticket", "one bun is enough")
	assert_eq(_the_pass().tray.ticket, int(g.order.ticket))


func test_an_incomplete_tray_cannot_be_picked_up():
	_ordered_guest()
	_use("trays")
	game.use_station(_the_pass())
	_use("crate_bun")
	game.use_station(_the_pass())
	assert_eq(game.use_station(_the_pass()), "Needs patty")
	assert_eq(game.player.held, "")
	assert_eq(_the_pass().item, "tray")


func test_turn_moves_an_empty_tray_to_the_next_ticket():
	var pair: Array[Guest] = game.spawn_group([0, 1])
	_run(14.0)
	game.use_station(pair[0].table)
	assert_eq(game.tickets.size(), 2)
	_use("trays")
	game.use_station(_the_pass())
	var t: Tray = _the_pass().tray
	assert_eq(t.ticket, int(game.tickets[0].id), "an empty tray takes the oldest ticket")
	game.player.position = Grid.center(Vector2i(3, 4))
	game.player.look(Vector2i(1, 0))
	game.act(0, "turn")
	assert_eq(t.ticket, int(game.tickets[1].id), "Turn moves it on")
	game.act(0, "turn")
	assert_eq(t.ticket, int(game.tickets[0].id), "and round again")


func test_a_ticket_is_torn_off_when_its_guest_walks_out():
	var g := _ordered_guest()
	_use("trays")
	game.use_station(_the_pass())
	_use("crate_bun")
	game.use_station(_the_pass())
	g.mood.patience = 0.0
	_run(0.5)
	assert_eq(game.tickets.size(), 0)
	var t: Tray = _the_pass().tray
	assert_eq(t.ticket, -1, "the tray shows no ticket")
	assert_false(t.is_empty(), "but keeps what is on it")
	assert_eq(game.use_station(_the_pass()), "Pick up tray", "so it can be binned")
	assert_eq(game.use_station(game.find_station("bin")), "Scrape off")


func test_a_guest_who_finds_no_main_keeps_friends_company():
	game.town.people[1].dislikes = ["patty"]
	var pair: Array[Guest] = game.spawn_group([0, 1])
	_run(14.0)
	game.use_station(pair[0].table)
	assert_eq(pair[0].state, "waiting")
	assert_eq(pair[1].state, "company", "nothing they would eat, and no drink on the menu")
	assert_eq(game.tickets.size(), 1)
	_cook_burger()
	game.use_station(pair[0].table)
	_run(pair[0].eat_time + 0.5)
	assert_eq(pair[1].state, "leaving", "they go with their friend")
	assert_eq(game.ledger.strikes(), 0)


# ---------- Prep minigames (PRD 1, milestone 3) ----------

## Holds Use at a drink station until the cup is `fill` full, then lets go.
func _pour(st: Station, fill: float) -> void:
	var who: PlayerInput = game.controls.players[0]
	assert_eq(game.use_station(st), "Pour %s" % Pantry.name_of(Catalog.ingredient_of(st.type)).to_lower())
	who.hold("test", "a", "use", true)
	while game.prep_of(0).get("fill", 9.0) < fill:
		game.step(0.02)
	who.hold("test", "a", "use", false)
	game.step(0.02)


## Plays the chop minigame, pressing Use on the notch for the first `hits` sweeps.
func _chop(hits: int) -> void:
	for k in Prep.CHOP_SWEEPS:
		var notch := (k + 0.5) * Prep.CHOP_SWEEP_TIME
		while float(game.prep_of(0).get("t", 99.0)) < notch:
			game.step(0.01)
		if k < hits:
			game.act(0, "use")
	_run(Prep.CHOP_SWEEP_TIME)


func _tool(type: String, cell: Vector2i, crate: String) -> Station:
	game.add_station(crate, cell + Vector2i(0, 1))
	return game.add_station(type, cell)


func test_chopping_all_three_on_the_notch_is_good_and_speeds_the_chef():
	var board := _tool("board", Vector2i(2, 5), "crate_lettuce")
	_use("crate_lettuce")
	assert_eq(game.player.held, "raw:lettuce")
	assert_eq(game.use_station(board), "Chop")
	assert_eq(game.player.held, "", "the lettuce goes on the board")
	assert_false(game.prep_of(0).is_empty())
	_chop(3)
	assert_true(game.prep_of(0).is_empty(), "the minigame is over")
	assert_eq(game.player.held, "prep:lettuce")
	assert_eq(game.player.held_quality, Prep.GOOD)
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.BURST_SPEED, 0.01, "a good result is a burst")
	_run(Prep.BOOST_TIME + 0.1)
	assert_eq(game.player.speed(), Player.SPEED, "for one second")


func test_a_bad_chop_slows_the_chef_and_a_plain_one_does_neither():
	var board := _tool("board", Vector2i(2, 5), "crate_onion")
	_use("crate_onion")
	game.use_station(board)
	_chop(0)
	assert_eq(game.player.held_quality, Prep.BAD)
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.PENALTY_SPEED, 0.01, "a bad result slows")
	_run(Prep.BOOST_TIME + 0.1)
	assert_eq(game.player.speed(), Player.SPEED)
	game.player.set_held("")
	_use("crate_onion")
	game.use_station(board)
	_chop(2)
	assert_eq(game.player.held_quality, Prep.PLAIN)
	assert_eq(game.player.speed(), Player.SPEED, "plain does neither")


func test_the_chef_stands_still_and_back_gives_the_ingredient_back_raw():
	var board := _tool("board", Vector2i(2, 5), "crate_tomato")
	_use("crate_tomato")
	game.use_station(board)
	var at: Vector3 = game.player.position
	_axis(JOY_AXIS_LEFT_X, 1.0)
	for i in 4:
		game._process(0.05)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	assert_eq(game.player.position, at, "no walking off mid-chop")
	game.act(0, "back")
	assert_true(game.prep_of(0).is_empty())
	assert_eq(game.player.held, "raw:tomato")
	assert_eq(board.item, "")


func test_slicing_to_the_count_is_good_and_over_it_is_plain():
	var slicer := _tool("slicer", Vector2i(2, 5), "crate_cheese")
	for presses: int in [Prep.SLICE_COUNT, Prep.SLICE_COUNT + 2, Prep.SLICE_COUNT - 1]:
		game.player.set_held("")
		_use("crate_cheese")
		assert_eq(game.use_station(slicer), "Slice")
		for k in presses:
			game.act(0, "use")
			game.step(0.05)
		_run(Prep.SLICE_TIME)
		assert_eq(game.player.held, "prep:cheese")
		assert_eq(game.player.held_quality, {Prep.SLICE_COUNT: Prep.GOOD, Prep.SLICE_COUNT + 2: Prep.PLAIN}.get(presses, Prep.BAD), "%d presses" % presses)


func test_a_tool_refuses_what_it_does_not_prep():
	var board := _tool("board", Vector2i(2, 5), "crate_cheese")
	_use("crate_cheese")
	assert_eq(game.use_station(board, true), "Cheese doesn't go on the chopping board")


func test_pouring_into_the_top_band_is_good_and_overflowing_is_bad():
	var fountain: Station = game.add_station("crate_soda", Vector2i(2, 5))
	_pour(fountain, 0.9)
	assert_eq(game.player.held, "prep:soda")
	assert_eq(game.player.held_quality, Prep.GOOD)
	game.player.set_held("")
	_pour(fountain, 0.7)
	assert_eq(game.player.held_quality, Prep.PLAIN)
	game.player.set_held("")
	_pour(fountain, 2.0)   # never let go: it overflows and ends itself
	assert_eq(game.player.held_quality, Prep.BAD)


func test_fries_rest_on_the_rack_before_they_can_be_picked_up():
	var fryer := _tool("fryer", Vector2i(2, 5), "crate_potato")
	_use("crate_potato")
	assert_eq(game.use_station(fryer), "Fry")
	_run(Prep.FRY_GOOD + 0.5)
	assert_eq(game.use_station(fryer), "Lift basket")
	assert_eq(game.player.held, "", "lifted onto the rack, not into the hands")
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.BURST_SPEED, 0.01, "lifted in the window")
	assert_eq(game.use_station(fryer, true), "Still draining")
	_run(Prep.FRY_REST + 0.1)
	assert_eq(game.use_station(fryer), "Pick up")
	assert_eq(game.player.held, "prep:potato")
	assert_eq(game.player.held_quality, Prep.GOOD)


func test_fries_left_in_burn_and_slow_the_chef():
	var fryer := _tool("fryer", Vector2i(2, 5), "crate_potato")
	_use("crate_potato")
	game.use_station(fryer)
	_run(Prep.FRY_BURN + 0.5)
	game.use_station(fryer)
	assert_eq(game.player.held, "burnt:potato")
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.PENALTY_SPEED, 0.01)


func test_boiling_waits_when_done_and_never_gives_a_burst():
	var pot := _tool("pot", Vector2i(2, 5), "crate_corn")
	_use("crate_corn")
	assert_eq(game.use_station(pot), "Boil")
	assert_eq(game.use_station(pot, true), "Still boiling")
	_run(Prep.BOIL_TIME + 20.0)
	assert_eq(game.use_station(pot), "Take out")
	assert_eq(game.player.held, "prep:corn")
	assert_eq(game.player.held_quality, Prep.PLAIN)
	assert_eq(game.player.speed(), Player.SPEED)


func test_a_good_grill_gives_a_burst():
	_use("crate_patty")
	_use("stove")
	_run(Prep.GRILL_DONE + 0.5)
	_use("stove")
	assert_eq(game.player.held_quality, Prep.GOOD)
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.BURST_SPEED, 0.01)


# ---------- The menu screen, stock and the door card (PRD 1, milestone 4) ----------

func _at_door() -> void:
	game.player.position = Grid.center(Vector2i(9, 4))
	game.player.look(Vector2i(1, 0))


func test_door_card_will_not_flip_with_no_makeable_main():
	_to_build()
	game.menu.items.clear()
	_at_door()
	assert_false(game.use_door())
	assert_eq(game.phase, game.Phase.BUILD)
	assert_string_contains(game.hud.toast.text, "No main")
	game.menu.add("side", ["bun"], "Bread")
	assert_false(game.use_door(), "a side alone is not enough")
	game.write_test_menu()
	game.find_station("crate_patty").stocked = false
	assert_false(game.use_door(), "the Burger is off: no patty stocked")
	game.find_station("crate_patty").stocked = true
	assert_true(game.use_door())
	assert_eq(game.phase, game.Phase.SERVICE)


func test_door_card_will_not_flip_when_the_stock_cannot_be_paid():
	_to_build()
	game.ledger.money = game.night_cost() - 1
	_at_door()
	assert_false(game.use_door())
	assert_eq(game.phase, game.Phase.BUILD)
	assert_string_contains(game.hud.toast.text, "stock costs $%d" % game.night_cost())
	assert_string_contains(game.hud.menu_notes._box.get_child(game.hud.menu_notes._box.get_child_count() - 1).text, "can't pay")
	game.ledger.money = game.night_cost()
	assert_true(game.use_door())
	assert_eq(game.ledger.money, 0, "the stock took it all")


func test_opening_charges_the_night_cost_as_a_stock_line():
	assert_eq(game.night_cost(), Pantry.fee_of("patty") + Pantry.fee_of("bun"))
	game.add_station("ready_cheese", Vector2i(1, 6))
	assert_eq(game.night_cost(), Pantry.fee_of("patty") + Pantry.fee_of("bun") + roundi(Pantry.fee_of("cheese") * 1.5),
		"ready-made at half as much again")
	_to_build()
	var before: int = game.ledger.money
	var cost: int = game.night_cost()
	_at_door()
	assert_true(game.use_door())
	assert_eq(game.ledger.money, before - cost)
	assert_eq(game.ledger.today.stock, cost)
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.last_day.stock, cost, "the receipt has a Stock line")


func test_using_a_crate_at_night_switches_its_stock_and_takes_it_off_the_menu():
	_to_build()
	game.player.position = Grid.center(Vector2i(1, 2))
	game.player.look(Vector2i(-1, 0))
	var crate: Station = game.find_station("crate_patty")
	assert_eq(game.stock_station_in_front(), crate)
	var full: int = game.night_cost()
	game.act(0, "turn")
	assert_false(crate.stocked)
	assert_eq(game.night_cost(), full - Pantry.fee_of("patty"), "an unstocked station costs nothing")
	assert_true(game.tonight_menu().is_empty(), "the Burger is not offered")
	assert_eq(Menu.off_reason(game.menu.items[0], game.kitchen_stock(), game.kitchen_tools()), "Patty not stocked")
	assert_true(game.menu_board.names.is_empty(), "the board by the door follows")
	game.act(0, "turn")
	assert_true(crate.stocked)
	assert_eq(game.menu_board.names, ["Burger"])


func test_an_item_with_no_tool_is_off_the_menu():
	for c in [Vector2i(0, 3), Vector2i(0, 4)]:
		var st: Station = game.stations[c]
		game._unregister(st)
		st.queue_free()
	assert_eq(Menu.off_reason(game.menu.items[0], game.kitchen_stock(), game.kitchen_tools()), "No grill")
	assert_true(game.tonight_menu().is_empty())
	var g: Guest = game.spawn_guest(0)
	assert_true(game.order_for(g).main.is_empty(), "nothing is offered")


func test_an_unstocked_crate_gives_nothing_in_service():
	game.find_station("crate_patty").stocked = false
	_use("crate_patty")
	assert_eq(game.player.held, "")
	assert_eq(game.prompt_for(game.find_station("crate_patty")), "Not stocked today")


func test_the_menu_screen_opens_at_night_only():
	assert_false(game.open_menu(), "locked during service")
	assert_false(game.hud.menu_open())
	_to_build()
	game.act(0, "menu")
	assert_true(game.hud.menu_open())
	game.act(0, "menu")
	assert_false(game.hud.menu_open())


func test_writing_an_item_on_the_menu_screen():
	_to_build()
	game.add_station("crate_cheese", Vector2i(1, 6))
	game.add_station("slicer", Vector2i(2, 6))
	assert_true(game.open_menu())
	var ms: MenuScreen = game.hud.menu
	ms.new_item("main")
	assert_eq(ms.selected(), "add:bun", "the highlight starts on the kitchen's first ingredient")
	game.act(0, "use")
	ms.put_in("patty")
	ms.put_in("cheese")
	var it: Dictionary = ms.editing()
	assert_eq(it.ingredients, ["bun", "patty", "cheese"])
	assert_eq(it.name, "Cheese Patty Bun", "a made-up name until it is named")
	assert_true(game.menu.items.has(it))
	ms._shift(2, -1)   # cheese down under the patty
	assert_eq(it.ingredients, ["bun", "cheese", "patty"])
	assert_eq(it.name, "Patty Cheese Bun")
	ms._set_level("dear")
	assert_eq(Menu.price_of(it), roundi(10 * 1.25))
	ms.set_name_text("The Big One Burger Deluxe")
	assert_eq(it.name, "The Big One Burger", "18 characters at most")
	ms._take_out(0)
	assert_eq(it.name, "The Big One Burger", "a name of the player's stays")
	ms._toggle_off()
	assert_eq(Menu.off_reason(it, game.kitchen_stock(), game.kitchen_tools()), "Off tonight")
	assert_false(game.menu_board.names.has(it.name))
	ms._toggle_off()
	assert_true(game.menu_board.names.has(it.name))
	ms._delete()
	assert_false(game.menu.items.has(it))
	assert_true(ms.editing().is_empty(), "back to the list")


func test_naming_with_the_pad_letter_grid():
	_to_build()
	game.open_menu()
	var ms: MenuScreen = game.hud.menu
	ms.open_item(game.menu.items[0])
	ms.start_naming("grid")
	assert_eq(ms.naming(), "grid")
	for k in 7:
		ms._rub_out()
	assert_true(ms.select("L:%d" % MenuScreen.LETTERS.find("D")))
	game.act(0, "use")
	ms._type_letter("I")
	ms._type_letter("N")
	ms._type_letter("E")
	ms._type_letter("R")
	game.act(0, "back")
	assert_eq(ms.naming(), "")
	assert_eq(game.menu.items[0].name, "Diner")


func test_keys_move_the_highlight_on_the_menu_screen():
	_to_build()
	game.open_menu()
	var ms: MenuScreen = game.hud.menu
	await get_tree().process_frame   # laid out
	assert_true(ms.select("add:main"))
	game.act(0, "right")
	assert_eq(ms.selected(), "add:side")
	game.act(0, "left")
	assert_eq(ms.selected(), "add:main")
	game.act(0, "up")
	assert_eq(ms.selected(), "item:%d" % game.menu.items[0].id, "the Burger is above Add")
	game.act(0, "use")
	assert_eq(ms.editing(), game.menu.items[0])
	game.act(0, "back")
	assert_true(ms.editing().is_empty())
	game.act(0, "back")
	assert_false(game.hud.menu_open())


func test_night_zero_hints_come_one_at_a_time():
	game.menu.items.clear()
	for c in [Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 6)]:
		var st: Station = game.stations[c]
		game._unregister(st)
		st.queue_free()
	_to_build()
	game.ledger.history.clear()   # as on the night before day 1
	assert_eq(game.night_hint(), game.NIGHT_HINTS[0])
	game.add_station("crate_bun", Vector2i(0, 6), 1, 1)
	assert_eq(game.night_hint(), game.NIGHT_HINTS[0], "a tool too")
	game.add_station("board", Vector2i(0, 3), 1, 1)
	assert_eq(game.night_hint(), game.NIGHT_HINTS[1])
	game.menu.add("main", ["bun"], "Bread")
	assert_eq(game.night_hint(), game.NIGHT_HINTS[2])
	game.ledger.history.append({})
	assert_eq(game.night_hint(), "", "only on night zero")


# ---------------------------------------------------------------- seaside

## The seaside kitchen starts with a fish icebox and a bread basket, and its fixed
## Fish roll goes from ticket to paid bill like the Burger.
func test_seaside_fish_roll_from_ticket_to_bill():
	Scenery.theme_id = "seaside"
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	_neutral_tastes()
	game.test_kitchen()
	assert_null(game.find_station("crate_patty"), "no diner stations by the sea")
	var g := _ordered_guest()
	assert_eq(g.order.main.name, "Fish roll")
	_use("trays")
	game.use_station(_the_pass())
	_use("crate_fish")
	assert_eq(game.player.held, "raw:fish")
	_use("stove")
	_run(Station.COOK_TIME + 0.5)
	_use("stove")
	game.use_station(_the_pass())
	_use("crate_roll")
	game.use_station(_the_pass())
	game.use_station(_the_pass())
	assert_true(game.player.tray.is_complete())
	game.use_station(g.table)
	_run(g.eat_time + 0.5)
	assert_eq(g.bill_base, 9, "the Fish roll: roll 2 and fish 7")


## Every ingredient has a model in each state it can be in, and a stacked layer.
func test_every_ingredient_has_a_model():
	for id: String in Pantry.ITEMS:
		for state in ["raw", "prep", "burnt"]:
			var n := Node3D.new()
			Build.ingredient(n, id, state)
			assert_gt(n.get_child_count(), 0, "%s %s is drawn" % [id, state])
			n.free()
		var t := Node3D.new()
		assert_gt(Build._layer(t, id, 0.0, true, true), 0.0, "%s stacks on a plate" % id)
		t.free()
	for look in ["raw", "nearly", "perfect", "dry", "burnt"]:
		var f := Node3D.new()
		Build.fillet(f, look)
		assert_gt(f.get_child_count(), 0, "fish fillet looks %s" % look)
		f.free()


func test_a_roll_dish_icon_is_side_on_not_a_burger():
	var burger := Icons.icon("dish:bun,patty")
	var roll := Icons.icon("dish:roll,fish")
	assert_gt(roll.size(), 0)
	assert_ne(roll.size(), burger.size(), "a roll dish is drawn its own way")
	var tail := false
	for layer: Array in roll:
		if (layer[0] as PackedVector2Array).size() == 3 and layer[1] == Pantry.ITEMS.fish.prepped:
			tail = true
	assert_true(tail, "the fish in the roll has a tail")


# ---------- The critic (PRD 2) ----------

func _card_says(text: String) -> bool:
	if game.hud.guest_card == null:
		return false
	for n in game.hud.guest_card.find_children("*", "Label", true, false):
		if (n as Label).text == text:
			return true
	return false


## Starts `day` and leaves only the critic's arrival (if any), due at once.
func _start_day_with_only_the_critic(day: int) -> bool:
	game.ledger.day = day
	game.start_day()
	var booked: Array = game.arrivals.filter(func(a: Dictionary) -> bool: return a.get("critic", false))
	for a in booked:
		a.time = 0.2
	game.arrivals.assign(booked)
	return not booked.is_empty()


func _run_to_summary() -> void:
	for i in 600:
		if game.phase == game.Phase.SUMMARY:
			return
		game.step(0.1)


func test_the_receipt_on_day_5_carries_a_clipping_and_day_4_does_not():
	assert_false(_start_day_with_only_the_critic(4), "no critic on day 4")
	_run_to_summary()
	assert_false(game.last_day.has("review"))
	assert_true(_start_day_with_only_the_critic(5), "the critic comes on day 5")
	_run(1.0)
	var c: Guest = game.critic_guest
	assert_not_null(c)
	assert_eq(c.idx, game.critic.critic_idx)
	assert_eq(c.party.size(), 1, "they come alone")
	game.walk_out(c)
	_run_to_summary()
	assert_true(game.last_day.has("review"), "the review comes with the receipt")
	assert_lte(int(game.last_day.review.stars), Critic.WALKOUT_CAP, "a walkout caps the stars")
	assert_eq(int(game.last_day.review.ratings.speed), 1)
	assert_true(game.critic.known)


func test_the_critic_is_unmarked_until_the_first_review():
	game.ledger.day = 4
	var g: Guest = game.spawn_guest(game.critic.critic_idx)
	game.inspect(g)
	assert_false(_card_says("Critic"), "nothing marks them before the reveal")
	game.inspect(null)
	game.critic.publish({"speed": 4, "clean": 4, "quality": 4, "variety": 4}, false, game.town, 5)
	game.ledger.day = 6
	game.inspect(g)
	assert_true(_card_says("Critic"), "marked after the reveal")
	game.hud.show_town()
	game.hud.show_review()   # the last clipping can be read again from the town book


func test_closing_early_before_the_critic_comes_puts_them_off_a_day():
	game.ledger.day = 5
	game.start_day()
	game.close_early()   # before any step: the critic is still in the arrivals
	assert_false(game.critic.visits_on(5))
	assert_true(game.critic.visits_on(6), "they come tomorrow instead")


func test_the_critic_orders_even_when_nothing_suits_them():
	var p: Dictionary = game.town.people[game.critic.critic_idx]
	p.dislikes = ["patty"]
	_start_day_with_only_the_critic(5)
	_run(1.0)
	var c: Guest = game.critic_guest
	assert_not_null(c)
	assert_false(c.planned.main.is_empty(), "never turned away by the menu")
	assert_ne(c.state, "browse")
