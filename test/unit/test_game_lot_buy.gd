extends "res://test/helpers/game_case.gd"
## The lot's edge and buyable blocks at night, and buying one by holding shop (EPIC-99-T3).

const BLOCK := Vector2i(-2, 0)   # the block behind the restaurant, x -10..-6, y -3..1


func _view() -> Node:
	game.lot_view._redraw()
	return game.lot_view._root


func _stand_at_block() -> void:
	game.phase = Game.Phase.BUILD
	game.player.position = Grid.center(Vector2i(-5, -1))
	game.player.look(Vector2i(-1, 0))


func _go_out() -> void:
	game.player.position = Grid.center(Vector2i(-4, 1))


func _go_in() -> void:
	game.player.position = Grid.center(Vector2i(2, 3))


func test_build_phase_draws_the_edge_and_every_buyable_block():
	game.phase = Game.Phase.BUILD
	_go_out()
	var root := _view()
	assert_not_null(root)
	var plus := 0
	var prices := 0
	for l in root.find_children("*", "Label3D", true, false):
		plus += int(l.text == "+")
		prices += int(l.text == "$150")
	assert_eq(plus, game.lot.buyable().size())
	assert_eq(prices, game.lot.buyable().size())
	assert_gt(root.find_children("*", "MeshInstance3D", true, false).size(), 0, "the white line")


func test_day_phase_draws_nothing():
	game.phase = Game.Phase.BUILD
	_go_out()
	_view()
	game.phase = Game.Phase.SERVICE
	assert_null(_view())


func test_holding_shop_at_a_block_buys_it_and_the_price_rises():
	_stand_at_block()
	game.ledger.money = 400
	game.lot_view.tick(game.player, true, GameLotView.HOLD_TIME + 0.1)
	assert_true(game.lot.blocks.has(BLOCK))
	assert_eq(game.ledger.money, 250)
	assert_eq(game.lot.next_price(), 225)


func test_a_short_press_buys_nothing():
	_stand_at_block()
	game.ledger.money = 400
	game.lot_view.tick(game.player, true, 0.2)
	game.lot_view.tick(game.player, false, 0.1)
	game.lot_view.tick(game.player, true, 0.2)
	assert_false(game.lot.blocks.has(BLOCK))
	assert_eq(game.ledger.money, 400)


func test_without_the_money_nothing_is_bought_and_a_line_says_why():
	_stand_at_block()
	game.ledger.money = 100
	game.lot_view.tick(game.player, true, GameLotView.HOLD_TIME + 0.1)
	assert_false(game.lot.blocks.has(BLOCK))
	assert_eq(game.ledger.money, 100)
	assert_true(game.hud.toast.text.contains("$150"))


func test_overlay_is_hidden_while_the_only_chef_is_on_the_floor():
	game.phase = Game.Phase.BUILD
	_go_in()
	assert_true(game.plan.has_floor(Grid.to_cell(game.player.position)))
	assert_null(_view())


func test_overlay_shows_when_a_chef_walks_out_and_hides_when_back_in():
	game.phase = Game.Phase.BUILD
	_go_in()
	assert_null(_view())
	_go_out()
	assert_not_null(_view())
	_go_in()
	assert_null(_view())


func test_a_chef_inside_facing_a_block_gets_none():
	game.phase = Game.Phase.BUILD
	game.player.position = Grid.center(Vector2i(2, 3))
	game.player.look(Vector2i(-1, 0))
	assert_eq(game.lot_view.block_for(game.player), Vector2i.MAX)
	_go_out()
	game.player.position = Grid.center(Vector2i(-5, -1))
	assert_ne(game.lot_view.block_for(game.player), Vector2i.MAX)


func test_with_two_chefs_one_outside_is_enough():
	game.phase = Game.Phase.BUILD
	_go_in()
	var second := Player.new()
	game.add_child(second)
	second.position = Grid.center(Vector2i(-4, 1))
	game.chefs.append(second)
	assert_not_null(_view())
	second.position = Grid.center(Vector2i(2, 3))
	assert_null(_view())
	game.chefs.erase(second)
	second.queue_free()
