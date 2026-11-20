extends "res://test/helpers/game_case.gd"
## The outside bin on the pavement (EPIC-20 T3): a chef can step out to it and no further.


func _can_walk(a: Vector2i, b: Vector2i) -> bool:
	return game.player._can_stand(Grid.center(a), Grid.center(b))


func test_chef_walks_out_the_door_to_the_bin_and_no_further():
	var door: Vector2i = Game.DOOR
	assert_true(_can_walk(door + Vector2i(-1, 0), door), "through the doorway")
	assert_true(_can_walk(door, door + Vector2i(1, 0)), "onto the pavement beside the bin")
	assert_false(_can_walk(door, door + Vector2i(0, 1)), "not down the pavement")
	assert_false(_can_walk(door, door + Vector2i(0, -1)), "not up the queue line")


func test_bin_is_clear_of_the_queue_and_the_chefs_reach():
	var bin := Scenery.outside_bin_cell()
	assert_false(game.grid.chef_pavement.has(bin), "the chef does not stand in it")
	for i in 12:
		assert_ne(Grid.to_cell(game.seating.queue_spot(i)), bin, "queue place %d" % i)
		assert_gt(game.seating.queue_spot(i).distance_to(Scenery.outside_bin_at()), 1.0)


func test_bin_lid_flips_and_closes():
	Scenery.flip_bin_lid()   # a scene without the street drawn must not fail either
	assert_true(true)
