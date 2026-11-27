extends "res://test/helpers/game_case.gd"
## Practice from the title: service with no guests, nothing kept, ended from the pause menu.

const SAVE := "user://regulars_practice_test.json"


func before_each():
	super.before_each()
	DirAccess.remove_absolute(SAVE)
	game.save_path = SAVE
	game.session.open_title()
	game.arrivals.clear()


func after_each():
	DirAccess.remove_absolute(SAVE)


func _title() -> Title:
	return game.hud.options_ui.title


func test_title_lists_practice_between_play_and_settings():
	var texts: Array = _title().buttons.map(func(b: Button) -> String: return b.text)
	assert_eq(texts.find("Practice"), texts.find("Play") + 1)
	assert_eq(texts.find("Settings"), texts.find("Practice") + 1)


func test_practice_starts_service_with_no_guests():
	_title().press_id("practice")
	assert_true(game.practice)
	assert_eq(game.phase, Game.Phase.SERVICE)
	assert_true(game.door_open)
	assert_not_null(game.world.find_station("stove"))
	assert_true(game.arrivals.is_empty())
	game.step(5.0)
	assert_true(game.guests.is_empty())


func test_practice_does_not_end_or_change_anything():
	var money: int = game.ledger.money
	var day: int = game.ledger.day
	_title().press_id("practice")
	var rep = game.ledger.reputation
	game.step(game.day.day_length() + 30.0)
	assert_eq(game.phase, Game.Phase.SERVICE)
	assert_eq(game.ledger.money, money)
	assert_eq(game.ledger.day, day)
	assert_eq(game.ledger.reputation, rep)
	assert_false(FileAccess.file_exists(SAVE))
	assert_ne(game.day.door_action(game.player), "Close early")


func test_pause_menu_ends_practice_without_confirming():
	_title().press_id("practice")
	var pause := PauseMenu.new()
	pause.setup(game.hud)
	assert_eq(pause.quit_label(), "End practice")
	pause.press_id("quit")   # straight to the title: the scene reload has no tree to run in here
	assert_engine_error("current_scene")
	assert_false(pause.confirming)
	pause.free()
