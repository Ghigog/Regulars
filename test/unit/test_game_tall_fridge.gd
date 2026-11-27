extends "res://test/helpers/game_case.gd"
## A tall fridge has two levels: plain use takes the first kind, Reach (the `reach` meta
## stands in for the held key, as in test_game_reach.gd) the second.

const C := Vector2i(0, 6)


func _reach(on: bool) -> void:
	game.player.set_meta("reach", on)


func _fridge(boxes: Array) -> void:
	if not game.stations.has(C):
		game.world.add_station("counter", C)
	game.stations[C].set_base("tall_fridge")
	game.kitchen.set_cell(C, "tall_fridge")
	game.highs.erase(C)
	game.kitchen.cells[C].stock.base.assign(boxes)
	game.player.position = Grid.center(Vector2i(1, 6))
	game.player.look(Vector2i(-1, 0))


func _try(dry := false) -> String:
	var st: Station = game.world.station_at(C, game.player)
	return game.cooking.use_station(st, dry, game.player)


func test_plain_takes_the_first_kind():
	_fridge(["box_patty", "box_cheese"])
	assert_eq(_try(true), "Take patty")
	_try()
	assert_eq(game.player.held, Tray.kind("raw", "patty"))


func test_reach_takes_the_second_kind():
	_fridge(["box_patty", "box_cheese"])
	_reach(true)
	assert_eq(game.world.station_at(C, game.player), game.stations[C])
	assert_eq(_try(true), "Take cheese")
	_try()
	assert_eq(game.player.held, Tray.kind("raw", "cheese"))


func test_put_back_and_swap_per_level():
	_fridge(["box_patty", "box_cheese"])
	_try()
	_reach(true)
	assert_eq(_try(true), "Swap for cheese")
	_reach(false)
	assert_eq(_try(true), "Put back")
	_try()
	assert_eq(game.player.held, "")


func test_one_kind_has_no_chip_and_reach_does_nothing():
	_fridge(["box_patty"])
	assert_eq(game.card.reach_action(game.player), "")
	_reach(true)
	assert_eq(_try(true), "")
	_try()
	assert_eq(game.player.held, "")


func test_two_kinds_show_the_chip():
	_fridge(["box_patty", "box_cheese"])
	assert_eq(game.card.reach_action(game.player), "Take cheese")
