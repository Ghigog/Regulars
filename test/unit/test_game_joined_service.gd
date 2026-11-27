extends "res://test/helpers/game_case.gd"
## One table of two tiles is served, billed and cleared as one table.


## Clears the room and builds one table of two tiles with four chairs; a party of four sits.
func _joined() -> Array[Station]:
	_clear_dining()
	return _add_table([Vector2i(6, 1), Vector2i(6, 2)], [Vector2i(5, 1), Vector2i(5, 2), Vector2i(7, 1), Vector2i(7, 2)])


func _party_of_four() -> Array[Guest]:
	var party: Array[Guest] = game.seating.spawn_group([0, 1, 2, 3])
	_run(16.0)
	return party


func _ordering(party: Array[Guest]) -> bool:
	return party.all(func(g: Guest) -> bool: return g.state == "ordering")


func _one_order_at(half: int) -> void:
	var t := _joined()
	var party: Array[Guest] = _party_of_four()
	assert_true(_ordering(party), "seated and ready to order")
	assert_string_contains(game.cooking.prompt_for(t[half]), "Take 4 orders")
	game.cooking.use_station(t[half])
	assert_true(party.all(func(g: Guest) -> bool: return g.state == "waiting"), "all four ordered")
	var ticketed: Array = party.filter(func(g: Guest) -> bool: return int(g.order.get("ticket", -1)) >= 0)
	assert_eq(game.tickets.size(), ticketed.size(), "one ticket each, none printed twice")
	assert_eq(game.cooking.prompt_for(t[1 - half]).begins_with("Take"), false, "nothing left to take at the other half")


func test_one_order_for_all_four_at_the_lead_half():
	_one_order_at(0)


func test_one_order_for_all_four_at_the_other_half():
	_one_order_at(1)


func test_a_second_chef_takes_the_order_at_the_other_half():
	var t := _joined()
	var party: Array[Guest] = _party_of_four()
	game.coop.join("pad:1")
	var two: Player = game.chefs[1]
	assert_string_contains(game.cooking.prompt_for(t[1], two), "Take 4 orders")
	game.cooking.use_station(t[1], false, two)
	assert_true(party.all(func(g: Guest) -> bool: return g.state == "waiting"))
	assert_eq(game.cooking.prompt_for(t[0], game.player).begins_with("Take"), false, "nothing left to take")


## A plate of the guest's own main, in the chef's hands.
func _plate_for(g: Guest) -> Dish:
	var item: Dictionary = g.order.main
	var d := Dish.make(Dish.PLATE)
	for id in item.ingredients:
		d.ings.append(str(id))
		d.qs.append(1.0)
	return d


func _serve_far_guest_at(half: int) -> void:
	var t := _joined()
	var party: Array[Guest] = _party_of_four()
	game.cooking.use_station(t[0])
	var far: Guest = party.filter(func(g: Guest) -> bool: return g.seat in t[1].seats and not (g.order.get("main", {}) as Dictionary).is_empty())[0]
	far.mood.patience = 0.1   # the one a shared dish goes to first
	var plate: Dish = _plate_for(far)
	game.player.take_dish(plate)
	assert_eq(game.serving._dish_guests(t[half], [plate]), [far], "found from either half")
	assert_eq(game.serving.serve_dishes(game.player, t[half]), 1)


func test_a_dish_for_a_guest_on_the_far_half_is_served_at_the_lead_half():
	_serve_far_guest_at(0)


func test_a_dish_for_a_guest_on_the_far_half_is_served_at_that_half():
	_serve_far_guest_at(1)


func test_one_bill_under_the_lower_number_handed_at_either_half():
	var t := _joined()
	var party: Array[Guest] = _party_of_four()
	game.cooking.use_station(t[0])
	for g in party:
		if int(g.order.get("ticket", -1)) >= 0:
			game.serving.serve(g, game.serving.full_tray_for(g))
	_run(party[0].eat_time + Guest.CHAT_TIME + 0.5)
	assert_true(game.paying.ready_to_pay(t[0]))
	assert_false(game.paying.ready_to_pay(t[1]), "the second half has no party of its own")
	var rows: Array = game.paying.bill_tables()
	assert_eq(rows.size(), 1, "one row on the bill screen")
	assert_eq(int(rows[0].number), game.paying.table_number(t[0]), "under the lower table number")
	assert_eq(int(rows[0].size), 4)
	var bill: Bill = game.paying.right_bill(t[0])
	assert_true(game.paying.bill_place(t[1]), "a bill can be handed at either half")
	game.player.set_held("bill")
	game.player.bill = bill
	assert_true(game.paying.give_bill(game.player, t[1]), "accepted at the far half")
	for g in party:
		assert_eq(g.state, "leaving")
		assert_false(game.seat_taken.has(g.seat))


func test_both_halves_are_free_once_the_last_guest_leaves():
	var t := _joined()
	var party: Array[Guest] = _party_of_four()
	for g in party:
		game.paying.leave_with_friends(g)
	assert_eq(game.seating._free_table_for(4), t[0], "the whole table is free again")
	assert_eq(game.seat_taken.size(), 0)


func test_plates_are_left_on_the_half_each_guest_sat_at():
	var t := _joined()
	var party: Array[Guest] = _party_of_four()
	game.cooking.use_station(t[0])
	for g in party:
		if int(g.order.get("ticket", -1)) >= 0:
			game.serving.serve(g, game.serving.full_tray_for(g))
	_run(party[0].eat_time + 0.5)
	assert_gt(t[0].dirty, 0, "plates on the lead half")
	assert_gt(t[1].dirty, 0, "plates on the other half")


func test_a_day_can_end_with_a_joined_table_occupied():
	var t := _joined()
	var party: Array[Guest] = _party_of_four()
	game.cooking.use_station(t[0])
	game.day.close_early()
	game.day._end_day()
	assert_eq(game.phase, game.Phase.SUMMARY)
	assert_true(is_instance_valid(t[1]))


## Faces the non-lead half of a joined table and seats an impatient party of three.
func _impatient_party_at_far_half() -> Array:
	var t := _joined()
	var party: Array[Guest] = game.seating.spawn_group([0, 1, 2])
	_run(16.0)
	game.cooking.use_station(t[0])
	var g: Guest = party[0]
	g.mood.patience = Game.DISCOUNT_BELOW * 0.5
	game.player.position = Grid.center(t[1].cell + Vector2i(-1, 0))
	game.player.facing = Vector2i(1, 0)
	assert_eq(game.world.station_at(game.player.target_cell()), t[1], "facing the non-lead half")
	return [t, g]


func test_half_price_hold_works_at_the_non_lead_half():
	var r := _impatient_party_at_far_half()
	var g: Guest = r[1]
	game.cooking.use_station(r[0][1])
	assert_true(game.serving._deal_hold.has(game.player), "a hold started")
	game.serving._tick_deal(game.player, true, game.serving.DEAL_HOLD * 0.5)
	assert_true(game.serving._deal_hold.has(game.player), "still holding")
	game.serving._tick_deal(game.player, true, game.serving.DEAL_HOLD * 0.6)
	assert_true(g.mood.discounted, "half price given")


func test_free_meal_hold_works_at_the_non_lead_half():
	var r := _impatient_party_at_far_half()
	var g: Guest = r[1]
	game.serving.offer_discount(g)
	g.mood.patience = 0.0
	g.mood.delight(-100.0, "")
	game.cooking.use_station(r[0][1])
	assert_eq(game.serving._deal_hold.get(game.player, {}).get("kind"), "comp")
	game.serving._tick_deal(game.player, true, game.serving.DEAL_HOLD + 0.01)
	assert_true(g.mood.comped, "free meal given")


func test_deal_hold_at_the_far_half_cancels_on_letting_go_or_walking_off():
	var r := _impatient_party_at_far_half()
	var g: Guest = r[1]
	game.cooking.use_station(r[0][1])
	game.serving._tick_deal(game.player, false, game.serving.DEAL_HOLD + 0.01)
	assert_false(g.mood.discounted, "let go early")
	game.cooking.use_station(r[0][1])
	game.player.position = Grid.center(Vector2i(1, 1))
	game.player.facing = Vector2i(-1, 0)
	game.serving._tick_deal(game.player, true, game.serving.DEAL_HOLD + 0.01)
	assert_false(g.mood.discounted, "walked away")
	assert_false(game.serving._deal_hold.has(game.player))
