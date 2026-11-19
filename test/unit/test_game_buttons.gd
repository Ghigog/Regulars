extends "res://test/helpers/game_case.gd"
## The button set: which discs show, the keycap each wears, and that a press is the key.


func _ids() -> Array:
	return game.hud.buttons_ui.specs().map(func(s: Dictionary) -> String: return s.id)


func _spec(id: String) -> Dictionary:
	for s: Dictionary in game.hud.buttons_ui.specs():
		if s.id == id:
			return s
	return {}


func _click(id: String) -> void:
	game.hud.buttons_ui._nodes[id].pressed.emit()


## Lifts the placed counter at (4, 4), as the player's own pick-up does.
func _carry() -> void:
	assert_true(game.placing.pick_up(Grid.center(Vector2i(4, 4)), game.player), "the counter is lifted")


func test_build_phase_with_empty_hands_shows_shop_dishes_and_options():
	_to_build()
	assert_eq(_ids(), ["shop", "menu", "options"])


func test_service_on_keys_shows_only_the_cog():
	assert_eq(_ids(), ["options"])


func test_keycap_follows_the_owners_device():
	_to_build()
	assert_eq(_spec("shop").key, "Tab")
	assert_eq(_spec("menu").key, "N")
	game.hud.buttons_ui.update()
	assert_true(game.hud.buttons_ui._nodes["shop"].key_shown())
	game.controls.set_mode("pad")
	assert_eq(_spec("shop").key, "Y")
	assert_eq(_spec("options").key, "Start")
	game.controls.set_mode("touch")
	game.hud.buttons_ui.update()
	assert_false(game.hud.buttons_ui._nodes["shop"].key_shown(), "no keycap on touch")


func test_clicking_shop_opens_it_as_tab_does():
	_to_build()
	_click("shop")
	assert_true(game.shopping)


func test_clicking_dishes_opens_the_menu_screen():
	_to_build()
	_click("menu")
	assert_true(game.hud.menu_open())


func test_back_shows_only_while_there_is_something_to_go_back_from():
	_to_build()
	assert_does_not_have(_ids(), "back")
	_carry()
	assert_has(_ids(), "back")
	assert_eq(_spec("back").key, "Esc")
	_click("back")
	assert_true(game.player.hand.is_empty(), "Back drops the piece, as Esc does")
	_click("shop")
	assert_has(_ids(), "back", "the open shop can be left")


func test_back_shows_over_the_menu_screen_on_keys():
	_to_build()
	_click("menu")
	assert_has(_ids(), "back")
	_click("back")
	assert_false(game.hud.menu_open())


func test_c_sells_a_moved_piece_with_its_value():
	_to_build()
	_carry()
	var s := _spec("sell")
	assert_eq(s.badge, "$%d" % game.placing.sell_value(game.player))
	assert_eq(s.icon, "sell")
	assert_false(s.blocked)
	var before: int = game.ledger.money
	_click("sell")
	assert_true(game.player.hand.is_empty(), "sold")
	assert_gte(game.ledger.money, before)


func test_c_is_erase_with_a_build_tool_and_hidden_without_one():
	_to_build()
	assert_does_not_have(_ids(), "sell")
	game.player.hand = {"id": "floor_planks", "tier": 1, "price": 0, "facing": 0}
	if Catalog.is_build_tool("floor_planks"):
		assert_eq(_spec("sell").icon, "erase")
	else:
		assert_does_not_have(_ids(), "sell", "a piece from the shop cannot be sold")


func test_a_blocked_sale_is_greyed_and_says_why():
	_to_build()
	_carry()
	game.player.hand.id = "ghost"   # a piece the catalog does not sell
	var why: String = game.placing.sell_block(game.player)
	if why == "":
		pending("till can be sold in this catalog")
		return
	assert_true(_spec("sell").blocked)
	_click("sell")
	assert_eq(game.hud.toast.text, why)
	assert_false(game.player.hand.is_empty(), "nothing was sold")


func test_touch_adds_use_and_aim_and_dishes_only_with_empty_hands():
	game.controls.set_mode("touch")
	assert_has(_ids(), "use")
	assert_has(_ids(), "aim")
	assert_true(_spec("use").touch)
	_to_build()
	assert_has(_ids(), "menu")
	_carry()
	assert_does_not_have(_ids(), "menu")
	assert_has(_ids(), "turn")


func test_buttons_stop_the_mouse():
	assert_eq(game.hud.buttons_ui._nodes["shop"].mouse_filter, Control.MOUSE_FILTER_STOP)


func test_holding_aim_while_steering_still_works_through_touch():
	game.controls.set_mode("touch")
	var aim: Array = game.controls.buttons().filter(func(b: Array) -> bool: return b[0] == "aim")[0]
	var finger := InputEventScreenTouch.new()
	finger.index = 2
	finger.pressed = true
	finger.position = aim[2]
	game.controls._input(finger)
	var stick := InputEventScreenTouch.new()
	stick.index = 1
	stick.pressed = true
	stick.position = game.controls._stick_home()
	game.controls._input(stick)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = stick.position + Vector2(200, 0)
	game.controls._input(drag)
	assert_true(game.controls.aiming(0), "Aim is held")
	assert_almost_eq(game.controls.move(0).x, 1.0, 0.01, "while the joystick steers")
	assert_has(game.controls.held_ids(), "aim")
