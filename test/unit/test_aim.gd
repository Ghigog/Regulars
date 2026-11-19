extends GutTest
## Shift (a trigger, the touch Aim button) holds the chef in place: the move input
## only turns them, diagonals too at night, so any cell around them can be reached.

var game


func before_each():
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.arrivals.clear()
	game.step(0.1)
	game.step(0.1)
	game.session.open_build()


func test_holding_aim_turns_without_walking():
	var ch: Player = game.player
	ch.position = Grid.center(Vector2i(6, 3))
	var at := ch.position
	for i in 10:
		ch.move(Vector2(1, 0), 0.1, true)   # D held with Shift
	assert_eq(ch.position, at, "planted")
	assert_eq(ch.facing, Vector2i(1, -1), "screen right is a diagonal cell at night")
	ch.move(Vector2(0, 1), 0.1, true)       # W
	assert_eq(ch.facing, Vector2i(-1, -1), "W faces the cell straight up the screen")
	ch.move(Vector2(1, 1).normalized(), 0.1, true)   # W and D
	assert_eq(ch.facing, Vector2i(0, -1))
	ch.move(Vector2(1, 0), 0.1)
	assert_ne(ch.position, at, "let go, the chef walks again")


func test_an_aimed_diagonal_piece_is_picked_up():
	var ch: Player = game.player
	ch.position = Grid.center(Vector2i(5, 3))
	ch.move(Vector2(-1, 0), 0.1, true)       # A: the cell up-left on screen is (4, 4)
	assert_eq(ch.facing, Vector2i(-1, 1))
	assert_eq(game.room_edit.build_action(), "Pick up")
	var counter: Station = game.stations[Vector2i(4, 4)]
	game.room_edit.build_interact()
	assert_eq(game.player.hand.get("node"), counter, "the diagonal counter is lifted")


func test_aim_is_a_held_action_not_a_press():
	game.coop.act(0, "aim")
	assert_true(game.player.hand.is_empty())
	game.controls.players[0].hold("pad:0", "trigger4", "aim", true)
	assert_true(game.controls.aiming(0))
	game.controls.players[0].hold("pad:0", "trigger4", "aim", false)
	assert_false(game.controls.aiming(0))


func _stand(cell: Vector2i, off := Vector3.ZERO, face := Vector2i(0, 1)) -> Player:
	var ch: Player = game.player
	ch.position = Grid.center(cell) + off
	ch.look(face)
	return ch


func test_night_pick_up_takes_the_nearest_piece_even_off_centre_and_turned_away():
	var ch := _stand(Vector2i(5, 3), Vector3(0.2, 0, 0.3), Vector2i(0, 1))   # the counter at (4, 3) is beside, not ahead
	assert_eq(game.room_edit.build_action(), "Pick up")
	assert_eq(Grid.to_cell(game.room_edit._piece_in_front(ch)), Vector2i(4, 3))
	assert_eq(game.card.lift_name(ch), "counter")
	game.room_edit.build_interact()
	assert_eq(game.player.hand.get("node"), game.stations.get(Vector2i(4, 3), game.player.hand.get("node")))
	assert_false(game.player.hand.is_empty(), "lifted")


func test_night_pick_up_prefers_the_faced_piece_only_on_a_near_tie():
	var ch := _stand(Vector2i(5, 3), Vector3(0, 0, 0.1), Vector2i(-1, 1))   # faces (4, 4), (4, 3) is nearer
	assert_eq(Grid.to_cell(game.room_edit._piece_in_front(ch)), Vector2i(4, 3))
	ch.position = Grid.center(Vector2i(5, 4)) + Vector3(0, 0, -0.5)   # on the line between (4, 3) and (4, 4)
	ch.look(Vector2i(-1, 1))
	assert_eq(Grid.to_cell(game.room_edit._piece_in_front(ch)), Vector2i(4, 4), "faced, and as close")


func test_night_aiming_picks_the_faced_piece_exactly():
	var ch := _stand(Vector2i(5, 3), Vector3(0, 0, 0.1), Vector2i(-1, 0))
	assert_eq(Grid.to_cell(game.room_edit._piece_in_front(ch)), Vector2i(4, 3))
	ch.aiming = true
	ch.look(Vector2i(-1, 1))
	assert_eq(Grid.to_cell(game.room_edit._piece_in_front(ch)), Vector2i(4, 4))
	game.room_edit.build_interact()
	assert_eq(game.player.hand.get("node"), game.stations[Vector2i(4, 4)] if game.stations.has(Vector2i(4, 4)) else game.player.hand.get("node"))
	assert_false(game.player.hand.is_empty())


func test_night_pick_up_takes_a_partition_the_chef_faces():
	game.placing.pick_catalog("screen")
	assert_true(game.placing.place(Vector3i(6, 3, 1)))
	game.player.hand = {}
	var ch := _stand(Vector2i(6, 3), Vector3.ZERO, Vector2i(-1, 0))
	var p: Vector3 = game.room_edit._piece_in_front(ch)
	assert_eq(GamePlacing.snap_edge(p), Vector3i(6, 3, 1))
	game.room_edit.build_interact()
	assert_false(game.wall_nodes.has(Vector3i(6, 3, 1)), "the partition is lifted")


func test_night_pick_up_does_not_reach_through_a_partition():
	game.placing.pick_catalog("screen")
	assert_true(game.placing.place(Vector3i(5, 3, 1)))   # between (4, 3) and (5, 3)
	game.player.hand = {}
	var ch := _stand(Vector2i(5, 3), Vector3(-0.3, 0, 0), Vector2i(-1, 0))
	var p: Vector3 = game.room_edit._piece_in_front(ch)
	assert_eq(GamePlacing.snap_edge(p), Vector3i(5, 3, 1), "only the partition is offered, not the counter behind it")


func test_night_pick_up_offers_nothing_out_of_reach():
	var ch := _stand(Vector2i(9, 6))
	assert_eq(game.room_edit._piece_in_front(ch), Vector3.INF)
	assert_ne(game.room_edit.build_action(), "Pick up")
