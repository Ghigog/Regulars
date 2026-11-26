extends "res://test/helpers/game_case.gd"
## The town book's rows open each person's own page.


func _texts() -> Array[String]:
	var out: Array[String] = []
	for n in game.hud.center.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


func _says(text: String) -> bool:
	return _texts().has(text)


func _row_of(i: int) -> Control:
	for n in game.hud.center.find_children("*", "MarginContainer", true, false):
		if (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP and _says_in(n, game.town.people[i].name):
			return n
	return null


func _says_in(node: Node, text: String) -> bool:
	for l in node.find_children("*", "Label", true, false):
		if (l as Label).text == text:
			return true
	return false


func _click(row: Control) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	row.gui_input.emit(e)


func test_clicking_a_row_opens_that_persons_page():
	game.hud.screens_ui.show_town()
	var row := _row_of(2)
	assert_not_null(row)
	_click(row)
	assert_true(_says(game.town.people[2].name))
	assert_true(_says(game.town.status_word(2, game.ledger.day)))
	assert_false(_says("THE TOWN"))
	assert_eq(_back().text, "Back")


func _back() -> Button:
	for b in game.hud.center.find_children("*", "Button", true, false):
		if (b as Button).text == "Back":
			return b
	return null


func test_back_returns_to_the_book_and_t_to_the_receipt():
	game.last_day = game.ledger.end_day()
	game.hud.screens_ui.show_town()
	_click(_row_of(0))
	assert_true(game.hud._town_open)
	_back().pressed.emit()
	assert_true(_says("THE TOWN"))
	_click(_row_of(0))
	game.hud.screens_ui.toggle_town()
	assert_false(game.hud._town_open)
	assert_false(_says("THE TOWN"))


func test_the_quill_shows_only_after_the_reveal_and_tastes_never():
	var c: int = game.critic.critic_idx
	game.town.people[c].dislikes = ["patty"]
	game.hud.screens_ui.show_person(c)
	assert_false(_says("Critic"))
	game.critic.publish({"speed": 4, "clean": 4, "quality": 4, "variety": 4}, false, game.town, 5)
	game.hud.screens_ui.show_person(c)
	assert_true(_says("Critic"))
	for t in _texts():
		assert_false("patty" in t.to_lower() or "dislike" in t.to_lower() or "tolerance" in t.to_lower(), t)


func test_friends_and_orders_are_listed_when_there_are_some():
	var i := 1
	game.town.record_order(i, int(game.menu.items[0].id))
	game.hud.screens_ui.show_person(i)
	var orders := false
	for t in _texts():
		orders = orders or t.begins_with("Orders: ")
	assert_true(orders)


func _book_button() -> Button:
	var last: Button = null
	for b in game.hud.center.find_children("*", "Button", true, false):
		last = b
	return last


func test_book_button_shows_the_back_glyph_for_each_device():
	game.last_day = game.ledger.end_day()
	game.controls.set_mode("pad")
	game.hud.screens_ui.show_town()
	assert_eq(_book_button().text, "Back   (B)")
	game.controls.set_mode("keys")
	game.hud.screens_ui.show_town()
	assert_eq(_book_button().text, "Back   (Esc)")
	game.controls.set_mode("touch")
	game.hud.screens_ui.show_town()
	assert_eq(_book_button().text, "Back")


func test_back_on_the_book_returns_to_the_receipt_and_keeps_ready_marks():
	game.last_day = game.ledger.end_day()
	game.phase = Game.Phase.SUMMARY
	game.hud.receipt_ui.show_summary(game.last_day)
	game.ready_chefs.append(game.chefs[0])
	game.hud.screens_ui.show_town()
	game.coop.act(0, "back")
	assert_false(game.hud._town_open)
	assert_eq(game.ready_chefs.size(), 1)


func test_back_on_a_persons_page_returns_to_the_book():
	game.last_day = game.ledger.end_day()
	game.phase = Game.Phase.SUMMARY
	game.hud.screens_ui.show_person(1)
	game.coop.act(0, "back")
	assert_true(game.hud._town_open)
	assert_true(_says("THE TOWN"))
