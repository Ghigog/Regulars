extends "res://test/helpers/game_case.gd"


# ---------------------------------------------------------------- building the room

func test_floor_tool_grows_the_room_and_charges_per_tile():
	_to_build()
	game.ledger.money = 100
	assert_true(game.placing.pick_catalog("floor_planks"))
	assert_true(game.grid.is_blocked(Vector2i(5, -1)), "bare ground behind the dining room")
	assert_eq(game.room_edit.finish_drag(Vector3(4.5, 0, -0.5), Vector3(7.5, 0, -1.5), false), 8)
	assert_eq(game.ledger.money, 60)
	assert_false(game.grid.is_blocked(Vector2i(5, -1)), "now floor")
	assert_true(game.grid.reachable(Vector2i(5, 1), Vector2i(5, -2)), "the old back wall came down")
	assert_eq(game.hand.id, "floor_planks", "still in hand for more")
	assert_eq(game.room_edit.finish_drag(Vector3(4.5, 0, -3.5), Vector3(7.5, 0, -3.5), false), 0, "nothing past the edge of the lot")
	assert_true(game.placing.place(Vector3i(3, 1, 0)), "laid beside the room one at a time")
	assert_true(game.room_edit.remove_at(Vector3i(3, 1, 0)))
	assert_eq(game.ledger.money, 60, "taking a tile up pays it back")
	assert_false(game.room_edit.remove_at(Vector3i(9, 4, 0)), "never the floor inside the front door")
	assert_false(game.room_edit.remove_at(Vector3i(6, 1, 0)), "nor under a table")



func test_walls_divide_the_room_but_never_shut_anyone_in():
	_to_build()
	game.ledger.money = 500
	game.placing.pick_catalog("floor_planks")
	game.room_edit.finish_drag(Vector3(4.5, 0, -0.5), Vector3(9.5, 0, -1.5), false)
	assert_true(game.placing.pick_catalog("wall"))
	var built: int = game.room_edit.finish_drag(Vector3(4, 0, 0), Vector3(10, 0, 0), false)
	assert_eq(built, 6)
	assert_false(game.grid.reachable(Vector2i(5, 1), Vector2i(5, -1)), "the back room is walled off")
	assert_false(game.grid.has_los(Vector2i(5, 1), Vector2i(5, -1)))
	# A wall across the front of a table's seats would cut them off: refused.
	var seat: Vector2i = game.world.find_station("table").seats[0]
	var shut := 0
	for e in Floorplan.cell_edges(seat):
		if game.placing.can_place(e):
			game.placing.place(e)
			shut += 1
	assert_true(game.grid.reachable(game.DOOR, seat), "the seat can still be reached")
	assert_lt(shut, 4)



func test_doors_and_archways_open_walls_and_warn_when_unusable():
	_to_build()
	game.ledger.money = 500
	assert_true(game.placing.pick_catalog("door"))
	var back := Vector3i(6, 0, 0)
	assert_true(game.placing.place(back), "a door can go in the back wall before there is a room behind it")
	assert_false(game.world.opening_usable(back), "it leads onto bare ground")
	assert_eq(game.ledger.money, 480)
	game.placing.pick_catalog("floor_planks")
	assert_true(game.placing.place(Vector3i(6, -1, 0)))
	assert_false(game.plan.openings.has(back), "laying floor past an outer door merges the rooms")
	assert_eq(game.ledger.money, 495, "and the door is paid back")
	game.placing.pick_catalog("wall")
	assert_true(game.placing.place(back))
	game.placing.pick_catalog("arch")
	assert_true(game.placing.place(back))
	assert_true(game.world.opening_usable(back))
	assert_true(game.grid.has_los(Vector2i(6, 0), Vector2i(6, -1)), "an archway lets guests see through")
	assert_true(game.room_edit.remove_at(back))
	game.placing.pick_catalog("door")
	assert_true(game.placing.place(back))
	assert_true(game.grid.reachable(Vector2i(6, 0), Vector2i(6, -1)))
	assert_false(game.grid.has_los(Vector2i(6, 0), Vector2i(6, -1)), "a door does not")
	# A door with a stove in front of it cannot be used.
	assert_true(game.placing.place(Vector3i(0, 3, 1)))
	assert_false(game.world.opening_usable(Vector3i(0, 3, 1)))
	assert_false(game.plan.has_floor(Vector2i(-1, 3)))



func test_mouse_drags_lay_floor_and_right_drags_take_it_up():
	_to_build()
	game.cam.position = game._frame[0] + game.CAM_OFFSET   # settled, as after a frame or two
	game.cam.size = game._frame[1]
	game.ledger.money = 100
	game.placing.pick_catalog("floor_tile")
	_mouse(Vector3(0.5, 0, 1.5), MOUSE_BUTTON_LEFT, true)
	assert_eq(game.room_edit.build_action().begins_with("Lay"), true, "the prompt counts the drag")
	_mouse(Vector3(3.5, 0, 0.5), MOUSE_BUTTON_LEFT, false)
	assert_eq(game.plan.kind(Vector2i(0, 0)), "tile", "the corner behind the kitchen is floored")
	assert_eq(game.ledger.money, 60)
	_mouse(Vector3(0.5, 0, 0.5), MOUSE_BUTTON_RIGHT, true)
	_mouse(Vector3(1.5, 0, 0.5), MOUSE_BUTTON_RIGHT, false)
	assert_false(game.plan.has_floor(Vector2i(1, 0)))
	assert_eq(game.ledger.money, 70)
