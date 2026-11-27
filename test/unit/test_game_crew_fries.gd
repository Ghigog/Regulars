extends "res://test/helpers/game_case.gd"
## A helper who preps sides serves a Fries order: fetches a potato, chops it on the board,
## fries the cut potato (on a fryer, or a stove without one), and the chef touches none of it.

const PERSON := 5
const DUTIES := ["fetch", "board", "fry", "grill", "assemble", "carry_trays"]


func _kitchen(fryer: bool) -> void:
	game.menu.items.clear()
	game.menu.add("main", ["fries"], "Fries")
	game.menu_board.refresh(game.menu_stock.tonight_menu())
	game.menu_stock.stock_box("potato", Vector2i(1, 6))
	game.world.add_station("board", Vector2i(5, 5))
	game.world.add_station("fryer" if fryer else "stove", Vector2i(2, 5))
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])


func _fried_by_helper(fryer: bool) -> bool:
	_kitchen(fryer)
	game.crew.crew_demos.demo_hire(PERSON, "Cook", DUTIES, Vector2i(3, 3))
	var g := _ordered_guest()
	assert_eq(game.player.held, "", "the chef holds nothing")
	var fried := false
	for i in 2400:
		game.step(0.1)
		if game.crew.helpers[0].held == "prep:fries":
			fried = true
		if g.state in ["eating", "paying"]:
			break
	assert_eq(game.player.held, "", "the chef never touched it")
	return fried and g.state in ["eating", "paying"]


func test_a_helper_chops_and_fries_potato_on_a_fryer():
	_to_build()
	game.day.start_day()
	assert_true(_fried_by_helper(true))


func test_a_helper_fries_the_cut_potato_on_a_stove_without_a_fryer():
	_to_build()
	game.day.start_day()
	assert_true(_fried_by_helper(false))
