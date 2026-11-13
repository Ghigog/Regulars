extends GutTest
## Drives the real game scene headlessly through its public methods.

var game


func before_each():
	game = load("res://game/main.tscn").instantiate()
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


func test_flyers_cost_money_once_a_night_and_are_used_up_next_day():
	assert_false(game.buy_flyers(), "not during service")
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.phase, game.Phase.SUMMARY)
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


func test_catalog_tray_filters_as_you_search():
	_to_build()
	assert_eq(game.hud._cards.get_child_count(), 11)
	game.hud.set_search("fern")
	assert_eq(game.hud._cards.get_child_count(), 3)
	game.hud._set_category("Kitchen")
	assert_eq(game.hud._cards.get_child_count(), 1, "only the nothing-matches line")
	game.hud.set_search("")
	assert_eq(game.hud._cards.get_child_count(), 4)
	game.start_day()
	assert_null(game.hud.build_bar)


func test_catalog_piece_is_paid_for_when_placed_and_gated_by_level():
	_to_build()
	assert_false(game.pick_catalog("stove"), "level 3 and $80")
	assert_true(game.pick_catalog("counter"))
	assert_eq(game.ledger.money, 50, "picking is free")
	assert_false(game.place(Vector3i(5, 6, 0)), "that would block the doorway")
	assert_false(game.place(Vector3i(1, 0, 0)), "a stove is already there")
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
	assert_true(game.pick_up(Vector3(0.5, 0, 0.5)))
	game.start_day()
	assert_eq(game.stations[Vector2i(0, 0)], fridge)
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
	var g: Guest = game.spawn_guest(0)
	var h: Guest = game.spawn_guest(1)
	var i: Guest = game.spawn_guest(2)
	var j: Guest = game.spawn_guest(3)
	var k: Guest = game.spawn_guest(4)
	var l: Guest = game.spawn_guest(5)
	_run(14.0)
	var cells: Array = [g.cell, h.cell, i.cell, j.cell, k.cell, l.cell]
	assert_true(cells.has(Vector2i(8, 2)) and cells.has(Vector2i(8, 4)), "guests use the turned seats")


func test_selling_refunds_half_but_not_the_last_stove_or_fixtures():
	_to_build()
	assert_true(game.pick_up(Vector3(9.5, 0, 0.5)))        # the fern
	assert_eq(game.sell_value(), 10)
	assert_true(game.sell_hand())
	assert_eq(game.ledger.money, 60)
	assert_false(game.stations.has(Vector2i(9, 0)))
	assert_true(game.pick_up(Vector3(0.5, 0, 0.5)))        # the fridge
	assert_false(game.sell_hand(), "fixtures are not for sale")
	game.cancel_hand()
	assert_true(game.pick_up(Vector3(1.5, 0, 0.5)))        # one of two stoves
	assert_true(game.sell_hand())
	assert_eq(game.ledger.money, 100)
	assert_true(game.pick_up(Vector3(2.5, 0, 0.5)))
	assert_eq(game.sell_block(), "Your last stove")
	assert_false(game.sell_hand())
	game.cancel_hand()
	assert_eq(game.find_station("stove").cell, Vector2i(2, 0))


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
	assert_false(game.pick_up(Vector3(3.5, 0, 6.95)), "the front wall is not yours to move")


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
	assert_eq(game.find_station("plates").count, 5)


func test_ignored_guest_walks_out_and_counts_as_a_strike():
	var g: Guest = game.spawn_guest(1)
	_run(80.0)
	assert_eq(game.ledger.strikes(), 1)
	assert_lt(float(game.town.people[1].affinity), 0.0)
	assert_false(is_instance_valid(g) and g.state == "waiting")


func test_dirty_table_disgusts_guests_unless_a_wall_hides_it():
	var g: Guest = game.spawn_guest(2)
	_run(12.0)
	assert_eq(g.state, "waiting")
	var other: Station = game.stations[Vector2i(6, 5)] if g.table.cell != Vector2i(6, 5) else game.stations[Vector2i(6, 1)]
	other.dirty = 1
	_run(2.0)
	var seen: float = g.mood.disgust
	assert_gt(seen, 0.0)
	for c: Vector2i in [g.cell, g.cell + Vector2i(1, 0), g.cell + Vector2i(0, 1)]:
		game.grid.walls[Vector3i(c.x, c.y, 0)] = true
		game.grid.walls[Vector3i(c.x, c.y, 1)] = true
	_run(2.0)
	assert_eq(g.mood.disgust, seen, "boxed in: nothing gross in view")


func _seat_at(table_cell: Vector2i, left: bool) -> Guest:
	# Fill tables in order until a guest lands on the wanted seat.
	var want := table_cell + Vector2i(-1 if left else 1, 0)
	for i in 6:
		var g: Guest = game.spawn_guest(i)
		_run(12.0)
		if g.cell == want and g.state == "waiting":
			return g
	return null


func test_bin_bothers_only_nearby_guests_until_a_partition_hides_it():
	var near := _seat_at(Vector2i(6, 5), true)        # seat (5, 5), five cells from the bin
	assert_not_null(near)
	if near == null:
		return
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
	assert_gte(game.arrivals.size(), 5)
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


func test_chef_aims_at_the_station_most_in_front():
	# Standing at (1, 1) with a stove behind-left and the fridge two cells away.
	game.player.position = Grid.center(Vector2i(1, 1))
	game.player.look(Vector2i(0, -1))
	assert_eq(game.player.target_cell(), Vector2i(1, 0))
	# One key moves diagonally from this camera; the chef still finds the stove.
	game.player.move(Vector2(0, 1), 0.0)
	assert_eq(game.player.target_cell(), Vector2i(1, 0))
	# Looking away from every station, nothing is picked up by accident.
	game.player.look(Vector2i(0, 1))
	assert_false(game.stations.has(game.player.target_cell()))
