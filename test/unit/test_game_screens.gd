extends "res://test/helpers/game_case.gd"


func test_options_screen_works_from_the_keyboard():
	var hud = game.hud
	var saved: Dictionary = hud.options_ui.options.duplicate()
	hud.options_ui.options.sfx = 0.5
	hud.options_ui.options.music = 0.5
	_tap(KEY_O)
	assert_true(hud.options_ui.pause_open(), "O opens the pause menu")
	hud.options_ui.pause.press_id("options")
	assert_true(hud.options_ui.options_open())
	assert_true(get_tree().paused, "the game waits")
	assert_eq(hud.options_ui._options_row(), hud.options_ui._options_tab_row, "the tabs are chosen first")
	_tap(KEY_DOWN)
	_tap(KEY_RIGHT)
	assert_almost_eq(float(hud.options_ui.options.sfx), 0.6, 0.001, "right turns the sound effects up")
	_tap(KEY_DOWN)
	_tap(KEY_LEFT)
	_tap(KEY_LEFT)
	assert_almost_eq(float(hud.options_ui.options.music), 0.3, 0.001, "left turns the music down")
	while hud.options_ui._options_row() != hud.options_ui._options_done:
		_tap(KEY_DOWN)
	assert_eq(hud.options_ui._options_row(), hud.options_ui._options_done, "down reaches Done")
	_tap(KEY_DOWN)
	assert_eq(hud.options_ui._options_row(), hud.options_ui._options_tab_row, "down from Done wraps to the tabs")
	_tap(KEY_UP)
	assert_eq(hud.options_ui._options_row(), hud.options_ui._options_done, "up from the tabs wraps to Done")
	while hud.options_ui._options_row() != hud.options_ui._options_tab_row:
		_tap(KEY_UP)
	_tap(KEY_RIGHT)
	assert_eq(hud.options_ui._options_tab, "graphics", "right on the tabs switches tab")
	var tilt: bool = hud.options_ui.options.tilt_shift
	_tap(KEY_DOWN)
	_tap(KEY_E)
	assert_eq(bool(hud.options_ui.options.tilt_shift), not tilt, "E presses the switch")
	_tap(KEY_ENTER)
	assert_eq(bool(hud.options_ui.options.tilt_shift), tilt, "so does Enter")
	hud.options_ui.options.merge(saved, true)   # leave the player's own settings file as it was
	_tap(KEY_ESCAPE)
	assert_false(hud.options_ui.options_open())
	assert_true(hud.options_ui.pause_open(), "Esc goes back to the pause menu")
	_tap(KEY_ESCAPE)
	assert_false(hud.options_ui.pause_open())
	assert_false(get_tree().paused)



func test_options_screen_works_with_a_controller():
	var hud = game.hud
	var saved: Dictionary = hud.options_ui.options.duplicate()
	hud.options_ui.options.sfx = 0.5
	_tap_pad(JOY_BUTTON_START)
	assert_true(hud.options_ui.pause_open(), "Start opens the pause menu")
	hud.options_ui.pause.press_id("options")
	assert_true(hud.options_ui.options_open())
	assert_eq(game.controls.mode, "pad")
	assert_true(hud.options_ui._options_keys.visible, "the key line shows for a pad")
	assert_string_contains(hud.options_ui._options_keys.text, "D-pad")
	_tap_pad(JOY_BUTTON_DPAD_DOWN)
	_tap_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_almost_eq(float(hud.options_ui.options.sfx), 0.6, 0.001, "the d-pad turns a slider")
	_axis(JOY_AXIS_LEFT_X, 1.0)   # the stick browses too
	game.controls._process(0.01)
	game.controls._process(0.01)
	assert_almost_eq(float(hud.options_ui.options.sfx), 0.7, 0.001, "a flick of the stick is one notch")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	game.controls._process(0.01)
	_tap_pad(JOY_BUTTON_DPAD_DOWN)
	_tap_pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(hud.options_ui._options_row(), hud.options_ui._options_done)
	hud.options_ui.options.merge(saved, true)
	_tap_pad(JOY_BUTTON_A)
	assert_false(hud.options_ui.options_open(), "A on Done closes")
	hud.options_ui.pause.press_id("options")
	assert_true(hud.options_ui.options_open())
	_tap_pad(JOY_BUTTON_B)
	assert_false(hud.options_ui.options_open(), "and so does B")
	hud.options_ui.toggle_pause()



func test_arrows_do_not_walk_the_chef_while_options_are_open():
	_tap(KEY_O)
	game.hud.options_ui.pause.press_id("options")
	var from: Vector3 = game.player.position
	_key(KEY_RIGHT)
	for i in 10:
		game._process(0.05)
	_key(KEY_RIGHT, false)
	assert_almost_eq(game.player.position.distance_to(from), 0.0, 0.001, "the chef stays put")
	_tap(KEY_ESCAPE)
	assert_false(game.hud.options_ui.options_open())
	game.hud.options_ui.toggle_pause()



func test_options_on_touch_have_big_targets_and_no_highlight():
	game.controls.set_mode("touch")
	game.hud.options_ui.toggle_options()
	var hud = game.hud
	assert_false(hud.options_ui._options_keys.visible, "no key line on touch")
	assert_gte(hud.options_ui._options_done.custom_minimum_size.y, 64.0, "Done fits a thumb")
	var slider: HSlider = hud.options_ui._options_rows[1].get_meta("slider")
	assert_gte(slider.get_theme_icon("grabber").get_width(), 44, "so does a slider's grabber")
	var ids: Array = game.controls.buttons().map(func(b: Array) -> String: return b[0])
	assert_eq(ids, ["options"], "only the Menu button stays over the card")
	assert_false(game.controls._stick_shown())
	hud.options_ui.toggle_options()



# ---------------------------------------------------------------- title screen

func test_title_play_starts_the_first_night_from_the_keyboard():
	game.session.open_title()
	assert_true(game.hud.options_ui.title_open())
	assert_eq(game.phase, game.Phase.TITLE)
	assert_eq(game.music_id, "title", "Intro plays on the title")
	_run(2.0)
	assert_eq(game.phase, game.Phase.TITLE, "nothing happens behind the title")
	_tap(KEY_DOWN)
	_tap(KEY_UP)
	assert_eq(game.hud.options_ui.title.sel, 0, "Play is chosen")
	_tap(KEY_ENTER)
	assert_true(game.hud.options_ui.title.themes_open, "the theme card")
	assert_eq(game.hud.options_ui.title.theme_ids[game.hud.options_ui.title.sel], "diner")
	_tap(KEY_ENTER)
	assert_false(game.hud.options_ui.title_open())
	assert_eq(game.phase, game.Phase.BUILD, "the night before day 1")
	assert_false(game.door_open)



func test_title_play_with_a_controller():
	game.session.open_title()
	_tap_pad(JOY_BUTTON_A)
	assert_true(game.hud.options_ui.title.themes_open, "A presses Play")
	_tap_pad(JOY_BUTTON_A)
	assert_false(game.hud.options_ui.title_open(), "and A picks the theme")
	assert_eq(game.phase, game.Phase.BUILD)



func test_title_settings_opens_the_options_and_comes_back():
	game.session.open_title()
	_tap(KEY_DOWN)
	_tap(KEY_E)
	assert_true(game.hud.options_ui.options_open(), "Settings opens the options")
	_tap(KEY_DOWN)
	assert_true(game.hud.options_ui.title_open())
	assert_eq(game.hud.options_ui.title.sel, 1, "the arrows belong to the options meanwhile")
	_tap(KEY_ESCAPE)
	assert_false(game.hud.options_ui.options_open())
	assert_true(game.hud.options_ui.title_open(), "back on the title")
	assert_eq(game.phase, game.Phase.TITLE)



func test_title_quit_where_quitting_is_a_thing():
	game.allow_quit = false
	game.session.open_title()
	var names: Array = game.hud.options_ui.title.buttons.map(func(b: Button) -> String: return b.text)
	if not Title.can_quit():
		assert_false(names.has("Quit"), "no Quit on phones or the web")
		return
	assert_eq(names, ["Play", "Settings", "Quit"])
	_tap(KEY_DOWN)
	_tap(KEY_DOWN)
	_tap(KEY_DOWN)
	assert_eq(game.hud.options_ui.title.sel, 0, "down from Quit wraps to Play")
	_tap(KEY_UP)
	assert_eq(game.hud.options_ui.title.sel, 2, "up from Play wraps to Quit")
	_tap(KEY_SPACE)
	assert_true(game.quit_asked)



func test_a_tool_in_hand_draws_its_ghost_every_frame_without_errors():
	_to_build()
	game.ledger.money = 100
	for id in ["floor_tile", "wall", "door", "arch", "paint"]:
		assert_true(game.placing.pick_catalog(id), id)
		game._demo_hover = Vector3(3.5, 0, 1.5)
		game.room_edit._update_ghost()   # no drag: the one spot under the hover point
		assert_not_null(game._tool_ghost, "%s shows a ghost" % id)
		game._drag = {"from": Vector3(0.5, 0, 1.5), "remove": false}
		game.room_edit._update_ghost()   # mid-drag: every spot along it
		game._drag = {}
		game.placing.cancel_hand()



func test_everyone_in_line_has_their_own_place_and_the_line_moves_up():
	for i in 14:
		game.seating.spawn_group([i], true)   # the critic always joins: a line too long for strangers
	_run(15.0)
	assert_gt(game.queue.size(), 6, "more guests than tables, so a long line")
	var spots := {}
	for i in game.queue.size():
		var g: Guest = game.queue[i]
		assert_almost_eq(g.position.distance_to(game.seating.queue_spot(i)), 0.0, 0.01, "%s stands in their place" % g.info.name)
		spots[g.goal] = true
	assert_eq(spots.size(), game.queue.size(), "no two share a place")
	assert_gt(_closest_pair(game.queue), game.QUEUE_GAP - 0.01)
	var second: Guest = game.queue[1]
	game.paying.walk_out(game.queue[0])
	_run(3.0)
	assert_eq(game.queue[0], second)
	assert_almost_eq(second.position.distance_to(game.seating.queue_spot(0)), 0.0, 0.01, "the line steps up")



func test_a_group_comes_in_single_file_not_stacked():
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	game.world.add_station("table", Vector2i(6, 2))   # pushed against (6, 1): a table for four
	for i in 6:
		game.seating.spawn_group([i], true)    # the tables fill, so the four have to queue too
	var four: Array[Guest] = game.seating.spawn_group([6, 7, 8, 9], true)
	var worst := 99.0
	for i in 120:
		game.step(0.1)
		worst = minf(worst, _closest_pair(four))
	assert_gt(worst, 0.5, "friends keep a little apart all the way to the line")



func test_a_rush_never_walks_guests_through_one_another():
	# critics always join, so the whole rush queues whatever the line (QueueChoice)
	game.arrivals.assign([{"time": 0.3, "group": [0, 1], "critic": true}, {"time": 0.6, "idx": 2, "critic": true},
		{"time": 0.9, "group": [3, 4], "critic": true}, {"time": 1.2, "idx": 6, "critic": true},
		{"time": 1.5, "group": [7, 8], "critic": true}, {"time": 1.8, "group": [9, 10, 11], "critic": true},
		{"time": 2.1, "idx": 13, "critic": true}])
	for p in game.town.people:   # middling, so the line clears by walkouts in time (PRD 10.1)
		p.tolerance = {"food": 3, "service": 3, "clean": 3}
	var worst := 99.0
	for i in 900:
		game.step(0.1)
		if i % 50 == 0:
			for g: Guest in game.guests.duplicate():
				if g.state == "ordering":
					game.serving.take_orders(g.table)
				if g.state == "waiting":
					game.serving.serve(g, game.serving.full_tray_for(g))
				if g.paying() and game.paying.ready_to_pay(g.table):
					game.paying.pay_bill(g.table)
		worst = minf(worst, _closest_pair(game.guests))
	assert_gt(worst, 0.3, "people step round or wait, never pass through")
	assert_eq(game.guests.size(), 0, "nobody is left stuck on the pavement")



func test_a_seated_guest_waits_to_order_with_a_notepad_bubble():
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	assert_eq(g.state, "ordering")
	assert_true(g.order.is_empty())
	assert_eq(g._order.get_meta("icon"), "order", "the bubble asks for the chef")
	assert_eq(game.cooking.prompt_for(g.table), "Take order")
	_order(g)
	assert_eq(g.state, "waiting")
	assert_eq(g.order.main.name, "Burger", "an order is data on the guest: menu items and a ticket")
	assert_true(g.order.side.is_empty() and g.order.drink.is_empty(), "the test menu has no side or drink")
	assert_eq(int(g.order.ticket), int(game.tickets[0].id))
	_run(0.2)
	assert_eq(g._order.get_meta("icon"), "dish:bun,patty", "the bubble shows what they ordered")



func test_waiting_to_order_drains_patience_faster_than_waiting_for_food():
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	g.mood.patience = 0.9
	_run(2.0)
	var ordering_drop: float = 0.9 - g.mood.patience
	assert_gt(ordering_drop, 0.0)
	_order(g)
	g.mood.patience = 0.9
	_run(2.0)
	var food_drop: float = 0.9 - g.mood.patience
	assert_gt(ordering_drop, food_drop * 1.1, "being ignored at the table wears thin quicker")



func test_an_ignored_guest_walks_out_before_ordering():
	var g: Guest = game.seating.spawn_guest(1)
	_run(12.0)
	assert_eq(g.state, "ordering")
	g.mood.patience = 0.01
	_run(1.0)
	assert_eq(game.ledger.strikes(), 1)



func test_a_group_orders_together_in_one_go():
	var pair: Array[Guest] = game.seating.spawn_group([0, 1])
	_run(14.0)
	assert_eq(pair[0].state, "ordering")
	assert_eq(pair[1].state, "ordering")
	assert_eq(game.cooking.prompt_for(pair[0].table), "Take 2 orders")
	game.cooking.use_station(pair[0].table)
	for g in pair:
		assert_eq(g.state, "waiting")
		assert_eq(g.order.main.name, "Burger")
	assert_eq(game.tickets.size(), 2, "a ticket each")
	assert_eq(game.cooking.prompt_for(pair[0].table), "", "nothing left to take")



func test_serving_a_guest_who_has_not_ordered_is_refused():
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	_use("dish_rack")
	assert_eq(game.cooking.prompt_for(g.table), "Take order first")
	game.cooking.use_station(g.table)
	assert_eq(g.state, "ordering", "still waiting to order")
	assert_eq(game.player.held, "dishes", "the chef keeps the plate")
	_use("dish_rack")    # put it back, take the order, then cook
	assert_eq(game.player.held, "")
	game.serving.take_orders(g.table)
	_cook_burger()
	assert_string_contains(game.cooking.prompt_for(g.table), "Serve")
	game.cooking.use_station(g.table)
	assert_eq(g.state, "eating")



func test_guest_card_says_waiting_to_order():
	assert_eq(Hud.STATE_WORDS.ordering, "Waiting to order")



func test_a_comfortable_guest_eats_longer_and_pays_more():
	var cosy := _serve_one(0, 1.0, 1.0)
	assert_true(cosy.mood.thoughts.has(GuestMood.COSY_THOUGHTS[0]))
	var start := int(game.ledger.today.sales)
	_run(Guest.EAT_TIME + 0.5)
	assert_eq(cosy.state, "eating", "still lingering after the plain eating time")
	_run(cosy.eat_time + Guest.CHAT_TIME)
	game.paying.pay_bill(cosy.table)
	var cosy_paid := int(game.ledger.today.sales) - start
	var rushed := _serve_one(1, 0.0, 0.1, 0.7)   # one score: good food alone keeps them from rushing
	assert_true(rushed.mood.thoughts.has(GuestMood.HURRIED_THOUGHTS[1]))
	assert_lt(rushed.eat_time, cosy.eat_time)
	start = int(game.ledger.today.sales)
	_run(rushed.eat_time + Guest.CHAT_TIME + 0.5)
	game.paying.pay_bill(rushed.table)
	assert_eq(rushed.state, "leaving")
	var rushed_paid := int(game.ledger.today.sales) - start
	assert_eq(cosy_paid, cosy.bill_base, "they pay what the slip says")
	assert_eq(rushed_paid, rushed.bill_base)
	assert_gt(cosy.mood.pay_for(cosy.bill_base), cosy.bill_base, "a cosy guest's extras go with the tip")
	assert_lt(rushed.mood.pay_for(rushed.bill_base), rushed.bill_base, "a rushed one skimps on it")


func test_title_wraps_past_both_ends_with_keys_and_pad():
	game.session.open_title()
	var title = game.hud.options_ui.title
	var last: int = title.buttons.size() - 1
	_tap(KEY_UP)
	assert_eq(title.sel, last, "up from Play goes to the last button")
	_tap(KEY_DOWN)
	assert_eq(title.sel, 0, "down from the last goes to Play")
	assert_true(title.action("up"))
	assert_eq(title.sel, last, "pad up wraps")
	assert_true(title.action("down"))
	assert_eq(title.sel, 0, "pad down wraps")


func test_pause_menu_wraps_past_both_ends():
	game.hud.options_ui.toggle_pause()
	var pause = game.hud.options_ui.pause
	var last: int = pause.buttons.size() - 1
	pause.action("up")
	assert_eq(pause.sel, last, "up from Resume goes to the last button")
	pause.action("down")
	assert_eq(pause.sel, 0, "down from the last goes to Resume")
	pause.press_id("quit")
	pause.pick(0)
	pause.action("up")
	assert_eq(pause.sel, pause.buttons.size() - 1, "the confirm card wraps too")
	pause.action("down")
	assert_eq(pause.sel, 0)
