extends "res://test/helpers/game_case.gd"
## EPIC-85-T4: rooms built from Table tiles, chairs and booth seats.


func _dining_names() -> Array:
	return game.session.shop_items("", "Dining").map(func(bp: Dictionary) -> String: return Catalog.label(bp))


func test_the_shop_sells_a_table_and_a_chair_and_no_sets():
	var names := _dining_names()
	assert_has(names, "Table")
	assert_has(names, "Chair")
	for gone: String in ["Table for two", "Booth", "Table for four", "Counter stool"]:
		assert_does_not_have(names, gone)
	assert_eq(Catalog.price_of("table"), 20)
	assert_eq(Catalog.price_of("chair"), 10)
	for id: String in ["booth", "table4", "stool"]:
		assert_false(Catalog.ITEMS.has(id), id)


func test_the_starting_room_is_three_tiles_with_two_chairs_each_on_the_old_cells():
	assert_eq(game.paying.dining_tables().size(), 3)
	for t: Vector2i in [Vector2i(6, 1), Vector2i(8, 3), Vector2i(6, 5)]:
		var tile: Station = game.stations[t]
		assert_eq(tile.type, "table")
		assert_eq(tile.seats.size(), 2)
		assert_has(tile.seats, t + Vector2i(-1, 0))
		assert_has(tile.seats, t + Vector2i(1, 0))
		for s: Vector2i in tile.seats:
			assert_eq(game.stations[s].type, "chair")
			assert_true(game.grid.reserved.has(s))
			assert_false(game.grid.is_blocked(s), "guests walk onto a chair")
	assert_eq(game.seating.max_party(), 2)


func test_three_tiles_in_a_row_with_six_chairs_seat_a_group_of_six():
	_clear_dining()
	var cells := [Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3)]
	var chairs := []
	for c: Vector2i in cells:
		chairs.append_array([c + Vector2i(-1, 0), c + Vector2i(1, 0)])
	var t := _add_table(cells, chairs)
	assert_eq(game.seating.max_party(), 6, "the biggest table sets the biggest group")
	var party: Array[Guest] = game.seating.spawn_group([0, 1, 2, 3, 4, 5])
	_run(16.0)
	for g in party:
		assert_eq(g.table, t[0])
		assert_true(game.tables.seats_of(t[0]).has(g.seat))
	var coming: Array[int] = game.town.roll_guests(12)
	for group: Array in game.town.make_groups(coming, game.seating.max_party(), 1):
		assert_lte(group.size(), 6, "no group larger than the table")


func test_comfort_comes_from_the_guests_own_seat():
	_clear_dining()
	var cells := [Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3)]
	var t := _add_table(cells, [Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3)])
	game.stations[Vector2i(5, 1)].tier = 3
	game.world.add_station("booth_seat", Vector2i(7, 1), 1, 0)
	game.world.add_station("chair", Vector2i(7, 2), 1, 0)
	var high := Guest.new()
	var low := Guest.new()
	var booth := Guest.new()
	for g: Guest in [high, low, booth]:
		add_child_autofree(g)
		g.setup(game, 0, Game.SPAWN)
		g.table = t[0]
		g.mood.joy = 0.5
	high.seat = Vector2i(5, 1)
	low.seat = Vector2i(7, 2)
	booth.seat = Vector2i(7, 1)
	for g: Guest in [high, low, booth]:
		game.seating.on_seated(g)
	assert_gt(high.mood.joy, low.mood.joy, "a tier 3 chair is comfier than a tier 1")
	assert_true(booth.mood.thoughts.has("A booth! How cosy"))
	assert_false(low.mood.thoughts.has("A booth! How cosy"))


func test_a_lone_guest_takes_the_one_chair_table_before_the_two_chair_one():
	_clear_dining()
	_add_table([Vector2i(6, 1)], [Vector2i(5, 1), Vector2i(7, 1)])
	var one := _add_table([Vector2i(8, 5)], [Vector2i(7, 5)])
	var solo: Guest = game.seating.spawn_guest(5)
	_run(14.0)
	assert_eq(solo.table, one[0])


func test_a_chair_turned_away_from_a_table_is_never_used():
	_clear_dining()
	var t := _add_table([Vector2i(6, 1)], [Vector2i(5, 1)])
	game.world.add_station("chair", Vector2i(8, 1), 1, 2)   # faces away
	assert_eq(game.tables.seats_of(t[0]).size(), 1)


func test_a_seat_piece_has_no_seats_of_its_own_and_a_table_tile_is_a_station_that_blocks():
	var chair: Station = game.world.add_station("chair", Vector2i(9, 6), 1, 0)
	assert_true(chair.seats.is_empty())
	assert_true(game.grid.reserved.has(Vector2i(9, 6)))
	game.world._unregister(chair)
	assert_false(game.grid.reserved.has(Vector2i(9, 6)))
	assert_true(game.grid.blocked.has(Vector2i(6, 1)))
