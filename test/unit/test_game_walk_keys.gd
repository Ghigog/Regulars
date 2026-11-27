extends "res://test/helpers/game_case.gd"
## The walk keycaps over the chef (EPIC-5 T3): shown until each key is pressed once.


func _shown() -> bool:
	game.hud.day_ui.update_walk_keys(0, Vector2(400, 300))
	return game.hud.day_ui.walk_rect(0).size != Vector2.ZERO


func after_each() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_LEFT]:
		_key(k, false)
	super.after_each()


func test_fresh_profile_shows_the_cluster() -> void:
	assert_true(_shown())


func test_three_keys_do_not_hide_it_the_fourth_does() -> void:
	for k in [KEY_W, KEY_LEFT, KEY_S]:
		_key(k)
		assert_true(_shown())
	assert_false(game.hud.options_ui.options.walk_learned)
	_key(KEY_D)
	assert_true(_shown())   # popping
	assert_true(game.hud.options_ui.options.walk_learned)
	_step_tweens(0.6)
	assert_false(_shown())


func test_arrows_count() -> void:
	for k in [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
		_key(k)
		_shown()
		_key(k, false)
	assert_true(game.hud.options_ui.options.walk_learned)


func test_learning_is_saved_across_a_reload() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_key(k)
		_shown()
	var again: Node = load("res://game/main.tscn").instantiate()   # a later run
	add_child_autofree(again)
	again.set_process(false)
	assert_true(again.hud.options_ui.options.walk_learned, "read back from the file")
	again.hud.day_ui.update_walk_keys(0, Vector2(400, 300))
	assert_eq(again.hud.day_ui.walk_rect(0).size, Vector2.ZERO)


func test_pad_shows_one_stick_cap_until_moved() -> void:
	game.controls.set_mode("pad", 0)
	assert_true(_shown())
	assert_eq(game.hud.day_ui._walk[0].caps["W"].get_child(0).text, "Stick")
	assert_false(game.hud.day_ui._walk[0].caps["A"].visible)
	_axis(JOY_AXIS_LEFT_X, 1.0)
	_shown()
	assert_true(game.hud.options_ui.options.stick_learned)
	assert_false(game.hud.options_ui.options.walk_learned)


func test_touch_shows_none() -> void:
	game.controls.set_mode("touch", 0)
	assert_false(_shown())
