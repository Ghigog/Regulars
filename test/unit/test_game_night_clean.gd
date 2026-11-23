extends "res://test/helpers/game_case.gd"


func test_mess_carries_over_from_one_day_to_the_next():
	var t := _dirty_table()
	var sink: Station = game.world.find_station("sink")
	var bin: Station = game.world.find_station("bin")
	sink.dirty = Station.SINK_PILED
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
	var sink: Station = game.world.find_station("sink")
	var plates: Station = game.world.find_station("plates")
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
	game.room_edit.build_interact()
	game.room_edit.build_interact()
	assert_eq(sink.dirty, 0)
	assert_eq(plates.count, stack + 2)



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
	sink.dirty = Station.SINK_PILED
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


func test_the_night_cleaner_leaves_nothing_to_clean():
	_dirty_table()
	_to_build()
	game.ledger.money = 100
	assert_true(game.room_edit.hire_cleaner())


func test_food_in_hand_is_gone_when_the_door_opens():
	_to_build()
	game.player.set_held("raw:patty")
	game.day.start_day()
	assert_eq(game.player.held, "")
