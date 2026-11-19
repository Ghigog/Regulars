extends "res://test/helpers/game_case.gd"
## The left column of order notes: scrolling, arrows, and the disgust side bubble.


func _long_column() -> void:
	var g := _ordered_guest()
	var first: Dictionary = game.tickets[0]
	for k in 15:
		var copy := first.duplicate()
		copy.id = int(first.id) + 1000 + k
		game.tickets.append(copy)
	game.hud.day_ui.refresh_tickets()
	await get_tree().process_frame
	await get_tree().process_frame


func test_the_column_holds_every_ticket_with_the_bottom_arrow_first():
	await _long_column()
	var col: HudWidgets.OrderColumn = game.hud.order_column
	assert_eq(game.hud.ticket_rail.get_child_count(), 16, "every open ticket, no +N tab")
	assert_gt(col.max_scroll(), 0, "more than fits")
	assert_true(col.down.visible)
	assert_false(col.up.visible)


func test_pressing_the_bottom_arrow_scrolls_down_and_shows_the_top_arrow():
	await _long_column()
	var col: HudWidgets.OrderColumn = game.hud.order_column
	col.down.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	assert_gt(col.scroll.scroll_vertical, 0)
	assert_true(col.up.visible)
	col.scroll.scroll_vertical = col.max_scroll()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(col.down.visible, "gone at the end of the list")


func test_disgust_shows_beside_the_request_not_over_it():
	var g := _ordered_guest()
	assert_eq(g.state, "waiting")
	g.mood.disgust = 0.9
	g.tick(0.1)
	assert_eq(g._gross_bubble.get_meta("icon"), "stink")
	assert_eq(g._order.get_meta("icon"), g.want_icon(), "the dish stays in the main bubble")
	assert_ne(g._gross_bubble.position, g._order.position)
