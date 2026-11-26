extends "res://test/helpers/game_case.gd"
## The glowing menu key over the board by the door, and "Write menu" beside it.


func _stand_at_board() -> void:
	var b: Vector3 = game.menu_board.global_position
	game.player.position = Vector3(b.x + 0.6, 0, b.z + 0.9)   # the street side, off the door's reach


func _frame() -> void:
	game._process(0.1)


func _no_main() -> void:
	game.menu.items.clear()
	game.menu_stock.menu_changed()


func test_refused_open_says_nothing_and_swells_the_key():
	_to_build()
	_no_main()
	game.ledger.history.clear()   # night zero
	game.hud.toast.text = ""
	_at_door()
	assert_eq(game.day.door_action(), "Open up", "set-up")
	assert_eq(game.menu_stock.open_block(), GameMenuStock.NO_MAIN_YET, "set-up")
	assert_false(game.day.use_door())
	assert_eq(game.phase, game.Phase.BUILD, "the card stays shut")
	assert_false(game.hud.toast.text.contains("board by the door"))
	assert_false(game.hud.toast.text.contains("N, or"))
	assert_eq(game.menu_stock.night_hint(), "")
	await wait_seconds(0.06)
	assert_gt(game.hud.board_key_ui.cap.scale.x, 1.05, "the key swells")


func test_glyph_follows_the_input_mode():
	_to_build()
	_frame()
	var k: HudBoardKey = game.hud.board_key_ui
	assert_eq(k.label.text, game.controls.glyph("menu"))
	game.controls.set_mode("touch")
	_frame()
	assert_eq(k.label.text, game.controls.glyph("menu"))
	game.controls.set_mode("pad")
	_frame()
	assert_eq(k.label.text, game.controls.glyph("menu"))


func test_visible_in_build_hidden_in_service_and_brighter_without_a_main():
	_to_build()
	_no_main()
	_frame()
	var k: HudBoardKey = game.hud.board_key_ui
	assert_true(k.cap.visible)
	assert_true(k.bright)
	game.menu_stock.write_test_menu()
	game.menu_stock.menu_changed()
	_frame()
	assert_false(k.bright, "dimmer once there is a main")
	game.phase = game.Phase.SERVICE
	_frame()
	assert_false(k.cap.visible)


func test_write_menu_opens_the_menu_screen():
	_to_build()
	_stand_at_board()
	assert_false(game.day.at_door(), "set-up")
	assert_eq(game.day.door_action(), "Write menu")
	game.day.use_door()
	assert_true(game.hud.menu_open())
