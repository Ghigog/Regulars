extends GutTest
## PRD 4: a second chef on the same screen. Drives the real game scene headlessly.

var game


func before_each():
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false   # straight into day 1
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])   # keeps the day open
	game.test_kitchen()


func _run(seconds: float) -> void:
	for i in int(seconds / 0.1):
		game.step(0.1)


func _to_summary() -> void:
	game.arrivals.clear()
	_run(0.2)


func _to_build() -> void:
	_to_summary()
	game.open_build()


func _pad(button: int, pressed: bool, device := 0) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = pressed
	game.controls._input(e)


func _tap_pad(button: int, device := 0) -> void:
	_pad(button, true, device)
	_pad(button, false, device)


func _two() -> Player:
	assert_eq(game.join("pad:1"), 1, "pad 1 joins as player two")
	return game.chefs[1]


# ---------------------------------------------------------------- joining and acting

func test_a_join_adds_a_second_chef_who_acts_for_themselves():
	var one: Player = game.player
	var two := _two()
	assert_eq(game.chefs.size(), 2)
	assert_eq(game.controls.owner_of("pad:1"), 1)
	assert_eq(two.trim, 1, "player two's trim colour")
	one.position = Grid.center(Vector2i(3, 4))
	two.position = Grid.center(Vector2i(1, 2))
	two.look(Vector2i(-1, 0))   # at the patty crate
	game.act(1, "use")
	assert_eq(two.held, Tray.kind("raw", game.fixed_main().grill), "chef 2 took a patty")
	assert_eq(one.held, "", "chef 1's hands are untouched")
	assert_eq(one.position, Grid.center(Vector2i(3, 4)), "and chef 1 did not move")


func test_each_chef_walks_with_their_own_device():
	var one: Player = game.player
	var two := _two()
	var at1 := one.position
	var at2 := two.position
	var e := InputEventJoypadMotion.new()
	e.device = 1
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = 1.0
	game.controls._input(e)
	for i in 5:
		game._process(0.1)
	assert_ne(two.position, at2, "chef 2 walks on pad 1's stick")
	assert_eq(one.position, at1, "chef 1 stands still")


func test_the_first_use_at_a_station_wins():
	var one: Player = game.player
	var two := _two()
	for ch: Player in [one, two]:
		ch.position = Grid.center(Vector2i(1, 2))
		ch.look(Vector2i(-1, 0))
	game.set_stocked("crate_" + game.fixed_main().grill, true)
	var stove: Station = game.stations[Vector2i(0, 3)]
	one.set_held(Tray.kind("raw", game.fixed_main().grill))
	two.set_held(Tray.kind("raw", game.fixed_main().grill))
	for ch: Player in [one, two]:
		ch.position = Grid.center(Vector2i(1, 3))
	assert_ne(game.use_station(stove, false, one), "", "chef 1 puts a patty on")
	assert_eq(game.use_station(stove, true, two).begins_with("Grill"), false, "chef 2 cannot put a second one on")


# ---------------------------------------------------------------- building together

func test_two_build_hands_are_independent():
	_to_build()
	var one: Player = game.player
	var two := _two()
	game.ledger.money = 500
	assert_true(game.pick_catalog("plant", 1, one))
	assert_true(game.pick_catalog("plant", 1, two))
	assert_eq(one.hand.id, "plant")
	assert_eq(two.hand.id, "plant", "each chef holds their own piece")
	assert_ne(one.hand, two.hand.merged({"x": 1}), "two dictionaries, not one")
	game.rotate_hand(two)
	assert_eq(int(two.hand.facing), 1)
	assert_eq(int(one.hand.facing), 0, "turning one hand leaves the other")
	var spot := Vector3i(2, 4, 0)
	assert_true(game.can_place(spot, one))
	assert_true(game.place(spot, one), "the first to press Use gets the spot")
	assert_false(game.can_place(spot, two), "the other's ghost shows the cross")
	game.cancel_hand(one)
	assert_true(game.pick_up(Grid.center(Vector2i(6, 1)), one), "chef 1 lifts a table")
	assert_false(game.pick_up(Grid.center(Vector2i(6, 1)), two), "chef 2 cannot take the piece chef 1 is moving")


func test_a_piece_cannot_shut_the_other_chef_in():
	_to_build()
	var two := _two()
	two.position = Grid.center(Vector2i(7, 3))
	var reach: Array[Vector2i] = game._reach()
	assert_true(reach.has(Vector2i(7, 3)), "every chef must still get about")


func test_the_shop_is_shared_and_whoever_opened_it_buys():
	_to_build()
	var one: Player = game.player
	var two := _two()
	game.ledger.money = 500
	game.act(1, "shop")
	assert_eq(game.shopper, two, "player two opened the shop")
	game.act(0, "shop")
	assert_eq(game.shopper, two, "player one's Shop does nothing while it is open")
	game.act(0, "turn")   # player one keeps building: no shop browsing
	assert_true(game.buy({"id": "plant", "tier": 1}))
	assert_eq(two.hand.get("id", ""), "plant", "the buyer holds what was bought")
	assert_true(one.hand.is_empty())
	assert_false(game.shopping)


# ---------------------------------------------------------------- shared screens

func test_the_receipt_needs_every_player():
	_two()
	_to_summary()
	assert_eq(game.phase, game.Phase.SUMMARY)
	game.act(0, "confirm")
	assert_eq(game.phase, game.Phase.SUMMARY, "one confirm is not enough with two")
	assert_eq(game.ready_states(), ["ready", "waiting"] as Array[String])
	game.act(0, "back")
	assert_eq(game.ready_states(), ["waiting", "waiting"] as Array[String], "Back takes it back")
	game.act(1, "confirm")
	game.act(0, "confirm")
	assert_eq(game.phase, game.Phase.BUILD, "both confirmed")


func test_the_receipt_takes_one_confirm_with_one_chef():
	_to_summary()
	game.act(0, "confirm")
	assert_eq(game.phase, game.Phase.BUILD)


func test_the_door_card_needs_both_chefs():
	_to_build()
	var one: Player = game.player
	var two := _two()
	for ch: Player in [one, two]:
		ch.position = game.DOORWAY + Vector3(-0.6, 0, 0)
	assert_eq(game.door_action(one), "Open up")
	game.use_door(one)
	assert_eq(game.phase, game.Phase.BUILD, "half turned")
	assert_eq(game.ready_states(), ["ready", "waiting"] as Array[String])
	game.use_door(one)
	assert_eq(game.ready_states(), ["waiting", "waiting"] as Array[String], "using it again cancels")
	game.use_door(two)
	game.use_door(one)
	assert_eq(game.phase, game.Phase.SERVICE, "the second chef opens")


func test_the_door_card_takes_one_use_with_one_chef():
	_to_build()
	game.player.position = game.DOORWAY + Vector3(-0.6, 0, 0)
	game.use_door()
	assert_eq(game.phase, game.Phase.SERVICE)


func test_closing_early_needs_both_chefs():
	var one: Player = game.player
	var two := _two()
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	game.clock = game.day_length() * 0.8
	for ch: Player in [one, two]:
		ch.position = game.DOORWAY + Vector3(-0.6, 0, 0)
	assert_eq(game.door_action(two), "Close early")
	game.use_door(two)
	assert_true(game.door_open, "one is not enough")
	game.use_door(one)
	assert_false(game.door_open, "both agreed")


# ---------------------------------------------------------------- leaving

func test_a_chef_who_leaves_returns_a_moved_piece():
	_to_build()
	var two := _two()
	assert_true(game.pick_up(Grid.center(Vector2i(6, 1)), two))
	assert_false(game.stations.has(Vector2i(6, 1)))
	assert_true(game.leave(1))
	assert_eq(game.chefs.size(), 1)
	assert_true(game.stations.has(Vector2i(6, 1)), "the table went back")


func test_a_new_piece_in_hand_costs_nothing_when_its_chef_leaves():
	_to_build()
	var two := _two()
	var money: int = game.ledger.money
	assert_true(game.pick_catalog("plant", 1, two))
	game.leave(1)
	assert_eq(game.ledger.money, money, "nothing was paid, so nothing is owed")


func test_food_lands_on_a_free_counter_when_its_chef_leaves():
	var two := _two()
	var patty := Tray.kind("raw", game.fixed_main().grill)
	two.set_held(patty)
	two.position = Grid.center(Vector2i(5, 3))
	game.leave(1)
	var found := false
	for st: Station in game.stations.values():
		found = found or (st.type in ["counter", "pass"] and st.item == patty)
	assert_true(found, "the patty is on the pass")


func test_when_player_one_leaves_the_other_becomes_player_one():
	var two := _two()
	game.leave(0)
	assert_eq(game.chefs.size(), 1)
	assert_eq(game.player, two)
	assert_eq(two.trim, 0, "dressed as player one")
	assert_eq(game.controls.owner_of("pad:1"), 0, "pad 1 is player one's now")


func test_the_last_chef_never_leaves():
	assert_false(game.leave(0))
	assert_eq(game.chefs.size(), 1)


# ---------------------------------------------------------------- devices

func test_start_on_an_unseated_pad_joins_and_on_a_seated_one_opens_options():
	_tap_pad(JOY_BUTTON_A, 0)   # player one picks up pad 0
	_tap_pad(JOY_BUTTON_START, 1)
	assert_eq(game.chefs.size(), 2, "pad 1 joined")
	assert_false(game.hud.options_open(), "joining does not open the options")
	_tap_pad(JOY_BUTTON_START, 1)
	assert_true(game.hud.options_open(), "Start on a seated pad opens the options")
	game.hud.toggle_options()
	_tap_pad(JOY_BUTTON_START, 0)
	assert_true(game.hud.options_open(), "and on player one's pad")
	game.hud.toggle_options()


func test_holding_start_leaves():
	_tap_pad(JOY_BUTTON_A, 0)
	_tap_pad(JOY_BUTTON_START, 1)
	assert_eq(game.chefs.size(), 2)
	_pad(JOY_BUTTON_START, true, 1)
	game.controls._process(0.5)
	assert_eq(game.chefs.size(), 2, "not yet")
	game.controls._process(0.6)
	assert_eq(game.chefs.size(), 1, "held a second: chef 2 left")
	_pad(JOY_BUTTON_START, false, 1)
	assert_false(game.hud.options_open(), "and the release opens nothing")


func test_enter_on_the_keyboard_joins_when_player_one_is_on_a_pad():
	_tap_pad(JOY_BUTTON_A, 0)
	var e := InputEventKey.new()
	e.physical_keycode = KEY_ENTER
	e.pressed = true
	game.controls._input(e)
	assert_eq(game.chefs.size(), 2)
	assert_eq(game.controls.owner_of("keys"), 1)


func test_touch_never_joins():
	_tap_pad(JOY_BUTTON_A, 0)
	assert_false(game.controls.joins("touch"))


func test_no_join_before_any_device_is_used():
	assert_false(game.controls.joins("pad:0"), "the first device used is player one's")


func test_each_players_hint_line_uses_their_own_device():
	assert_string_contains(game.hud._hint_text(0), "WASD")
	_two()
	assert_eq(game.controls.input_of(1).mode, "pad")
	assert_string_contains(game.hud._hint_text(0), "WASD", "player one is on the keyboard")
	assert_string_contains(game.hud._hint_text(1), "Stick", "player two is on a pad")
	game.hud.show_prompt(Vector2(300, 300), "Cook", 1)
	assert_eq(game.hud._prompts[1].key_label.text, "A", "chef 2's bubble shows the pad's button")
	assert_true(game.hud._prompts[1].tag.visible, "and their numbered tag")
	_to_build()
	assert_string_contains(game.hud._build_tip(1), "A pick up")
	assert_string_contains(game.hud._build_tip(0), "E pick up")
