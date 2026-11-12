extends GutTest
## Unit tests for the pure simulation classes in res://sim.


# ---------- Grid ----------

func test_path_goes_around_furniture():
	var g := Grid.new(3, 3)
	g.blocked[Vector2i(1, 0)] = true
	g.blocked[Vector2i(1, 1)] = true
	var path := g.find_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_eq(path.size(), 6, "has to detour through the bottom row")
	assert_eq(path[-1], Vector2i(2, 0))


func test_path_empty_when_walled_off():
	var g := Grid.new(2, 1)
	g.walls[Grid.edge_between(Vector2i(0, 0), Vector2i(1, 0))] = true
	assert_true(g.find_path(Vector2i(0, 0), Vector2i(1, 0)).is_empty())
	assert_false(g.reachable(Vector2i(0, 0), Vector2i(1, 0)))


func test_wall_blocks_line_of_sight():
	var g := Grid.new(5, 1)
	assert_true(g.has_los(Vector2i(0, 0), Vector2i(4, 0)))
	g.walls[Vector3i(2, 0, 1)] = true  # west edge of cell 2
	assert_false(g.has_los(Vector2i(0, 0), Vector2i(4, 0)))
	assert_true(g.has_los(Vector2i(2, 0), Vector2i(4, 0)), "both on the same side")


func test_furniture_does_not_block_sight():
	var g := Grid.new(5, 1)
	g.blocked[Vector2i(2, 0)] = true
	assert_true(g.has_los(Vector2i(0, 0), Vector2i(4, 0)))


func test_diagonal_sight_blocked_by_corner_walls():
	var g := Grid.new(2, 2)
	assert_true(g.has_los(Vector2i(0, 0), Vector2i(1, 1)))
	g.walls[Vector3i(1, 0, 1)] = true  # between (0,0) and (1,0)
	g.walls[Vector3i(0, 1, 0)] = true  # between (0,0) and (0,1)
	assert_false(g.has_los(Vector2i(0, 0), Vector2i(1, 1)))


# ---------- GuestMood ----------

func test_patience_runs_out():
	var m := GuestMood.new()
	m.wait(10.0, 40.0)
	assert_almost_eq(m.patience, 0.75, 0.001)
	m.wait(100.0, 40.0)
	assert_true(m.walked_out())


func test_disgust_lowers_satisfaction_and_tip():
	var happy := GuestMood.new()
	happy.taste(1.0)
	var grossed := GuestMood.new()
	grossed.taste(1.0)
	grossed.see_gross(0.1, 6.0, "Ew")
	assert_gt(happy.satisfaction(), grossed.satisfaction())
	assert_gt(happy.tip_for(12), grossed.tip_for(12))
	assert_eq(grossed.latest_thought(), "Ew")


func test_thoughts_are_not_repeated():
	var m := GuestMood.new()
	assert_true(m.think("Hm"))
	assert_false(m.think("Hm"))
	assert_eq(m.thoughts.size(), 1)


func test_tip_never_negative():
	var m := GuestMood.new()
	m.see_gross(1.0, 1.0, "Ew")
	assert_eq(m.tip_for(12), 0)
	assert_eq(m.face(), "mad")


# ---------- Town ----------

func test_good_visit_spreads_to_friends_only():
	var t := Town.new(7)
	var friend: int = t.people[0].friends[0]
	var stranger := -1
	for i in t.people.size():
		if i != 0 and not t.are_friends(0, i):
			stranger = i
			break
	t.record_visit(0, 0.9)
	assert_gt(t.people[0].affinity, 0.0)
	assert_almost_eq(float(t.people[friend].affinity), float(t.people[0].affinity) * Town.FRIEND_SHARE, 0.001)
	assert_eq(t.people[stranger].affinity, 0.0)


func test_bad_visit_lowers_visit_chance():
	var t := Town.new(7)
	var before := t.visit_chance(3)
	t.record_visit(3, -0.5)
	assert_lt(t.visit_chance(3), before)


func test_roll_guests_has_minimum_and_no_duplicates():
	var t := Town.new(7)
	for p in t.people:
		p.affinity = -1.0
	var guests := t.roll_guests(2)
	assert_gte(guests.size(), 5)
	var seen := {}
	for g in guests:
		assert_false(seen.has(g))
		seen[g] = true


func test_friendships_are_mutual():
	var t := Town.new(7)
	for i in t.people.size():
		for f: int in t.people[i].friends:
			assert_true(t.are_friends(f, i))


# ---------- Ledger ----------

func test_sale_adds_money_and_xp():
	var l := Ledger.new()
	l.record_sale(12, 4)
	assert_eq(l.money, 66)
	assert_eq(l.xp, 14)
	assert_eq(l.today.served, 1)


func test_level_up_every_hundred_xp():
	var l := Ledger.new()
	assert_eq(l.level(), 1)
	l.xp = 250
	assert_eq(l.level(), 3)


func test_cannot_overspend():
	var l := Ledger.new()
	assert_false(l.spend(51))
	assert_true(l.spend(50))
	assert_eq(l.money, 0)


func test_three_walkouts_close_the_restaurant():
	var l := Ledger.new()
	l.record_walkout()
	l.record_walkout()
	assert_false(l.is_closed_down())
	l.record_walkout()
	assert_true(l.is_closed_down())


func test_end_day_resets_today_and_keeps_history():
	var l := Ledger.new()
	l.record_sale(12, 0)
	l.record_walkout()
	var rec := l.end_day()
	assert_eq(rec.day, 1)
	assert_eq(rec.served, 1)
	assert_eq(l.day, 2)
	assert_eq(l.strikes(), 0)
	assert_eq(l.history.size(), 1)


func test_lifetime_earnings_span_days():
	var l := Ledger.new()
	l.record_sale(12, 3)
	l.end_day()
	l.record_sale(12, 0)
	assert_eq(l.lifetime_earnings(), 27)


# ---------- Catalog (parked system, see docs/DESIGN.md) ----------

func test_offer_has_two_different_blueprints():
	var c := Catalog.new(3)
	for i in 20:
		var o := c.offer()
		assert_eq(o.size(), 2)
		assert_ne(o[0].id, o[1].id)


func test_catalog_is_gated_by_money_and_level():
	var c := Catalog.new()
	assert_true(c.can_buy("plant", 20, 1))
	assert_false(c.can_buy("plant", 19, 1))
	assert_false(c.can_buy("stove", 999, 2))
	assert_true(c.can_buy("stove", 80, 3))


func test_shelved_blueprint_returns_upgraded_after_two_days():
	var c := Catalog.new()
	c.shelve({"id": "plant", "tier": 1}, 2)
	assert_eq(c.collect_ready(3).size(), 0)
	var ready := c.collect_ready(4)
	assert_eq(ready.size(), 1)
	assert_eq(ready[0].tier, 2)
	assert_eq(c.shelf.size(), 0)
	assert_eq(Catalog.label(ready[0]), "Potted fern +")


func test_cannot_shelve_past_max_tier():
	var c := Catalog.new()
	assert_true(c.can_shelve({"id": "plant", "tier": 2}))
	assert_false(c.can_shelve({"id": "plant", "tier": 3}))


func test_expression_follows_the_strongest_feeling():
	var m := GuestMood.new()
	assert_eq(m.expression(), "neutral")
	m.delight(0.1)
	assert_eq(m.expression(), "content")
	m.delight(0.3)
	assert_eq(m.expression(), "delighted")
	m.patience = 0.4
	assert_eq(m.expression(), "impatient")
	m.patience = 0.2
	assert_eq(m.expression(), "snap")
	m.disgust = 0.6
	assert_eq(m.expression(), "disgusted")
	assert_eq(m.expression(true), "chewing")
	assert_eq(m.expression(false, true), "angry")
