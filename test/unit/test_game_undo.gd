extends "res://test/helpers/game_case.gd"
## Undo in the build phase: placing, moving, selling and floor strokes reversed to the cent.

const SPOT := Vector3i(8, 5, 0)


func _ids() -> Array:
	return game.hud.buttons_ui.specs().map(func(s: Dictionary) -> String: return s.id)


func _place_counter(spot := SPOT) -> void:
	assert_true(game.placing.pick_catalog("counter"))
	assert_true(game.placing.place(spot), "the counter is placed")
	game.player.hand = {}


func test_place_then_undo_restores_the_cell_and_the_money():
	_to_build()
	game.ledger.money = 500
	_place_counter()
	assert_true(game.stations.has(Vector2i(8, 5)))
	assert_lt(game.ledger.money, 500)
	assert_true(game.undo.undo(game.player))
	await get_tree().process_frame
	assert_false(game.stations.has(Vector2i(8, 5)), "the cell is free")
	assert_eq(game.ledger.money, 500)
	assert_false(game.undo.has_steps())


func test_move_then_undo_puts_the_piece_back_with_its_facing():
	_to_build()
	_place_counter()
	game.stations[Vector2i(8, 5)].place_at(Vector2i(8, 5), 1)
	assert_true(game.placing.pick_up(Grid.center(Vector2i(8, 5)), game.player))
	game.player.hand.facing = 3
	assert_true(game.placing.place(Vector3i(9, 5, 0)))
	assert_true(game.stations.has(Vector2i(9, 5)))
	assert_true(game.undo.undo(game.player))
	assert_true(game.stations.has(Vector2i(8, 5)), "back at its old cell")
	assert_false(game.stations.has(Vector2i(9, 5)))
	assert_eq(game.stations[Vector2i(8, 5)].facing, 1, "and its old facing")


func test_sell_then_undo_restores_the_piece_and_takes_the_sale_back():
	_to_build()
	_place_counter()
	game.ledger.money = 500
	assert_true(game.placing.pick_up(Grid.center(Vector2i(8, 5)), game.player))
	assert_true(game.placing.sell_hand(game.player))
	var sold_at: int = game.ledger.money
	assert_gt(sold_at, 500)
	assert_false(game.stations.has(Vector2i(8, 5)))
	assert_true(game.undo.undo(game.player))
	assert_true(game.stations.has(Vector2i(8, 5)), "the piece comes back")
	assert_eq(game.ledger.money, 500, "the sale is taken back")


func test_pad_undo_walks_back_two_steps_then_refuses():
	_to_build()
	_place_counter(Vector3i(8, 5, 0))
	assert_true(game.placing.pick_up(Grid.center(Vector2i(8, 5)), game.player))
	assert_true(game.placing.place(Vector3i(9, 5, 0)))   # moved
	assert_true(game.placing.pick_up(Grid.center(Vector2i(9, 5)), game.player))
	assert_true(game.placing.sell_hand(game.player))     # sold
	game.undo.steps.pop_front()   # the purchase is not part of this story
	_tap_pad(JOY_BUTTON_LEFT_STICK)
	assert_true(game.stations.has(Vector2i(9, 5)), "the sold piece returns first")
	_tap_pad(JOY_BUTTON_LEFT_STICK)
	assert_true(game.stations.has(Vector2i(8, 5)), "then the move is undone")
	var money: int = game.ledger.money
	_tap_pad(JOY_BUTTON_LEFT_STICK)
	assert_eq(game.ledger.money, money, "nothing left: nothing changes")
	assert_true(game.stations.has(Vector2i(8, 5)))


func test_a_sale_that_cannot_be_bought_back_changes_nothing():
	_to_build()
	_place_counter()
	assert_true(game.placing.pick_up(Grid.center(Vector2i(8, 5)), game.player))
	game.placing.sell_hand(game.player)
	game.ledger.money = 0
	assert_false(game.undo.undo(game.player))
	assert_false(game.stations.has(Vector2i(8, 5)))
	assert_eq(game.ledger.money, 0)
	assert_true(game.undo.has_steps(), "the step is kept")


func test_a_floor_drag_is_one_step():
	_to_build()
	game.ledger.money = 500
	var tiles: int = game.plan.floors.size()
	game.placing.pick_catalog("floor_planks")
	var n: int = game.room_edit.finish_drag(Vector3(-2.5, 0, 2.5), Vector3(-0.5, 0, 2.5), false)
	game.player.hand = {}
	assert_gt(n, 1, "several tiles laid")
	assert_eq(game.undo.steps.size(), 1)
	assert_true(game.undo.undo(game.player))
	assert_eq(game.plan.floors.size(), tiles, "the strip is gone")
	assert_eq(game.ledger.money, 500, "and refunded")


func test_ctrl_z_is_undo_and_plain_z_is_still_prev():
	_to_build()
	_place_counter()
	_key(KEY_CTRL)
	var e := InputEventKey.new()
	e.physical_keycode = KEY_Z
	e.keycode = KEY_Z
	e.pressed = true
	e.ctrl_pressed = true
	e.command_or_control_autoremap = true
	game.controls._unhandled_input(e)
	_key(KEY_CTRL, false)
	assert_false(game.stations.has(Vector2i(8, 5)), "Ctrl+Z undoes")
	assert_eq(Controls.action_for_key(KEY_Z), "prev")


func test_the_disc_shows_with_the_stack_and_goes_with_it():
	_to_build()
	assert_false("undo" in _ids())
	_place_counter()
	assert_true("undo" in _ids())
	assert_lt(_ids().find("shop"), _ids().find("undo"), "above Shop in the column")
	game.undo.undo(game.player)
	assert_false("undo" in _ids())


func test_a_hand_full_blocks_undo():
	_to_build()
	_place_counter()
	game.placing.pick_catalog("counter")
	assert_false(game.undo.undo(game.player))
	assert_true(game.stations.has(Vector2i(8, 5)))
	assert_false("undo" in _ids())


func test_opening_the_restaurant_clears_the_stack():
	_to_build()
	_place_counter()
	game.day.start_day()
	assert_false(game.undo.has_steps())
	assert_false(game.undo.undo(game.player))
