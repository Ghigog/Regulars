extends "res://test/helpers/game_case.gd"
## Only genuinely gross things put a guest off, and the cause they react to is in view.


func _seated() -> Guest:
	_neutral_tolerance_and_dirt()
	game.stations.erase(Vector2i(0, 5))
	var g: Guest = game.seating.spawn_guest(2)
	_run(12.0)
	g.mood.disgust = 0.0
	g.seen.clear()
	g.disgust_from = {}
	return g


func _beside(g: Guest) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if game.grid.has_los(g.cell, g.cell + d) and not game.stations.has(g.cell + d):
			return g.cell + d
	return g.cell


func _hold_near(g: Guest, item: String) -> void:
	game.player.held = item
	game.player.position = Grid.center(_beside(g))


func test_level_one_dirt_beside_a_guest_does_not_disgust_them():
	var g := _seated()
	game.floor_dirt.mess.dirt[_beside(g)] = 1
	for i in 300:
		game.floor_dirt.disgust(g, 0.1, Game.SIGHT_RANGE)
	assert_lt(g.mood.disgust, GuestMood.DISGUST_STAGES[0])
	assert_true(g.disgust_from.is_empty())


func test_an_uncleared_plate_is_background_clutter():
	var g := _seated()
	for st: Station in game.stations.values():
		if Station.is_table(st.type) and st.dirty == 0:
			st.dirty = 1
			st.dirty_age = 600.0
			break
	game.seating._collect_gross()
	for i in 1200:
		game.seating.apply_surroundings(g, 0.1)
	assert_lt(g.mood.disgust, GuestMood.DISGUST_STAGES[0])
	assert_true(g.disgust_from.is_empty())


func test_carrying_dirty_plates_past_does_not_reach_disgusted():
	var g := _seated()
	game.floor_dirt.mess.dirt[_beside(g)] = 1
	_hold_near(g, "dirty_dishes")
	for i in 600:
		game.seating._collect_gross()
		game.seating.apply_surroundings(g, 0.1)
	assert_lt(g.mood.disgust_level(), 2)
	assert_true(g.disgust_from.is_empty())


func test_a_carried_rubbish_bag_is_named_as_the_cause():
	var g := _seated()
	var spot := _beside(g)
	_hold_near(g, "rubbish_bag")
	for i in 100:
		game.seating._collect_gross()
		game.seating.apply_surroundings(g, 0.1)
	assert_eq(g.disgust_from.get("kind"), "rubbish")
	assert_eq(g.disgust_from.get("cell"), spot)


func test_rubbish_out_of_view_starts_again_from_its_base_rate():
	var g := _seated()
	_hold_near(g, "rubbish_bag")
	for i in 50:
		game.seating._collect_gross()
		game.seating.apply_surroundings(g, 0.1)
	assert_gt(g.seen.get("rubbish", 0.0), 4.0)
	game.player.held = ""
	game.seating._collect_gross()
	game.seating.apply_surroundings(g, 0.1)
	assert_false(g.seen.has("rubbish"))


func test_floor_dirt_is_attributed_to_the_worst_cell():
	var g := _seated()
	var a := _beside(g)
	var b := a
	for c: Vector2i in [g.cell + Vector2i(0, 2), g.cell + Vector2i(0, -2), g.cell + Vector2i(2, 0), g.cell + Vector2i(-2, 0)]:
		if game.grid.in_bounds(c) and game.grid.has_los(g.cell, c) and c != a and not game.stations.has(c):
			b = c
			break
	assert_ne(a, b, "needs two visible cells")
	game.floor_dirt.mess.dirt[a] = 1
	game.floor_dirt.mess.dirt[b] = 3
	assert_eq(game.floor_dirt._worst_of([a, b]), b)
	assert_eq(game.floor_dirt._worst_of([b, a]), b)
