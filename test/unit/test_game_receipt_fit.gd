extends "res://test/helpers/game_case.gd"
## The end-of-day clipboard stays on screen; its paper scrolls when the day runs long.


func _long_day() -> Dictionary:
	var unordered: Array = []
	for i in 6:
		unordered.append("Nobody ordered the side or drink number %d, so it sat on the shelf all day long." % i)
	return {"day": 7, "served": 30, "sales": 400, "tips": 60, "walkouts": 2, "stock": 80,
		"staff": 50, "unpaid": 2, "unpaid_bills": 3, "found_nothing": 4, "unordered": unordered,
		"level": 9, "level_was": 1,
		"review": {"day": 7, "headline": "A very long headline for a very long day", "stars": 3,
			"ratings": {"speed": 3, "clean": 3, "quality": 3, "variety": 3}, "line": "Fine.", "name": "Ada"}}


func _short_day() -> Dictionary:
	return {"day": 1, "served": 2, "sales": 10, "tips": 1, "walkouts": 0, "stock": 3}


func _scroll() -> ScrollContainer:
	return game.hud.receipt_ui.paper_scroll


func _screen_900() -> void:   # the default window: 1440 x 900
	get_window().size = Vector2i(1440, 900)
	await wait_frames(3)


func test_long_day_fits_the_screen_and_scrolls() -> void:
	await _screen_900()
	game.hud.receipt_ui.show_summary(_long_day(), false)
	await wait_frames(2)
	_step_tweens(1.0)   # settle the panel's pop-in before measuring
	var clip: Control = game.hud._summary_clip
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	assert_true(view.encloses(clip.get_global_rect()), "clip %s inside %s" % [clip.get_global_rect(), view])
	var sc := _scroll()
	assert_not_null(sc)
	assert_true(sc.get_v_scroll_bar().max_value > sc.get_v_scroll_bar().page)
	assert_true(sc.get_v_scroll_bar().visible)


func test_short_day_has_no_scrollbar() -> void:
	game.hud.receipt_ui.show_summary(_short_day(), false)
	await wait_frames(2)
	var sc := _scroll()
	assert_false(sc.get_v_scroll_bar().visible)
	assert_almost_eq(sc.size.y, sc.get_child(0).get_combined_minimum_size().y, 1.0)


func test_buttons_are_outside_the_scroll() -> void:
	await _screen_900()
	game.hud.receipt_ui.show_summary(_long_day(), false)
	await wait_frames(2)
	var sc := _scroll()
	for b in game.hud._summary_clip.find_children("*", "Button", true, false):
		assert_false(sc.is_ancestor_of(b), "button %s pinned" % b.text)
	assert_gt(game.hud._summary_clip.find_children("*", "Button", true, false).size(), 1)


func test_pad_nudge_scrolls_the_paper() -> void:
	await _screen_900()
	game.hud.receipt_ui.show_summary(_long_day(), false)
	await wait_frames(2)
	assert_true(game.hud.receipt_ui.scroll_paper(60.0))
	assert_gt(_scroll().scroll_vertical, 0)
