extends "res://test/helpers/game_case.gd"
## The pause menu's Chefs section: controllers join and leave while it is open.


func _pad(button: int, pressed: bool, device := 0) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = pressed
	game.controls._input(e)


func _pause() -> PauseMenu:
	game.controls.used_any = true
	game.controls.players[0].source = "pad:0"
	game.hud.options_ui.toggle_pause()
	return game.hud.options_ui.pause


func _rows(m: PauseMenu) -> int:
	return m._chefs.get_child_count()


func _filled(m: PauseMenu) -> int:
	return m._tags.size()


func test_one_chef_shows_one_filled_and_one_empty_row():
	var m := _pause()
	assert_eq(_rows(m), 2)
	assert_eq(_filled(m), 1)


func test_start_on_a_new_pad_joins_and_stays_paused():
	var m := _pause()
	m.pick(2)
	_pad(JOY_BUTTON_START, true, 1)
	_pad(JOY_BUTTON_START, false, 1)
	assert_eq(game.chefs.size(), 2)
	assert_true(game.get_tree().paused)
	assert_eq(_filled(m), 2)
	assert_eq(_rows(m), 2, "full: no empty row")
	assert_eq(m.sel, 2, "the pointer stays")


func test_holding_start_leaves_and_menu_stays_open():
	var m := _pause()
	game.coop.join("pad:1")
	_pad(JOY_BUTTON_START, true, 1)
	game.controls._process(0.5)
	assert_almost_eq(game.controls.leave_progress(1), 0.5, 0.01)
	game.controls._process(0.6)
	_pad(JOY_BUTTON_START, false, 1)
	assert_eq(game.chefs.size(), 1)
	assert_true(game.hud.options_ui.pause_open())
	assert_eq(_filled(m), 1)
	assert_eq(_rows(m), 2)


func test_unplugging_removes_the_row():
	var m := _pause()
	game.coop.join("pad:1")
	game.controls._on_joy_connection(1, false)
	assert_eq(game.chefs.size(), 1)
	assert_eq(_filled(m), 1)
	assert_true(game.hud.options_ui.pause_open())


func test_the_last_chef_is_not_removed_by_unplugging():
	var m := _pause()
	game.controls.seat("pad:0", 0)
	game.controls._on_joy_connection(0, false)
	assert_eq(game.chefs.size(), 1)
	assert_eq(_filled(m), 1)


func test_a_stranger_pad_offers_to_join():
	var m := _pause()
	game.controls._offer_join("pad:1")
	var l: Label = m._chefs.get_child(1).get_child(1).get_child(0)
	assert_true(l.text.begins_with("Controller ready"))
