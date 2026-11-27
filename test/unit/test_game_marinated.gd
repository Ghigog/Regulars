extends "res://test/helpers/game_case.gd"
## Marinated boxes in service (EPIC-132): the bonus, the glaze and the plus; Prepared stays ready-made.


func _serve_plain_patty(box_cell: Vector2i, marinated: bool) -> Dish:
	game.menu_stock.stock_box("patty", box_cell, false, 0, marinated)
	var box: Station = game.stations[box_cell]
	game.player.set_held("")
	game.cooking.use_station(box)
	var ch: Player = game.player
	assert_eq(ch.held, "raw:patty")
	assert_eq(ch.held_marinated, marinated)
	# Grilled plain: put a prepped, plain patty straight on a plate, as the grill would hand it over.
	ch.set_held("prep:patty", Prep.PLAIN, [], false, marinated)
	var d := Dish.make(Dish.PLATE)
	d.add(ch.held, ch.held_quality, ch.held_marinated)
	return d


func test_a_marinated_patty_scores_the_bonus_over_a_plain_one():
	var plain := _serve_plain_patty(Vector2i(2, 6), false)
	var marinated := _serve_plain_patty(Vector2i(3, 6), true)
	assert_almost_eq(marinated.qs[0] - plain.qs[0], Pantry.MARINATE_BONUS, 0.0001)
	assert_true(marinated.is_marinated(0))
	assert_false(plain.is_marinated(0))


func test_the_bonus_never_goes_above_one():
	var d := Dish.make(Dish.PLATE)
	d.add("prep:patty", Prep.GOOD, true)
	assert_eq(d.qs[0], 1.0)


func test_the_glaze_survives_stacking_and_scraping():
	var a := Dish.new()
	a.add("prep:patty", Prep.PLAIN, true)
	var b := Dish.new()
	b.add("prep:bun", Prep.PLAIN)
	b.take_all(a)
	assert_eq(b.marks, [false, true])
	assert_true(b.duplicate_dish().any_marinated())
	b.scrape()
	assert_false(b.any_marinated())


func test_a_prepared_cheese_box_hands_out_sliced_and_plain():
	game.menu_stock.stock_box("cheese", Vector2i(2, 6), true)
	game.cooking.use_station(game.stations[Vector2i(2, 6)])
	assert_eq(game.player.held, "prep:cheese")
	assert_eq(game.player.held_quality, Prep.PLAIN)
	assert_false(game.player.held_marinated)


func test_the_flag_rides_through_a_prep_minigame():
	game.menu_stock.stock_box("lettuce", Vector2i(2, 6), false, 0, true)
	game.cooking.use_station(game.stations[Vector2i(2, 6)])
	assert_true(game.player.held_marinated)
	var st: Station = game.world.add_station("board", Vector2i(2, 4), 1, 1)
	game.prep_games.start_prep(0, st, "chop", "lettuce", game.player.held)
	assert_true(game.preps[0].marinated)
	game.prep_games._finish_prep(0, "good")
	assert_eq(game.player.held, "prep:lettuce")
	assert_true(game.player.held_marinated)


func test_the_pop_carries_a_plus_only_when_marinated():
	var host := Node3D.new()
	add_child_autofree(host)
	PrepWidget.pop(host, Vector3.ZERO, "good", true)
	PrepWidget.pop(host, Vector3.ZERO, "good")
	var with_plus: Node3D = host.get_child(0)
	var without: Node3D = host.get_child(1)
	assert_eq(with_plus.get_child_count(), without.get_child_count() + 1)


func test_food_wears_a_glaze_when_marinated():
	var plain := BuildFood.item("prep:patty", 1.0)
	var glazed := BuildFood.item("prep:patty", 1.0, "", true)
	assert_gt(glazed.get_child_count(), plain.get_child_count())
	var d := Dish.make(Dish.PLATE)
	d.add("prep:patty", 1.0, true)
	var e := Dish.make(Dish.PLATE)
	e.add("prep:patty", 1.0)
	assert_gt(BuildFood.dish(d).get_child_count(), BuildFood.dish(e).get_child_count())
	plain.free()
	glazed.free()


func test_the_crew_view_lists_a_marinated_box_as_plain_and_a_prepared_one_as_ready():
	game.menu_stock.stock_box("lettuce", Vector2i(2, 6), false, 0, true)
	game.menu_stock.stock_box("cheese", Vector2i(3, 6), true)
	var kinds := []
	var ready := []
	for s: Dictionary in game.crew.room_view.world()["storage"]:
		kinds.append_array(s.kinds)
		ready.append_array(s.ready)
	assert_has(kinds, "lettuce")
	assert_has(ready, "cheese")
	assert_does_not_have(ready, "lettuce")
