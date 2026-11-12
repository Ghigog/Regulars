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


func test_half_price_is_offered_once_and_halves_the_bill():
	var m := GuestMood.new()
	m.wait(8.0, 10.0)
	assert_true(m.offer_discount())
	assert_almost_eq(m.patience, 0.55, 0.001, "an apology buys back some patience")
	assert_false(m.offer_discount(), "only once per visit")
	assert_almost_eq(m.patience, 0.55, 0.001)
	assert_eq(m.bill_for(12), 6)
	assert_eq(m.bill_for(13), 7, "rounds in the house's favour")
	assert_eq(GuestMood.new().bill_for(12), 12)


func test_tip_never_negative():
	var m := GuestMood.new()
	m.see_gross(1.0, 1.0, "Ew")
	assert_eq(m.tip_for(12), 0)
	assert_eq(m.face(), "mad")


# ---------- Building ----------

func _room() -> Grid:
	# A 4 x 3 room with the door cell just outside its bottom edge at (1, 3).
	var g := Grid.new(4, 4)
	for x in 4:
		if x != 1:
			g.walls[Vector3i(x, 3, 0)] = true
	return g


func test_furniture_cannot_block_the_only_way_in():
	var g := _room()
	var area := Rect2i(0, 0, 4, 3)
	var door := Vector2i(1, 3)
	var chef: Array[Vector2i] = [Vector2i(3, 0)]
	var none: Array[Vector2i] = []
	assert_false(g.can_place_block(Vector2i(1, 2), none, area, door, chef, none), "right inside the door")
	assert_true(g.can_place_block(Vector2i(2, 1), none, area, door, chef, none))
	assert_false(g.can_place_block(Vector2i(3, 0), none, area, door, chef, none), "on top of the chef")
	assert_false(g.can_place_block(Vector2i(1, 3), none, area, door, chef, none), "outside the room")
	assert_false(g.blocked.has(Vector2i(2, 1)), "asking changes nothing")


func test_table_needs_room_for_both_seats():
	var g := _room()
	var area := Rect2i(0, 0, 4, 3)
	var none: Array[Vector2i] = []
	var mid: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 1)]
	var edge: Array[Vector2i] = [Vector2i(-1, 1), Vector2i(1, 1)]
	assert_true(g.can_place_block(Vector2i(2, 1), mid, area, Vector2i(1, 3), none, none))
	assert_false(g.can_place_block(Vector2i(0, 1), edge, area, Vector2i(1, 3), none, none), "a seat outside the room")
	g.reserved[Vector2i(1, 1)] = true
	assert_false(g.can_place_block(Vector2i(2, 1), mid, area, Vector2i(1, 3), none, none), "a seat already taken")
	assert_false(g.can_place_block(Vector2i(1, 1), none, area, Vector2i(1, 3), none, none), "nothing goes on a seat")


func test_wall_cannot_seal_off_a_seat_or_a_station():
	var g := _room()
	var area := Rect2i(0, 0, 4, 3)
	var door := Vector2i(1, 3)
	var none: Array[Vector2i] = []
	var seat: Array[Vector2i] = [Vector2i(0, 0)]
	g.walls[Vector3i(0, 1, 0)] = true                     # south of the corner seat
	assert_false(g.can_place_wall(Vector3i(1, 0, 1), area, door, seat, none), "the last way to the seat")
	assert_true(g.can_place_wall(Vector3i(2, 0, 1), area, door, seat, none))
	assert_false(g.can_place_wall(Vector3i(0, 1, 0), area, door, seat, none), "already a wall there")
	assert_false(g.can_place_wall(Vector3i(0, 0, 0), area, door, none, none), "the room's outer edge")
	# A stove in the corner: walls may not leave it with no side to stand at.
	g = _room()
	g.blocked[Vector2i(3, 0)] = true
	var stove: Array[Vector2i] = [Vector2i(3, 0)]
	g.walls[Vector3i(3, 1, 0)] = true
	assert_false(g.can_place_wall(Vector3i(3, 0, 1), area, door, none, stove))
	assert_false(g.walls.has(Vector3i(3, 0, 1)), "asking changes nothing")


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


func test_standing_and_trend_follow_visits():
	var t := Town.new(7)
	assert_eq(t.standing(0), 2, "everyone starts undecided")
	t.record_visit(0, 1.0)
	t.record_visit(0, 1.0)
	assert_eq(t.standing(0), 4)
	assert_eq(t.trend(0), 1)
	var friend: int = t.people[0].friends[0]
	assert_eq(t.trend(friend), 1, "friends heard about it")
	t.new_day()
	assert_eq(t.trend(0), 0)
	assert_eq(t.standing(0), 4, "a new day keeps opinions")
	t.record_visit(1, -0.5)
	t.record_visit(1, -0.5)
	t.record_visit(1, -0.5)
	assert_eq(t.standing(1), 0)
	assert_eq(t.trend(1), -1)


func test_gossip_line_names_the_friends():
	var t := Town.new(7)
	var friend: String = t.people[int(t.people[2].friends[0])].name
	assert_string_contains(t.gossip_line(2, 0.2), "will tell")
	assert_string_contains(t.gossip_line(2, 0.2), friend)
	assert_string_contains(t.gossip_line(2, -0.2), "will warn")
	assert_eq(t.gossip_line(2, 0.01), "", "a so-so visit starts no talk")


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


func test_flyers_bring_a_bigger_crowd():
	var plain := 0
	var boosted := 0
	for seed_value in range(1, 21):
		plain += Town.new(seed_value).roll_guests(1).size()
		boosted += Town.new(seed_value).roll_guests(1, Town.FLYER_BOOST).size()
	assert_gt(boosted, plain + 20, "at least one more guest a day on average")


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
