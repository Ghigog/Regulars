extends "res://test/helpers/kitchen_case.gd"
## An under-counter fridge put on another becomes a tall fridge, for good.

const A := Vector2i(2, 5)
const B := Vector2i(4, 5)
const TALL_WALL := "A tall fridge needs the wall above clear. Take down what hangs there first."


func _fridge(cell: Vector2i, facing: int, box: String) -> Station:
	var st := game.world.add_station("counter", cell, 1, facing)
	st.set_base("fridge")
	game.kitchen.set_cell(cell, "fridge")
	game.kitchen.store(cell, box)
	return st


func _carry_a() -> void:
	game.player.position = _at(2, 6)
	assert_true(game.placing.pick_up(_at(2, 5)))


func test_stacking_makes_a_tall_fridge_with_both_boxes():
	_game()
	_fridge(A, 0, "box_patty")
	_fridge(B, 1, "box_cheese")
	var money: int = game.ledger.money
	_carry_a()
	var spot := Vector3i(B.x, B.y, 0)
	assert_true(game.placing.can_place(spot))
	game.player.demo_hover = _at(B.x, B.y)
	assert_eq(game.room_edit.build_action(), "Make tall fridge")
	assert_true(game.placing.place(spot))
	var st: Station = game.stations[B]
	assert_eq(st.base, "tall_fridge")
	assert_eq(st.facing, 1)
	assert_eq(game.kitchen.get_piece(B, "base"), "tall_fridge")
	assert_eq((game.kitchen.cells[B].stock.base as Array).size(), 2)
	assert_false(game.stations.has(A))
	assert_eq(game.ledger.money, money)
	assert_false(game.undo.has_steps(), "nothing to undo after the merge")


func test_a_stacked_tall_fridge_lifts_whole_and_sells_for_half():
	_game()
	_fridge(A, 0, "box_patty")
	_fridge(B, 0, "box_cheese")
	_carry_a()
	assert_true(game.placing.place(Vector3i(B.x, B.y, 0)))
	game.player.position = _at(4, 6)
	assert_true(game.placing.pick_up(_at(4, 5)))   # boxes come first
	assert_true(game.placing.pick_up(_at(4, 5)))
	assert_true(game.placing.pick_up(_at(4, 5)))
	assert_eq(game.player.hand.node.base, "tall_fridge")
	assert_eq(game.placing.sell_value(game.player), Kitchen.price_of("tall_fridge") / 2)


func test_a_cabinet_above_or_a_tool_on_the_target_refuses():
	_game()
	_fridge(A, 0, "box_patty")
	_fridge(B, 0, "box_cheese")
	_carry_a()
	game.kitchen.cells[B].high = "cabinet"
	assert_eq(game.placing.place_refusal(Vector3i(B.x, B.y, 0)), TALL_WALL)
	game.kitchen.cells[B].high = ""
	game.stations[B].type = "board"
	assert_eq(game.placing.place_refusal(Vector3i(B.x, B.y, 0)), GamePlacing.TAKEN)
	game.stations[B].type = "counter"


func test_only_an_existing_fridge_stacks():
	_game()
	_fridge(B, 0, "box_cheese")
	assert_true(game.placing.pick_catalog("fridge"))
	assert_eq(game.placing.place_refusal(Vector3i(B.x, B.y, 0)), GamePlacing.TAKEN, "new from the shop")
	game.placing.cancel_hand()
	game.placing.pick_catalog("counter")
	game.placing.place(Vector3i(2, 5, 0))
	game.placing.cancel_hand()
	game.player.position = _at(2, 6)
	assert_true(game.placing.pick_up(_at(2, 5)))
	assert_eq(game.placing.place_refusal(Vector3i(B.x, B.y, 0)), GamePlacing.TAKEN, "a counter")
