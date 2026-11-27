extends "res://test/helpers/game_case.gd"


func test_a_guest_who_finishes_eating_chats_then_waits_to_pay():
	var g := _ordered_guest()
	game.serving.serve(g, game.serving.full_tray_for(g))
	_run(g.eat_time + 0.5)
	assert_eq(g.state, "chatting")
	assert_eq(g.table.dirty, 1, "the plate is left as they finish eating")
	_run(Guest.CHAT_TIME)
	assert_eq(g.state, "to_pay")
	assert_true(game.paying.ready_to_pay(g.table))
	assert_eq(int(game.ledger.today.sales), 0, "no money until the bill is handed over")
	assert_true(game.paying.pay_wait(g) >= 0.0)



func test_a_ready_table_calls_a_chef_in_sight_but_not_behind_a_wall():
	var g := _ready_to_pay()
	game.player.position = Grid.center(Vector2i(8, 6))
	_run(1.0)
	assert_true(game.grid.has_los(g.table.cell, game.player.cell()))
	assert_true(g.calling, "a hand up with the bill bubble")
	_walls_round(g.table.cell)
	_run(1.0)
	assert_false(g.calling, "nobody can see them")



func test_after_a_while_one_guest_walks_to_the_till_and_the_rest_stay():
	var pair: Array[Guest] = game.seating.spawn_group([0, 1])
	_run(14.0)
	game.cooking.use_station(pair[0].table)
	for g in pair:
		game.serving.serve(g, game.serving.full_tray_for(g))
	_run(pair[0].eat_time + pair[1].eat_time + Guest.CHAT_TIME)
	assert_true(game.paying.ready_to_pay(pair[0].table))
	_run(game.paying.TILL_AFTER + 0.5)
	var going := pair.filter(func(g: Guest) -> bool: return g.state == "to_till" or g.state == "at_till")
	assert_eq(going.size(), 1, "one of them goes to pay")
	var stayed := pair.filter(func(g: Guest) -> bool: return g.state == "to_pay")
	assert_eq(stayed.size(), 1, "the other stays seated")
	_run(6.0)
	assert_eq(going[0].state, "at_till")
	assert_eq(Grid.to_cell(going[0].position), game.paying.till_front(), "queued in front of the pass")



func test_an_exact_bill_pays_as_before_and_a_wrong_one_is_refused():
	var g := _ready_to_pay()
	var n: int = game.paying.table_number(g.table)
	var wrong := Bill.new(n, {int(g.order.main.id): 2})
	game.player.set_held("bill")
	game.player.bill = wrong
	var joy := g.mood.joy
	assert_false(game.paying.give_bill(game.player, g.table))
	assert_eq(game.player.held, "", "the slip is thrown away")
	assert_almost_eq(g.mood.joy, joy - GuestMood.WRONG_BILL_JOY, 0.0001)
	assert_eq(g.mood.latest_thought(), "We never had the %s" % str(g.order.main.name).to_lower())
	assert_eq(g.state, "to_pay", "still waiting")
	assert_eq(int(game.ledger.today.sales), 0)
	# The right one, written at the till.
	var slip := Bill.new()
	slip.add(int(g.order.main.id))
	game.paying.print_bill(game.player, slip)
	assert_eq(game.player.held, "bill")
	assert_eq(game.player.bill.table, -1, "a chef's slip carries no table")
	assert_false(game.paying.slip_out(n), "only helper slips count as out")
	var bill := g.mood.bill_for(g.bill_base)
	var tip := maxi(0, g.mood.tip_for(bill, game.town.tip_bonus(g.idx)) + g.mood.pay_for(g.bill_base) - bill)
	assert_true(game.paying.give_bill(game.player, g.table))
	assert_eq(int(game.ledger.today.sales), bill, "the amount on the slip, never anything else")
	assert_eq(int(game.ledger.today.tips), tip, "the mood's extras with the tip")
	assert_eq(g.state, "leaving")



func test_holding_e_at_the_table_hands_the_bill_over():
	var g := _ready_to_pay()
	var stand := g.table.cell + Vector2i(0, 1) if not game.grid.is_blocked(g.table.cell + Vector2i(0, 1)) else g.table.cell + Vector2i(-1, 0)
	game.player.position = Grid.center(stand)
	game.player.look_at_cell(g.table.cell)
	game.player.set_held("bill")
	game.player.bill = game.paying.right_bill(g.table)
	assert_eq(game.cooking.prompt_for(g.table), "Hold to give the bill")
	game.paying._tick_giving(game.player, true, game.paying.HAND_TIME / 2.0)
	assert_eq(game.player.held, "bill", "half way")
	game.paying._tick_giving(game.player, false, 0.1)
	assert_eq(game.player.give_t, 0.0, "letting go starts again")
	for i in 12:
		game.paying._tick_giving(game.player, true, 0.1)
	assert_eq(game.player.held, "")
	assert_eq(g.state, "leaving")



func test_a_table_can_be_cleared_while_its_party_waits_to_pay():
	var g := _ready_to_pay()
	assert_eq(game.cooking.use_station(g.table), "Clear plates")
	assert_eq(g.table.dirty, 0)
	assert_true(game.seat_taken.has(g.seat), "the seat is still theirs")
	game.player.set_held("")
	game.paying.pay_bill(g.table)
	assert_false(game.seat_taken.has(g.seat), "free once they go")



func test_the_till_writes_a_bill_for_a_table_waiting_to_pay():
	var g := _ready_to_pay()
	var till: Station = game.paying.till_station()
	assert_eq(game.cooking.prompt_for(till), "Write the bill")
	game.cooking.use_station(till)
	assert_true(game.hud.bill_open())
	assert_eq(game.hud.bill.bill.table, -1, "no table is picked")
	for t in game.hud.bill._targets:
		assert_false(str(t.get_meta("key")).begins_with("table:"), "no table buttons")
	assert_true((game.hud.bill._targets.back() as Button).disabled, "Print waits for an item")
	game.hud.bill.select("item:%d" % int(g.order.main.id))
	game.hud.bill.action("use")
	game.hud.bill.action("use")
	game.hud.bill.action("sell")
	assert_eq(game.hud.bill.bill.count(int(g.order.main.id)), 1)
	game.hud.bill._print()
	assert_false(game.hud.bill_open())
	assert_eq(game.player.held, "bill")
	assert_eq(Bill.check(game.player.bill, game.paying.right_bill(g.table)), "ok")
	assert_eq(game.player.bill.table, -1)


func test_a_slip_with_no_table_is_checked_against_the_table_it_is_handed_to():
	var g := _ready_to_pay()
	game.player.set_held("bill")
	game.player.bill = Bill.new(-1, {int(g.order.main.id): 2})
	assert_false(game.paying.give_bill(game.player, g.table))
	assert_ne(g.mood.latest_thought(), "That's not our table")
	assert_eq(g.state, "to_pay")
	game.player.set_held("bill")
	game.player.bill = Bill.new(-1, {int(g.order.main.id): 1})
	assert_true(game.paying.give_bill(game.player, g.table))
	assert_eq(g.state, "leaving")


func test_at_the_till_a_slip_with_no_table_pays_the_guest_it_matches():
	var a := _ready_to_pay(0)
	var b := _ready_to_pay(1)
	assert_ne(a.table, b.table)
	a.order["side"] = {"id": 999}   # the two parties ordered the same main; give the front one a side
	game.paying.send_to_till(a.table)
	game.paying.send_to_till(b.table)
	_run(8.0)
	assert_eq(game.paying.till_line()[0], a)
	var slip: Bill = game.paying.right_bill(b.table)
	slip.table = -1
	game.player.set_held("bill")
	game.player.bill = slip
	assert_eq(game.paying._bill_table_at(game.paying.till_station(), slip), b.table)
	assert_true(game.paying.give_bill(game.player, game.paying.till_station()))
	assert_eq(b.state, "leaving")
	assert_ne(a.state, "leaving", "the front guest keeps waiting")


func test_a_slip_with_no_table_is_thrown_away_once_nobody_waits_to_pay():
	var g := _ready_to_pay()
	game.player.set_held("bill")
	game.player.bill = Bill.new(-1, {int(g.order.main.id): 1})
	game.paying._tick_paying(0.1)
	assert_eq(game.player.held, "bill", "someone is still waiting")
	game.paying.pay_bill(g.table)
	game.paying._tick_paying(0.1)
	assert_eq(game.player.held, "")



func test_a_ready_party_is_still_seated_and_patient_after_30_seconds():
	var g := _ordered_guest(0)
	game.serving.serve(g, game.serving.full_tray_for(g))
	_run(g.eat_time + Guest.CHAT_TIME + 0.5)
	assert_true(game.paying.ready_to_pay(g.table))
	_run(30.0)
	assert_eq(g.state, "to_pay", "still seated")
	assert_gt(g.mood.patience, 0.0)


func test_a_party_left_too_long_leaves_without_paying_and_no_strike():
	var g := _ordered_guest(0)
	game.serving.serve(g, game.serving.full_tray_for(g))
	g.mood.patience = 0.001   # almost none left when the table becomes ready to pay
	_run(g.eat_time + Guest.CHAT_TIME + 0.5)
	_run(GuestMood.PAY_GRACE - 1.5)
	assert_ne(g.state, "leaving", "still waiting inside the grace")
	_run(GuestMood.PAY_GRACE * 0.5 + 3.0)
	assert_eq(g.state, "leaving")
	assert_true(g.mood.skipped_bill)
	assert_eq(int(game.ledger.today.unpaid_bills), 1)
	assert_eq(int(game.ledger.today.sales), 0)
	assert_eq(game.ledger.strikes(), 0, "not a walkout")



func test_every_payer_shows_the_partys_lowest_patience_and_the_quitter_is_named():
	var pair: Array[Guest] = game.seating.spawn_group([0, 1])
	_run(14.0)
	game.cooking.use_station(pair[0].table)
	for g in pair:
		game.serving.serve(g, game.serving.full_tray_for(g))
	_run(pair[0].eat_time + pair[1].eat_time + Guest.CHAT_TIME)
	assert_true(game.paying.ready_to_pay(pair[0].table), "both are on the bill")
	pair[0].mood.patience = 1.0
	pair[1].mood.patience = 0.2
	_run(0.1)
	assert_lt(game.paying.pay_patience(pair[0].table), 0.25)
	assert_lt(pair[0]._fill.scale.x, 0.25, "the full-patience guest's bar shows the party's")
	pair[1].mood.patience = 0.001
	_run(0.5)
	assert_eq(pair[0].state, "leaving")
	assert_string_contains(game.hud.toast.text, "gave up", "the corner line names who snapped")
	assert_eq(int(game.ledger.today.unpaid_bills), 1)
	assert_eq(game.ledger.strikes(), 0)


func test_a_till_guest_running_out_drags_the_tables_bars_low_and_is_named():
	var pair: Array[Guest] = game.seating.spawn_group([0, 1])
	_run(14.0)
	game.cooking.use_station(pair[0].table)
	for g in pair:
		game.serving.serve(g, game.serving.full_tray_for(g))
	_run(pair[0].eat_time + pair[1].eat_time + Guest.CHAT_TIME)
	_run(game.paying.TILL_AFTER + 0.5)
	var at_till: Guest = pair.filter(func(g: Guest) -> bool: return g.state == "to_till" or g.state == "at_till")[0]
	var seated: Guest = pair.filter(func(g: Guest) -> bool: return g != at_till)[0]
	at_till.mood.patience = 0.2
	_run(0.1)
	assert_lt(game.paying.pay_patience(at_till.table), 0.25, "the table reads the till guest's patience")
	assert_lt(seated._fill.scale.x, 0.25, "the seated guest's bar is low too")
	at_till.mood.patience = 0.001
	_run(0.5)
	assert_eq(seated.state, "leaving", "the whole table gives up")
	assert_string_contains(game.hud.toast.text, "gave up", "the corner line names who snapped")
	assert_string_contains(game.hud.toast.text, game.town.people[at_till.idx].name, "and it is the till guest")


func test_one_press_makes_a_counter_the_fridge_a_box_needs():
	_to_build()
	game.ledger.money = 200
	var c := _plain_counter()
	assert_true(game.card.open_storage(c))
	var price: int = game.card.fridge_offer("box_patty")
	assert_eq(price, Upgrades.step_price("fridge"))
	assert_true(game.placing.buy({"id": "box_patty", "tier": 1}))
	assert_eq(game.stations[c].base, "fridge", "the counter is a fridge now")
	assert_true(game.kitchen.stock(c).has("box_patty"), "with the box in")
	assert_eq(game.ledger.money, 200 - price)
	assert_true(game.card.storing(), "the card stays open")
	game.session.close_shop()
	assert_true(game.card.open_storage(_plain_counter()))
	assert_string_contains(game.hud.shop_ui._storage_info({"id": "box_bun", "tier": 1}).blurb, "Unlimited tonight", "a box says it never runs out")
	game.session.close_shop()



func test_the_door_refusing_for_money_offers_remedies():
	_to_build()
	game.ledger.money = 0
	var why: String = game.menu_stock.open_block()
	assert_string_contains(why, "Tomorrow's stock costs")
	assert_string_contains(why, "dearest box")
	assert_string_contains(why, "sell something")



func test_a_wash_takes_one_dish_into_the_hands():
	_to_build()
	var sink: Station = game.world.find_station("sink")
	sink.dirty = 3
	sink.dirty_cups = 1
	var d: Dish = game.cooking.wash_one(sink)
	assert_eq(d.vessel, Dish.PLATE, "plates before cups")
	assert_eq(sink.dirty, 2)



func test_the_receipt_names_a_side_nobody_ordered():
	game.menu.add("side", [game.world.fixed_main().bread], "Plain Roll")
	game.ledger.today.served = 1
	var nudges: Array[String] = game.menu_stock.unordered_nudges()
	assert_eq(nudges.size(), 1)
	assert_string_contains(nudges[0], "Plain Roll: no orders.")


func test_the_till_rewrites_a_held_slip():
	var g := _ready_to_pay()
	var till: Station = game.paying.till_station()
	var id := int(g.order.main.id)
	game.player.set_held("bill")
	game.player.bill = Bill.new(-1, {id: 2})
	assert_eq(game.cooking.prompt_for(till), "Write a new bill")
	game.cooking.use_station(till)
	assert_true(game.hud.bill_open())
	assert_eq(game.hud.bill.bill.count(id), 2, "opens filled in from the slip")
	game.hud.bill.select("item:%d" % id)
	game.hud.bill.action("sell")
	game.hud.bill._print()
	assert_false(game.hud.bill_open())
	assert_eq(game.player.held, "bill")
	assert_eq(game.player.bill.count(id), 1, "the corrected slip replaced the old one")
	assert_true(game.paying.give_bill(game.player, g.table))


func test_closing_the_rewrite_keeps_the_old_slip():
	_ready_to_pay()
	var till: Station = game.paying.till_station()
	game.player.set_held("bill")
	game.player.bill = Bill.new(-1, {1: 2})
	game.cooking.use_station(till)
	game.hud.bill.action("back")
	assert_false(game.hud.bill_open())
	assert_eq(game.player.held, "bill")
	assert_eq(game.player.bill.count(1), 2)


func test_a_guest_queued_at_the_till_still_gets_the_slip_handed_over():
	var g := _ready_to_pay()
	g.state = "at_till"
	g.line_place = 0
	game.player.set_held("bill")
	game.player.bill = Bill.new(-1, {1: 2})
	assert_eq(game.cooking.prompt_for(game.paying.till_station()), "Hold to give the bill")


func test_the_bill_is_a_small_undimmed_slip_in_the_top_right():
	var g := _ready_to_pay()
	game.cooking.use_station(game.paying.till_station())
	var bs = game.hud.bill
	for c in bs.get_children():
		assert_false(c is ColorRect, "no dim layer over the room")
	assert_eq(bs.mouse_filter, Control.MOUSE_FILTER_IGNORE, "clicks outside the slip reach the room")
	assert_eq(bs._card.mouse_filter, Control.MOUSE_FILTER_STOP)
	var view: Vector2 = bs.get_viewport_rect().size
	var r: Rect2 = bs._card.get_global_rect()
	assert_gt(r.position.x, view.x * 0.5, "left edge past the middle")
	assert_lt(r.position.y, view.y * 0.25, "near the top")
	assert_lt(r.size.x, 460.0, "narrow")
	assert_lt(r.end.y, view.y + 1.0, "never past the bottom")
	for t in bs._targets:
		assert_true(bs.select(str(t.get_meta("key"))), "every button can be selected")
	assert_true(bs.select("item:%d" % int(g.order.main.id)))
	bs.action("use")
	assert_eq(bs.bill.count(int(g.order.main.id)), 1)
