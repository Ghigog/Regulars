extends "res://test/helpers/game_case.gd"
## A lifted piece always fits its own spot, and a refused spot says why (EPIC-3-T2).


## Every cell of the lot where the piece in hand is accepted.
func _accepted() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x in range(Game.LOT.position.x, Game.LOT.end.x):
		for y in range(Game.LOT.position.y, Game.LOT.end.y):
			if game.placing.can_place(Vector3i(x, y, 0)):
				out.append(Vector3i(x, y, 0))
	return out


func _lift_table() -> void:
	var t: Station = game.world.find_station("table")
	assert_true(game.placing.pick_up(Grid.center(t.cell)), "the table comes up")


func _shut_in(cell: Vector2i) -> void:
	for e in Floorplan.cell_edges(cell):
		game.grid.walls[e] = true


func test_chef_on_ground_the_door_cannot_reach_does_not_strand_the_piece():
	_to_build()
	var bare := Vector2i(5, -1)   # bare ground beside the floor
	assert_true(game.grid.is_blocked(bare))
	game.player.position = Grid.center(bare)
	_lift_table()
	assert_false(_accepted().is_empty(), "somewhere takes the piece")
	assert_true(game.placing.can_place(game.hand.from), "its own spot at least")


func test_station_already_closed_in_does_not_strand_the_piece():
	_to_build()
	game.ledger.money = 500
	var fridge: Station = game.world.add_station("fridge", Vector2i(2, 2))
	_shut_in(fridge.cell)
	assert_false(game.grid.layout_ok(Game.DOOR, game.placing._reach(), game.placing._touch()), "the room is broken")
	_lift_table()
	assert_false(_accepted().is_empty(), "somewhere takes the piece")
	assert_true(game.placing.can_place(game.hand.from), "its own spot at least")


func test_own_spot_is_always_accepted_and_put_back_in_the_held_facing():
	_to_build()
	_lift_table()
	var from: Vector3i = game.hand.from
	var was: int = game.hand.from_facing
	game.placing.rotate_hand()
	assert_eq(game.placing.place_refusal(from), "")
	assert_true(game.placing.place(from))
	assert_true(game.stations.has(Vector2i(from.x, from.y)), "put down where it came from")
	assert_true(game.hand.is_empty())


func test_own_spot_falls_back_to_the_old_facing_when_the_turn_does_not_pass():
	_to_build()
	_lift_table()
	var from: Vector3i = game.hand.from
	var was: int = game.hand.from_facing
	game.hand.facing = (was + 1) % 4
	# Block the turned seat so only the old way round passes.
	var turned := Station.seats_for("table", Vector2i(from.x, from.y), int(game.hand.facing))
	for s in turned:
		if not Station.seats_for("table", Vector2i(from.x, from.y), was).has(s):
			game.grid.blocked[s] = true
	assert_true(game.placing.place(from))
	assert_eq(game.stations[Vector2i(from.x, from.y)].facing, was)


func test_cutting_off_a_seat_says_so():
	_to_build()
	game.ledger.money = 500
	var seat: Vector2i = game.world.find_station("table").seats[0]
	var open: Array[Vector3i] = []   # the seat's ways in: sides not already blocked by furniture
	for d in Grid.DIRS:
		if not game.grid.is_blocked(seat + d):
			open.append(game.grid.edge_between(seat, seat + d))
	var last: Vector3i = open.pop_back()
	for e in open:
		game.grid.walls[e] = true
	game.placing.pick_catalog("wall")
	assert_eq(game.placing.place_refusal(last), "That would shut someone in")
	assert_false(game.placing.place(last))


func test_a_tool_over_bare_floor_goes_on_a_counter():
	_to_build()
	game.ledger.money = 500
	assert_true(game.placing.pick_catalog("board"))
	assert_eq(game.placing.place_refusal(Vector3i(3, 1, 0)), "Tools go on a counter")
	game.hand = {}
	assert_true(game.placing.pick_catalog("plant"))
	assert_eq(game.placing.place_refusal(Vector3i(40, 40, 0)), "That's off the lot")


func test_lifting_in_a_broken_room_names_what_is_shut_in():
	_to_build()
	game.ledger.money = 500
	var fridge: Station = game.world.add_station("fridge", Vector2i(2, 2))
	_shut_in(fridge.cell)
	_lift_table()
	assert_eq(game.hud.toast.text, "The under-counter fridge can't be reached")
