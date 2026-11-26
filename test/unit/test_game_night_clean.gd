extends "res://test/helpers/game_case.gd"


func test_mess_carries_over_from_one_day_to_the_next():
	var t := _dirty_table()
	var sink: Station = game.world.find_station("sink")
	var bin: Station = game.world.find_station("bin")
	sink.dirty = Station.piled_at(sink.racked)
	bin.count = Station.BIN_HOLDS
	_run(1.0)
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.phase, game.Phase.SUMMARY)
	var ages := [t.dirty_age, sink.dirty_age, bin.dirty_age]
	assert_gt(float(ages[0]), 0.9)
	game.session.open_build()
	_run(1.0)
	game.day.start_day()
	assert_eq(t.dirty, 1)
	assert_eq(sink.dirty, Station.piled_at(sink.racked))
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
	var sink: Station = game.world.find_station("sink")
	var plates: Station = game.world.find_station("dish_rack")
	var stack := plates.count
	_face_table()
	assert_eq(game.room_edit.build_action(), "Clear table", "cleaning comes before picking up")
	game.room_edit.build_interact()
	assert_eq(game.player.held, "dirty_dishes")
	assert_eq(t.dirty, 0, "both plates in the hands")
	assert_eq(game.room_edit.build_action(), "", "plates in hand: nothing is picked up")
	_face_sink()
	assert_eq(game.room_edit.build_action(), "Put in sink")
	game.room_edit.build_interact()
	assert_eq(game.player.held, "")
	assert_eq(sink.dirty, 2)
	assert_eq(game.room_edit.build_action(), "Wash up")
	game.room_edit.build_interact()   # starts the hold: one clean dish a hold
	game.cooking._tick_wash(game.player, true, game.cooking.WASH_HOLD + 0.1)
	assert_eq(sink.dirty, 1)
	assert_eq(game.player.held, "dishes", "the washed plate is in hand, for the rack")
	assert_eq(plates.count, stack, "nothing goes straight onto the stack")



func test_night_cleaning_takes_the_bag_out():
	_to_build()
	var bin: Station = game.world.find_station("bin")
	bin.count = Station.BIN_HOLDS
	_face(Vector2i(1, 5), Vector2i(-1, 0))
	assert_eq(game.room_edit.build_action(), "Take the bag out")
	game.room_edit.build_interact()
	assert_eq(game.player.held, "rubbish_bag")
	assert_eq(bin.count, 0)



func test_a_messy_table_cannot_be_moved_or_sold_until_cleared():
	_to_build()
	_dirty_table()
	var spot := Grid.center(Vector2i(8, 3))
	assert_false(game.placing.pick_up(spot), "clean it first")
	assert_true(game.hand.is_empty())
	_face_table()
	game.room_edit.build_interact()
	assert_false(game.placing.pick_up(spot), "not with a dirty plate in hand")
	_face_sink()
	game.room_edit.build_interact()
	assert_true(game.placing.pick_up(spot))
	assert_true(game.placing.sell_hand())



func test_the_shop_stays_shut_while_carrying_a_dirty_plate():
	_to_build()
	_dirty_table()
	_face_table()
	game.room_edit.build_interact()
	game.session.open_shop()
	assert_false(game.shopping)
	assert_false(game.placing.pick_catalog("plant"))
	game.placing.cancel_hand()
	assert_eq(game.player.held, "dirty_dishes", "Back does nothing to a carried plate")



func test_mess_does_not_age_at_night_and_a_carried_plate_goes_into_service():
	_to_build()
	var sink: Station = game.world.find_station("sink")
	sink.dirty = Station.piled_at(sink.racked)
	sink.dirty_age = 5.0
	_dirty_table()
	_run(2.0)
	assert_eq(sink.dirty_age, 5.0)
	_face_table()
	game.room_edit.build_interact()
	game.day.start_day()
	assert_eq(game.player.held, "dirty_dishes")


# ---------- Leftover food ----------

func _counters_with_food(n: int) -> Array[Station]:
	var out: Array[Station] = []
	for st: Station in game.stations.values():
		if st.type == "counter" and st.item == "" and out.size() < n and not st.has_node("till"):
			st.item = "raw:patty"
			st.refresh()
			out.append(st)
	return out


func test_the_shop_sells_only_flyers():
	_dirty_table()
	game.world.find_station("bin").count = 3
	_to_build()
	for q in ["", "cleaner", "mop"]:
		var ids := []
		for bp: Dictionary in game.session.shop_items(q, "Extras"):
			ids.append(bp.id)
		assert_false(ids.has("night" + "_cleaner"), "no cleaner piece for '%s'" % q)
	assert_eq(game.session.shop_items("", "Extras").size(), 1, "Flyers alone")


func test_food_in_hand_is_gone_when_the_door_opens():
	_to_build()
	game.player.set_held("raw:patty")
	game.day.start_day()
	assert_eq(game.player.held, "")



func _hold_washed_plate() -> void:
	game.player.take_dish(Dish.make(Dish.PLATE))
	assert_eq(game.player.held, "dishes")


func test_a_washed_plate_in_hand_blocks_lifting_the_sink_rack_or_a_counter():
	_to_build()
	var sink: Station = game.world.find_station("sink")
	sink.dirty = 2
	_hold_washed_plate()
	var spots := {"sink": null, "dish_rack": null, "counter": null}
	for type in spots:
		var st: Station = game.world.find_station(type)
		_face_station(st)
		assert_ne(game.room_edit.build_action(), "Pick up", type)
		assert_false(game.placing.pick_up(Grid.center(game.stations.find_key(st))), type)
		assert_eq(game.player.held, "dishes", type)
		assert_true(game.stations.find_key(st) != null, "%s stays put" % type)


func test_the_sink_will_not_move_while_dishes_soak_even_empty_handed():
	_to_build()
	var sink: Station = game.world.find_station("sink")
	sink.dirty = 1
	_face_sink()
	assert_ne(game.room_edit.build_action(), "Pick up")
	assert_false(game.placing.pick_up(Grid.center(game.stations.find_key(sink))))


func test_a_washed_plate_goes_back_on_the_rack_at_night():
	_to_build()
	var rack: Station = game.world.find_station("dish_rack")
	rack.count = 0
	_hold_washed_plate()
	_face_station(rack)
	assert_eq(game.room_edit.build_action(), "Put back")
	game.room_edit.build_interact()
	assert_eq(rack.count, 1)
	assert_eq(game.player.held, "")
	assert_eq(game.room_edit.build_action(), "Pick up", "empty hands: the rack lifts as before")


func test_a_full_rack_refuses_the_plate_at_night():
	_to_build()
	var rack: Station = game.world.find_station("dish_rack")
	rack.count = Station.RACK_CAPACITY
	_hold_washed_plate()
	_face_station(rack)
	assert_ne(game.room_edit.build_action(), "Put back")
	assert_eq(game.cooking.use_station(rack, true), "The rack is full")


func test_use_at_a_counter_with_a_washed_plate_says_why():
	_to_build()
	_hold_washed_plate()
	_face_station(game.world.find_station("counter"))
	game.room_edit.build_interact()
	assert_eq(game.player.held, "dishes")
	assert_true(game.stations.find_key(game.world.find_station("counter")) != null)
