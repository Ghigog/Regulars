extends "res://test/helpers/game_case.gd"
## The game reads the lot it owns: floors, pavement and the street follow it (EPIC-99-T2).

const NEAR_BLOCK := Vector2i(1, 2)   # bought at the near end of the street



func test_floor_is_laid_at_the_lot_edge_and_refused_past_it():
	game.plan.fill(Rect2i(-5, -2, 5, 1), "tile")   # floor touching the edge row
	assert_true(game.plan.can_lay(Vector2i(-5, -3), "tile"))
	assert_false(game.plan.can_lay(Vector2i(-5, -4), "tile"))


func test_bought_block_takes_floor_and_the_pavement_follows():
	assert_eq(game.exit_cell(), Vector2i(Game.W + 1, 6))
	assert_true(game.lot.buy(NEAR_BLOCK))
	game.world._sync_grid()
	assert_true(game.plan.can_lay(Vector2i(5, 7), "tile"), "touches the room's near wall")
	assert_eq(game.exit_cell(), Vector2i(Game.W + 1, 11))
	assert_eq(game.pavement().end.y, 12)
	assert_false(game.grid.chef_blocked(Vector2i(Game.W, 11)))
	assert_eq(game.spawn_cell(), Vector2i(Game.W + 1, -3))


func test_grid_holds_the_largest_lot():
	var far := Lot.max_bounds()
	assert_true(game.grid.in_bounds(far.position))
	assert_true(game.grid.in_bounds(far.end - Vector2i.ONE))
