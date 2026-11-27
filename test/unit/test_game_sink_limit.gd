extends "res://test/helpers/game_case.gd"
## A sink holds at most ten dirty dishes (T-116).


func _in_hand(plates: int, cups := 0) -> void:
	var ds: Array = []
	for i in plates:
		ds.append(Dish.make(Dish.PLATE, true))
	for i in cups:
		ds.append(Dish.make(Dish.CUP, true))
	game.player.set_held("dirty_dishes", 1.0, ds, true)


func test_a_part_load_fills_the_sink_and_keeps_the_rest_in_hand():
	_to_build()
	var sink: Station = game.world.find_station("sink")
	sink.dirty = 8
	_in_hand(2, 2)
	_face_sink()
	assert_eq(game.room_edit.build_action(), "Put in sink")
	game.room_edit.build_interact()
	assert_eq(sink.dirty, 10)
	assert_eq(sink.dirty_cups, 0, "plates go in before cups")
	assert_eq(game.player.held, "dirty_dishes")
	assert_eq(game.player.dishes.size(), 2)


func test_a_full_sink_refuses_and_says_why_by_day_and_night():
	_to_build()
	var sink: Station = game.world.find_station("sink")
	sink.dirty = Station.SINK_HOLDS
	_in_hand(2)
	_face_sink()
	assert_eq(game.room_edit.build_action(), "")
	assert_eq(game.cooking.use_station(sink, true), "The sink is full. Wash some up")
	game.room_edit.build_interact()
	assert_eq(sink.dirty, 10)
	assert_eq(game.player.dishes.size(), 2)
	game.day.start_day()
	_face_sink()
	assert_eq(game.cooking.use_station(sink, true), "The sink is full. Wash some up")


func test_one_washed_out_makes_room_for_exactly_one():
	_to_build()
	var sink: Station = game.world.find_station("sink")
	sink.dirty = 9
	_in_hand(3)
	game.cooking.use_station(sink)
	assert_eq(sink.dirty, 10)
	assert_eq(game.player.dishes.size(), 2)


func test_a_helper_with_a_full_sink_puts_the_dishes_on_a_counter():
	_to_build()
	game.day.start_day()
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	var h: Helper = game.crew.crew_demos.demo_hire(5, "Cook", ["fetch"], Vector2i(5, 3))
	var sink: Station = game.world.find_station("sink")
	sink.dirty = Station.SINK_HOLDS
	var ds: Array = [Dish.make(Dish.PLATE, true), Dish.make(Dish.PLATE, true)]
	h.set_held("dishes", 1.0, ds)
	var s := {"do": "to_sink"}
	assert_true(game.crew.task_run._start(h, s))
	assert_eq(s.do, "stash", "no sink has room")
	assert_eq(sink.dirty, 10)


func test_a_helper_arriving_at_a_filling_sink_keeps_the_rest():
	_to_build()
	game.day.start_day()
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	var h: Helper = game.crew.crew_demos.demo_hire(5, "Cook", ["fetch"], Vector2i(5, 3))
	var sink: Station = game.world.find_station("sink")
	sink.dirty = 9
	var ds: Array = [Dish.make(Dish.PLATE, true), Dish.make(Dish.PLATE, true)]
	h.set_held("dishes", 1.0, ds)
	var next: Variant = game.crew.task_end._finish(h, {"do": "to_sink", "at": sink.cell})
	assert_eq(sink.dirty, 10)
	assert_eq(h.dishes.size(), 1)
	assert_eq(next[0].do, "stash")
