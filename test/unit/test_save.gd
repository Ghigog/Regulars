extends GutTest
## The saved game (written at the start of the night) and the pause menu.

const SAVE_TEST_PATH := "user://regulars_save_test.dat"
var game


func before_each():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEST_PATH))
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.save_path = SAVE_TEST_PATH


func after_each():
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEST_PATH))


func test_no_save_is_empty():
	assert_true(SaveGame.read(SAVE_TEST_PATH).is_empty())


func test_capture_round_trips_through_the_file():
	game.ledger.money = 321
	game.ledger.day = 4
	game.autosave()
	var d := SaveGame.read(SAVE_TEST_PATH)
	assert_false(d.is_empty())
	assert_eq(int(d.ledger.money), 321)
	assert_eq(int(d.ledger.day), 4)
	assert_true(SaveGame.blurb(d).begins_with("Day 4"))
	assert_gt(d.pieces.size(), 0)


func test_restore_rebuilds_the_room():
	game.ledger.money = 77
	game.add_station("table", Vector2i(7, 4), 1, 0)
	var data := SaveGame.capture(game)
	var other = load("res://game/main.tscn").instantiate()
	other._resume_data = data
	add_child_autofree(other)
	other.set_process(false)
	assert_eq(other.ledger.money, 77)
	assert_true(other.stations.has(Vector2i(7, 4)))
	assert_eq(other.stations.size(), game.stations.size())
	assert_eq(other.highs.size(), game.highs.size())
	assert_eq(other.phase, other.Phase.BUILD)
	assert_ne(other.till_cell(), other.NO_CELL)


func test_closing_down_deletes_the_save():
	game.autosave()
	assert_true(SaveGame.exists(SAVE_TEST_PATH))
	game._close_down()
	assert_false(SaveGame.exists(SAVE_TEST_PATH))


func test_pause_menu_opens_and_resumes():
	game.hud.toggle_pause()
	assert_true(game.hud.pause_open())
	assert_true(get_tree().paused)
	game.act(0, "down")
	assert_eq(game.hud.pause.sel, 1)
	game.act(0, "back")
	assert_false(game.hud.pause_open())
	assert_false(get_tree().paused)


func test_pause_options_returns_to_pause():
	game.hud.toggle_pause()
	game.hud.pause.press_id("options")
	assert_true(game.hud.options_open())
	game.hud.toggle_options()
	assert_true(game.hud.pause_open())
	assert_true(get_tree().paused)
	game.hud.toggle_pause()


func test_quit_asks_first():
	game.hud.toggle_pause()
	game.hud.pause.press_id("quit")
	assert_true(game.hud.pause.confirming)
	game.hud.pause.press_id("no")
	assert_false(game.hud.pause.confirming)
	game.hud.toggle_pause()
