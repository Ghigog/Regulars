extends "res://test/helpers/game_case.gd"
## Tables, chairs and decor on the open pavement, and guests seated there (EPIC-58-T3).

const STREET := Vector2i(Game.W + 1, 1)   # an open pavement cell off the queue line


func _hold(id: String, facing := 0) -> void:
	game.ledger.money = 500
	game.ledger.xp = 500
	assert_true(game.placing.pick_catalog(id), "bought " + id)
	for i in facing:
		game.placing.rotate_hand()


func _refusal(id: String, cell: Vector2i, facing := 0) -> String:
	_to_build()
	_hold(id, facing)
	return game.placing.place_refusal(Vector3i(cell.x, cell.y, 0))


func test_table_goes_down_on_an_open_pavement_cell():
	assert_eq(_refusal("table", Vector2i(Game.W + 1, 1), 1), "")
	assert_true(game.placing.place(Vector3i(Game.W + 1, 1, 0)))
	assert_true(game.stations.has(Vector2i(Game.W + 1, 1)))


func test_queue_line_doorway_board_kerb_and_road_are_refused():
	for cell in [Vector2i(Game.W, 0), Game.DOOR, Game.BOARD_CELL, Vector2i(Game.KERB_X, 1), Vector2i(Game.KERB_X + 1, 1)]:
		assert_ne(_refusal("plant", cell), "", "refused at %s" % cell)


func test_chair_on_the_queue_line_is_refused():
	assert_ne(_refusal("chair", Vector2i(Game.W, 1), 0), "", "a seat on the queue line")


func test_piece_that_shuts_the_street_end_off_is_refused():
	_to_build()
	_hold("plant")
	# The board closes (W, 5), so (W + 1, 5) is the only way down to the street end.
	var why: String = game.placing.place_refusal(Vector3i(Game.W + 1, 5, 0))
	assert_eq(why, "That would shut someone in")


func test_kitchen_pieces_stay_off_the_pavement():
	assert_ne(_refusal("counter", STREET), "")


func test_guest_goes_through_seat_order_serve_pay_at_an_outdoor_table():
	_to_build()
	# Take the indoor tables away so the pavement is the only seating.
	for st: Station in game.stations.values().duplicate():
		if Station.is_table(st.type) or Station.is_seat(st.type):
			game.world._unregister(st)
			st.queue_free()
	_hold("table")
	assert_true(game.placing.place(Vector3i(STREET.x, STREET.y, 0)))
	game.placing.cancel_hand()
	_hold("chair", 3)   # below the table, facing it
	assert_true(game.placing.place(Vector3i(STREET.x, STREET.y + 1, 0)))
	game.placing.cancel_hand()
	game.phase = Game.Phase.SERVICE   # the door opens on the new layout
	game.tables.rebuild()
	assert_eq(game.tables.list.size(), 1, "the pavement table is counted")
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	_order(g)
	assert_true(g.cell.x > Game.W, "seated out on the pavement")
	game.serving.serve(g, game.serving.full_tray_for(g))
	var before: int = game.ledger.money
	_run(g.eat_time + Guest.CHAT_TIME + 0.5)
	game.paying.pay_bill(g.table)
	assert_gt(game.ledger.money, before, "the bill is paid")


func test_guest_steps_round_a_piece_on_the_outer_lane():
	_to_build()
	var row := 3
	game.grid.blocked[Vector2i(Game.W + 1, row)] = true
	var lane: Vector2i = game.seating.outer_lane(row)
	assert_false(game.grid.is_blocked(lane))
	assert_eq(game.seating.outer_lane(row + 2), Vector2i(Game.W + 1, row + 2))
