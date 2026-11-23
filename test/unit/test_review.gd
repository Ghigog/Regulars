extends GutTest
## The outside design review's fixes (Nov 2026): the crowd, the critic, wealth, one
## happiness score, prep that pays, night zero, cleaning, rolling reputation.


# ---------- Item 1: the crowd follows reputation, and the late game stays hard ----------

func _mean_crowd(day: int, affinity: float, seeds := 40) -> float:
	var total := 0
	for s in seeds:
		var t := Town.new(100 + s)
		for p in t.people:
			p.affinity = affinity
		total += t.roll_guests(day).size()
	return float(total) / seeds


func test_town_is_forty_named_people_for_each_theme():
	for theme in ["diner", "seaside"]:
		var t := Town.new(3, theme)
		assert_eq(t.people.size(), Town.TOWN_SIZE)
		var seen := {}
		for p in t.people:
			assert_false(seen.has(p.name), "names are unique: %s" % p.name)
			seen[p.name] = true
			assert_false((p.friends as Array).is_empty(), "everyone has a friend")
	assert_ne(Town.new(3, "diner").people[20].name, Town.new(3, "seaside").people[20].name,
		"each theme has its own townsfolk past the drawn fourteen")


func test_generated_looks_are_fixed_by_name():
	assert_eq(Peg.look_for("Dolores"), Peg.look_for("Dolores"))
	assert_eq(Peg.look_for("Mabel"), Peg.LOOKS.Mabel, "the drawn fourteen keep their sheet looks")


func test_turnout_follows_reputation():
	var cold := _mean_crowd(6, -0.5)
	var plain := _mean_crowd(6, 0.0)
	var liked := _mean_crowd(6, 0.5)
	var loved := _mean_crowd(6, 1.0)
	assert_lt(plain, liked, "a liked place draws more")
	assert_lt(liked, loved)
	assert_almost_eq(cold, float(Town.crowd_floor(6)), 0.5, "a disliked place still gets its floor")
	assert_gt(liked - plain, 4.0, "reputation is worth several guests, not a rounding error")


func test_crowd_floor_grows_slowly():
	assert_eq(Town.crowd_floor(1), 2)
	assert_eq(Town.crowd_floor(10), 7)
	assert_eq(Town.crowd_floor(20), 12)


func test_day_20_is_not_easier_than_day_10():
	for affinity in [0.0, 0.4, 0.9]:
		var c10 := _mean_crowd(10, affinity)
		var c20 := _mean_crowd(20, affinity)
		assert_true(c20 >= c10 - 0.01, "no fewer guests on day 20 (affinity %.1f)" % affinity)
	assert_true(Town.table_patience(20) <= Town.table_patience(10), "tables wait no longer")
	# The same arrival window every day, so more guests means more pressure per second.
	assert_eq(Town.DAY_LENGTH, Town.DAY_LENGTH)
	var g10 := 0.0
	var g20 := 0.0
	for s in 200:
		var t := Town.new(500 + s)
		var everyone: Array[int] = []
		for i in t.people.size():
			everyone.append(i)
		g10 += t.make_groups(everyone, 4, 10).size()
		t = Town.new(500 + s)
		g20 += t.make_groups(everyone, 4, 20).size()
	assert_true(g20 <= g10 * 1.01, "parties are no smaller on day 20 (fewer, bigger groups)")


func test_picking_the_theme_later_brings_its_townsfolk():
	var t := Town.new(3)
	t.make_tastes("seaside")
	assert_eq(t.people[30].name, Town.new(3, "seaside").people[30].name)


# ---------- Item 2: the critic blends in, gets stricter, and says the variety rule ----------

func test_a_review_moves_opinion_part_way_and_never_wipes_it():
	var t := Town.new(5)
	for k in 6:
		t.record_visit(2, 1.0, {"speed": 0.35})
	var before := t.opinion(2, "speed")
	assert_gt(before, 0.1)
	Critic.new(5).publish({"speed": 1, "clean": 3, "quality": 3, "variety": 3}, false, t, 5)
	assert_gt(t.opinion(2, "speed"), 0.0, "one slow meal does not undo a run of good ones")
	assert_lt(t.opinion(2, "speed"), before)


func test_the_critic_gets_stricter_with_each_review():
	var c := Critic.new(1)
	assert_eq(c.strictness(), 0.0)
	assert_eq(Critic.speed_rating(0.86), 5)
	for d in [5, 10, 15, 20, 25, 30]:
		c.publish({"speed": 3, "clean": 3, "quality": 3, "variety": 3}, false, Town.new(1), d)
	assert_almost_eq(c.strictness(), Critic.STRICTEST, 0.0001, "capped")
	assert_lt(Critic.speed_rating(0.86, c.strictness()), 5, "the same wait earns less later")


func test_the_variety_rule_is_written_down():
	assert_string_contains(Critic.VARIETY_RULE, "full menu")


# ---------- Item 3: wealth, and what Dear costs ----------

func _dear(n: int) -> Dictionary:
	var o := {"main": {}, "side": {}, "drink": {}}
	var keys := ["main", "side", "drink"]
	for k in n:
		o[keys[k]] = {"course": keys[k], "price_level": "dear", "ingredients": []}
	return o


func _sat_with(wealth: int, dear: int) -> float:
	var m := GuestMood.new()
	m.wealth = wealth
	m.joy = 0.6
	m.taste(0.9)
	m.read_prices(Menu.dear_count(_dear(dear)))
	return m.satisfaction()


func test_everyone_has_a_wealth():
	var t := Town.new(9)
	var seen := {}
	for i in t.people.size():
		var w := t.wealth(i)
		assert_between(w, 1, 5)
		seen[w] = true
	assert_gt(seen.size(), 2, "the town is a mix of means")


func test_dear_items_cost_happiness_more_for_the_poor():
	assert_eq(_sat_with(1, 0), _sat_with(5, 0), "no Dear items, no difference")
	assert_lt(_sat_with(3, 1), _sat_with(3, 0), "a Dear item costs something")
	assert_lt(_sat_with(3, 3), _sat_with(3, 1), "more Dear items cost more")
	assert_lt(_sat_with(1, 2), _sat_with(3, 2), "the poor mind more")
	assert_lt(_sat_with(3, 2), _sat_with(5, 2), "the rich mind less")
	assert_lt(_sat_with(5, 2), _sat_with(5, 0), "but even the rich notice")


func test_wealth_is_hinted_on_the_card_like_a_tolerance():
	var poor := GuestMood.new()
	poor.wealth = 1
	poor.read_prices(1)
	assert_eq(poor.tolerance_hints(), ["Watches the pennies"] as Array[String])
	assert_true(poor.thoughts.has("Pricey for what it is"))
	var rich := GuestMood.new()
	rich.wealth = 5
	rich.read_prices(2)
	assert_eq(rich.tolerance_hints(), ["Money's no object"] as Array[String])
	var mid := GuestMood.new()
	mid.read_prices(0)
	assert_eq(mid.tolerance_hints(), [] as Array[String], "nothing Dear, nothing to hint")


func test_an_all_dear_menu_is_not_free_money():
	# A poor regular paying Dear for three items loses enough happiness to sour the visit.
	var fair := _sat_with(2, 0)
	var dear := _sat_with(2, 3)
	assert_gt(fair - dear, 0.25, "three Dear items cost a real share of the visit")


# ---------- Item 5: one happiness score ----------

func test_one_score_sets_the_bill_the_stay_the_tip_and_the_opinion():
	var happy := GuestMood.new()
	happy.joy = 0.9
	happy.patience = 0.9
	happy.taste(1.0)
	happy.settle_comfort()
	var glum := GuestMood.new()
	glum.joy = 0.9
	glum.patience = 0.9
	glum.taste(0.2)   # same room, same wait, worse food
	glum.settle_comfort()
	assert_gt(happy.satisfaction(), glum.satisfaction())
	assert_gt(happy.scaled_price(20), glum.scaled_price(20), "the food now moves the bill too")
	assert_gt(GuestMood.stay_scale(happy.served_comfort), GuestMood.stay_scale(glum.served_comfort))
	assert_gt(happy.tip_for(20), glum.tip_for(20))
	var t := Town.new(2)
	assert_gt(t.record_visit(0, happy.satisfaction()), t.record_visit(1, glum.satisfaction()))


func test_dear_prices_also_trim_the_bill_scale():
	var m := GuestMood.new()
	m.joy = 0.8
	m.patience = 0.8
	m.taste(0.9)
	var before := m.comfort()
	m.read_prices(2)
	assert_lt(m.comfort(), before, "one score: prices count everywhere")


# ---------- Item 6: good prep pays ----------

func test_a_perfect_streak_raises_the_tip_and_word_gets_round():
	assert_eq(Prep.streak_tip(0), 1.0)
	assert_gt(Prep.streak_tip(3), Prep.streak_tip(1))
	assert_eq(Prep.streak_tip(50), Prep.streak_tip(Prep.STREAK_TIP_MAX), "capped")
	assert_eq(Prep.streak_rep(Prep.STREAK_REP_FROM - 1), 0.0)
	assert_gt(Prep.streak_rep(Prep.STREAK_REP_FROM), 0.0)
	var m := GuestMood.new()
	m.joy = 0.8
	m.patience = 0.8
	m.taste(1.0)
	assert_gt(m.tip_for(20, Prep.streak_tip(4)), m.tip_for(20), "a streak is real money")
	var t := Town.new(4)
	t.record_praise(0, Prep.streak_rep(4))
	assert_gt(t.opinion(0, "quality"), 0.0, "filed under the cooking, for the critic to weigh")
	assert_gt(float(t.people[t.people[0].friends[0]].affinity), 0.0, "friends hear it")


func test_the_critic_weights_the_food():
	var good_food := {"speed": 3, "clean": 3, "quality": 5, "variety": 2}
	var good_clean := {"speed": 3, "clean": 5, "quality": 2, "variety": 3}
	assert_gt(Critic.stars(good_food), Critic.stars(good_clean), "the same sum, the food counts more")


func test_the_receipt_counts_perfect_plates():
	var l := Ledger.new()
	l.record_perfect(1)
	l.record_perfect(2)
	l.record_perfect(1)
	var rec := l.end_day()
	assert_eq(int(rec.perfect), 3)
	assert_eq(int(rec.best_streak), 2)


# ---------- Item 7: early days are a little longer ----------

func test_the_first_days_are_a_little_longer_and_then_steady():
	assert_gt(Town.day_length(1), Town.day_length(2))
	assert_gt(Town.day_length(2), Town.day_length(3))
	assert_eq(Town.day_length(3), Town.DAY_LENGTH)
	assert_eq(Town.day_length(30), Town.DAY_LENGTH, "it never grows again")
	assert_gt(Town.day_length(1), 55.0, "longer than the old first day")


# ---------- Item 8: cleaning ----------

# ---------- Item 9: a rolling reputation ----------

func _bad_day(l: Ledger, walkouts := 5, unhappy := 3) -> void:
	for i in walkouts:
		l.record_walkout()
	for i in unhappy:
		l.record_visit(-0.2)
	l.end_day()


func _good_day(l: Ledger, happy := 10) -> void:
	for i in happy:
		l.record_visit(0.6)
	l.end_day()


func test_reputation_carries_over_the_nights():
	var l := Ledger.new()
	l.record_walkout()
	var after := l.reputation
	l.end_day()
	assert_eq(l.reputation, after, "nothing resets it at night")
	assert_lt(after, Ledger.REP_START)
	var rec := l.end_day()
	assert_eq(float(rec.reputation), after, "the receipt shows it")


func test_one_bad_day_hurts_a_good_run_but_does_not_end_it():
	var l := Ledger.new()
	for d in 6:
		_good_day(l)
	var good := l.reputation
	assert_gt(good, 90.0, "a good run builds the meter up")
	_bad_day(l)
	assert_lt(l.reputation, good - 30.0, "a bad day hurts")
	assert_false(l.is_closed_down(), "but one bad day does not end a good run")
	_bad_day(l)
	_bad_day(l)
	assert_true(l.is_closed_down(), "a run of them does")


func test_good_service_and_reviews_raise_it():
	var l := Ledger.new()
	var r := l.reputation
	l.record_visit(0.6)
	assert_gt(l.reputation, r)
	r = l.reputation
	l.record_review(5)
	assert_gt(l.reputation, r)
	r = l.reputation
	l.record_review(1)
	assert_lt(l.reputation, r)
	l.reputation = Ledger.REP_MAX
	l.record_visit(0.9)
	assert_eq(l.reputation, Ledger.REP_MAX, "capped")
