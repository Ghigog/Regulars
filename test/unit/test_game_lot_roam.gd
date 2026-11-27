extends "res://test/helpers/game_case.gd"
## Chefs walk round the restaurant at night, and the lot edge keeps off the room (T-93).


func _bare_cell() -> Vector2i:
	for c: Vector2i in game.grid.roam:
		if game.lot.has_point(c) and not game.plan.has_floor(c) and c.x < game.grid.pavement_from - 2:
			return c
	return Vector2i.MAX


func test_night_chef_steps_onto_unbought_ground_but_not_in_service():
	var c := Vector2i(Game.W, 0)
	var off := c + Vector2i(0, game.lot.bounds().size.y + 1)   # past the pavement rows, unowned
	if not game.grid.in_bounds(off) or not game.grid.roam.has(off):
		off = Vector2i(Game.W, game.lot.bounds().position.y - 1)
	assert_true(game.grid.roam.has(off), "unowned ground is roamable")
	assert_true(game.grid.chef_blocked(off))
	game.phase = Game.Phase.BUILD
	assert_false(game.grid.chef_blocked(off))
	game.phase = Game.Phase.SERVICE
	assert_true(game.grid.chef_blocked(off))


func test_night_chef_can_reach_a_buyable_block_behind_the_restaurant():
	game.phase = Game.Phase.BUILD
	var from := Vector2i(Game.W, game.lot.bounds().position.y)
	var to := Vector2i(-5, -1)
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	while not q.is_empty() and not seen.has(to):
		var a: Vector2i = q.pop_front()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var b := a + d
			if not seen.has(b) and not game.grid.chef_blocked(b) and game.grid.edge_open(a, b):
				seen[b] = true
				q.append(b)
	assert_true(seen.has(to), "a route round the building")


func test_chef_left_outside_is_moved_when_the_day_starts():
	game.phase = Game.Phase.BUILD
	var c := _bare_cell()
	assert_ne(c, Vector2i.MAX)
	game.player.position = Grid.center(c)
	game.day.start_day()
	assert_false(game.grid.chef_blocked(game.player.cell()))


func test_lot_edge_has_no_strip_along_floored_cells():
	game.phase = Game.Phase.BUILD
	game.player.position = Grid.center(Vector2i(-4, 1))   # outside, so the overlay shows
	game.lot_view._redraw()
	var mids := []
	for m: MeshInstance3D in game.lot_view._root.find_children("*", "MeshInstance3D", true, false):
		mids.append(Vector2(m.position.x, m.position.z))
	assert_gt(mids.size(), 0)
	var edge_floor := 0
	for x in range(game.grid.origin.x, game.grid.origin.x + game.grid.size.x):
		for y in range(game.grid.origin.y, game.grid.origin.y + game.grid.size.y):
			if not game.plan.has_floor(Vector2i(x, y)):
				continue
			for side: Vector2 in [Vector2(x + 0.5, y), Vector2(x + 0.5, y + 1), Vector2(x, y + 0.5), Vector2(x + 1, y + 0.5)]:
				for m: Vector2 in mids:
					if m.distance_to(side) < 0.01:
						edge_floor += 1
	assert_eq(edge_floor, 0)
