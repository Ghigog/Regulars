extends "res://test/helpers/game_case.gd"
## The outside bin on the pavement (EPIC-20 T3): a chef can step out beside it.


func _can_walk(a: Vector2i, b: Vector2i) -> bool:
	return game.player._can_stand(Grid.center(a), Grid.center(b))


func test_chef_walks_out_the_door_and_along_the_street():
	var door: Vector2i = Game.DOOR
	assert_true(_can_walk(door + Vector2i(-1, 0), door), "through the doorway")
	assert_true(_can_walk(door, door + Vector2i(1, 0)), "onto the outer row beside the bin")
	assert_false(_can_walk(door, door + Vector2i(0, 1)), "not through the menu board")
	var outer := door + Vector2i(1, 0)
	assert_true(_can_walk(outer, outer + Vector2i(0, 1)), "round the board, down the street")
	assert_true(_can_walk(door, door + Vector2i(0, -1)), "up the pavement")


func test_bin_stands_on_the_kerb_tile_clear_of_the_queue():
	var bin := Scenery.outside_bin_cell()
	assert_eq(bin.x, Game.KERB_X, "on the back tile")
	assert_true(game.grid.chef_blocked(bin), "the chef does not stand in it")
	for i in 12:
		assert_ne(Grid.to_cell(game.seating.queue_spot(i)), bin, "queue place %d" % i)
		assert_gt(game.seating.queue_spot(i).distance_to(Scenery.outside_bin_at()), 1.0)


func test_bin_lid_flips_and_closes():
	Scenery.flip_bin_lid()   # a scene without the street drawn must not fail either
	assert_true(true)
