extends "res://test/helpers/game_case.gd"


func test_restock_note_is_a_basket_with_the_cost_over_it():
	_to_build()
	game.hud.menu_notes.refresh()
	var n = game.hud.menu_notes
	assert_eq(n.cost_tag.text, "−$%d" % game.menu_stock.night_cost())
	assert_false(n.open)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	n._clicked(click)
	assert_true(n.open, "a tap opens the breakdown")
	n._clicked(click)
	assert_false(n.open, "a second tap closes it")
	game.ledger.money = game.menu_stock.night_cost() - 1
	n.refresh()
	assert_eq(n.cost_tag.get_theme_color("font_color"), Hud.CORAL)
