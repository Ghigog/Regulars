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


# ---------------------------------------------------------------- turning a lifted piece

func _till_turn() -> float:
	return game.stations[Vector2i(4, 2)].get_node("till").rotation.y


func test_till_turned_in_hand_keeps_its_turn_on_the_same_counter():
	_to_build()
	var before := _till_turn()
	assert_true(game.placing.pick_up(Vector3(4.5, 0, 2.5), null, true, "till"))
	game.placing.rotate_hand()
	assert_eq(game.hand.facing, 1)
	assert_true(game.placing.place(Vector3i(4, 2, 0)))
	var till: Node3D = game.stations[Vector2i(4, 2)].get_node("till")
	assert_almost_eq(till.rotation.y, before + PI / 2, 0.001)
	assert_eq(int(till.get_meta("facing")), 1)
	var flat := Vector2(till.position.x, till.position.z)
	assert_almost_eq(flat.length(), 0.08, 0.001, "still centred on the worktop")
	assert_ne(game.paying.till_front(), game.NO_CELL)


func test_till_turned_in_hand_keeps_its_turn_on_another_counter():
	_to_build()
	assert_true(game.placing.pick_up(Vector3(4.5, 0, 2.5), null, true, "till"))
	game.placing.rotate_hand()
	game.placing.rotate_hand()
	assert_true(game.placing.place(Vector3i(4, 4, 0)))
	assert_eq(int(game.stations[Vector2i(4, 4)].get_node("till").get_meta("facing")), 2)


func test_till_picked_up_and_put_back_unturned_is_unchanged():
	_to_build()
	var before := _till_turn()
	assert_true(game.placing.pick_up(Vector3(4.5, 0, 2.5), null, true, "till"))
	assert_true(game.placing.place(Vector3i(4, 2, 0)))
	assert_almost_eq(_till_turn(), before, 0.001)


func test_cancelled_till_goes_back_as_it_was():
	_to_build()
	var before := _till_turn()
	assert_true(game.placing.pick_up(Vector3(4.5, 0, 2.5), null, true, "till"))
	game.placing.rotate_hand()
	game.placing.cancel_hand()
	assert_almost_eq(_till_turn(), before, 0.001)


func test_turned_till_survives_a_tool_going_on_its_counter():
	_to_build()
	assert_true(game.placing.pick_up(Vector3(4.5, 0, 2.5), null, true, "till"))
	game.placing.rotate_hand()
	assert_true(game.placing.place(Vector3i(4, 2, 0)))
	var st: Station = game.stations[Vector2i(4, 2)]
	var till: Node3D = st.get_node("till")
	var pos := till.position
	var tool := Station.new()
	game.add_child(tool)
	tool.setup("stove", Vector2i(4, 2), 1, 0)
	game.world._onto_counter(tool, Vector2i(4, 2), 0)
	till = game.stations[Vector2i(4, 2)].get_node("till")
	assert_eq(int(till.get_meta("facing")), 1, "on a tool")
	assert_eq(till.position, pos)
	game.world._off_counter(game.stations[Vector2i(4, 2)])
	till = game.stations[Vector2i(4, 2)].get_node("till")
	assert_eq(int(till.get_meta("facing")), 1, "and back off")
	assert_eq(till.position, pos)


func test_counters_turned_in_hand_keep_their_turn():
	_to_build()
	for cell: Vector2i in [Vector2i(4, 3), Vector2i(4, 5)]:
		var st: Station = game.stations[cell]
		assert_true(game.placing.pick_up(Vector3(cell.x + 0.5, 0, cell.y + 0.5), null, true))
		game.placing.rotate_hand()
		assert_true(game.placing.place(Vector3i(cell.x, cell.y, 0)))
		assert_eq(game.stations[cell].facing, 1, "turned on its own cell")
		assert_almost_eq(game.stations[cell]._vis.rotation.y, PI / 2, 0.001)


func test_counter_with_stock_turned_in_hand_lands_turned_on_a_free_cell():
	_to_build()
	var cell := Vector2i(4, 4)
	var to := Vector2i(6, 6)
	assert_false(game.stations.has(to), "a free cell")
	assert_true(game.placing.pick_up(Vector3(4.5, 0, 4.5), null, true))
	game.placing.rotate_hand()
	game.placing.rotate_hand()
	game.placing.rotate_hand()
	assert_true(game.placing.place(Vector3i(to.x, to.y, 0)))
	assert_eq(game.stations[to].facing, 3)
	assert_false(game.stations.has(cell))


func test_one_counter_of_a_double_counter_keeps_its_turn():
	_to_build()
	game.ledger.money = 500
	var st: Station = game.stations[Vector2i(4, 4)]   # as a save holds it: two counters stacked by hand
	st.set_base("double_counter")
	st.stacked = true
	game.kitchen.set_cell(Vector2i(4, 4), "double_counter")
	assert_true(game.placing.pick_up(Vector3(4.5, 0, 4.5), null, true))
	assert_eq(game.stations[Vector2i(4, 4)].base, "counter", "a counter stays standing")
	assert_false(game.placing.can_place(Vector3i(5, 4, 0)) and game.stations.has(Vector2i(5, 4)))
	game.placing.rotate_hand()
	assert_true(game.placing.place(Vector3i(4, 4, 0)))
	assert_true(game.stations[Vector2i(4, 4)].stacked, "back on top")


func test_pass_piece_shows_which_way_it_faces():
	var plain := Node3D.new()
	var marked := Node3D.new()
	BuildStations._pass(plain)
	BuildStations._pass(marked, true)
	assert_gt(marked.get_child_count(), plain.get_child_count(), "door and pull on the front")
	var piece: Station = game.stations[Vector2i(4, 3)]
	piece.place_at(piece.cell, 1)
	assert_almost_eq(piece._vis.rotation.y, PI / 2, 0.001, "the marked front turns with the piece")
	plain.free()
	marked.free()
