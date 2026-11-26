extends "res://test/helpers/game_case.gd"
## Nightfall tidy: clean plates back to the rack, food into the nearest bin, dirty plates left.


func _end_day_now() -> void:
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.phase, game.Phase.SUMMARY)


func _counters(n: int) -> Array[Station]:
	var out: Array[Station] = []
	for st: Station in game.stations.values():
		if st.type == "counter" and st.item == "" and out.size() < n and not st.has_node("till"):
			out.append(st)
	return out


func _plate_on(st: Station, food := false) -> void:
	var d := Dish.make(Dish.PLATE)
	if food:
		d.add("prep:patty", 1.0)
	st.set_dish(d)


func test_clean_plates_on_a_counter_and_in_hand_go_back_to_the_rack():
	var plates: Station = game.world.find_station("dish_rack")
	plates.count = 4   # room on the rack for the plates that come back
	var before := plates.count
	_plate_on(_counters(1)[0])
	game.player.set_held("dishes", 1.0, [Dish.make(Dish.PLATE)])
	_end_day_now()
	game.session.open_build()
	assert_eq(plates.count, before + 2)
	assert_eq(game.player.held, "")
	assert_true(game.player.dishes.is_empty())


func test_food_and_plated_food_go_into_the_bin():
	var plates: Station = game.world.find_station("dish_rack")
	plates.count = 4   # room on the rack for the plates that come back
	var bin: Station = game.world.find_station("bin")
	var cs := _counters(2)
	cs[0].item = "raw:patty"
	cs[0].refresh()
	_plate_on(cs[1], true)
	var p0 := plates.count
	var b0 := bin.count
	_end_day_now()
	game.session.open_build()
	assert_false(cs[0].has_leftover_food())
	assert_eq(cs[0].item, "")
	assert_eq(cs[1].item, "", "the plated burger and its plate are off the counter")
	assert_eq(plates.count, p0 + 1)
	assert_eq(bin.count, b0 + 2)


func test_food_in_hand_goes_into_the_bin():
	var bin: Station = game.world.find_station("bin")
	var b0 := bin.count
	game.player.set_held("raw:patty")
	_end_day_now()
	assert_eq(game.player.held, "")
	assert_eq(bin.count, b0 + 1)


func test_dirty_plates_stay_and_no_clear_food_prompt_exists():
	var t := _dirty_table(2)
	_counters(1)[0].item = "raw:patty"
	_end_day_now()
	game.session.open_build()
	assert_eq(t.dirty, 2)
	assert_false("Clear food" in Cleaning.NIGHT_ACTIONS)


func test_the_tidy_plays_and_clears_its_moves():
	game.world.find_station("dish_rack").count = 4
	_plate_on(_counters(1)[0])
	_end_day_now()
	game.session.open_build()
	var flying := 0
	for c in game.get_children():
		if c is Node3D and c.top_level and not c is Station:
			flying += 1
	assert_gt(flying, 0, "a plate is in the air")
	_run(1.0)


func _model_gone(st: Station) -> bool:
	return st._item_node == null or not is_instance_valid(st._item_node) or st._item_node.is_queued_for_deletion()


func test_tidied_counters_draw_no_food_and_take_new_food_next_day():
	var bin: Station = game.world.find_station("bin")
	var b0 := bin.count
	var cs := _counters(2)
	cs[0].set_item("raw:patty")
	_plate_on(cs[1], true)
	_end_day_now()
	game.session.open_build()
	assert_eq(bin.count, b0 + 2)
	assert_true(_model_gone(cs[0]), "no patty model left on the counter")
	assert_true(_model_gone(cs[1]), "no plate model left on the counter")
	cs[0].set_item("raw:bun")
	assert_eq(cs[0].item, "raw:bun")
	assert_false(_model_gone(cs[0]))
	cs[0].clear_food()
	assert_eq(cs[0].item, "")
	assert_true(_model_gone(cs[0]))


func test_food_left_on_a_stove_is_gone_and_the_cook_bar_hidden():
	var stove: Station = game.world.find_station("stove")
	stove.set_item("raw:patty")
	stove.cook = 1.0
	_end_day_now()
	game.session.open_build()
	assert_eq(stove.item, "")
	assert_true(_model_gone(stove))
	assert_false(stove._bar.visible)
	stove.set_item("raw:patty")
	assert_eq(stove.item, "raw:patty")


func _playing_loops() -> Array[String]:
	var out: Array[String] = []
	for id: String in Game.LOOPING:
		if game._sfx.has(id) and game._sfx[id].playing:
			out.append(id)
	return out


func test_nightfall_silences_the_cooking_loops():
	var stove: Station = game.world.find_station("stove")
	stove.set_item("raw:patty")
	game.prep_games._fade_loops({"sizzle_raw": true, "smoke_warn": true}, 0.1)
	assert_false(_playing_loops().is_empty(), "a loop is playing before the day ends")
	_end_day_now()
	game.session.open_build()
	assert_eq(_playing_loops(), [] as Array[String])
	assert_eq(stove.item, "")
	assert_false(stove.is_cooking())
