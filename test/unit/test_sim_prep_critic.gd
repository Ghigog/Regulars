extends "res://test/helpers/sim_case.gd"


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



# PRD 8.6: the five new jobs' minigames.

func test_grate_fills_in_the_band_and_scrapes_over_the_top():
	var band := Prep.grate_band()
	assert_eq(band, Vector2(Prep.GRATE_LOW, Prep.GRATE_HIGH))
	assert_gt(Prep.grate_band(1.6).y, band.y, "a better grater has a wider band")
	assert_lt(Prep.grate_band(0.6).y, band.y, "a stand-in a narrower one")
	assert_almost_eq(Prep.grate_speed(0.0, true, 1.0), Prep.GRATE_RISE, 0.001, "holding speeds it up")
	assert_eq(Prep.grate_speed(0.1, false, 1.0), 0.0, "letting go slows it, never below still")
	assert_eq(Prep.grate(1.0, false, false), "", "still going")
	assert_eq(Prep.grate(Prep.GRATE_GOOD, true, false), "good", "filled in time")
	assert_eq(Prep.grate(Prep.GRATE_GOOD + 0.1, true, false), "plain", "filled, slowly")
	assert_eq(Prep.grate(0.5, false, true), "bad", "a scraped knuckle")
	assert_eq(Prep.grate(Prep.GRATE_LIMIT, false, false), "bad", "out of time")



func test_saw_scores_presses_at_the_end_of_each_stroke():
	assert_eq(Prep.saw(4), "good")
	assert_eq(Prep.saw(3), "plain")
	assert_eq(Prep.saw(2), "bad")
	assert_true(Prep.saw_hit(1.0 - Prep.SAW_END))
	assert_false(Prep.saw_hit(1.0 - Prep.SAW_END - 0.01), "mid-stroke")
	assert_true(Prep.saw_hit(1.0 - Prep.SAW_END * 1.5, 1.6), "a specialist's end zone is wider")
	assert_gt(Prep.saw_stroke(1.6), Prep.saw_stroke(), "and its strokes slower")



func test_juice_scores_squeezes_let_go_in_the_band():
	assert_eq(Prep.juice(3), "good")
	assert_eq(Prep.juice(2), "plain")
	assert_eq(Prep.juice(1), "bad")
	assert_true(Prep.juice_hit(Prep.JUICE_GOOD))
	assert_true(Prep.juice_hit(Prep.JUICE_TOP))
	assert_false(Prep.juice_hit(Prep.JUICE_GOOD - 0.01), "too gentle")
	assert_false(Prep.juice_hit(Prep.JUICE_TOP + 0.01), "the pips squirt")
	assert_lt(Prep.juice_good(1.6), Prep.JUICE_GOOD, "a juicer's band is wider than a base tool's")



func test_blend_pulses_smooth_without_spilling():
	assert_eq(Prep.blend(1.0, 3, false), "", "still going")
	assert_eq(Prep.blend(2.0, Prep.BLEND_PULSES, false), "good")
	assert_eq(Prep.blend(Prep.BLEND_GOOD + 0.1, Prep.BLEND_PULSES, false), "plain", "slow")
	assert_eq(Prep.blend(1.0, 2, true), "bad", "the lid flew off")
	assert_eq(Prep.blend(Prep.BLEND_LIMIT, 2, false), "bad", "out of time")
	assert_lt(Prep.blend_kick(1.6), Prep.blend_kick(), "a better blender rocks less")
	assert_eq(Prep.blend_settle(0.1, 1.0), 0.0)



func test_steam_lifts_on_the_green():
	var band := Prep.steam_band()
	assert_eq(Prep.steam(band.x - 0.01), "bad", "still firm")
	assert_eq(Prep.steam(band.x), "good")
	assert_eq(Prep.steam(band.y), "good")
	assert_eq(Prep.steam(band.y + 0.01), "plain", "soft")
	assert_eq(Prep.steam(Prep.STEAM_OVER), "bad", "mushy")
	assert_gt(Prep.steam_band(1.6).y, band.y)
	assert_eq(Prep.reward("steam", "good"), "burst", "steaming is a skill, unlike boiling")



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



func test_a_themed_search_lists_untagged_pieces_and_that_themes_own():
	for theme: String in ["diner", "seaside"]:
		var other := "seaside" if theme == "diner" else "diner"
		var ids := {}
		for bp in Catalog.search("", "", theme):
			ids[bp.id] = true
			assert_ne(str(Catalog.ITEMS[bp.id].get("theme", theme)), other, "%s is not sold in the %s" % [bp.id, theme])
		for id: String in Catalog.ITEMS:
			var node := Kitchen.node_of(id)
			var treat := Treatments.key_of(id)   # PRD 9.5: laying tools and later boxes are not in the catalog's list
			if not Catalog.ITEMS[id].has("theme") and (node == "" or (Kitchen.is_root(node) and not Kitchen.TOP_LINKS.has(node))) \
					and (treat == "" or (Treatments.ON_SALE and Treatments.is_box(id) and Treatments.is_root(treat))) \
					and (Catalog.STAFF_ON_SALE or not Catalog.ITEMS[id].get("staff", false)) \
					and (Catalog.SEAT_PIECES_ON_SALE or not Catalog.ITEMS[id].get("seat", false)) \
					and not Catalog.ITEMS[id].get("tree_only", false):
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



## The same visits, with and without the topic split, end in the same affinities, and
## everyone's five parts add up to their affinity, clamps included.
func test_topic_split_changes_no_affinity():
	var a := Town.new(3)
	var b := Town.new(3)
	var m := GuestMood.new()
	m.patience = 0.8
	m.savour = 0.9
	m.joy = 0.7
	m.disgust = 0.3
	var script := func(t: Town, with_terms: bool) -> void:
		for k in 12:   # enough to hit the top clamp
			t.record_visit(0, m.satisfaction(), m.satisfaction_terms(0.75) if with_terms else {})
		t.record_disgust(0, 2)
		t.record_kindness(2, "comp")
		t.record_walkout(4, 1)
		t.record_visit(4, 0.8, m.satisfaction_terms() if with_terms else {})   # comes back sore and forgives
		t.record_found_nothing(5)
		for k in 8:
			t.record_visit(7, -0.9, {"speed": 0.0, "clean": -0.5, "quality": 0.0, "variety": 0.0} if with_terms else {})
	script.call(a, true)
	script.call(b, false)
	for i in a.people.size():
		assert_eq(float(a.people[i].affinity), float(b.people[i].affinity), "affinity of %d" % i)
		assert_almost_eq(_sum_parts(a, i), float(a.people[i].affinity), 0.00001, "parts add up for %d" % i)
	assert_almost_eq(float(a.people[0].affinity), 0.9, 0.00001, "held at 1, then disgust took 0.1; a friend finding nothing no longer reaches them")
	assert_almost_eq(float(Town.new(3).record_visit(0, 0.9)), 0.3, 0.00001, "a visit moves affinity as it always did")



func test_changes_are_filed_by_topic_and_friends_keep_it():
	var t := Town.new(3)
	var f: int = t.people[0].friends[0]
	t.record_disgust(0, 2)
	assert_almost_eq(t.opinion(0, "clean"), -0.1, 0.0001, "disgust is about cleanliness")
	assert_almost_eq(t.opinion(f, "clean"), -0.08, 0.0001, "and friends hear it as that")
	t.record_found_nothing(1)
	assert_lt(t.opinion(1, "variety"), 0.0, "nothing on the menu is variety")
	t.record_kindness(2, "half")
	assert_almost_eq(t.opinion(2, "other"), Town.KIND_HALF, 0.0001)
	var m := GuestMood.new()
	m.patience = 1.0
	m.savour = 1.0
	t.record_visit(3, m.satisfaction(), m.satisfaction_terms(0.8))
	assert_gt(t.opinion(3, "speed"), 0.0)
	assert_gt(t.opinion(3, "quality"), 0.0)
	assert_gt(t.opinion(3, "variety"), 0.0, "liked things on the menu count as variety")
	for k in 20:
		t.record_visit(3, m.satisfaction(), m.satisfaction_terms(0.8))
	assert_almost_eq(t.opinion(3, "quality"), Town.TOPIC_MAX, 0.0001, "a topic holds only so much")



func test_critic_is_fixed_by_seed_and_comes_every_fifth_day():
	assert_eq(Critic.new(42).critic_idx, Critic.new(42).critic_idx)
	var seen := {}
	for s in 30:
		seen[Critic.new(s).critic_idx] = true
	assert_gt(seen.size(), 3, "different runs, different critics")
	var c := Critic.new(42)
	assert_true(c.visits_on(5))
	assert_false(c.visits_on(4))
	assert_false(c.visits_on(6))
	var t := Town.new(42)
	c.publish({"speed": 3, "clean": 3, "quality": 3, "variety": 3}, false, t, 5)
	assert_true(c.visits_on(10))
	assert_false(c.visits_on(6))
	for k in 20:
		var at := c.arrival_time(100.0)
		assert_true(at >= 25.0 and at <= 75.0, "the middle half of the day")



func test_closing_early_puts_the_critic_off_a_day():
	var c := Critic.new(1)
	c.postpone(5)
	assert_false(c.visits_on(5))
	assert_true(c.visits_on(6))
	c.publish({"speed": 3, "clean": 3, "quality": 3, "variety": 3}, false, Town.new(1), 6)
	assert_true(c.visits_on(10), "and the next visit is back on the fives")



func test_critic_ratings_at_their_thresholds():
	assert_eq(Critic.speed_rating(0.85), 5)
	assert_eq(Critic.speed_rating(0.84), 4)
	assert_eq(Critic.speed_rating(0.7), 4)
	assert_eq(Critic.speed_rating(0.5), 3)
	assert_eq(Critic.speed_rating(0.3), 2)
	assert_eq(Critic.speed_rating(0.29), 1)
	assert_eq(Critic.clean_rating(0.0, 0), 5, "noticed nothing")
	assert_eq(Critic.clean_rating(0.1, 0), 4, "below Ick")
	assert_eq(Critic.clean_rating(0.3, 1), 3)
	assert_eq(Critic.clean_rating(0.5, 2), 2)
	assert_eq(Critic.clean_rating(0.8, 3), 1)
	assert_eq(Critic.quality_rating(1.0), 5)
	assert_eq(Critic.quality_rating(Prep.PLAIN), 4)
	assert_eq(Critic.quality_rating(0.0), 1)
	assert_eq(Critic.quality_rating(0.5), 3)
	var one := [{"course": "main", "ingredients": ["patty", "bun"]}]
	assert_eq(Critic.variety_rating([]), 1, "at least 1")
	assert_eq(Critic.variety_rating(one), 1)
	var wide := [
		{"course": "main", "ingredients": ["a", "b"]}, {"course": "main", "ingredients": ["c", "d"]},
		{"course": "main", "ingredients": ["e", "f"]}, {"course": "side", "ingredients": ["g"]},
		{"course": "drink", "ingredients": ["h"]}]
	assert_eq(Critic.variety_rating(wide), 5, "three courses, a wide one, eight ingredients")
	wide.pop_back()
	assert_eq(Critic.variety_rating(wide), 3, "two courses and a wide one; seven ingredients")



func test_stars_are_the_rounded_mean_and_a_walkout_caps_them():
	assert_eq(Critic.stars({"speed": 5, "clean": 4, "quality": 5, "variety": 4}), 5, "4.6 (food twice) rounds up")
	assert_eq(Critic.stars({"speed": 5, "clean": 5, "quality": 4, "variety": 4}), 4, "4.4: the food counts twice")
	assert_eq(Critic.stars({"speed": 4, "clean": 4, "quality": 3, "variety": 4}), 4)
	assert_eq(Critic.stars({"speed": 1, "clean": 2, "quality": 1, "variety": 1}), 1)
	assert_eq(Critic.stars({"speed": 5, "clean": 5, "quality": 5, "variety": 5}, true), 2)
	var r := Critic.rate(0.9, -1.0, 0.0, 0, [], true)
	assert_eq(int(r.speed), 1, "a walkout rates speed 1")
	assert_eq(int(r.clean), 5, "the rest from what they saw")



func test_a_review_blends_into_the_four_topics_only():
	var t := Town.new(5)
	t.record_disgust(3, 2)
	t.record_kindness(3, "comp")
	var other := t.opinion(3, "other")
	assert_lt(t.opinion(3, "clean"), 0.0)
	var c := Critic.new(5)
	var clean_before := t.opinion(3, "clean")
	var speed_before := t.opinion(3, "speed")
	var review := c.publish({"speed": 2, "clean": 5, "quality": 4, "variety": 3}, false, t, 5)
	assert_almost_eq(t.opinion(3, "clean"), lerpf(clean_before, Critic.opinion_for(5), Critic.BLEND), 0.0001,
		"the critic found it clean: the town moves 30% their way")
	assert_almost_eq(t.opinion(3, "speed"), lerpf(speed_before, Critic.opinion_for(2), Critic.BLEND), 0.0001)
	assert_almost_eq(t.opinion(3, "other"), other, 0.0001, "other is untouched")
	assert_almost_eq(float(t.people[3].affinity), _sum_parts(t, 3), 0.0001)
	assert_eq(int(review.stars), 4)
	assert_true(review.first, "the first review names them")
	assert_eq(review.name, t.people[c.critic_idx].name)
	assert_true(c.known)



func test_the_review_line_confirms_or_contradicts():
	var t := Town.new(5)
	for i in t.people.size():
		t.record_disgust(i, 2)   # everyone thinks it is dirty
	var line := Critic.verdict_line({"speed": 3, "clean": 5, "quality": 3, "variety": 3},
		{"clean": t.topic_average("clean")})
	assert_eq(line, "Whatever you have heard about the washing-up, we found it spotless.")
	var agree := Critic.verdict_line({"speed": 1, "clean": 3, "quality": 3, "variety": 3}, {"speed": -0.2})
	assert_eq(agree, "As the town already says, you will wait for your supper.")



func test_review_boost_lasts_four_days_and_stacks_with_flyers():
	var c := Critic.new(1)
	assert_eq(c.visit_boost(6), 0.0)
	c.publish({"speed": 5, "clean": 5, "quality": 5, "variety": 5}, false, Town.new(1), 5)
	assert_eq(c.visit_boost(5), 0.0, "not on the day itself")
	for d in [6, 7, 8, 9]:
		assert_eq(c.visit_boost(d), Critic.BOOST[5])
	assert_eq(c.visit_boost(10), 0.0)
	var plain := 0
	var both := 0
	for s in 40:
		plain += Town.new(s).roll_guests(1, 0.0, Town.FLYER_GUESTS).size()
		both += Town.new(s).roll_guests(1, c.visit_boost(6), Town.FLYER_GUESTS).size()
	assert_gt(both, plain, "a good review on top of flyers brings more")
	c.publish({"speed": 1, "clean": 1, "quality": 1, "variety": 1}, false, Town.new(1), 10)
	assert_eq(c.visit_boost(11), Critic.BOOST[1], "the next review replaces it")



func test_a_clean_review_does_not_bring_back_the_revolted():
	var t := Town.new(2)
	t.record_disgust(0, 3)
	Critic.new(2).publish({"speed": 5, "clean": 5, "quality": 5, "variety": 5}, false, t, 5)
	assert_true(t.people[0].gone)
	for day in range(6, 12):
		assert_false(t.roll_guests(day, 1.0).has(0), "still never coming back")



func test_the_critic_always_finds_something_to_order():
	var avail := [{"course": "main", "ingredients": ["patty", "bun"], "id": 1},
		{"course": "main", "ingredients": ["patty", "onion"], "id": 2}]
	var rng := RandomNumberGenerator.new()
	assert_true(Menu.order(avail, [], ["patty"], rng).main.is_empty(), "anyone else walks on")
	var o := Critic.order(avail, ["bun"], ["patty"], rng)
	assert_eq(int(o.main.id), 1, "the critic takes the best match")



func test_a_loose_stack_combines_only_into_what_the_menu_makes():
	var items := _burger_menu()
	var d := Dish.new()
	d.add("prep:patty", 1.0)
	assert_eq(d.refusal("prep:bun", items), "", "a bun on a cooked patty")
	assert_eq(d.refusal("prep:potato", items), "Nothing on the menu has patty with fries")
	assert_eq(d.refusal("raw:patty", items), "Patty needs grilling first")
	assert_eq(d.refusal("burnt:bun", items), "That's burnt. Bin it")
	assert_eq(d.refusal("prep:soda", items), "Drinks go in a cup")
	d.add("prep:bun", Prep.PLAIN)
	assert_eq(d.refusal("prep:bun", items), "One bun is enough")
	assert_eq(d.item_of(items).name, "Burger", "in any order")
	assert_false(d.is_ready(items), "loose: not served until plated")
	var plate := Dish.make(Dish.PLATE)
	assert_eq(plate.merge_refusal(d, items), "")
	plate.take_all(d)
	assert_true(d.is_empty())
	assert_true(plate.is_ready(items))
	assert_eq(plate.layout(items)[0], ["bun", "patty"], "drawn as the item lists it: the bun wraps the patty")



func test_a_cup_holds_drinks_and_a_plate_holds_food():
	var items := _burger_menu()
	var cup := Dish.make(Dish.CUP)
	assert_eq(cup.refusal("prep:potato", items), "Only drinks go in a cup")
	assert_eq(cup.refusal("prep:soda", items), "")
	cup.add("prep:soda", Prep.GOOD)
	assert_true(cup.is_ready(items))
	assert_eq(Dish.make(Dish.CUP, true).refusal("prep:soda", items), "Wash it first")



func test_an_order_fills_a_line_per_dish_served():
	var items := _burger_menu()
	var order := Tray.new()
	order.assign(1, items)
	var fries := Dish.make(Dish.PLATE)
	fries.add("prep:potato", Prep.GOOD)
	assert_eq(order.serve_dish(fries, items), 1, "the side's line")
	assert_eq(order.served_count(), 1)
	assert_false(order.is_complete())
	assert_eq(order.serve_dish(fries, items), -1, "one portion of fries was ordered")
	var burger := Dish.make(Dish.PLATE)
	burger.add("prep:patty", 1.0)
	burger.add("prep:bun", Prep.PLAIN)
	assert_eq(order.serve_dish(burger, items), 0)
	assert_eq(order.lines[0].have, [Prep.PLAIN, 1.0] as Array[float], "qualities laid out as the item lists them")
	var soda := Dish.make(Dish.CUP)
	soda.add("prep:soda", Prep.GOOD)
	order.serve_dish(soda, items)
	assert_true(order.is_complete())
	assert_eq(Tray.vessel_of(items[2]), Dish.CUP)
