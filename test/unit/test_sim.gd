extends "res://test/helpers/sim_case.gd"


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
	assert_eq(t.gossip_line(2, -0.2), "", "a small dip is not news")
	assert_string_contains(t.gossip_line(2, -0.2, "", true), "will warn")
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
	assert_gte(guests.size(), Town.crowd_floor(2))
	var seen := {}
	for g in guests:
		assert_false(seen.has(g))
		seen[g] = true



func test_flyers_bring_exactly_a_couple_of_extra_guests():
	for seed_value in range(1, 21):
		var plain := Town.new(seed_value).roll_guests(3).size()
		var flyered := Town.new(seed_value).roll_guests(3, 0.0, Town.FLYER_GUESTS).size()
		assert_eq(flyered, plain + Town.FLYER_GUESTS, "seed %d" % seed_value)


func test_flyers_skip_grudges_and_the_gone_and_never_fail():
	var t := Town.new(7)
	t.record_walkout(4, 3)
	t.people[0].gone = true
	for n in 20:
		var coming := t.roll_guests(4, 0.0, 1000)
		assert_false(coming.has(4), "holding a grudge")
		assert_false(coming.has(0), "gone for good")
		assert_eq(coming.size(), t.people.size() - 2, "everyone free comes, no more")



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



func test_the_restaurant_closes_when_reputation_bottoms_out():
	var l := Ledger.new()
	for i in 3:
		l.record_walkout()
	assert_false(l.is_closed_down(), "three walkouts no longer end the run on their own")
	l.reputation = Ledger.REP_WALKOUT
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
	assert_eq(Catalog.level_of("chair", 3), 3)
	assert_true(c.can_buy("plant", 40, 2, 2))
	assert_false(c.can_buy("plant", 40, 1, 2), "tier 2 needs level 2")
	assert_false(c.can_buy("plant", 39, 2, 2))
	assert_false(c.can_buy("counter", 999, 9, 2), "counters have one tier")
	assert_false(c.can_buy("stove", 9999, 9, 4))



func test_catalog_search_by_word_and_category():
	assert_eq(Catalog.search().size(), _roots(Catalog.search()).size(), "only roots: a step up a tree is bought on the piece, lifted")
	assert_eq(_roots(Catalog.search()).size(), 68, "one entry a piece, the cup and tray stacks and the till; no stove or fridge, which grow from a counter: higher tiers and later tree nodes are bought in upgrade trees (PRD 8.3); seven boxes of PRD 8.6; two cleaning pieces (PRD 9.4; the robot is in the wringer bucket's tree, 9.5); the floor cleaner's box (9.5); the desk (PRD 10.6); the window")
	var ferns := _roots(Catalog.search("FERN"))
	assert_eq(ferns.size(), 1)
	assert_eq(int(ferns[0].tier), 1, "cheapest first")
	var kitchen := _roots(Catalog.search("", "Kitchen", "diner"))
	assert_eq(kitchen.size(), 14, "the counter, a shelf, a wall cabinet, a hood, a bin, a dish rack, a sink, the cup and tray stacks, a till, board, the soda fountain, a sponge and the desk (PRD 10.6); the fridge and stove are counter upgrades, the mop bucket the sponge's")
	assert_eq(kitchen.map(func(bp: Dictionary) -> String: return Catalog.label(bp)).slice(0, 3),
		["Wall shelf", "Counter", "Wall cabinet"],
		"storage first, cheapest first within it")
	assert_eq(str(kitchen[-1].id), "desk", "the desk comes last")
	assert_eq(Catalog.group_of(kitchen[3]), 1, "then the cooking tools")
	assert_eq(Catalog.search("", "Kitchen", "diner", 1).filter(func(bp: Dictionary) -> bool:
		return Catalog.bp_level(bp) > 1).size(), 0, "a level hides what needs a higher one")
	var pantry := Catalog.search("", "Pantry", "diner")
	assert_eq(pantry.size(), 15, "a box per boxed diner food kind and four ready-made (PRD 8.4, 8.6); the floor cleaner is parked")
	assert_eq(pantry[0].id, "box_bun", "boxes are free to take: by name")
	assert_eq(Catalog.search("", "Kitchen", "seaside").filter(func(bp: Dictionary) -> bool:
		return Catalog.ITEMS[bp.id].get("theme", "seaside") != "seaside").size(), 0, "only the run's theme")
	assert_eq(Catalog.search("tiles that touch").size(), 1, "matches what a piece does")
	assert_eq(Catalog.search("stove ++").size(), 0, "tiers are steps in the trees now")
	assert_eq(Catalog.search("fern", "Kitchen").size(), 0)
	assert_eq(Catalog.search("partition")[0].id, "screen")
	assert_eq(Catalog.search("", "Build").size(), 12, "four floors, wall, three finishes, door, archway, window and the partition")
	assert_eq(Catalog.search("build", "Dining").size(), 0, "matches the category name")
	# The shop's tabs (owner's review of night zero).
	assert_eq(Catalog.tab_of("counter"), "Furniture")
	assert_eq(Catalog.tab_of("table"), "Furniture")
	assert_eq(Catalog.tab_of("plant"), "Furniture")
	assert_eq(Catalog.tab_of("board"), "Tools")
	assert_eq(Catalog.tab_of("sponge"), "Tools")
	assert_eq(Catalog.tab_of("box_bun"), "Ingredients")
	assert_eq(Catalog.tab_of("box_cleaner"), "Ingredients")
	assert_eq(Catalog.tab_of("wall"), "Build")
	assert_eq(Catalog.search("", "Ingredients", "diner").size(), pantry.size(), "Ingredients is the pantry")
	assert_true(Catalog.search("", "Tools", "diner").all(func(bp: Dictionary) -> bool:
		return Catalog.tab_of(bp.id) == "Tools"), "a tab lists its own")



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



func test_feelings_delight_alone():
	var m := GuestMood.new()
	m.joy = 0.9
	var f := m.feelings()
	assert_eq(f.anger, 0.0)
	assert_eq(f.disgust, 0)
	assert_gt(f.delight, 0.0)


func test_feelings_anger_rises_as_patience_falls():
	var m := GuestMood.new()
	m.joy = 0.9
	m.patience = 0.3
	var flush: float = m.feelings().anger
	m.patience = 0.1
	var f := m.feelings()
	assert_gt(f.anger, flush)
	assert_gt(f.anger, GuestMood.ANGER_FLUSH)
	assert_eq(f.disgust, 0)
	assert_eq(f.delight, 0.0)
	assert_eq(m.feelings(true).anger, 1.0)


func test_feelings_anger_and_disgust_together():
	var m := GuestMood.new()
	m.patience = 0.2
	m.disgust = 0.5
	var f := m.feelings()
	assert_gt(f.anger, 0.0)
	assert_eq(f.disgust, 2)


func test_disgust_holds_still_until_comped():
	var m := GuestMood.new()
	m.disgust = 0.5
	for i in 60:
		m.wait(1.0, 1000.0)
	assert_eq(m.disgust, 0.5)
	assert_eq(m.disgust_level(), 2)
	assert_true(m.offer_comp())
	assert_eq(m.disgust_level(), 1)


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


func test_only_really_bad_visits_reach_friends_and_the_headline():
	var t := Town.new(7)
	var f: int = t.people[2].friends[0]
	t.record_visit(2, 0.0)
	assert_lt(float(t.people[2].affinity), -0.05)
	assert_eq(float(t.people[f].affinity), 0.0, "a poor visit stays with the guest")
	assert_false(t.headline().contains("warning people off"))
	t.record_walkout(2, 1)
	assert_lt(float(t.people[f].affinity), 0.0, "a walkout reaches friends")
	assert_string_contains(t.headline(), "%s is warning people off." % t.people[2].name)
	t.record_visit(2, 1.0)
	assert_false(t.headline().contains("warning people off"), "a good visit clears it")


func test_disgust_and_unpaid_flag_a_guest_but_mild_disgust_does_not():
	var t := Town.new(7)
	t.record_disgust(1, 1)
	assert_false(t.people[1].warning)
	t.record_disgust(1, 2)
	assert_true(t.people[1].warning)
	t.left_unpaid(3)
	assert_true(t.people[3].warning)
