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
