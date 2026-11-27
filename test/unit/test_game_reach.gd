extends "res://test/helpers/game_case.gd"
## Reach: a held modifier (Left Alt / Cmd, RT, the touch Reach button) picks the high layer
## (wall shelf, cabinet); plain E is what stands below. No guessing, no alternating.
## Headless there is no Controls, so a `reach` meta on the Player stands in for the key.

const C := Vector2i(0, 6)


func _reach(on: bool) -> void:
	game.player.set_meta("reach", on)


## A counter with a box of buns below and a wall shelf with cheese above it.
func _stocked_counter() -> void:
	if not game.stations.has(C):
		game.world.add_station("counter", C)
	if not game.highs.has(C):
		game.world.add_high("shelf", C)
	game.kitchen.cells[C].stock.base.assign(["box_bun"])
	game.kitchen.cells[C].stock.high.assign(["box_cheese"])
	game.player.position = Grid.center(Vector2i(1, 6))
	game.player.look(Vector2i(-1, 0))


func test_service_plain_use_takes_from_below_and_reach_from_the_shelf():
	_stocked_counter()
	var low: Station = game.world.station_at(C, game.player)
	assert_eq(game.cooking.use_station(low, true, game.player), "Take %s" % Pantry.name_of("bun").to_lower())
	_reach(true)
	var high: Station = game.world.station_at(C, game.player)
	assert_eq(high, game.highs[C], "reaching finds the shelf")
	assert_eq(game.cooking.use_station(high, true, game.player), "Take cheese")
	game.cooking.use_station(high, false, game.player)
	assert_eq(game.player.held, Tray.kind("raw", "cheese"))


func test_reach_with_an_empty_high_layer_does_nothing():
	_stocked_counter()
	game.highs.erase(C)
	_reach(true)
	assert_null(game.world.station_at(C, game.player))
	assert_eq(game.card.reach_action(game.player), "", "no chip while reaching, and none for nothing")


func test_the_prompt_chip_names_the_reach_action_until_it_is_held():
	_stocked_counter()
	assert_eq(game.card.reach_action(game.player), "Take cheese")
	_reach(true)
	assert_eq(game.card.reach_action(game.player), "", "held: the main prompt names it instead")


func test_a_sponge_on_a_shelf_is_only_taken_with_reach():
	if not game.stations.has(C):
		game.world.add_station("counter", C)
	game.player.position = Grid.center(Vector2i(1, 6))
	game.player.look(Vector2i(-1, 0))
	game.highs.erase(C)
	var shelf: Station = game.clean_kit.shelve(C, "sponge")
	assert_null(game.clean_kit.home_at(C, game.player))
	_reach(true)
	assert_eq(game.clean_kit.home_at(C, game.player), shelf)
	assert_eq(game.cooking.use_station(game.world.station_at(C, game.player), true, game.player), "Take sponge")


func test_night_plain_and_reach_pick_their_layer_every_time():
	_stocked_counter()
	game.session.open_build()
	for i in 3:
		_reach(false)
		assert_eq(game.card._card_layer_at(C, game.player), "base")
		assert_eq(game.card._lift_layer(C, game.player), "base")
		_reach(true)
		assert_eq(game.card._card_layer_at(C, game.player), "high")
		assert_eq(game.card._lift_layer(C, game.player), "high")
	game.highs.erase(C)
	assert_eq(game.card._card_layer_at(C, game.player), "", "Reach with nothing hung opens nothing")


func test_glyphs_and_the_reach_key():
	assert_eq(Controls.GLYPHS.keys.reach, "Alt")
	assert_eq(Controls.GLYPHS.pad.reach, "RT")
	assert_eq(Controls.GLYPHS.pad.aim, "LT")
	assert_eq(Controls.GLYPHS.touch.reach, "Reach")


## Buns on a shelf over a bin in the corner, a grill beside it: holding Reach next to the
## shelf takes a bun from the shelf wherever the chef stands, never the grill's cell.
func test_reach_targets_the_shelf_over_a_bin_not_the_grill_beside_it():
	var corner := Vector2i(0, 4)   # a wall cell, free in the starter kitchen
	var next := Vector2i(0, 5)
	game.world.add_station("bin", corner)
	game.world.add_station("grill", next)
	game.world.add_high("shelf", corner)
	game.kitchen.cells[corner].stock.high.assign(["box_bun"])
	_reach(true)
	for case in [[Vector2i(1, 4), Vector2i(0, -1)], [Vector2i(1, 4), Vector2i(0, 1)], [Vector2i(1, 4), Vector2i(-1, 0)]]:
		game.player.held = ""
		game.player.position = Grid.center(case[0])
		game.player.look(case[1])
		var label := "from %s facing %s" % case
		assert_eq(game.player.target_cell(), corner, label)
		var st: Station = game.world.station_at(game.player.target_cell(), game.player)
		game.cooking.use_station(st, false, game.player)
		assert_eq(game.player.held, "prep:bun", "took a bun " + label)
	game.player.held = ""
	game.player.position = Grid.center(Vector2i(1, 4))
	_reach(false)
	assert_eq(game.card.reach_action(game.player), "Take bun")
