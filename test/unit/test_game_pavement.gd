extends "res://test/helpers/game_case.gd"
## The three-tile pavement: the chef walks the two open rows, the kerb tile holds props.


func _can_stand(c: Vector2i) -> bool:
	return not game.grid.chef_blocked(c)


func test_chef_stands_on_both_open_rows_to_either_end():
	var top: int = Game.LOT.position.y
	var bottom: int = Game.LOT.end.y - 1
	assert_true(_can_stand(Vector2i(Game.W, top)))
	assert_true(_can_stand(Vector2i(Game.W + 1, bottom)))
	assert_true(game.grid.reachable(Game.DOOR, Vector2i(Game.W + 1, bottom)))
	assert_true(game.grid.reachable(Game.DOOR, Vector2i(Game.W, top)))


func test_chef_never_stands_on_the_kerb_tile_or_the_road():
	for y in range(Game.LOT.position.y, Game.LOT.end.y):
		assert_false(_can_stand(Vector2i(Game.KERB_X, y)), "kerb %d" % y)
		assert_false(_can_stand(Vector2i(Game.KERB_X + 1, y)), "road %d" % y)
		assert_true(game.grid.is_blocked(Vector2i(Game.KERB_X, y)), "guests too")


func test_the_board_is_walked_round_and_survives_a_rebuild():
	assert_true(game.grid.is_blocked(Game.BOARD_CELL))
	game.world._sync_grid()
	assert_true(game.grid.is_blocked(Game.BOARD_CELL))
	assert_true(game.grid.reachable(Game.DOOR, Game.BOARD_CELL + Vector2i(0, 1)), "round it")
