extends "res://test/helpers/game_case.gd"


func test_the_last_device_used_sets_the_mode_and_the_hints():
	assert_eq(game.controls.mode, "keys")
	_tap_pad(JOY_BUTTON_B)
	assert_eq(game.controls.mode, "pad")
	assert_eq(game.controls.input_of(0).source, "pad:0")
	assert_eq(game.hud._prompt_key_label.text, "A", "the prompt shows the pad's button")
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(700, 300)
	touch.pressed = true
	game.controls._input(touch)
	assert_eq(game.controls.mode, "touch")
	assert_false(game.hud._prompt_key.visible, "no keycap on touch: the Use button says it")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	game.controls._input(key)
	assert_eq(game.controls.mode, "keys")
	assert_eq(game.hud._prompt_key_label.text, "E")



func test_left_stick_and_d_pad_walk_the_chef():
	_axis(JOY_AXIS_LEFT_X, 1.0)
	assert_eq(game.controls.move(0), Vector2(1, 0))
	var from: Vector3 = game.player.position
	for i in 10:
		game._process(0.05)
	assert_gt(game.player.position.distance_to(from), 0.5, "the chef walked")
	_axis(JOY_AXIS_LEFT_X, 0.1)
	assert_eq(game.controls.move(0), Vector2.ZERO, "inside the dead zone")
	_pad(JOY_BUTTON_DPAD_UP, true)
	assert_eq(game.controls.move(0), Vector2(0, 1), "the d-pad walks too")
	_pad(JOY_BUTTON_DPAD_UP, false)
	assert_eq(game.controls.move(0), Vector2.ZERO)



func test_pad_buttons_become_actions_for_the_phase():
	_to_build()
	game.ledger.money = 100
	_tap_pad(JOY_BUTTON_Y)
	assert_true(game.shopping, "Y opens the shop")
	_tap_pad(JOY_BUTTON_B)
	assert_false(game.shopping, "B closes it")
	assert_true(game.placing.pick_catalog("plant"))
	_tap_pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(int(game.hand.facing), 1, "a shoulder button turns the piece")
	_tap_pad(JOY_BUTTON_B)
	assert_true(game.hand.is_empty(), "B puts it back")



func test_a_confirms_the_receipt_and_y_opens_the_town_book():
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.phase, game.Phase.SUMMARY)
	_tap_pad(JOY_BUTTON_Y)
	assert_true(game.hud._town_open, "Y opens the town book")
	_tap_pad(JOY_BUTTON_Y)
	_tap_pad(JOY_BUTTON_A)
	assert_eq(game.phase, game.Phase.BUILD, "A carries on to the build phase")



func test_holding_use_with_a_floor_tool_paves_ahead_on_any_device():
	_to_build()
	game.ledger.money = 100
	assert_true(game.placing.pick_catalog("floor_planks"))
	game.player.position = Grid.center(Vector2i(5, 0))
	game.player.look(Vector2i(0, -1))
	_pad(JOY_BUTTON_A, true)
	assert_true(game.plan.has_floor(Vector2i(5, -1)), "the press lays the first board")
	assert_true(game.controls.holding(0, "use"))
	game.player.position = Grid.center(Vector2i(6, 0))
	game._paint_held(0)
	assert_true(game.plan.has_floor(Vector2i(6, -1)), "held, it keeps laying")
	_pad(JOY_BUTTON_A, false)
	assert_false(game.controls.holding(0, "use"))
	game.player.position = Grid.center(Vector2i(7, 0))
	game._paint_held(0)
	assert_false(game.plan.has_floor(Vector2i(7, -1)), "let go, it stops")



func test_a_floor_taken_with_a_held_confirm_lays_nothing_until_pressed_again():
	_to_build()
	game.ledger.money = 100
	game.player.position = Grid.center(Vector2i(5, 0))
	game.player.look(Vector2i(0, -1))
	_pad(JOY_BUTTON_A, true)
	assert_true(game.placing.pick_catalog("floor_planks"))
	game._paint_held(0)
	assert_false(game.plan.has_floor(Vector2i(5, -1)), "the confirming press lays nothing")
	assert_eq(game.ledger.money, 100, "and costs nothing")
	_pad(JOY_BUTTON_A, false)
	game._paint_held(0)
	_pad(JOY_BUTTON_A, true)
	assert_true(game.plan.has_floor(Vector2i(5, -1)), "a fresh press lays the first tile")
	assert_lt(game.ledger.money, 100, "and pays for it")


func test_each_device_is_routed_to_the_player_it_is_seated_to():
	var c: Controls = game.controls
	assert_eq(c.owner_of("pad:3"), 0, "with one chef, every device is player one's")
	c.seat("pad:1", 1)
	assert_eq(c.players.size(), 2)
	_axis(JOY_AXIS_LEFT_X, 1.0, 1)
	_pad(JOY_BUTTON_A, true, 1)
	assert_eq(c.input_of(1).mode, "pad")
	assert_eq(c.move(1), Vector2(1, 0), "player two steers")
	assert_true(c.holding(1, "use"))
	assert_eq(c.mode, "keys", "player one's hints are unchanged")
	assert_eq(c.move(0), Vector2.ZERO, "and player one stands still")
	assert_false(c.holding(0, "use"))
	_pad(JOY_BUTTON_A, false, 1)
	_tap_pad(JOY_BUTTON_START, 1)
	assert_true(game.hud.options_ui.pause_open(), "the pause menu is shared")
	game.hud.options_ui.pause.press_id("options")
	assert_true(game.hud.options_ui.options_open(), "the options screen is shared")
	game.hud.options_ui.toggle_options()
	game.hud.options_ui.toggle_pause()



func test_touch_joystick_and_buttons_never_reach_the_room():
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = game.controls._stick_home()
	game.controls._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.position = touch.position + Vector2(200, 0)
	game.controls._input(drag)
	assert_almost_eq(game.controls.move(0).x, 1.0, 0.01, "dragged to the right edge")
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = touch.position
	game.controls._input(mouse)
	assert_true(game.controls.owns_pointer(), "the mouse made from that touch is swallowed")
	touch.pressed = false
	game.controls._input(touch)
	assert_eq(game.controls.move(0), Vector2.ZERO, "let go")
	var ids := []
	for b: Array in game.controls.buttons():
		ids.append(b[0])
	assert_has(ids, "use", "a Use button during service")



func test_touch_buttons_press_and_hold_their_action():
	_to_build()
	game.ledger.money = 100
	game.controls.set_mode("touch")
	var shop: Array = game.controls.buttons().filter(func(b: Array) -> bool: return b[0] == "shop")[0]
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = shop[2]
	game.controls._input(touch)
	assert_true(game.shopping, "Shop opens the shop")
	touch.pressed = false
	game.controls._input(touch)
	game.session.close_shop()
	assert_true(game.placing.pick_catalog("floor_planks"))
	var use: Array = game.controls.buttons().filter(func(b: Array) -> bool: return b[0] == "use")[0]
	touch.position = use[2]
	touch.pressed = true
	game.controls._input(touch)
	assert_true(game.controls.holding(0, "use"), "Use is held while the finger stays")
	touch.pressed = false
	game.controls._input(touch)
	assert_false(game.controls.holding(0, "use"))



func test_rug_lies_flat_and_is_moved_and_sold_like_a_fern():
	_to_build()
	game.ledger.money = 100
	assert_not_null(game.placing.rug_at(Vector2i(8, 4)), "the first rug lies under the middle table")
	assert_false(game.grid.is_blocked(Vector2i(8, 4)), "anyone can walk over it")
	assert_true(game.placing.pick_up(Vector3(8.5, 0, 3.5)))
	assert_eq(game.hand.id, "table", "what stands on a rug is picked up first")
	game.placing.cancel_hand()
	assert_true(game.placing.pick_up(Vector3(8.5, 0, 4.5)))
	assert_eq(game.hand.id, "rug")
	assert_null(game.placing.rug_at(Vector2i(8, 4)))
	game.placing.rotate_hand()
	assert_eq(game.placing.rug_cells(Vector2i(6, 3), 1).size(), 6)
	assert_true(game.placing.rug_cells(Vector2i(6, 3), 1).has(Vector2i(7, 2)), "turned, it runs toward +x")
	assert_false(game.placing.can_place(Vector3i(9, 3, 0)), "not half off the floor")
	assert_true(game.placing.place(Vector3i(6, 3, 0)))
	assert_eq(game.ledger.money, 100, "moving is free")
	assert_not_null(game.placing.rug_at(Vector2i(7, 4)))
	assert_true(game.placing.pick_catalog("rug"))
	assert_false(game.placing.can_place(Vector3i(7, 3, 0)), "not on top of another rug")
	assert_true(game.placing.place(Vector3i(6, 0, 0)), "under a table is fine")
	assert_eq(game.ledger.money, 75)
	game.placing.cancel_hand()
	assert_true(game.placing.pick_catalog("floor_planks"))
	assert_false(game.room_edit.remove_at(Vector3i(7, 4, 0)), "no lifting the floor out from under a rug")
	game.placing.cancel_hand()
	game.ledger.day += 1   # a later night: no same-night return
	assert_true(game.placing.pick_up(Vector3(5.5, 0, 0.5)))
	assert_true(game.placing.sell_hand())
	assert_eq(game.ledger.money, 87, "half back")
	assert_eq(game.rugs.size(), 1)



func test_paint_and_paper_go_on_walls_and_come_off_for_a_refund():
	_to_build()
	game.ledger.money = 200
	game.ledger.xp = 300
	assert_true(game.placing.pick_catalog("paint"))
	assert_true(game.placing.on_edge("paint"))
	assert_eq(game.room_edit.finish_drag(Vector3(5, 0, 0), Vector3(8, 0, 0), false), 3, "a row along the back wall")
	assert_eq(game.ledger.money, 185)
	assert_eq(game.plan.finishes.get(Vector3i(6, 0, 0), ""), "paint")
	assert_true(game.placing.pick_catalog("paper_rose"))
	assert_true(game.placing.place(Vector3i(6, 0, 0)))
	assert_eq(game.ledger.money, 170, "$20 for the paper, $5 back for the paint under it")
	assert_true(game.room_edit.remove_at(Vector3i(6, 0, 0)))
	assert_eq(game.ledger.money, 190)
	assert_false(game.room_edit.remove_at(Vector3i(6, 0, 0)), "nothing left to strip")
	game.placing.cancel_hand()
	assert_true(game._room.get_child_count() > 0, "the room redraws with its paint")



func test_decor_cheers_a_guest_once_by_how_close_it_is():
	_to_build()
	game.stations[Vector2i(9, 0)].tier = 1
	var on_rug: Vector2i = Vector2i(7, 4)        # the first rug lies under the middle table
	var sees_rug := Vector2i(5, 3)              # two cells off, in sight
	assert_not_null(game.placing.rug_at(on_rug))
	assert_null(game.placing.rug_at(sees_rug))
	var on: float = game.decor.decor_bonus(on_rug).joy
	var seen: float = game.decor.decor_bonus(sees_rug).joy
	gut.p("decor on the rug %.3f, only seeing it %.3f" % [on, seen])
	assert_gt(on, seen, "sitting on the rug beats seeing it")
	assert_eq(game.decor.decor_bonus(on_rug).best, "rug")
	game.plan.floors[sees_rug] = "marble"
	assert_almost_eq(game.decor.decor_bonus(sees_rug).joy - seen, Catalog.joy_of("floor_marble"), 0.0001)
	game.plan.finishes[Vector3i(5, 0, 0)] = "paint"
	game.plan.finishes[Vector3i(6, 0, 0)] = "paper_stripe"
	var near_wall: Array = game.decor.decor_near(Vector2i(5, 1)).filter(func(n: Dictionary) -> bool: return n.id == "paper_stripe")
	assert_eq(near_wall.size(), 1, "the paper is beside the seat")
	assert_eq(int(near_wall[0].dist), 1)
	# Once, on sitting, not every second; and again only if the room changes.
	var g: Guest = game.seating.spawn_guest(0)
	g.seat = on_rug
	g.cell = on_rug
	g.mood.joy = 0.2
	on = game.decor.decor_bonus(on_rug).joy        # the marble is in view of the rug now
	game.decor.cheer_with_decor(g)
	assert_almost_eq(g.mood.joy, 0.2 + on, 0.0001)
	assert_true(g.mood.thoughts.has("Such a cosy rug"))
	game.seating.apply_surroundings(g, 1.0)
	game.decor.cheer_with_decor(g)
	assert_almost_eq(g.mood.joy, 0.2 + on, 0.0001, "no more joy while they sit")
	game.placing.pick_up(Vector3(7.5, 0, 4.5))
	game.placing.sell_hand()
	game.decor.cheer_with_decor(g)
	assert_almost_eq(g.mood.joy, 0.2 + game.decor.decor_bonus(on_rug).joy, 0.0001, "the rug went, and its cheer with it")



func test_a_marble_drag_shows_every_seat_it_would_cheer():
	_to_build()
	game.ledger.xp = 500
	game.ledger.money = 1000
	assert_true(game.placing.pick_catalog("floor_marble"))
	var drag := {"from": Vector3(6.5, 0, 2.5), "remove": false}
	var pr: Dictionary = game.decor.piece_reach(game.hand, Vector3(9.5, 0, 4.5), drag)
	assert_eq(pr.area, Rect2i(), "no pale square for a floor")
	var marks: Dictionary = game.decor.reach_marks(pr)
	for s: Vector2i in [Vector2i(7, 3), Vector2i(9, 3)]:
		assert_eq(marks[s].mark, Decor.MARK_ON, "every seat on the rectangle")
	assert_eq(marks[Vector2i(7, 1)].mark, Decor.MARK_BESIDE)
	assert_eq(game.decor.piece_reach(game.hand, Vector3(9.5, 0, 4.5), {"from": drag.from, "remove": true}), {},
		"nothing for a removing drag")
	# A narrower strip, really laid: on, in view and out of reach all match.
	drag = {"from": Vector3(9.5, 0, 3.5), "remove": false}
	marks = game.decor.reach_marks(game.decor.piece_reach(game.hand, Vector3(9.5, 0, 4.5), drag))
	assert_gt(game.room_edit.finish_drag(drag.from, Vector3(9.5, 0, 4.5), false), 0)
	var seen := _marks_tell_the_truth(marks, "floor_marble")
	for m in [Decor.MARK_ON, Decor.MARK_VIEW, Decor.MARK_NONE]:
		assert_true(seen.has(m), "the strip reaches seats %s (seen %s)" % [m, seen.keys()])
	game.placing.cancel_hand()
	assert_true(game.placing.pick_catalog("floor_tile"))
	assert_eq(game.decor.piece_reach(game.hand, Vector3(6.5, 0, 2.5), {}), {}, "plain tile shows nothing")



func test_a_carried_rug_shows_its_reach_truly():
	_to_build()
	assert_true(game.placing.pick_up(Vector3(8.5, 0, 4.5)))   # the old rug goes, so only the new one counts
	assert_true(game.placing.sell_hand())
	game.ledger.money = 100
	assert_true(game.placing.pick_catalog("rug"))
	var pr: Dictionary = game.decor.piece_reach(game.hand, Vector3(6.5, 0, 1.5), {})
	assert_true(pr.area.has_point(Vector2i(9, 3)), "the rug keeps a square, VIEW_RANGE round it")
	var marks: Dictionary = game.decor.reach_marks(pr)
	assert_true(game.placing.place(Vector3i(6, 1, 0)))
	var seen := _marks_tell_the_truth(marks, "rug")
	for m in [Decor.MARK_ON, Decor.MARK_BESIDE, Decor.MARK_VIEW]:
		assert_true(seen.has(m), "the rug reaches seats %s (seen %s)" % [m, seen.keys()])
	game.placing.cancel_hand()
	game.decor._update_range()
	assert_eq(game._range_key, "", "nothing in hand, no marks")



func test_paint_marks_the_seats_against_the_wall_and_in_view():
	_to_build()
	game.ledger.xp = 500
	game.ledger.money = 1000
	assert_true(game.placing.pick_catalog("paper_rose"))
	var drag := {"from": Vector3(4, 0, 0), "remove": false}
	var pr: Dictionary = game.decor.piece_reach(game.hand, Vector3(10, 0, 0), drag)
	assert_eq(pr.area, Rect2i(), "no pale square for a wall")
	var marks: Dictionary = game.decor.reach_marks(pr)
	assert_eq(marks[Vector2i(5, 1)].mark, Decor.MARK_BESIDE, "against the wall")
	assert_gt(game.room_edit.finish_drag(drag.from, Vector3(10, 0, 0), false), 0)
	var seen := _marks_tell_the_truth(marks, "paper_rose")
	assert_true(seen.has(Decor.MARK_VIEW) and seen.has(Decor.MARK_NONE), "seen %s" % [seen.keys()])
	assert_false(seen.has(Decor.MARK_ON), "nobody sits on a wall")
	game._drag = drag
	game._demo_hover = Vector3(10, 0, 0)
	game.decor._update_range()
	assert_gt(game._range_marks.get_child_count(), 5, "a mark for every seat")



func test_a_seat_at_the_decor_cap_is_marked_full():
	_to_build()
	game.ledger.xp = 500
	game.ledger.money = 1000
	assert_true(game.placing.pick_catalog("floor_marble"))
	assert_eq(game.room_edit.finish_drag(Vector3(9.5, 0, 3.5), Vector3(9.5, 0, 3.5), false), 1)
	assert_true(Decor.is_full(game.decor.decor_near(Vector2i(9, 3))), "on the rug and on marble")
	assert_true(game.placing.pick_catalog("paint"))
	var marks: Dictionary = game.decor.reach_marks(game.decor.piece_reach(game.hand, Vector3(10, 0, 3.5), {}))
	assert_gt(marks[Vector2i(9, 3)].share, 0.0)
	assert_true(marks[Vector2i(9, 3)].full, "more decor adds nothing there")
	assert_false(marks[Vector2i(5, 1)].full)



func test_seated_guests_get_the_decor_bonus_as_they_sit():
	var g := _seat_at(Vector2i(8, 3), true)     # seat (7, 3), on the rug
	assert_not_null(g)
	if g == null:
		return
	assert_gt(g.decor, 0.0)
	assert_almost_eq(g.decor, game.decor.decor_bonus(g.seat).joy, 0.0001)


func test_m_maps_to_no_action_and_never_mutes():
	assert_eq(Controls.action_for_key(KEY_M), "")
	_key(KEY_M)
	_key(KEY_M, false)
	assert_false(AudioServer.is_bus_mute(0), "M does nothing in build")
	game.day.use_door(game.player)
	assert_eq(game.phase, game.Phase.SERVICE)
	_key(KEY_M)
	_key(KEY_M, false)
	assert_false(AudioServer.is_bus_mute(0), "M does nothing in service")
