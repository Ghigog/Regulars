extends "res://test/helpers/game_case.gd"
## Undo for purchases and upgrades, and redo for everything undo reverses.

const SPOT := Vector3i(8, 5, 0)
const CELL := Vector2i(8, 5)


func _ids() -> Array:
	return game.hud.buttons_ui.specs().map(func(s: Dictionary) -> String: return s.id)


func _build(money := 900) -> void:
	_to_build()
	game.ledger.money = money
	game.ledger.xp = 100000


func _place(id: String, spot := SPOT) -> Node:
	assert_true(game.placing.pick_catalog(id))
	assert_true(game.placing.place(spot), "%s is placed" % id)
	game.player.hand = {}
	return game.stations.get(Vector2i(spot.x, spot.y))


## Opens the piece's card tree where it stands, as the Upgrades tab does.
func _card_hand(st: Station) -> void:
	game.player.hand = {"id": st.type, "tier": st.tier, "price": 0, "facing": st.facing, "moving": true,
		"node": st, "in_place": true, "layer": "base", "from": Vector3i(st.cell.x, st.cell.y, 0), "from_facing": st.facing}


func _upgrade_in_place(st: Station, to: String) -> void:
	_card_hand(st)
	assert_true(game.upgrades.buy_upgrade(to, game.player), "bought %s" % to)
	game.player.hand = {}


func _block() -> Vector2i:
	return game.lot.buyable()[0]


func test_lot_block_undo_and_redo():
	_build()
	var b := _block()
	var price: int = game.lot.next_price()
	assert_true(game.lot_view.buy(b))
	assert_eq(game.ledger.money, 900 - price)
	assert_true(game.undo.undo(game.player))
	assert_false(game.lot.blocks.has(b))
	assert_eq(game.lot.next_price(), price, "the price is what it was")
	assert_true(game.lot.buyable().has(b), "buyable again")
	assert_eq(game.ledger.money, 900)
	assert_true(game.undo.redo(game.player))
	assert_true(game.lot.blocks.has(b))
	assert_eq(game.ledger.money, 900 - price)
	assert_true(game.undo.has_steps())
	assert_false(game.undo.has_redo())


func test_ctrl_shift_z_and_ctrl_y_redo():
	_build()
	_place("counter")
	game.undo.undo(game.player)
	for key in [KEY_Z, KEY_Y]:
		var e := InputEventKey.new()
		e.physical_keycode = key
		e.keycode = key
		e.pressed = true
		e.ctrl_pressed = true
		e.shift_pressed = key == KEY_Z
		e.command_or_control_autoremap = true
		game.controls._unhandled_input(e)
		assert_true(game.stations.has(CELL), "redone by %s" % key)
		game.undo.undo(game.player)


func test_flyers_undo_and_redo():
	_build()
	assert_true(game.room_edit.buy_flyers())
	assert_true(game.undo.undo(game.player))
	assert_false(game.flyers_out)
	assert_eq(game.ledger.money, 900)
	assert_true(game.undo.redo(game.player))
	assert_true(game.flyers_out)
	assert_eq(game.ledger.money, 900 - Town.FLYER_PRICE)


func test_sponge_undo_only_while_in_hand():
	_build()
	assert_true(game.placing.pick_catalog("sponge"))
	var price: int = 900 - game.ledger.money
	assert_gt(price, 0)
	assert_true(game.undo.undo(game.player))
	assert_false(CleanKit.holding(game.player))
	assert_eq(game.ledger.money, 900)
	assert_true(game.undo.redo(game.player))
	assert_true(CleanKit.holding(game.player))
	game.player.set_held("")   # it left the hands
	assert_false(game.undo.undo(game.player), "it has changed since")
	assert_eq(game.ledger.money, 900 - price)


func test_upgrade_in_place_undo_keeps_the_stock_and_redo_buys_again():
	_build()
	var st := _place("counter") as Station
	assert_true(game.kitchen.store(CELL, "box_cleaner"))
	var money: int = game.ledger.money
	_upgrade_in_place(st, "fridge")
	var price: int = money - game.ledger.money
	assert_eq(price, Upgrades.step_price("fridge"))
	assert_true(game.undo.undo(game.player))
	assert_eq(game.stations[CELL].base, "counter")
	assert_eq(game.kitchen.get_piece(CELL, "base"), "counter")
	assert_has(game.kitchen.stock(CELL), "box_cleaner")
	assert_eq(game.ledger.money, money)
	assert_true(game.undo.redo(game.player))
	assert_eq(game.stations[CELL].base, "fridge")
	assert_eq(game.ledger.money, money - price)
	assert_true(game.undo.undo(game.player))
	assert_eq(game.ledger.money, money)


func test_lifted_upgrade_put_down_is_two_steps():
	_build()
	var st := _place("counter") as Station
	var money: int = game.ledger.money
	assert_true(game.placing.pick_up(Grid.center(CELL), game.player))
	assert_true(game.upgrades.buy_upgrade("fridge", game.player))
	assert_true(game.placing.place(Vector3i(9, 5, 0)))
	assert_eq(game.stations[Vector2i(9, 5)].base, "fridge")
	assert_true(game.undo.undo(game.player), "the move first")
	assert_eq(game.stations[CELL].base, "fridge")
	assert_true(game.undo.undo(game.player), "then the upgrade")
	assert_eq(game.stations[CELL].base, "counter")
	assert_eq(game.ledger.money, money)
	assert_true(game.undo.redo(game.player))
	assert_eq(game.stations[CELL].base, "fridge")
	assert_true(game.undo.redo(game.player))
	assert_true(game.stations.has(Vector2i(9, 5)))
	assert_false(game.stations.has(CELL))
	assert_eq(game.ledger.money, money - Upgrades.step_price("fridge"))


func test_counter_grown_into_a_stove_undoes_to_the_counter():
	_build()
	var st := _place("counter") as Station
	var money: int = game.ledger.money
	_upgrade_in_place(st, "stove")
	assert_eq(game.stations[CELL].type, "stove")
	assert_true(game.undo.undo(game.player))
	assert_eq(game.stations[CELL].type, "counter")
	assert_eq(game.ledger.money, money)
	assert_true(game.undo.redo(game.player))
	assert_eq(game.stations[CELL].type, "stove")
	assert_eq(game.ledger.money, money - Upgrades.step_price("stove"))


func test_table_branch_undo_and_redo():
	_build()
	var t := _place("table") as Station
	var facing := t.facing
	var money: int = game.ledger.money
	var to: String = Upgrades.children("table@1")[0]
	_upgrade_in_place(t, to)
	assert_eq(game.stations[CELL].type, Upgrades.catalog_id(to))
	assert_true(game.undo.undo(game.player))
	assert_eq(game.stations[CELL].type, "table")
	assert_eq(game.stations[CELL].facing, facing)
	assert_eq(game.ledger.money, money)
	assert_true(game.undo.redo(game.player))
	assert_eq(game.stations[CELL].type, Upgrades.catalog_id(to))
	assert_eq(game.ledger.money, money - Upgrades.step_price(to))


func test_seat_branch_undo():
	_build()
	var c := _place("chair") as Station
	var money: int = game.ledger.money
	var to: String = Upgrades.children("chair@1")[0]
	_upgrade_in_place(c, to)
	assert_true(game.undo.undo(game.player))
	assert_eq(game.stations[CELL].type, "chair")
	assert_eq(game.stations[CELL].tier, 1)
	assert_eq(game.ledger.money, money)


func test_treatment_box_undo():
	_build()
	var st := _place("counter") as Station
	assert_true(game.kitchen.store(CELL, "box_cleaner"), "a box on the counter")
	game.treat_laid = {Vector2i(4, 2): "cleaner"}
	var money: int = game.ledger.money
	assert_true(game.placing.pick_up(Grid.center(CELL), game.player))
	assert_eq(game.player.hand.id, "box_cleaner")
	assert_true(game.upgrades.buy_upgrade("box_primer", game.player))
	game.placing.cancel_hand(game.player)
	assert_eq(game.treat_laid[Vector2i(4, 2)], "primer")
	assert_true(game.undo.undo(game.player))
	assert_has(game.kitchen.stock(CELL), "box_cleaner")
	assert_does_not_have(game.kitchen.stock(CELL), "box_primer")
	assert_eq(game.treat_laid[Vector2i(4, 2)], "cleaner")
	assert_eq(game.ledger.money, money)


func test_upgrade_refuses_when_the_piece_is_gone():
	_build()
	var st := _place("counter") as Station
	_upgrade_in_place(st, "fridge")
	game.stations[CELL].queue_free()
	game.stations.erase(CELL)
	var money: int = game.ledger.money
	assert_false(game.undo.undo(game.player))
	assert_eq(game.ledger.money, money)
	assert_true(game.undo.has_steps())


func test_redo_of_place_move_sell_and_plan():
	_build()
	_place("counter")
	assert_true(game.placing.pick_up(Grid.center(CELL), game.player))
	assert_true(game.placing.place(Vector3i(9, 5, 0)))
	assert_true(game.placing.pick_up(Grid.center(Vector2i(9, 5)), game.player))
	assert_true(game.placing.sell_hand(game.player))
	game.placing.pick_catalog("floor_planks")
	game.room_edit.finish_drag(Vector3(-2.5, 0, 2.5), Vector3(-0.5, 0, 2.5), false)
	game.player.hand = {}
	var floors: int = game.plan.floors.size()
	var money: int = game.ledger.money
	for i in 4:
		assert_true(game.undo.undo(game.player), "undo %d" % i)
	assert_false(game.stations.has(CELL))
	assert_eq(game.ledger.money, 900)
	assert_true(game.undo.redo(game.player))   # place
	assert_true(game.stations.has(CELL))
	assert_true(game.undo.redo(game.player))   # move
	assert_true(game.stations.has(Vector2i(9, 5)))
	assert_true(game.undo.redo(game.player))   # sell
	assert_false(game.stations.has(Vector2i(9, 5)))
	assert_true(game.undo.redo(game.player))   # plan
	assert_eq(game.plan.floors.size(), floors)
	assert_eq(game.ledger.money, money)
	assert_false(game.undo.has_redo())
	assert_false(game.undo.redo(game.player), "nothing to redo")


func test_a_new_action_empties_redo():
	_build()
	_place("table")
	game.undo.undo(game.player)
	assert_true(game.undo.has_redo())
	assert_true("redo" in _ids())
	_place("counter", Vector3i(9, 5, 0))
	assert_false(game.undo.has_redo())
	assert_false("redo" in _ids())
	assert_true("undo" in _ids())


func test_a_redo_that_cannot_be_paid_changes_nothing():
	_build()
	_place("table")
	game.undo.undo(game.player)
	game.ledger.money = 0
	assert_false(game.undo.redo(game.player))
	assert_false(game.stations.has(CELL))
	assert_eq(game.ledger.money, 0)
	assert_true(game.undo.has_redo(), "the step waits")


func test_the_redo_disc_sits_above_undo_only_with_something_to_redo():
	_build()
	assert_false("redo" in _ids())
	_place("counter")
	_place("counter", Vector3i(9, 5, 0))
	game.undo.undo(game.player)
	var ids := _ids()
	assert_true("redo" in ids and "undo" in ids)
	var at := {}
	for s in game.hud.buttons_ui.specs():
		at[s.id] = s.centre
	assert_eq(at.redo.x, at.undo.x)
	assert_lt(at.redo.y, at.undo.y, "above Undo")
	game.placing.pick_catalog("counter")
	assert_false("redo" in _ids(), "not with a piece in hand")
	game.player.hand = {}
	game.undo.clear()
	assert_false("redo" in _ids())
