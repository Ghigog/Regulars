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
