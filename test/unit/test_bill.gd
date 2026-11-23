extends GutTest
## PRD 11.1: the bill sim, the paying wait and leaving without paying.


func _menu() -> Menu:
	var m := Menu.new()
	m.add("main", ["bun", "patty"], "Burger")     # id 1, $8
	m.add("side", ["bun"], "Fries")                # id 2
	m.add("drink", ["soda"], "Soda")              # id 3
	return m


func test_for_party_counts_duplicates_and_skips_guests_who_ordered_nothing():
	var m := _menu()
	var burger := m.find(1)
	var soda := m.find(3)
	var b := Bill.for_party(2, [[burger, soda], [burger], []])
	assert_eq(b.table, 2)
	assert_eq(b.count(1), 2, "two burgers")
	assert_eq(b.count(3), 1)
	assert_eq(b.count(2), 0)
	assert_eq(b.total_count(), 3, "the guest who ordered nothing adds nothing")


func test_check_is_ok_for_an_exact_bill_whatever_the_order_of_ticking():
	var right := Bill.new(1, {1: 2, 3: 1})
	var written := Bill.new(1)
	written.add(3)
	written.add(1)
	written.add(1)
	assert_eq(Bill.check(written, right), "ok")


func test_check_names_each_kind_of_mistake():
	var right := Bill.new(1, {1: 1, 3: 1})
	var missing = Bill.check(Bill.new(1, {1: 1}), right)
	assert_eq(missing.kind, "missing")
	assert_eq(missing.item, 3)
	var extra = Bill.check(Bill.new(1, {1: 1, 3: 1, 2: 1}), right)
	assert_eq(extra.kind, "extra")
	assert_eq(extra.item, 2)
	var too_many = Bill.check(Bill.new(1, {1: 2, 3: 1}), right)
	assert_eq(too_many.kind, "extra", "two burgers for one")
	assert_eq(Bill.check(Bill.new(2, {1: 1, 3: 1}), right).kind, "table")


func test_refusals_are_written_lines():
	var m := _menu()
	assert_eq(Bill.refusal({"kind": "extra", "item": 2}, m), "We never had the fries")
	assert_eq(Bill.refusal({"kind": "missing", "item": 3}, m), "You forgot my soda")
	assert_eq(Bill.refusal({"kind": "table", "item": -1}, m), "That's not our table")


func test_price_sums_tonights_prices():
	var m := _menu()
	var b := Bill.new(1, {1: 2, 3: 1})
	assert_eq(Bill.price(b, m), 2 * Menu.price_of(m.find(1)) + Menu.price_of(m.find(3)))


func test_waiting_to_pay_drains_patience_at_the_paying_scale():
	var food := GuestMood.new()
	var pay := GuestMood.new()
	food.wait(10.0, 100.0)
	var till := GuestMood.new()
	pay.wait_to_pay(10.0, 100.0, true)
	till.wait_to_pay(10.0, 100.0, false)
	var scale := GuestMood.PAY_PATIENCE_SCALE
	assert_almost_eq(1.0 - pay.patience, (1.0 - food.patience) / (scale * GuestMood.PAY_TABLE_SLOWER), 0.0001)
	assert_almost_eq(1.0 - till.patience, (1.0 - food.patience) / scale, 0.0001)
	assert_false(pay.skipped_bill)
	pay.wait_to_pay(1000.0, 100.0, true)
	assert_true(pay.walked_out())
	assert_true(pay.skipped_bill, "running out while waiting to pay is leaving unpaid")


func test_a_wrong_bill_costs_joy_and_is_said():
	var m := GuestMood.new()
	m.joy = 0.5
	m.refuse_bill("We never had the fries")
	assert_almost_eq(m.joy, 0.5 - GuestMood.WRONG_BILL_JOY, 0.0001)
	assert_eq(m.latest_thought(), "We never had the fries")


func test_leaving_unpaid_costs_less_opinion_than_a_walkout_and_is_no_strike():
	var a := Town.new(3)
	var b := Town.new(3)
	var before := float(a.people[0].affinity)
	a.left_unpaid(0)
	b.record_walkout(0, 1)
	var unpaid := before - float(a.people[0].affinity)
	var walked := before - float(b.people[0].affinity)
	assert_gt(unpaid, 0.0)
	assert_lt(unpaid, walked)
	assert_false(a.people[0].sore, "no grudge")
	var l := Ledger.new()
	l.record_unpaid_bill()
	assert_eq(int(l.today.unpaid_bills), 1)
	assert_eq(l.strikes(), 0)
	assert_eq(int(l.today.unpaid), 0, "staff wages stay their own")


func test_a_fussy_payer_with_no_patience_left_still_waits_the_grace():
	var m := GuestMood.new()
	m.tolerance["service"] = 1
	m.patience = 0.001
	for i in 340:
		m.wait_to_pay(0.1, 20.0, true)
	assert_false(m.skipped_bill, "still waiting at 34 s")
	for i in 40:
		m.wait_to_pay(0.1, 20.0, true)
	assert_true(m.skipped_bill, "gone by 38 s")


func test_a_patient_payer_keeps_their_patience():
	var m := GuestMood.new()
	m.wait_to_pay(0.1, 100.0, true)
	assert_gt(m.patience, 0.99)
