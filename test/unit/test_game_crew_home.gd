extends "res://test/helpers/game_case.gd"
## Helpers see the night out (T-123): cleaning in hand is finished, anything else is let go,
## nobody takes a new task, and each stops by a desk for their things and walks out.

const PERSON := 9
const WASHER := ["wash_up", "empty_bin", "clear_tables", "mop"]
const COOK := ["fetch", "grill", "assemble"]


func _day_with(duties: Array, at := Vector2i(3, 3)) -> Helper:
	_to_build()
	game.day.start_day()
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	return game.crew.crew_demos.demo_hire(PERSON, "Staff", duties, at)


func _end() -> void:
	game.arrivals.clear()
	game.guests.clear()
	game.day._end_day()


func _desk() -> void:
	if game.world.find_station("desk") == null:
		game.world.add_station("desk", Vector2i(8, 6))


func _rack(sink: Station) -> Station:
	var rack: Station = game.world.find_station("dish_rack")
	if rack == null:
		rack = game.world.add_station("dish_rack", sink.cell + Vector2i(0, 1))
	rack.count = 0
	return rack


func test_a_washer_mid_wash_finishes_it_after_the_day_ends():
	var h := _day_with(WASHER)
	var sink: Station = game.world.find_station("sink")
	var rack := _rack(sink)
	sink.dirty = 3
	sink.refresh()
	var n := 0
	while n < 300 and not (not h.steps.is_empty() and str(h.steps[0].do) == "wash" and h.step_started):
		game.step(0.1)
		n += 1
	assert_lt(n, 300, "the washer started washing")
	_end()
	assert_true(h.going_home)
	assert_false(h.task.is_empty(), "the wash is kept")
	for i in 400:
		game.step(0.1)
		if not game.crew.helpers.has(h):
			break
	assert_false(game.crew.helpers.has(h), "then they went home")
	assert_gt(rack.count, 0, "the clean plates went on the rack")
	assert_eq(sink.dirty + rack.count, 3, "none lost, and no new dish taken up")


func test_a_food_task_is_dropped_at_nightfall():
	var h := _day_with(COOK)
	h.task = {"type": "fetch", "key": "x"}
	h.steps = [{"do": "cook"}]
	game.crew.end_day()
	assert_true(h.task.is_empty(), "let go")
	assert_true(h.steps.is_empty(), "no steps left")


func test_nobody_takes_a_task_at_night():
	var h := _day_with(WASHER)
	var sink: Station = game.world.find_station("sink")
	_rack(sink)
	_end()
	sink.dirty = 4
	game.floor_dirt.mess.dirt[Vector2i(6, 6)] = 2
	for i in 30:
		game.step(0.1)
		assert_true(h.task.is_empty(), "no task at night")
	assert_eq(sink.dirty, 4)
	assert_eq(game.floor_dirt.mess.level(Vector2i(6, 6)), 2)


func test_a_free_helper_stops_at_the_desk_gets_the_bag_and_is_freed_at_the_exit():
	var h := _day_with(WASHER, Vector2i(5, 3))
	_desk()
	_end()
	assert_null(h.bag)
	var collected := false
	var near_desk := false
	for i in 600:
		game.step(0.1)
		if not is_instance_valid(h) or not game.crew.helpers.has(h):
			break
		if h.home_stage == "collect":
			near_desk = true
			assert_null(h.bag, "no bag before the pause ends")
		if h.bag != null:
			collected = true
	assert_true(near_desk, "stopped at the desk")
	assert_true(collected, "carried a bag")
	assert_eq(game.crew.helpers.size(), 0, "freed at the exit")


func test_with_no_desk_they_walk_straight_out():
	var h := _day_with(WASHER, Vector2i(5, 3))
	for st: Station in game.stations.values().duplicate():
		if st.type == "desk":
			game.world.remove_station(st.cell)
	_end()
	for i in 600:
		game.step(0.1)
		assert_ne(h.home_stage, "collect")
	assert_eq(game.crew.helpers.size(), 0)


func test_opening_the_door_while_one_walks_out_leaves_no_helper():
	_day_with(WASHER, Vector2i(5, 3))
	_end()
	game.step(0.1)
	assert_eq(game.crew.helpers.size(), 1)
	game.session.open_build()
	game.day.start_day()
	var n := 0
	for h in game.crew.helpers:
		n += 1
	assert_lte(n, game.staff.employees.size(), "the day's staff only, no duplicate")
	var ids := {}
	for h in game.crew.helpers:
		assert_false(ids.has(h.person), "one helper per person")
		ids[h.person] = true
