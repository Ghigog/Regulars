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


func test_disgust_starts_small_and_doubles_up_to_a_cap():
	assert_almost_eq(GuestMood.gross_rate(0.002, 0.0, 10.0, 0.06), 0.002, 0.0001)
	assert_almost_eq(GuestMood.gross_rate(0.002, 10.0, 10.0, 0.06), 0.004, 0.0001)
	assert_almost_eq(GuestMood.gross_rate(0.002, 30.0, 10.0, 0.06), 0.016, 0.0001)
	assert_eq(GuestMood.gross_rate(0.002, 300.0, 10.0, 0.06), 0.06, "capped")
	var m := GuestMood.new()
	m.see_gross(0.002, 1.0, "Ew")
	assert_eq(m.latest_thought(), "", "too faint to notice yet")
	assert_gt(m.disgust, 0.0)
	m.see_gross(0.01, 1.0, "Ew")
	assert_eq(m.latest_thought(), "Ew")


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


func test_free_meal_only_for_the_very_unhappy_and_costs_the_whole_bill():
	var m := GuestMood.new()
	m.patience = 0.4
	assert_false(m.very_unhappy())
	assert_false(m.offer_comp(), "not for a guest who is merely impatient")
	m.patience = GuestMood.COMP_BELOW - 0.05
	assert_true(m.offer_comp())
	assert_false(m.offer_comp(), "only once per visit")
	assert_gt(m.patience, 0.75, "calms them more than half price")
	assert_eq(m.bill_for(12), 0)
	var d := GuestMood.new()
	d.disgust = 0.5
	assert_true(d.very_unhappy(), "disgust counts as very unhappy")
	assert_true(d.offer_comp())
	assert_lt(d.disgust_level(), 2, "a free meal takes the edge off")


func test_a_free_meal_wins_more_goodwill_than_half_price_and_reaches_friends():
	var t := Town.new()
	t.record_kindness(0, "half")
	t.record_kindness(2, "comp")
	assert_gt(float(t.people[2].affinity), float(t.people[0].affinity))
	assert_gt(float(t.people[3].affinity), 0.0, "friends hear about a free meal")
	assert_eq(float(t.people[13].affinity), 0.0, "but not about half price")


func test_guests_given_deals_come_to_expect_them():
	var t := Town.new()
	for n in Town.EXPECT_AT - 1:
		t.record_kindness(4, "half")
	assert_false(t.expects_deal(4))
	t.record_kindness(4, "half")
	assert_true(t.expects_deal(4))
	assert_string_contains(t.greeting(4).thought, "knock something off")
	var before := float(t.people[4].affinity)
	t.record_kindness(4, "half")
	assert_almost_eq(float(t.people[4].affinity) - before, Town.KIND_HALF * Town.EXPECTED_KINDNESS, 0.001,
			"an expected deal earns less goodwill")
	assert_eq(t.paid_full_price(4), Town.LETDOWN_JOY, "full price lets them down")
	assert_eq(t.paid_full_price(4), Town.LETDOWN_JOY, "until the habit wears off")
	assert_false(t.expects_deal(4))
	assert_eq(t.paid_full_price(4), 0.0)
	assert_eq(Town.new().paid_full_price(0), 0.0, "no letdown for someone never given a deal")


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


func test_three_good_visits_make_a_regular_who_tips_more():
	var t := Town.new(7)
	t.record_visit(0, 0.8)
	t.record_visit(0, 0.8)
	assert_false(t.is_regular(0))
	assert_eq(t.tip_bonus(0), 1.0)
	t.record_visit(0, 0.8)
	assert_true(t.is_regular(0))
	assert_eq(t.greeting(0).thought, "My favourite place")
	var m := GuestMood.new()
	m.taste(1.0)
	assert_gt(m.tip_for(12, t.tip_bonus(0)), m.tip_for(12))
	assert_string_contains(t.status_word(0, 5), "Regular, 3")
	t.record_visit(0, 0.1)
	assert_false(t.is_regular(0), "a poor visit breaks the streak")


func test_walkout_keeps_them_away_then_they_return_sore():
	var t := Town.new(7)
	t.record_walkout(4, 3)
	for day in [4, 5]:
		assert_true(t.holds_grudge(4, day))
		for n in 20:
			assert_false(t.roll_guests(day, 1.0).has(4), "stays away even when the crowd is topped up")
	assert_string_contains(t.status_word(4, 5), "1 more day")
	assert_false(t.holds_grudge(4, 6))
	assert_true(t.roll_guests(6, 1.0).has(4))
	assert_almost_eq(float(t.greeting(4).patience), 0.75, 0.001)


func test_a_good_visit_forgives_and_a_second_walkout_lasts_longer():
	var t := Town.new(7)
	t.record_walkout(4, 3)
	var before: float = t.people[4].affinity
	var delta := t.record_visit(4, 0.8)
	assert_false(t.people[4].sore)
	assert_almost_eq(delta, 0.35, 0.001, "the usual 0.25 plus 0.1 for forgiving")
	assert_gt(float(t.people[4].affinity), before)
	assert_eq(float(t.greeting(4).patience), 1.0)
	t.record_walkout(4, 10)
	assert_true(t.holds_grudge(4, 14), "four days away the second time")
	assert_false(t.holds_grudge(4, 15))


func test_groups_are_friends_and_fit_the_biggest_table():
	for seed_value in range(1, 11):
		var t := Town.new(seed_value)
		var coming := t.roll_guests(6)
		for max_size in [1, 2, 4]:
			var seen := {}
			for group: Array in t.make_groups(coming, max_size):
				assert_between(group.size(), 1, max_size)
				for who: int in group:
					assert_false(seen.has(who), "nobody is in two groups")
					seen[who] = true
					if who != group[0]:
						assert_true(t.are_friends(group[0], who), "no strangers at the table")
			assert_eq(seen.size(), coming.size(), "everyone who is coming is in a group")


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
	assert_eq(l.money, 166)
	assert_eq(l.xp, 14)
	assert_eq(l.today.served, 1)


func test_level_up_every_hundred_xp():
	var l := Ledger.new()
	assert_eq(l.level(), 1)
	l.xp = 250
	assert_eq(l.level(), 3)


func test_cannot_overspend():
	var l := Ledger.new()
	assert_false(l.spend(151))
	assert_true(l.spend(150))
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
	assert_false(c.can_buy("stove", 49, 1))
	assert_true(c.can_buy("stove", 50, 1), "a first kitchen can buy a stove at level 1")
	assert_false(c.can_buy("ready_cheese", 999, 1), "ready-made needs level 2")


func test_higher_tiers_cost_more_and_need_more_levels():
	var c := Catalog.new(1)
	assert_eq(Catalog.price_of("stove", 2), 100)
	assert_eq(Catalog.price_of("plant", 3), 80)
	assert_eq(Catalog.level_of("table", 3), 4)
	assert_true(c.can_buy("plant", 40, 2, 2))
	assert_false(c.can_buy("plant", 40, 1, 2), "tier 2 needs level 2")
	assert_false(c.can_buy("plant", 39, 2, 2))
	assert_false(c.can_buy("counter", 999, 9, 2), "counters have one tier")
	assert_false(c.can_buy("stove", 9999, 9, 4))


func test_catalog_search_by_word_and_category():
	assert_eq(Catalog.search().size(), 84, "45 room pieces, five tools of three tiers, 18 ingredient stations and 6 ready-made")
	var ferns := Catalog.search("FERN")
	assert_eq(ferns.size(), 3)
	assert_eq(int(ferns[0].tier), 1, "cheapest first")
	var kitchen := Catalog.search("", "Kitchen", "diner")
	assert_eq(kitchen.size(), 32, "the counter, a bin, a dish rack, a sink, five tools, nine diner stations and four ready-made")
	assert_eq(kitchen[0].id, "crate_bun", "cheapest first, then by name")
	assert_eq(Catalog.search("", "Kitchen", "seaside").filter(func(bp: Dictionary) -> bool:
		return Catalog.ITEMS[bp.id].get("theme", "seaside") != "seaside").size(), 0, "only the run's theme")
	assert_eq(Catalog.search("two more seats").size(), 1, "matches what a piece does")
	assert_eq(Catalog.search("stove ++").size(), 1)
	assert_eq(Catalog.search("fern", "Kitchen").size(), 0)
	assert_eq(Catalog.search("partition")[0].id, "screen")
	assert_eq(Catalog.search("", "Build").size(), 11, "four floors, wall, three finishes, door, archway and the partition")
	assert_eq(Catalog.search("build", "Dining").size(), 0, "matches the category name")


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
	assert_eq(m.expression(), "content", "people look pleasant by default")
	m.joy = 0.3
	assert_eq(m.expression(), "neutral")
	m.joy = 0.5
	m.delight(0.3)
	assert_eq(m.expression(), "delighted")
	m.patience = 0.3
	assert_eq(m.expression(), "impatient")
	m.patience = 0.1
	assert_eq(m.expression(), "snap")
	m.disgust = 0.3
	assert_eq(m.expression(), "snap", "the first stage of disgust does not change the face")
	m.disgust = 0.6
	assert_eq(m.expression(), "disgusted")
	assert_eq(m.expression(true), "chewing")
	assert_eq(m.expression(false, true), "angry")


func test_disgust_does_nothing_until_it_crosses_a_stage():
	var m := GuestMood.new()
	m.savour = 1.0
	var clean := m.satisfaction()
	m.disgust = 0.15
	assert_eq(m.disgust_level(), 0)
	assert_eq(m.satisfaction(), clean, "below the first stage it has no effect")
	m.disgust = 0.25
	assert_eq(m.disgust_level(), 1)
	assert_lt(m.satisfaction(), clean)
	m.disgust = 0.5
	assert_eq(m.disgust_level(), 2)
	m.disgust = 0.8
	assert_eq(m.disgust_level(), 3)


func test_disgusted_guests_tell_friends_and_revolted_ones_never_return():
	var t := Town.new(1)
	var friend: int = t.people[0].friends[0]
	assert_eq(t.record_disgust(0, 1), "", "an ick is theirs alone")
	assert_eq(t.people[friend].affinity, 0.0)
	assert_ne(t.record_disgust(0, 2), "")
	assert_lt(t.people[friend].affinity, 0.0, "friends hear about it")
	assert_false(t.people[0].gone)
	t.record_disgust(0, 3)
	assert_true(t.people[0].gone)
	assert_eq(t.visit_chance(0), 0.0)
	for day in range(1, 6):
		assert_false(t.roll_guests(day).has(0), "never comes back")
	assert_eq(t.status_word(0, 1), "Never coming back")



# ---------------------------------------------------------------- floorplan

func _plan() -> Floorplan:
	var p := Floorplan.new(Rect2i(-3, -3, 10, 10))
	p.fill(Rect2i(0, 0, 2, 2), "planks")
	return p


func test_outer_walls_follow_the_edge_of_the_floor():
	var p := _plan()
	assert_eq(p.walls().size(), 8, "a 2 x 2 floor has 8 lengths of wall round it")
	assert_false(p.is_wall(Vector3i(1, 0, 1)), "none inside")
	assert_true(p.is_wall(Vector3i(0, 0, 0)))
	var gone := p.lay(Vector2i(2, 0), "tile")
	assert_true(gone.is_empty())
	assert_false(p.is_wall(Vector3i(2, 0, 1)), "the wall between old and new floor comes down")
	assert_true(p.is_wall(Vector3i(3, 0, 1)), "and goes up round the new edge")


func test_floor_must_touch_the_room_and_stay_on_the_lot():
	var p := _plan()
	assert_false(p.can_lay(Vector2i(4, 4), "tile"), "not floating on its own")
	assert_true(p.can_lay(Vector2i(2, 1), "tile"))
	assert_false(p.can_lay(Vector2i(0, 0), "planks"), "already planks")
	assert_true(p.can_lay(Vector2i(0, 0), "tile"), "but can be re-laid as tile")
	assert_false(p.can_lay(Vector2i(-4, 0), "tile"), "off the lot")
	var order := p.lay_order(Floorplan.rect_cells(Vector2i(5, 0), Vector2i(2, 0)), "tile")
	assert_eq(order, [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)] as Array[Vector2i],
		"a dragged strip is laid outward from the room")


func test_built_walls_and_openings():
	var p := _plan()
	assert_true(p.can_build(Vector3i(1, 0, 1)), "between two floors")
	assert_false(p.can_build(Vector3i(0, 0, 0)), "not on the outline")
	p.build(Vector3i(1, 0, 1))
	assert_true(p.is_wall(Vector3i(1, 0, 1)))
	assert_true(p.can_open(Vector3i(1, 0, 1), "door"))
	assert_true(p.can_open(Vector3i(0, 0, 0), "arch"), "an outer wall can take one, for floor laid later")
	assert_false(p.can_open(Vector3i(1, 1, 1), "door"), "no wall there")
	p.openings[Vector3i(0, 0, 0)] = "arch"
	assert_false(p.opening_has_floor(Vector3i(0, 0, 0)), "bare ground behind it")
	p.openings[Vector3i(1, 0, 1)] = "arch"
	assert_true(p.opening_has_floor(Vector3i(1, 0, 1)))
	assert_eq(p.unbuild(Vector3i(1, 0, 1)), "arch", "taking the wall down takes its archway")
	p.openings[Vector3i(1, 0, 0)] = "door"
	assert_eq(p.lay(Vector2i(1, -1), "planks"), {Vector3i(1, 0, 0): "door"}, "a door in an outer wall goes when floor is laid past it")
	p.build(Vector3i(1, 0, 1))
	p.lift(Vector2i(0, 0))
	assert_false(p.built.has(Vector3i(1, 0, 1)), "a built wall goes with the floor beside it")
	assert_eq(Floorplan.line(Vector2i(0, 2), Vector2i(3, 2)), [Vector3i(0, 2, 0), Vector3i(1, 2, 0), Vector3i(2, 2, 0)] as Array[Vector3i])
	assert_eq(Floorplan.line(Vector2i(1, 3), Vector2i(1, 1)), [Vector3i(1, 1, 1), Vector3i(1, 2, 1)] as Array[Vector3i])


func test_doors_let_people_through_but_not_their_gaze():
	var g := Grid.new(3, 1, Vector2i(-1, 0))
	assert_true(g.in_bounds(Vector2i(-1, 0)), "a grid can start below zero")
	g.doors[Vector3i(0, 0, 1)] = true
	assert_true(g.reachable(Vector2i(-1, 0), Vector2i(1, 0)))
	assert_false(g.has_los(Vector2i(-1, 0), Vector2i(1, 0)))
	g.outside[Vector2i(0, 0)] = true
	assert_false(g.reachable(Vector2i(-1, 0), Vector2i(1, 0)), "nobody walks on bare ground")


func test_walls_take_one_finish_that_goes_with_the_wall():
	var p := _plan()
	var back := Vector3i(0, 0, 0)            # the north edge of the floor: an outer wall
	assert_true(p.can_finish(back, "paint"))
	assert_false(p.can_finish(Vector3i(1, 0, 1), "paint"), "no wall between two floors")
	assert_false(p.can_finish(back, "glitter"), "only real finishes")
	assert_eq(p.finish(back, "paint"), "")
	assert_false(p.can_finish(back, "paint"), "already painted")
	assert_eq(p.finish(back, "paper_rose"), "paint", "papering over paint hands the paint back")
	var gone := p.lay(Vector2i(0, -1), "planks")
	assert_eq(gone.get(back, ""), "paper_rose", "the wall came down, and its paper with it")
	assert_false(p.finishes.has(back))
	p.openings[Vector3i(0, 0, 1)] = "door"
	assert_false(p.can_finish(Vector3i(0, 0, 1), "paint"), "not across a doorway")
	p.finish(Vector3i(0, 1, 1), "paint")
	assert_eq(p.strip(Vector3i(0, 1, 1)), "paint")
	assert_eq(p.strip(Vector3i(0, 1, 1)), "")


func test_nicer_finishes_cost_more_need_a_level_and_give_more_joy():
	assert_true(Floorplan.KINDS.has("parquet") and Floorplan.KINDS.has("marble"))
	for id in Floorplan.FINISHES:
		assert_true(Catalog.is_finish(id) and Catalog.is_build_tool(id))
	assert_false(Catalog.is_finish("wall"))
	for pair: Array in [["floor_planks", "floor_parquet"], ["floor_parquet", "floor_marble"], ["paint", "paper_stripe"], ["paper_stripe", "paper_rose"]]:
		assert_lt(Catalog.price_of(pair[0]), Catalog.price_of(pair[1]))
		assert_lt(Catalog.level_of(pair[0]), Catalog.level_of(pair[1]))
		assert_lt(Catalog.joy_of(pair[0]), Catalog.joy_of(pair[1]))
	assert_eq(Catalog.joy_of("floor_tile"), 0.0, "plain floors do nothing")
	assert_almost_eq(Catalog.joy_of("plant", 3) - Catalog.joy_of("plant"), 2 * Catalog.TIER_JOY, 0.0001)


# ---------------------------------------------------------------- decor

func test_decor_gives_most_on_it_less_beside_and_least_in_view():
	assert_eq(Decor.band(0), Decor.ON)
	assert_eq(Decor.band(1), Decor.BESIDE)
	assert_eq(Decor.band(Decor.VIEW_RANGE), Decor.IN_VIEW)
	assert_eq(Decor.band(Decor.VIEW_RANGE + 1), 0.0, "out of sight range")
	var rug := Catalog.joy_of("rug")
	var on: float = Decor.bonus([{"id": "rug", "dist": 0}]).joy
	var beside: float = Decor.bonus([{"id": "rug", "dist": 1}]).joy
	var seen: float = Decor.bonus([{"id": "rug", "dist": 3}]).joy
	assert_almost_eq(on, rug, 0.0001)
	assert_almost_eq(beside, rug * Decor.BESIDE, 0.0001)
	assert_almost_eq(seen, rug * Decor.IN_VIEW, 0.0001)
	assert_gt(on, beside)
	assert_gt(beside, seen)
	assert_eq(Decor.bonus([]).joy, 0.0)
	assert_eq(Decor.bonus([]).best, "")


func test_decor_sight_is_the_nearest_cell_in_reach_and_view():
	var g := Grid.new(6, 3)
	var seat := Vector2i(0, 1)
	assert_eq(Decor.nearest(g, seat, [Vector2i(3, 1), Vector2i(2, 2)], 3), 2, "the nearest cell counts")
	assert_eq(Decor.nearest(g, seat, [Vector2i(4, 1)], 3), -1, "out of reach")
	assert_eq(Decor.nearest(g, seat, [seat], 3), 0, "under the seat")
	g.walls[Vector3i(1, 0, 1)] = true
	g.walls[Vector3i(1, 1, 1)] = true
	g.walls[Vector3i(1, 2, 1)] = true
	assert_eq(Decor.nearest(g, seat, [Vector2i(2, 1)], 3), -1, "a partition blocks it")
	assert_eq(Decor.share("floor_marble", 0), Decor.ON)
	assert_eq(Decor.share("paint", 0), Decor.BESIDE, "nobody sits on a wall")
	assert_eq(Decor.share("rug", 2), Decor.IN_VIEW)
	assert_eq(Decor.share("rug", -1), 0.0)
	assert_eq(Decor.share("plant", 4, 2), Decor.IN_VIEW, "a better fern is seen further")


func test_decor_marks_have_four_levels_and_a_full_flag():
	assert_eq(Decor.mark(Decor.ON), Decor.MARK_ON)
	assert_eq(Decor.mark(Decor.BESIDE), Decor.MARK_BESIDE)
	assert_eq(Decor.mark(Decor.IN_VIEW), Decor.MARK_VIEW)
	assert_eq(Decor.mark(0.0), Decor.MARK_NONE)
	assert_true(Decor.is_full([{"id": "rug", "dist": 0}, {"id": "floor_marble", "dist": 0}]), "0.15 + 0.2 is the cap")
	assert_false(Decor.is_full([{"id": "rug", "dist": 0}]))


func test_a_wall_finish_only_cheers_its_own_side():
	var p := Floorplan.new(Rect2i(0, 0, 5, 5))
	p.fill(Rect2i(0, 0, 5, 2), "tile")
	var outer := Vector3i(2, 0, 0)            # the north wall of (2, 0): only floor on one side
	assert_eq(Decor.finish_cells(p, [outer]), [Vector2i(2, 0)] as Array[Vector2i])
	var inner := Vector3i(2, 1, 0)            # between (2, 1) and (2, 0)
	assert_eq(Decor.finish_cells(p, [inner]).size(), 2)
	var g := Grid.new(5, 2)
	var seat := Vector2i(2, 1)
	assert_eq(Decor.share_from(g, seat, "paint", Decor.finish_cells(p, [outer])), Decor.BESIDE)
	for x in 5:
		g.walls[Vector3i(x, 1, 0)] = true      # a wall between the rows
	assert_eq(Decor.share_from(g, seat, "paint", Decor.finish_cells(p, [outer])), 0.0,
		"the far room's painted wall is not seen through the wall")


func test_decor_counts_each_kind_once_and_kinds_stack_to_a_cap():
	var two_rugs: float = Decor.bonus([{"id": "rug", "dist": 0}, {"id": "rug", "dist": 1}, {"id": "rug", "dist": 2}]).joy
	assert_almost_eq(two_rugs, Catalog.joy_of("rug"), 0.0001, "the best of a kind, not the sum")
	var b := Decor.bonus([{"id": "rug", "dist": 0}, {"id": "paint", "dist": 1}])
	assert_almost_eq(b.joy, Catalog.joy_of("rug") + Catalog.joy_of("paint") * Decor.BESIDE, 0.0001)
	assert_eq(b.best, "rug")
	var lavish := Decor.bonus([{"id": "rug", "dist": 0}, {"id": "floor_marble", "dist": 0},
		{"id": "paper_rose", "dist": 1}, {"id": "plant", "tier": 3, "dist": 1}])
	assert_eq(lavish.joy, Decor.CAP)
	assert_eq(Decor.thought(lavish.best), "What a fine floor")


func test_nobody_sits_on_a_wall_or_a_fern():
	assert_almost_eq(Decor.bonus([{"id": "paper_rose", "dist": 0}]).joy, Catalog.joy_of("paper_rose") * Decor.BESIDE, 0.0001)
	assert_almost_eq(Decor.bonus([{"id": "plant", "dist": 0}]).joy, Catalog.joy_of("plant") * Decor.BESIDE, 0.0001)


func test_a_better_fern_is_seen_from_further_and_gives_more():
	assert_eq(Decor.reach("plant", 1), 3)
	assert_eq(Decor.reach("plant", 3), 5)
	assert_eq(Decor.bonus([{"id": "plant", "tier": 1, "dist": 5}]).joy, 0.0)
	assert_gt(Decor.bonus([{"id": "plant", "tier": 3, "dist": 5}]).joy, 0.0)
	assert_gt(Decor.bonus([{"id": "plant", "tier": 2, "dist": 1}]).joy, Decor.bonus([{"id": "plant", "tier": 1, "dist": 1}]).joy)


func test_a_nicely_dressed_table_is_worth_what_a_fern_once_was():
	# A fern used to add 0.015 joy a second; a guest sits for some 20 seconds.
	var dressed: float = Decor.bonus([{"id": "rug", "dist": 0}, {"id": "floor_parquet", "dist": 0},
		{"id": "plant", "dist": 1}]).joy
	assert_between(dressed, 0.25, Decor.CAP)
	assert_lt(Decor.bonus([{"id": "plant", "dist": 3}, {"id": "paint", "dist": 3}]).joy, 0.1, "what is only seen adds a little")


func test_comfort_rises_with_joy_and_patience_and_falls_with_disgust():
	var m := GuestMood.new()
	m.joy = 0.0
	m.patience = 0.0
	assert_eq(m.comfort(), 0.0)
	m.joy = 1.0
	m.patience = 1.0
	assert_eq(m.comfort(), 1.0)
	m.joy = 0.5
	var base := m.comfort()
	m.joy = 0.6
	assert_gt(m.comfort(), base)
	m.patience = 0.5
	assert_lt(m.comfort(), base + 0.1)
	var before := m.comfort()
	m.disgust = 0.5
	assert_lt(m.comfort(), before)
	m.disgust = 1.0
	assert_eq(m.comfort(), 0.0, "never below 0")
	m.savour = 1.0
	assert_eq(m.comfort(), 0.0, "the dish does not count")


func test_bill_and_stay_scales_hit_their_ends_and_only_rise():
	assert_almost_eq(GuestMood.bill_scale(0.0), GuestMood.BILL_LOW, 0.0001)
	assert_almost_eq(GuestMood.bill_scale(1.0), GuestMood.BILL_HIGH, 0.0001)
	assert_almost_eq(GuestMood.stay_scale(0.0), GuestMood.STAY_LOW, 0.0001)
	assert_almost_eq(GuestMood.stay_scale(1.0), GuestMood.STAY_HIGH, 0.0001)
	for i in 10:
		assert_lt(GuestMood.bill_scale(i / 10.0), GuestMood.bill_scale((i + 1) / 10.0))
		assert_lt(GuestMood.stay_scale(i / 10.0), GuestMood.stay_scale((i + 1) / 10.0))


func test_comfort_is_fixed_when_the_food_arrives():
	var m := GuestMood.new()
	m.joy = 1.0
	m.patience = 1.0
	assert_eq(m.settle_comfort(), GuestMood.COSY_THOUGHTS[0])
	m.joy = 0.0
	m.patience = 0.0
	assert_eq(m.served_comfort, 1.0, "the bill and the stay agree")
	assert_eq(m.scaled_price(12), 15)
	assert_eq(m.settle_comfort(4), GuestMood.HURRIED_THOUGHTS[1])
	assert_eq(m.scaled_price(12), 11)
	assert_eq(m.scaled_price(1), 1, "never below 1")
	m.joy = 0.5
	m.patience = 0.5
	assert_eq(m.settle_comfort(), "", "nothing to say in the middle")


func test_deals_apply_after_the_mood_scale():
	var m := GuestMood.new()
	m.joy = 1.0
	m.patience = 1.0
	m.settle_comfort()
	assert_eq(m.pay_for(12), 15)
	assert_true(m.paid_full())
	m.discounted = true
	assert_eq(m.pay_for(12), 8, "half of 15, in the house's favour")
	assert_false(m.paid_full())
	m.comped = true
	assert_eq(m.pay_for(12), 0)
	assert_eq(m.tip_for(m.pay_for(12)), 0, "the tip is on the final bill")


func test_a_guest_who_expects_a_deal_is_let_down_even_when_the_bill_moved():
	var t := Town.new()
	t.people[0].deals = Town.EXPECT_AT
	var m := GuestMood.new()
	m.joy = 0.0
	m.patience = 0.2
	m.settle_comfort()
	assert_ne(m.pay_for(12), 12, "the scaled bill is not the base price")
	assert_true(m.paid_full(), "but it is still full price")
	assert_gt(t.paid_full_price(0) if m.paid_full() else 0.0, 0.0)


# ---------- Cleaning (night cleaning, PRD 5) ----------

func test_cleaning_knows_what_is_still_dirty():
	assert_true(Cleaning.needs_cleaning("table", 1, 0))
	assert_false(Cleaning.needs_cleaning("table", 0, 0))
	assert_true(Cleaning.needs_cleaning("sink", 1, 0), "one plate soaking still needs washing")
	assert_true(Cleaning.needs_cleaning("bin", 0, 1))
	assert_false(Cleaning.needs_cleaning("bin", 0, 0))
	assert_false(Cleaning.needs_cleaning("stove", 3, 3), "only tables, sinks and bins get dirty")


func test_cleaning_names_the_night_actions_and_nothing_else():
	assert_eq(Cleaning.night_action("Clear tray"), "Clear table")
	assert_eq(Cleaning.night_action("Wash"), "Wash up")
	assert_eq(Cleaning.night_action("Empty bin"), "Take the bag out")
	assert_eq(Cleaning.night_action("Put in sink"), "Put in sink")
	assert_eq(Cleaning.night_action("Take meat"), "", "no cooking at night")
	assert_eq(Cleaning.night_action("Scrape off"), "")


func test_cleaning_carried_mess_is_a_plate_or_the_bag():
	assert_true(Cleaning.carrying_mess("dirty_tray"))
	assert_true(Cleaning.carrying_mess("rubbish_bag"))
	assert_false(Cleaning.carrying_mess(""))
	assert_false(Cleaning.carrying_mess("plate"))


func test_mess_ages_in_service_only():
	assert_eq(Cleaning.aged(2.0, 1.0, true, true), 3.0)
	assert_eq(Cleaning.aged(2.0, 1.0, true, false), 2.0 if not Cleaning.AGES_AT_NIGHT else 3.0)
	assert_eq(Cleaning.aged(2.0, 1.0, false, true), 0.0, "clean is back to zero")
	assert_eq(Cleaning.aged(2.0, 1.0, false, false), 0.0)


func test_dirty_note_lists_what_is_left():
	assert_eq(Cleaning.dirty_note(2, 1, 1), "Still dirty: 2 tables, the sink, the bin.")
	assert_eq(Cleaning.dirty_note(1, 0, 1), "Still dirty: a table, the bin.")
	assert_eq(Cleaning.dirty_note(0, 1, 0), "Still dirty: the sink.")
	assert_eq(Cleaning.dirty_note(0, 2, 2), "Still dirty: 2 sinks, 2 bins.", "a second sink and bin each count")
	assert_eq(Cleaning.dirty_note(0, 0, 0), "")


# ---------- Pantry and Menu (PRD 1) ----------

func _stations(ids: Array, ready := [], off := []) -> Array:
	var out := []
	for id: String in ids:
		out.append({"ingredient": id, "ready": ready.has(id), "stocked": not off.has(id)})
	return out


func test_every_ingredient_has_its_fields():
	for id: String in Pantry.ITEMS:
		var it: Dictionary = Pantry.ITEMS[id]
		for key in ["name", "theme", "tool", "tags", "worth", "fee", "colour", "prepped", "shape"]:
			assert_true(it.has(key), "%s has %s" % [id, key])
		assert_true(Pantry.TOOLS.has(it.tool), "%s's tool is one of the seven" % id)
		assert_true(Pantry.THEMES.has(it.theme))
		assert_eq(Pantry.is_drink(id), it.tool == "pour", "only drinks are poured")
	assert_eq(Pantry.TOOLS.size(), 7)


## The seaside list from the PRD: tool, tags, worth and fee as in the table.
func test_seaside_ingredients_are_complete():
	var table := {
		"roll": ["none", ["bread"], 2, 3], "fish": ["grill", ["fish"], 7, 9],
		"calamari": ["fry", ["fish", "fried"], 5, 6], "lemon": ["slice", ["fruit"], 1, 2],
		"courgette": ["chop", ["vegetable"], 2, 2], "pepper": ["chop", ["vegetable"], 2, 2],
		"new_potato": ["boil", ["vegetable"], 3, 3], "beans": ["boil", ["vegetable"], 2, 2],
		"wine": ["pour", ["drink"], 5, 5],
	}
	assert_eq(Pantry.for_theme("seaside").size(), table.size())
	for id: String in table:
		var row: Array = table[id]
		var it: Dictionary = Pantry.ITEMS[id]
		assert_eq(it.theme, "seaside")
		assert_eq(it.tool, row[0], "%s's tool" % id)
		assert_eq(it.tags, row[1], "%s's tags" % id)
		assert_eq(it.worth, row[2], "%s's worth" % id)
		assert_eq(it.fee, row[3], "%s's fee" % id)
		assert_true(Pantry.TOOLS.has(it.tool), "%s's tool is one of the seven" % id)
		if Pantry.needs_prep(id):
			var tool_station: String = Pantry.TOOL_STATION[it.tool]
			assert_true(Catalog.ITEMS.has(tool_station), "%s's tool is sold" % id)
			assert_eq(Catalog.tool_of(tool_station), it.tool)
			assert_false(Catalog.ITEMS[tool_station].has("theme"), "tools are sold to both themes")
		var crate := Pantry.station_id(id)
		assert_true(Catalog.ITEMS.has(crate), "%s has a station" % id)
		assert_eq(Catalog.ITEMS[crate].theme, "seaside")
		assert_eq(Catalog.ingredient_of(crate), id)
		assert_eq(Catalog.ITEMS.has(Pantry.station_id(id, true)), Pantry.can_be_ready(id),
			"%s is sold ready-made only if it is on the list" % id)
	assert_eq(Catalog.tool_of("crate_wine"), "pour", "wine is poured at its own barrel")
	for id in ["courgette", "pepper"]:
		assert_eq(Catalog.ITEMS[Pantry.station_id(id, true)].theme, "seaside")
	assert_false(Pantry.can_be_ready("lemon"), "only the chopped ones and cheese come ready-made")


func test_every_theme_has_all_three_courses():
	for theme in Pantry.THEMES:
		var ings := Pantry.for_theme(theme)
		assert_true(ings.any(func(i: String) -> bool: return Pantry.is_drink(i)), "%s has a drink" % theme)
		assert_gt(ings.filter(func(i: String) -> bool: return not Pantry.is_drink(i)).size(), 3)


func test_price_is_worth_times_level():
	var burger := {"ingredients": ["bun", "patty", "cheese"], "price_level": "fair"}
	assert_almost_eq(float(Menu.price_of(burger)), 12.0, 2.0, "a plain cheeseburger is about the old 12")
	assert_eq(Menu.price_of(burger), 10)
	burger.price_level = "cheap"
	assert_eq(Menu.price_of(burger), 8)
	burger.price_level = "dear"
	assert_eq(Menu.price_of(burger), 13, "12.5 rounds up")
	assert_eq(Menu.price_of({"ingredients": ["lettuce"], "price_level": "cheap"}), 1, "never below 1")


func test_night_cost_sums_stocked_fees():
	assert_eq(Menu.night_cost(_stations(["bun", "patty"])), 11)
	assert_eq(Menu.night_cost(_stations(["bun", "patty"], [], ["patty"])), 3, "an unstocked station costs nothing")
	assert_eq(Menu.night_cost(_stations(["cheese"], ["cheese"])), 5, "ready-made at 1.5 times, rounded")
	assert_eq(Menu.night_cost([]), 0)


func test_item_off_menu_without_stock_or_tool():
	var item := {"ingredients": ["bun", "patty"], "off": false}
	assert_eq(Menu.off_reason(item, _stations(["bun", "patty"]), ["grill"]), "")
	assert_eq(Menu.off_reason(item, _stations(["bun", "patty"]), []), "No grill")
	assert_eq(Menu.off_reason(item, _stations(["bun"]), ["grill"]), "No patty")
	assert_eq(Menu.off_reason(item, _stations(["bun", "patty"], [], ["patty"]), ["grill"]), "Patty not stocked")
	var salad := {"ingredients": ["lettuce"], "off": false}
	assert_eq(Menu.off_reason(salad, _stations(["lettuce"]), []), "No chopping board")
	assert_eq(Menu.off_reason(salad, _stations(["lettuce"], ["lettuce"]), []), "", "ready-made needs no tool")
	item.off = true
	assert_eq(Menu.off_reason(item, _stations(["bun", "patty"]), ["grill"]), "Off tonight")


func test_course_rules():
	assert_ne(Menu.refusal("drink", ["soda", "lettuce"]), "", "a drink with a non-drink is refused")
	assert_ne(Menu.refusal("main", ["soda"]), "", "a drink is not a main")
	assert_eq(Menu.refusal("main", ["cheese"]), "", "a one-ingredient main is fine")
	assert_eq(Menu.refusal("main", ["bun", "patty", "patty", "cheese", "onion", "bun"]), "")
	assert_ne(Menu.refusal("main", ["bun", "patty", "patty", "cheese", "onion", "tomato", "bun"]), "", "more than 6 is refused")
	var m := Menu.new()
	assert_true(m.add("drink", ["soda", "bun"]).is_empty())
	assert_false(m.add("main", ["bun", "patty", "patty"]).is_empty(), "the same ingredient twice is a double")


func test_new_item_gets_a_default_name():
	var m := Menu.new()
	assert_eq(m.add("main", ["bun", "patty", "cheese"]).name, "Cheese Patty Bun")
	assert_eq(m.add("side", ["potato"]).name, "Fries")
	var it := m.add("main", ["patty"], "   ")
	assert_eq(it.name, "Patty")
	m.rename(it.id, "A very long name for a burger indeed")
	assert_eq(m.find(it.id).name.length(), Menu.MAX_NAME)


func test_tastes_obey_the_limits():
	for s in [1, 2, 7, 42, 1234]:
		for theme in Pantry.THEMES:
			var t := Town.new(s)
			t.make_tastes(theme)
			var ings := Pantry.for_theme(theme)
			var haters := {}
			for p in t.people:
				assert_lte((p.dislikes as Array).size(), floori(ings.size() / 3.0), "nobody dislikes over a third")
				var staple := false
				for ing: String in p.likes:
					assert_false((p.dislikes as Array).has(ing), "never likes and dislikes one thing")
					staple = staple or Pantry.tool_of(ing) == "grill" or Pantry.tags_of(ing).has("vegetable")
				assert_true(staple, "%s likes a grill ingredient or vegetable" % p.name)
				for ing: String in p.dislikes:
					haters[ing] = int(haters.get(ing, 0)) + 1
			for ing in haters:
				assert_lte(int(haters[ing]), floori(t.people.size() / 5.0), "%s disliked by at most a fifth" % ing)


func test_tastes_are_the_same_for_a_seed():
	var a := Town.new(9)
	var b := Town.new(9)
	for i in a.people.size():
		assert_eq(a.people[i].likes, b.people[i].likes)
		assert_eq(a.people[i].dislikes, b.people[i].dislikes)
	var c := Town.new(10)
	var same := true
	for i in a.people.size():
		same = same and a.people[i].likes == c.people[i].likes
	assert_false(same, "a different seed, different tastes")


func test_tastes_leave_visits_alone():
	var a := Town.new(3)
	a.make_tastes("seaside")
	var b := Town.new(3)
	assert_eq(a.roll_guests(1), b.roll_guests(1), "taste rolls do not use the town's own generator")


func _menu_items() -> Array:
	var m := Menu.new()
	m.add("main", ["bun", "patty"])
	m.add("main", ["lettuce", "tomato"])
	m.add("side", ["potato"])
	m.add("side", ["corn"])
	m.add("drink", ["soda"])
	return m.items


func test_order_never_has_a_disliked_ingredient():
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var items := _menu_items()
	for k in 200:
		var o := Menu.order(items, [], ["patty"], rng)
		assert_eq(o.main.ingredients, ["lettuce", "tomato"])
	assert_true(Menu.order(items, [], ["patty", "lettuce"], rng).main.is_empty(), "no acceptable main")


func test_side_and_drink_need_a_liked_ingredient():
	var rng := RandomNumberGenerator.new()
	var items := _menu_items()
	for k in 50:
		var o := Menu.order(items, [], [], rng)
		assert_true(o.side.is_empty() and o.drink.is_empty(), "neutral sides and drinks are not added")
	for k in 50:
		var o := Menu.order(items, ["potato", "soda"], [], rng)
		assert_eq(o.side.ingredients, ["potato"])
		assert_eq(o.drink.ingredients, ["soda"])


func test_cheap_is_ordered_more_than_dear():
	var m := Menu.new()
	var cheap := m.add("main", ["bun", "patty"], "Cheap", "cheap")
	m.add("main", ["bun", "patty"], "Dear", "dear")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := 0
	for k in 1000:
		if Menu.order(m.items, [], [], rng).main.id == cheap.id:
			n += 1
	assert_gt(n, 600, "1.5 against 0.6 is about 71%")


func test_group_walks_on_only_when_nobody_has_a_main():
	var rng := RandomNumberGenerator.new()
	var items := _menu_items()
	var picky := {"likes": [], "dislikes": ["patty", "lettuce"]}
	var easy := {"likes": [], "dislikes": []}
	var g := Menu.group_order(items, [picky, easy], rng)
	assert_false(g.walk, "the group stays")
	assert_eq(g.found_nothing, [0])
	assert_eq(g.orders[0].drink.ingredients, ["soda"], "the picky one just has a drink, even a neutral one")
	assert_true(g.orders[0].main.is_empty())
	var alone := Menu.group_order(items, [picky], rng)
	assert_true(alone.walk, "on their own they walk on")
	var no_soda := {"likes": [], "dislikes": ["patty", "lettuce", "soda"]}
	var g2 := Menu.group_order(items, [no_soda, easy], rng)
	assert_false(g2.walk)
	assert_true(g2.orders[0].drink.is_empty(), "sits with nothing")
	assert_true(Menu.group_order(items, [picky, picky], rng).walk)


func test_savour_is_average_plus_capped_liked_bonus():
	assert_almost_eq(Menu.savour([1.0, 0.5], ["bun", "patty"], []), 0.75, 0.001)
	assert_almost_eq(Menu.savour([0.75], ["patty"], ["patty"]), 0.85, 0.001)
	assert_almost_eq(Menu.savour([0.5, 0.5, 0.5, 0.5], ["bun", "patty", "cheese", "onion"],
		["bun", "patty", "cheese", "onion"]), 0.8, 0.001, "liked bonus caps at +0.3")


func test_order_counts_survive_a_rename():
	var t := Town.new(1)
	var m := Menu.new()
	var a := m.add("main", ["bun", "patty"], "Burger")
	var b := m.add("side", ["potato"], "Fries")
	t.record_order(0, a.id)
	t.record_order(0, b.id)
	t.record_order(0, a.id)
	m.rename(a.id, "Stupid Burger")
	assert_eq(t.order_summary(0, m), "Stupid Burger x2, Fries x1")
	m.remove(b.id)
	assert_eq(t.order_summary(0, m), "Stupid Burger x2, Fries x1", "a deleted item keeps its last name")


func test_taste_hints_never_name_an_ingredient():
	assert_eq(Menu.hint_thought("vegetable"), "So many things with vegetables. I love vegetables!")
	assert_eq(Town.praise_about(true, "vegetable"), "it was just how they like it")
	assert_eq(Town.praise_about(false, "vegetable"), "about all the things with vegetables")
	assert_eq(Town.praise_about(false, ""), "")
	var t := Town.new(1)
	var line := t.gossip_line(0, 0.2, Town.praise_about(true, ""))
	assert_true(line.ends_with("it was just how they like it."), line)
	assert_true(t.gossip_line(0, t.record_found_nothing(0), "x") != "", "walking on is news")


func test_finding_nothing_costs_a_little_and_friends_hear():
	var t := Town.new(1)
	var f: int = t.people[0].friends[0]
	t.record_found_nothing(0)
	assert_almost_eq(float(t.people[0].affinity), -Town.NOTHING_LIKED_DROP, 0.001)
	assert_lt(float(t.people[f].affinity), 0.0)
	assert_eq(t.people[0].grudges, 0, "not a walkout")


func test_stock_is_paid_only_when_affordable():
	var l := Ledger.new()
	l.money = 20
	assert_false(l.pay_stock(25))
	assert_eq(l.money, 20)
	assert_true(l.pay_stock(15))
	assert_eq(l.today.stock, 15)
	assert_eq(l.strikes(), 0)


func test_tag_hint_needs_three_items():
	var items := _menu_items()
	assert_eq(Menu.tag_hint(items, ["vegetable"]), "vegetable", "salad, fries and corn")
	assert_eq(Menu.tag_hint(items, ["meat"]), "")


# ---------- Prep minigames (PRD 1) ----------

func test_chop_scores_hits_in_the_notch():
	assert_eq(Prep.chop(3), "good")
	assert_eq(Prep.chop(2), "plain")
	assert_eq(Prep.chop(1), "bad")
	assert_eq(Prep.chop(0), "bad")
	assert_true(Prep.chop_hit(0.5))
	assert_true(Prep.chop_hit(0.5 + Prep.CHOP_NOTCH))
	assert_false(Prep.chop_hit(0.5 + Prep.CHOP_NOTCH + 0.01))


func test_slice_scores_the_count():
	var n := Prep.SLICE_COUNT
	assert_eq(Prep.slice(n), "good", "exact")
	assert_eq(Prep.slice(n + 1), "plain")
	assert_eq(Prep.slice(n + 3), "plain")
	assert_eq(Prep.slice(n + 4), "bad")
	assert_eq(Prep.slice(n - 1), "bad", "out of time short of the count")


func test_pour_scores_the_fill():
	assert_eq(Prep.pour(0.84), "plain")
	assert_eq(Prep.pour(0.85), "good")
	assert_eq(Prep.pour(1.0), "good")
	assert_eq(Prep.pour(1.01), "bad", "overflowed")
	assert_eq(Prep.pour(0.59), "bad")
	assert_eq(Prep.pour(0.6), "plain")


func test_fry_and_grill_windows():
	assert_eq(Prep.fry(Prep.FRY_MIN - 0.1).state, "raw")
	assert_eq(Prep.fry(Prep.FRY_GOOD - 0.1).result, "plain", "early")
	assert_eq(Prep.fry(Prep.FRY_GOOD).result, "good")
	assert_eq(Prep.fry(Prep.FRY_LATE).result, "good")
	assert_eq(Prep.fry(Prep.FRY_LATE + 0.1).result, "plain", "late")
	assert_eq(Prep.fry(Prep.FRY_BURN).result, "spoiled")
	assert_eq(Prep.grill(Prep.GRILL_DONE - 0.1).result, "plain", "underdone")
	assert_eq(Prep.grill(Prep.GRILL_DONE).result, "good")
	assert_eq(Prep.grill(Prep.GRILL_PERFECT + 0.1).result, "plain", "drying out")
	assert_eq(Prep.grill(Prep.GRILL_BURN).result, "spoiled")
	assert_lt(float(Prep.grill(Prep.GRILL_BURN - 0.1).quality), 0.5, "the curve falls toward bad")


func test_boil_is_always_plain_and_never_rewards():
	assert_eq(Prep.boil(Prep.BOIL_TIME - 0.1).state, "raw")
	assert_eq(Prep.boil(Prep.BOIL_TIME).result, "plain")
	assert_eq(Prep.boil(999.0).result, "plain", "it cannot overcook")
	assert_eq(Prep.reward("boil", "good"), "")
	assert_eq(Prep.reward("chop", "good"), "burst")
	assert_eq(Prep.reward("pour", "bad"), "penalty")
	assert_eq(Prep.reward("grill", "spoiled"), "penalty")
	assert_eq(Prep.reward("slice", "plain"), "")


func test_results_set_quality():
	assert_eq(Prep.quality_of("good"), Prep.GOOD)
	assert_eq(Prep.quality_of("plain"), Prep.PLAIN)
	assert_eq(Prep.quality_of("bad"), Prep.BAD)
	var t := Tray.new()
	var m := Menu.new()
	t.assign(1, [m.add("main", ["bun", "patty"])])
	t.add("prep:bun", Prep.PLAIN)
	t.add("prep:patty", Prep.GOOD)
	assert_almost_eq(t.quality(), (Prep.PLAIN + Prep.GOOD) / 2.0, 0.001, "a tray's quality is the average")


# ---------------------------------------------------------------- PRD 7: catalog and themes

const PRD7_PIECES := ["floor_lamp", "flower_stand", "coat_stand", "jukebox", "gumball", "aquarium",
	"palm", "lantern", "stool", "bin", "dish_rack", "sink"]


func test_a_themed_search_lists_untagged_pieces_and_that_themes_own():
	for theme: String in ["diner", "seaside"]:
		var other := "seaside" if theme == "diner" else "diner"
		var ids := {}
		for bp in Catalog.search("", "", theme):
			ids[bp.id] = true
			assert_ne(str(Catalog.ITEMS[bp.id].get("theme", theme)), other, "%s is not sold in the %s" % [bp.id, theme])
		for id: String in Catalog.ITEMS:
			if not Catalog.ITEMS[id].has("theme"):
				assert_true(ids.has(id), "%s is sold everywhere" % id)
	assert_true(Catalog.sold_in("jukebox", "diner"))
	assert_false(Catalog.sold_in("jukebox", "seaside"))
	assert_true(Catalog.sold_in("aquarium", "seaside"))
	assert_false(Catalog.sold_in("plant", "seaside"), "the fern is the diner's; the seaside has the palm")
	assert_true(Catalog.sold_in("floor_lamp", "seaside"))
	assert_true(Catalog.sold_in("floor_lamp", ""), "no theme: everything")


func test_decor_reach_comes_from_the_entry_and_the_fern_is_unchanged():
	assert_eq(Decor.reach("plant", 1), 3)
	assert_eq(Decor.reach("plant", 2), 4)
	assert_eq(Decor.reach("plant", 3), 5)
	assert_eq(Decor.reach("palm", 2), Decor.reach("plant", 2), "the palm is the seaside's fern")
	assert_eq(Decor.reach("flower_stand"), 1)
	assert_eq(Decor.reach("gumball"), 2)
	assert_eq(Decor.reach("jukebox", 1), 4)
	assert_eq(Decor.reach("aquarium", 3), 6)
	assert_eq(Decor.reach("rug"), Decor.VIEW_RANGE, "floors, rugs and finishes keep the view range")
	assert_eq(Decor.share("flower_stand", 2), 0.0, "a short reach: beside only")
	assert_eq(Decor.share("jukebox", 4), Decor.IN_VIEW)
	assert_eq(Decor.share("lantern", 0), Decor.BESIDE, "nobody sits on a decor piece")


func test_every_new_piece_has_its_entry_and_every_decor_piece_a_thought():
	for id: String in PRD7_PIECES:
		var e: Dictionary = Catalog.ITEMS[id]
		for key in ["name", "price", "level", "category", "blurb", "tiers"]:
			assert_true(e.has(key), "%s has a %s" % [id, key])
		if int(e.tiers) > 1:
			assert_true(e.has("up"), "%s says what a tier does" % id)
	for id: String in Catalog.ITEMS:
		if Catalog.is_decor_piece(id):
			assert_ne(Decor.thought(id), "", "%s has a thought line" % id)
			assert_gt(Catalog.joy_of(id), 0.0)
