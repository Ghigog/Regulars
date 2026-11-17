extends GutTest
## Unit tests for res://sim/staff.gd (PRD 10.2): posts, applying, CVs, hiring and haggling,
## wages, satisfaction, managing, firing, the week, breaks, chat and training.

const EVEN := {"food": 3, "service": 3, "clean": 3}


func _staff() -> Staff:
	return Staff.new(7)


## A hire with the given tolerances, straight from a CV, at the asking wage.
func _hire(s: Staff, person: int, duties: Array, tol := EVEN, rating := 3, breaks := 0,
		days_off := 0, day := 1) -> int:
	var pid := s.add_post("Job", duties, breaks, days_off, 99)
	var cv := s._make_cv(person, Staff.skills_from(tol), rating, 1.0, pid)
	s.cvs.append(cv)
	return s.hire(cv.id, -1, day)


# ---------- Posts ----------

func test_post_clamps_breaks_and_days_off():
	var s := _staff()
	var id := s.add_post("Grill cook", ["grill", "grill", "fetch"], 9, -1, 1)
	assert_eq(s.posts[id].breaks, 3)
	assert_eq(s.posts[id].days_off, 0)
	assert_eq(s.posts[id].duties.size(), 2, "a duty once")


func test_posts_and_hires_capped_by_desks():
	var s := _staff()
	assert_true(s.add_post("A", ["grill"], 0, 0, 1) > 0)
	assert_eq(s.add_post("B", ["grill"], 0, 0, 1), -1, "one desk, one opening")
	assert_false(s.can_sell_desk(1))
	assert_true(s.can_sell_desk(2))
	_hire(s, 4, ["mop"], EVEN, 3, 0, 0)
	assert_eq(s.seats_used(), 2, "the open post and the hire")


func test_duty_kinds_and_registering():
	var s := _staff()
	assert_eq(s.duty_kind("mop"), "clean")
	assert_true(s.duty_weight("mop") > s.duty_weight("sponge"))
	assert_true(s.duty_weight("fryer") > s.duty_weight("board"))
	s.register_duty("smoker", "food", 5.0)
	assert_eq(s.duty_kind("smoker"), "food")
	assert_eq(s.kinds_of(["mop", "grill", "sponge"]), ["food", "clean"] as Array[String])


# ---------- Applying ----------

func test_skill_is_six_minus_tolerance():
	var sk := Staff.skills_from({"food": 1, "service": 5, "clean": 4})
	assert_eq(sk.food, 5.0)
	assert_eq(sk.service, 1.0)
	assert_true(Staff.is_weak(sk, "clean"))
	assert_false(Staff.is_weak(sk, "food"))


func test_fit_penalises_weak_kind_duties():
	var s := _staff()
	var messy := Staff.skills_from({"food": 1, "service": 3, "clean": 5})
	assert_almost_eq(s.fit(messy, ["grill"]), 1.0, 0.001)
	assert_true(s.fit(messy, ["grill", "mop"]) < s.fit(messy, ["grill", "take_orders"]),
		"a messy person avoids a post with the mop in it")
	assert_eq(s.fit(messy, []), 0.0)


func test_apply_chance_scales_with_like():
	var s := _staff()
	var pid := s.add_post("Cook", ["grill"], 0, 0, 3)
	var sk := Staff.skills_from(EVEN)
	assert_eq(s.apply_chance(sk, 0.0, pid), 0.0)
	assert_almost_eq(s.apply_chance(sk, 1.0, pid), 2.0 * s.apply_chance(sk, 0.5, pid), 0.001)


func test_applicants_skip_away_employed_and_piled():
	var s := _staff()
	s.add_post("Cook", ["grill"], 0, 0, 5)
	var keen := {"food": 1, "service": 1, "clean": 1}
	var cands := [
		{"id": 0, "tolerance": keen, "rating": 3, "like": 1.0, "away": true},
		{"id": 1, "tolerance": keen, "rating": 3, "like": 1.0},
	]
	_hire(s, 1, ["mop"])
	s.add_post("Cook", ["grill"], 0, 0, 5)
	for i in 20:
		s.roll_applicants(cands)
	assert_eq(s.cvs.size(), 0, "staying away and already employed never apply")
	cands.append({"id": 2, "tolerance": keen, "rating": 3, "like": 1.0})
	for i in 40:
		s.roll_applicants(cands)
	assert_eq(s.cvs.size(), 1, "one CV a person while it sits in the pile")


func test_applicants_capped_per_night():
	var s := _staff()
	s.add_post("Cook", ["grill"], 0, 0, 5)
	s.add_post("Cook 2", ["grill"], 0, 0, 5)
	var cands := []
	for i in 30:
		cands.append({"id": i, "tolerance": {"food": 1, "service": 1, "clean": 1}, "rating": 3, "like": 1.0})
	var got := s.roll_applicants(cands)
	assert_true(got.size() <= Staff.MAX_NEW_CVS)
	assert_true(got.size() > 0)


func test_cv_stays_until_dismissed():
	var s := _staff()
	var pid := s.add_post("Cook", ["grill"], 0, 0, 5)
	var cv := s._make_cv(3, Staff.skills_from(EVEN), 3, 0.5, pid)
	s.cvs.append(cv)
	s.roll_applicants([])
	s.roll_applicants([])
	assert_false(s.cv(cv.id).is_empty(), "still in the pile two nights on")
	s.dismiss(cv.id)
	assert_true(s.cv(cv.id).is_empty())


# ---------- Wages and hiring ----------

func test_asking_wage_from_rating_and_duties():
	var s := _staff()
	var base := s.asking_wage(3, [])
	assert_eq(base, int(Staff.WAGE_BASE * 3))
	assert_true(s.asking_wage(4, []) > base)
	assert_true(s.asking_wage(3, ["mop"]) > s.asking_wage(3, ["sponge"]))


func test_hire_fills_post_and_clears_its_pile():
	var s := _staff()
	var pid := s.add_post("Cook", ["grill"], 2, 1, 5)
	var a := s._make_cv(1, Staff.skills_from(EVEN), 3, 0.5, pid)
	var b := s._make_cv(2, Staff.skills_from(EVEN), 3, 0.5, pid)
	s.cvs.append(a)
	s.cvs.append(b)
	assert_eq(s.hire(a.id), 1)
	assert_false(s.posts.has(pid), "one post, one opening")
	assert_true(s.cv(b.id).is_empty())
	var e := s.employee(1)
	assert_eq(e.wage, a.ask)
	assert_eq(e.breaks, 2)
	assert_eq(e.days_off, 1)
	assert_almost_eq(e.satisfaction, s.target(1), 0.001)


func test_haggle_chance_falls_with_gap_and_low_satisfaction():
	assert_eq(Staff.haggle_chance(20, 20, 0.5), 1.0)
	assert_true(Staff.haggle_chance(20, 18, 1.0) > Staff.haggle_chance(20, 14, 1.0))
	assert_true(Staff.haggle_chance(20, 18, 1.0) > Staff.haggle_chance(20, 18, 0.0))
	assert_eq(Staff.haggle_chance(20, 5, 1.0), 0.0)


func test_haggle_hire_two_refusals_then_take_or_walk():
	var s := _staff()
	var pid := s.add_post("Cook", ["grill"], 0, 0, 5)
	var keen := s._make_cv(1, Staff.skills_from(EVEN), 3, 0.9, pid)
	s.cvs.append(keen)
	assert_eq(s.haggle_hire(keen.id, 1), "refuse")
	assert_eq(s.haggle_hire(keen.id, 2), "take_last", "a keen applicant takes the last offer")
	assert_eq(s.employee(1).wage, 2)
	var pid2 := s.add_post("Cook", ["grill"], 0, 0, 5)
	var cool := s._make_cv(2, Staff.skills_from(EVEN), 3, 0.1, pid2)
	s.cvs.append(cool)
	s.haggle_hire(cool.id, 1)
	assert_eq(s.haggle_hire(cool.id, 1), "walk")
	assert_true(s.cv(cool.id).is_empty(), "they leave")
	assert_false(s.employees.has(2))


func test_haggle_at_ask_accepts():
	var s := _staff()
	var pid := s.add_post("Cook", ["grill"], 0, 0, 5)
	var c := s._make_cv(1, Staff.skills_from(EVEN), 3, 0.1, pid)
	s.cvs.append(c)
	assert_eq(s.haggle_hire(c.id, c.ask), "accept")
	assert_true(s.employees.has(1))


# ---------- Satisfaction ----------

func test_target_weak_duty_breaks_and_days_off():
	var s := _staff()
	_hire(s, 1, ["mop"], {"food": 3, "service": 3, "clean": 3})
	_hire(s, 2, ["mop"], {"food": 3, "service": 3, "clean": 5})
	assert_almost_eq(s.target(1), Staff.TARGET_AT_PAR, 0.001, "paid the ask, worth it")
	s.employee(2).wage = s.employee(1).wage
	assert_true(s.target(2) < s.target(1), "a weak-kind duty counts double")
	var before := s.target(1)
	s.add_break(1)
	assert_almost_eq(s.target(1), before + Staff.BREAK_ADD, 0.001)
	s.add_day_off(1)
	assert_true(Staff.DAY_OFF_ADD > Staff.BREAK_ADD)
	assert_almost_eq(s.target(1), before + Staff.BREAK_ADD + Staff.DAY_OFF_ADD, 0.001)


func test_end_night_pays_and_moves_toward_target():
	var s := _staff()
	_hire(s, 1, ["grill"])
	var e := s.employee(1)
	e.satisfaction = 0.2
	var r := s.end_night(1000)
	assert_eq(r.paid, e.wage)
	assert_true(e.satisfaction > 0.2 and e.satisfaction < s.target(1))


func test_unpaid_wage_is_a_big_hit_not_a_debt():
	var s := _staff()
	_hire(s, 1, ["grill"])
	var e := s.employee(1)
	e.satisfaction = s.target(1)
	var r := s.end_night(0)
	assert_eq(r.paid, 0)
	assert_eq(r.unpaid, [1] as Array[int])
	assert_almost_eq(e.satisfaction, s.target(1) - Staff.UNPAID_HIT, 0.001)
	assert_eq(s.end_night(1000).paid, e.wage, "nothing carried over")


func test_quit_after_three_nights_at_bottom():
	var s := _staff()
	_hire(s, 1, ["grill"])
	s.employee(1).wage = 0
	s.employee(1).satisfaction = 0.0
	assert_true(s.end_night(0).quit.is_empty())
	assert_true(s.end_night(0).quit.is_empty())
	assert_eq(s.end_night(0).quit, [1] as Array[int])
	assert_false(s.employees.has(1))


func test_bottom_streak_resets():
	var s := _staff()
	_hire(s, 1, ["grill"])
	var e := s.employee(1)
	e.satisfaction = 0.0
	e.wage = 0
	s.end_night(0)
	s.end_night(0)
	e.wage = 100
	e.satisfaction = 0.9
	s.end_night(1000)
	assert_eq(e.bottom_nights, 0)


func test_low_satisfaction_slow_and_mistakes():
	assert_eq(Staff.slowness(0.8), 1.0)
	assert_almost_eq(Staff.slowness(0.0), 1.0 + Staff.SLOW_MAX, 0.001)
	assert_eq(Staff.mistake_chance(0.6), 0.0)
	assert_true(Staff.mistake_chance(0.1) > Staff.mistake_chance(0.3))
	var s := _staff()
	_hire(s, 1, ["grill"])
	s.employee(1).satisfaction = 1.0
	for i in 50:
		assert_eq(s.roll_mistake(1), "")


# ---------- Managing ----------

func test_add_duty_accepted_when_happy():
	var s := _staff()
	_hire(s, 1, ["grill"])
	s.employee(1).satisfaction = 1.0
	s.employee(1).wage = 200
	assert_true(s.propose_duty(1, "fryer").ok)
	assert_true(s.employee(1).duties.has("fryer"))


func test_add_duty_refused_names_a_raise():
	var s := _staff()
	_hire(s, 1, ["grill"])
	s.employee(1).satisfaction = 0.0
	var r := s.propose_duty(1, "mop")
	assert_false(r.ok)
	assert_true(r.raise >= 1)
	var wage: int = s.employee(1).wage
	assert_eq(s.answer_raise(1, "approve"), "added")
	assert_eq(s.employee(1).wage, wage + r.raise)
	assert_true(s.employee(1).duties.has("mop"))


func test_raise_withdraw_and_deny():
	var s := _staff()
	_hire(s, 1, ["grill"])
	s.employee(1).satisfaction = 0.0
	s.propose_duty(1, "mop")
	assert_eq(s.answer_raise(1, "withdraw"), "withdrawn")
	assert_false(s.employee(1).duties.has("mop"))
	s.propose_duty(1, "mop")
	assert_eq(s.answer_raise(1, "deny"), "quit")
	assert_false(s.employees.has(1))


func test_raise_haggle_walks_when_unhappy():
	var s := _staff()
	_hire(s, 1, ["grill"])
	s.employee(1).satisfaction = 0.0
	s.propose_duty(1, "mop")
	assert_eq(s.answer_raise(1, "haggle", 0), "refuse")
	assert_eq(s.answer_raise(1, "haggle", 0), "quit")


func test_remove_duty_and_add_break_raise_target():
	var s := _staff()
	_hire(s, 1, ["grill", "mop"])
	var t := s.target(1)
	s.remove_duty(1, "mop")
	assert_true(s.target(1) > t)
	for i in 3:
		assert_true(s.add_break(1))
	assert_false(s.add_break(1), "three at most")
	assert_true(s.add_day_off(1))
	assert_true(s.add_day_off(1))
	assert_false(s.add_day_off(1), "two at most")


func test_fire_with_and_without_severance():
	var s := _staff()
	_hire(s, 1, ["grill"])
	_hire(s, 2, ["grill"])
	var kind := s.fire(1, true)
	assert_eq(kind.cost, s.asking_wage(3, ["grill"]))
	var harsh := s.fire(2, false)
	assert_eq(harsh.cost, 0)
	assert_true(harsh.drop > kind.drop)
	assert_true(harsh.friend_drop > 0.0)
	assert_true(s.employees.is_empty())


# ---------- The week ----------

func test_week_numbers():
	assert_eq(Staff.week_of(1), 0)
	assert_eq(Staff.week_of(5), 0)
	assert_eq(Staff.week_of(6), 1)
	assert_eq(Staff.week_day(5), 4)
	assert_eq(Staff.week_day(6), 0)


func test_days_off_never_two_in_a_row():
	for seed_value in 30:
		var s := Staff.new(seed_value)
		_hire(s, 1, ["grill"], EVEN, 3, 0, 2)
		s.start_week(1)
		var off: Array = s.employee(1).week_off
		assert_eq(off.size(), 2)
		assert_true(absi(int(off[0]) - int(off[1])) > 1)


func test_days_off_avoid_others_when_they_can():
	for seed_value in 20:
		var s := Staff.new(seed_value)
		_hire(s, 1, ["grill"], EVEN, 3, 0, 2)
		_hire(s, 2, ["grill"], EVEN, 3, 0, 2)
		s.start_week(6)
		for d in s.employee(1).week_off:
			assert_false(s.employee(2).week_off.has(d))


func test_hired_mid_week_waits_and_days_off_lookup():
	var s := _staff()
	_hire(s, 1, ["grill"], EVEN, 3, 0, 1, 3)
	s.start_week(1)
	assert_true(s.employee(1).week_off.is_empty(), "hired on day 3, starts next week")
	s.start_week(6)
	var d: int = s.employee(1).week_off[0]
	assert_true(s.is_day_off(1, 6 + d))
	assert_false(s.is_day_off(1, 1 + d), "only this week")


func test_satisfied_staff_visit_on_days_off():
	var s := _staff()
	_hire(s, 1, ["grill"], EVEN, 3, 0, 1)
	s.start_week(1)
	var d: int = s.employee(1).week_off[0]
	var work := 1 + (d + 2) % 5
	s.employee(1).satisfaction = 0.9
	assert_true(s.may_visit(1, 1 + d))
	assert_false(s.may_visit(1, work), "a working day")
	s.employee(1).satisfaction = 0.5
	assert_false(s.may_visit(1, 1 + d))
	assert_true(s.may_visit(9, 1), "not staff: as any guest")


# ---------- Breaks ----------

func test_break_times_spread_evenly():
	assert_eq(Staff.break_starts(0, 120.0).size(), 0)
	assert_eq(Staff.break_starts(1, 120.0), [60.0] as Array[float])
	assert_eq(Staff.break_starts(3, 120.0), [30.0, 60.0, 90.0] as Array[float])
	var two := Staff.break_starts(2, 120.0)
	for t in two:
		for u in Staff.break_starts(3, 120.0):
			assert_true(absf(t - u) >= Staff.BREAK_SECONDS, "2 and 3 never overlap")


func test_on_break():
	var s := _staff()
	_hire(s, 1, ["grill"], EVEN, 3, 1, 0)
	assert_true(s.on_break(1, 61.0, 120.0))
	assert_false(s.on_break(1, 59.0, 120.0))
	assert_false(s.on_break(1, 60.0 + Staff.BREAK_SECONDS, 120.0))


# ---------- Chat and training ----------

func test_chat_pulls_together():
	var s := _staff()
	_hire(s, 1, ["grill"])
	_hire(s, 2, ["grill"])
	s.employee(1).satisfaction = 0.9
	s.employee(2).satisfaction = 0.1
	s.chat(1, 2, 2.0)
	assert_true(s.employee(1).satisfaction < 0.9)
	assert_true(s.employee(2).satisfaction > 0.1)
	assert_almost_eq(s.employee(1).satisfaction + s.employee(2).satisfaction, 1.0, 0.001)


func test_training_raises_skill_and_lowers_tolerance():
	var s := _staff()
	_hire(s, 1, ["mop"], {"food": 3, "service": 3, "clean": 5})
	var tol := 5.0
	for i in 10:
		tol = s.train(1, "clean")
	assert_almost_eq(tol, 5.0 - 10 * Staff.TRAIN_PER_TASK, 0.001)
	assert_almost_eq(s.tolerance(1, "clean"), tol, 0.001)
	for i in 1000:
		s.train(1, "clean")
	assert_eq(s.employee(1).skills.clean, 5.0, "capped at five stars")
	assert_eq(Staff.stars(s.employee(1).skills.clean), 5)


# ---------- The desk (PRD 10.3) ----------

func test_room_duties_list_tool_kinds_in_the_room_and_the_fixed_tasks():
	var room := Staff.room_duties(["grill", "chop", "pour"], ["stove", "stove", "sink", "bin", "mop"])
	assert_eq(room.food, ["grill", "board", "tap", "fetch", "assemble"] as Array[String])
	assert_eq(room.service, ["take_orders", "take_payment", "carry_trays", "clear_tables", "help_up"] as Array[String])
	assert_eq(room.clean, ["mop", "wash_up", "empty_bin"] as Array[String], "a cleaning tool by its piece")
	var empty := Staff.room_duties([], [])
	assert_eq(empty.food, ["fetch", "assemble"] as Array[String], "no prep tools: only the fixed tasks")
	assert_false((empty.clean as Array).has("mop"))


func test_every_listed_duty_has_words_and_a_kind():
	var room := Staff.room_duties(Staff.TOOL_DUTIES.keys(), Staff.CLEAN_TOOLS)
	var s := _staff()
	for k in Staff.KINDS:
		for d: String in room[k]:
			assert_eq(s.duty_kind(d), k, d)
			assert_true(Staff.DUTY_WORDS.has(d), "%s has words" % d)


func test_a_duty_whose_tool_left_the_room_is_missing():
	var room := Staff.room_duties(["chop"], [])
	assert_eq(Staff.missing_duties(["board", "grill", "fetch"], room), ["grill"] as Array[String])
	assert_eq(Staff.missing_duties(["wash_up"], room), [] as Array[String])


func test_like_follows_affinity():
	assert_almost_eq(Staff.like_of(0.0), Staff.LIKE_AT_NEUTRAL, 0.0001)
	assert_eq(Staff.like_of(1.0), 1.0)
	assert_eq(Staff.like_of(-1.0), 0.0)
	assert_gt(Staff.like_of(0.3), Staff.like_of(0.1))


func test_candidates_carry_tolerances_rating_and_who_stays_away():
	var town := Town.new(4)
	town.people[2].away_until = 5
	town.people[3].gone = true
	town.people[1].affinity = 0.4
	var c := Staff.candidates(town, 3)
	assert_eq(c.size(), town.people.size())
	assert_eq(c[0].tolerance, town.people[0].tolerance)
	assert_eq(c[0].rating, town.rating(0))
	assert_true(c[2].away, "a grudge keeps them away")
	assert_true(c[3].away)
	assert_false(c[0].away)
	assert_almost_eq(float(c[1].like), Staff.like_of(0.4), 0.0001)
	var was: int = town.people[0].tolerance.food
	c[0].tolerance.food = 9
	assert_eq(town.people[0].tolerance.food, was, "a copy, not the town's own")


func test_the_town_applies_to_a_post_from_its_candidates():
	var town := Town.new(9)
	for p in town.people:
		p.affinity = 0.5
	var s := _staff()
	s.add_post("Grill cook", ["grill", "fetch"], 1, 1, 2)
	var cvs := s.roll_applicants(Staff.candidates(town, 1))
	assert_between(cvs.size(), 1, Staff.MAX_NEW_CVS)
	for cv in cvs:
		assert_eq(cv.rating, town.rating(cv.person))
		assert_eq(cv.skills.food, float(town.skill(cv.person, "food")))


func test_everyone_has_a_rating_from_one_to_five_fixed_by_the_seed():
	var a := Town.new(21)
	var b := Town.new(21)
	var seen := {}
	for i in a.people.size():
		assert_between(a.rating(i), 1, 5)
		assert_eq(a.rating(i), b.rating(i))
		seen[a.rating(i)] = true
	assert_gt(seen.size(), 1, "ratings vary")


func test_ratings_leave_tolerances_and_tastes_alone():
	var a := Town.new(5)
	var tol: Array = a.people.map(func(p: Dictionary) -> Dictionary: return p.tolerance.duplicate())
	var likes: Array = a.people.map(func(p: Dictionary) -> Array: return p.likes)
	a.make_ratings()
	assert_eq(a.people.map(func(p: Dictionary) -> Dictionary: return p.tolerance), tol)
	assert_eq(a.people.map(func(p: Dictionary) -> Array: return p.likes), likes)


func test_the_desk_is_a_one_cell_catalog_piece_on_sale_with_helpers():
	assert_true(Catalog.ITEMS.has("desk"))
	assert_eq(int(Catalog.ITEMS.desk.tiers), 1)
	assert_eq(Catalog.STAFF_ON_SALE, true, "on sale since helpers work (10.6)")
	assert_true(Catalog.sold_in("desk", "diner"))
	assert_true(Catalog.sold_in("desk", "seaside"))
	assert_true(Catalog.search("desk").any(func(bp: Dictionary) -> bool: return bp.id == "desk"))


# ---------- The staff list (PRD 10.4) ----------

func test_mood_words_run_from_happy_to_fed_up():
	assert_eq(Staff.mood_word(0.9), "Happy")
	assert_eq(Staff.mood_word(0.65), "Content")
	assert_eq(Staff.mood_word(0.45), "So-so")
	assert_eq(Staff.mood_word(0.3), "Unhappy")
	assert_eq(Staff.mood_word(Staff.BOTTOM), "Fed up", "the bottom fifth, where quitting nights count")
	assert_eq(Staff.mood_word(0.0), "Fed up")


func test_week_boxes_show_the_five_days_and_days_off():
	var s := _staff()
	_hire(s, 1, ["grill"], EVEN, 3, 0, 2)
	assert_eq(Staff.week_first(8), 6)
	assert_false(s.picked_week(1, 6), "not picked until the week starts")
	s.start_week(6)
	assert_true(s.picked_week(1, 8))
	assert_false(s.picked_week(1, 11), "next week is picked afresh")
	var boxes := s.week_boxes(1, 7)
	assert_eq(boxes.map(func(b: Dictionary) -> int: return b.day), [6, 7, 8, 9, 10])
	assert_eq(boxes.filter(func(b: Dictionary) -> bool: return b.off).size(), 2)


func test_removing_a_duty_or_adding_rest_lifts_satisfaction_now():
	var s := _staff()
	_hire(s, 1, ["grill", "mop"])
	var e := s.employee(1)
	var sat: float = e.satisfaction
	s.remove_duty(1, "mop")
	assert_gt(e.satisfaction, sat)
	sat = e.satisfaction
	assert_true(s.add_break(1))
	assert_almost_eq(e.satisfaction, sat + Staff.BREAK_ADD, 0.0001)
	sat = e.satisfaction
	assert_true(s.add_day_off(1))
	assert_almost_eq(e.satisfaction, sat + Staff.DAY_OFF_ADD, 0.0001)
	sat = e.satisfaction
	s.remove_duty(1, "mop")
	assert_eq(e.satisfaction, sat, "a duty they do not have changes nothing")


func test_ledger_pays_staff_with_no_debt():
	var l := Ledger.new()
	l.money = 30
	l.pay_staff(20, 1)
	assert_eq(l.money, 10)
	assert_eq(l.today.staff, 20)
	assert_eq(l.today.unpaid, 1)
	var rec := l.end_day()
	assert_eq(rec.staff, 20)
	assert_eq(l.today.staff, 0, "a new day starts clean")


func test_firing_drops_opinion_and_friends_hear_without_severance():
	var town := Town.new(4)
	var i := 0
	while (town.people[i].friends as Array).is_empty():
		i += 1
	var f: int = town.people[i].friends[0]
	for p in town.people:
		p.affinity = 0.5
	town.record_fired(i, Staff.FIRE_DROP)
	assert_almost_eq(float(town.people[i].affinity), 0.5 - Staff.FIRE_DROP, 0.0001)
	assert_eq(float(town.people[f].affinity), 0.5, "with severance their friends hear nothing")
	town.record_fired(i, Staff.FIRE_DROP_HARSH, Staff.FIRE_DROP_HARSH * Staff.FIRE_FRIEND_SHARE)
	assert_almost_eq(float(town.people[f].affinity), 0.5 - Staff.FIRE_DROP_HARSH * Staff.FIRE_FRIEND_SHARE, 0.0001)


# ---------- New jobs and cleaning tools in the duty lists (PRD 10.5) ----------

func test_every_job_a_tool_does_has_a_duty_with_words_and_a_kind():
	var s := _staff()
	for job in Kitchen.jobs_known():
		assert_true(Staff.TOOL_DUTIES.has(job), "%s has a duty" % job)
		var d: String = Staff.TOOL_DUTIES.get(job, "")
		assert_eq(s.duty_kind(d), "food", d)
		assert_true(Staff.DUTY_WORDS.has(d), "%s has words" % d)


func test_the_new_tools_list_their_duties_in_the_room():
	var room := Staff.room_duties(["grate", "saw", "juice", "blend", "steam"], [])
	for d in ["grater", "bread_knife", "juicer", "blender", "steamer"]:
		assert_true((room.food as Array).has(d), d)


func test_cleaning_pieces_bring_their_duty():
	var room := Staff.room_duties([], ["mop_bucket", "sponge", "hook", "robot_dock"])
	assert_eq(room.clean, ["mop", "sponge", "wash_up", "empty_bin"] as Array[String])


func test_a_tool_s_duty_is_the_job_it_does_best():
	assert_eq(Staff.duty_of_tool("stove"), "grill")
	assert_eq(Staff.duty_of_tool("pot"), "pot", "a stock pot is the pot's duty, not the grill's")
	assert_eq(Staff.duty_of_tool("sharp_knife"), "board")
	assert_eq(Staff.duty_of_tool("rotary_grater"), "grater")
	assert_eq(Staff.duty_of_tool("blender"), "blender")
	assert_eq(Staff.duty_of_tool("coffee_machine"), "tap")
	assert_eq(Staff.duty_of_tool("counter"), "", "no job, no duty")


# ---------- The task board (PRD 10.5) ----------

func _board(world: Dictionary) -> JobBoard:
	var b := JobBoard.new()
	b.rebuild(world)
	return b


func _types(b: JobBoard) -> Array:
	var out := []
	for t: Dictionary in b.tasks.values():
		out.append(t.type)
	out.sort()
	return out


func test_an_empty_world_has_no_tasks():
	assert_eq(_board({}).tasks.size(), 0)


func test_every_task_kind_comes_with_its_duty():
	var b := _board({
		"stations": [{"id": "g", "cell": Vector2i(1, 0), "tool": "stove"}],
		"storage": [{"cell": Vector2i(0, 0), "kinds": ["patty"]}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["patty"]},
			{"id": 2, "cell": Vector2i(3, 1), "lacks": []}],
		"trays": [{"id": 9, "cell": Vector2i(3, 2), "table": 4}],
		"tables": [{"id": 4, "cell": Vector2i(8, 8), "state": "order"}, {"id": 5, "cell": Vector2i(9, 8), "state": "clear"}],
		"dirt": {Vector2i(5, 5): 1, Vector2i(6, 5): 2},
		"fallen": [{"id": 12, "cell": Vector2i(6, 6)}],
		"sinks": [{"cell": Vector2i(0, 3), "dishes": 2}, {"cell": Vector2i(0, 4), "dishes": 0}],
		"bins": [{"cell": Vector2i(0, 5), "full": true}, {"cell": Vector2i(0, 6), "full": false}],
	})
	assert_eq(_types(b), ["assemble", "bin", "carry", "clear", "dirt", "fetch", "help_up", "order", "wash"])
	assert_eq(b.tasks["fetch:1:0"].duties, ["fetch"])
	assert_eq(b.tasks["fetch:1:0"].dest, Vector2i(1, 0), "fetched to the stove")
	assert_eq(b.tasks["carry:9"].duties, ["carry_trays"])
	assert_eq(b.tasks["order:4"].duties, ["take_orders"])
	assert_eq(b.tasks["clear:5"].duties, ["clear_tables"])
	assert_eq(b.tasks["help_up:12"].duties, ["help_up"])
	assert_eq(b.tasks["wash:0,3"].duties, ["wash_up"])
	assert_eq(b.tasks["bin:0,5"].duties, ["empty_bin"])
	assert_eq(b.tasks["assemble:2"].duties, ["assemble"])
	assert_true(b.tasks["dirt:6,5"].duties.has("mop") and b.tasks["dirt:6,5"].duties.has("sponge"))
	assert_false(b.tasks.has("dirt:5,5"), "dirt under level 2 is left")


func test_a_raw_item_at_a_station_is_a_prep_and_items_in_hand_cover_their_lack():
	var b := _board({
		"stations": [{"id": "g", "cell": Vector2i(1, 0), "tool": "stove"}],
		"storage": [{"cell": Vector2i(0, 0), "kinds": ["patty"]}],
		"items": [{"id": 7, "kind": "patty", "cell": Vector2i(1, 0), "state": "raw", "station": "g"},
			{"id": 8, "kind": "patty", "cell": Vector2i(1, 0), "state": "cooking", "station": "g"}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["patty", "patty", "patty"]}],
	})
	assert_eq(_types(b), ["fetch", "prep"], "one raw, one cooking, one still to fetch")
	var prep: Dictionary = b.tasks["prep:7"]
	assert_eq(prep.duties, ["grill"])
	assert_eq(prep.cell, Vector2i(1, 0))


func test_prep_lists_stand_ins_and_their_duties():
	var b := _board({
		"stations": [{"id": "pot", "cell": Vector2i(2, 0), "tool": "pot"},
			{"id": "stove", "cell": Vector2i(1, 0), "tool": "stove"},
			{"id": "board", "cell": Vector2i(4, 0), "tool": "board"}],
		"items": [{"id": 3, "kind": "patty", "cell": Vector2i(0, 0), "state": "raw"}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["patty"]}],
	})
	var prep: Dictionary = b.tasks["prep:3"]
	assert_eq(prep.duties, ["grill", "pot"], "the stove, then the stock pot standing in")
	assert_almost_eq(float(prep.options[1].quality), Kitchen.STAND_IN_FAR, 0.001)
	var only_pot := b.best_for(["pot"], Vector2i(0, 0))
	assert_eq(only_pot.station, "pot", "a pot cook grills at the stock pot")
	assert_eq(b.best_for(["board"], Vector2i(0, 0)), {}, "a board cannot grill")


func test_a_drink_is_poured_at_a_dispenser_that_has_it():
	var b := _board({
		"stations": [{"id": "f", "cell": Vector2i(1, 0), "tool": "fountain", "drinks": ["soda"]},
			{"id": "c", "cell": Vector2i(2, 0), "tool": "coffee_machine", "drinks": ["coffee"]}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["soda"]}],
	})
	assert_eq(_types(b), ["prep"], "no fetch: a dispenser keeps its own")
	assert_eq(b.tasks["pour:1:0"].options.size(), 1)
	assert_eq(b.tasks["pour:1:0"].options[0].station, "f")


func test_nothing_to_fetch_or_no_tool_leaves_the_lack_stuck():
	var b := _board({
		"stations": [{"id": "b", "cell": Vector2i(1, 0), "tool": "board"}],
		"storage": [{"cell": Vector2i(0, 0), "kinds": ["patty"]}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["patty", "lettuce"]}],
	})
	assert_eq(b.tasks.size(), 0, "no stove for the patty, no lettuce in stock")


func test_an_ingredient_with_no_job_is_fetched_to_the_ticket():
	var b := _board({"storage": [{"cell": Vector2i(0, 0), "kinds": ["bun"]}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["bun"]}]})
	assert_eq(b.tasks["fetch:1:0"].dest, Vector2i(3, 0))


func test_a_new_job_needs_its_new_tool():
	var b := _board({
		"stations": [{"id": "gr", "cell": Vector2i(1, 0), "tool": "rotary_grater"}],
		"items": [{"id": 1, "kind": "shredded_cheese", "cell": Vector2i(1, 0), "state": "raw"}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["shredded_cheese"]}],
	})
	assert_eq(b.tasks["prep:1"].duties, ["grater"])


func test_dirt_grows_more_urgent_by_level_and_waiting_adds_urgency():
	var b := _board({"dirt": {Vector2i(0, 0): 2, Vector2i(1, 0): 4},
		"tables": [{"id": 1, "cell": Vector2i(0, 0), "state": "order", "wait": 0.0},
			{"id": 2, "cell": Vector2i(0, 0), "state": "order", "wait": 30.0}]})
	assert_gt(b.tasks["dirt:1,0"].urgency, b.tasks["dirt:0,0"].urgency)
	assert_gt(b.tasks["order:2"].urgency, b.tasks["order:1"].urgency)


## A staff of one hire per entry: person id -> duties.
func _crew(duties_by_person: Dictionary, tol := EVEN) -> Staff:
	var s := _staff()
	for p: int in duties_by_person:
		_hire(s, p, duties_by_person[p], tol)
	return s


func test_a_helper_takes_the_most_urgent_task_their_duties_allow_and_reserves_it():
	var s := _crew({1: ["clear_tables", "help_up", "mop"]})
	var b := _board({
		"tables": [{"id": 4, "cell": Vector2i(2, 0), "state": "clear"}, {"id": 5, "cell": Vector2i(1, 0), "state": "order"}],
		"fallen": [{"id": 9, "cell": Vector2i(6, 0)}],
		"dirt": {Vector2i(1, 1): 3},
	})
	var got := b.assign(s, [{"id": 1, "cell": Vector2i(0, 0), "idle": 5.0}], 1, 0.0, 100.0)
	assert_eq(got[1].key, "help_up:9", "a fallen person first, though further")
	assert_eq(b.reserved["help_up:9"], 1)
	assert_eq(b.task_of(1).key, "help_up:9")
	b.done(1)
	got = b.assign(s, [{"id": 1, "cell": Vector2i(0, 0), "idle": 5.0}], 1, 0.0, 100.0)
	assert_eq(got[1].key, "help_up:9", "still open until the world says it is done")
	b.done(1)
	b.rebuild({"tables": [{"id": 4, "cell": Vector2i(2, 0), "state": "clear"}], "dirt": {Vector2i(1, 1): 3}})
	got = b.assign(s, [{"id": 1, "cell": Vector2i(0, 0), "idle": 5.0}], 1, 0.0, 100.0)
	assert_eq(got[1].key, "clear:4", "no order-taking duty")


func test_of_two_like_tasks_the_nearest_is_taken():
	var s := _crew({1: ["wash_up"]})
	var b := _board({"sinks": [{"cell": Vector2i(9, 9), "dishes": 1}, {"cell": Vector2i(1, 1), "dishes": 1}]})
	var got := b.assign(s, [{"id": 1, "cell": Vector2i(0, 0), "idle": 5.0}], 1, 0.0, 100.0)
	assert_eq(got[1].key, "wash:1,1")


func test_two_helpers_never_take_the_same_task_or_station():
	var s := _crew({1: ["grill"], 2: ["grill"]})
	var b := _board({
		"stations": [{"id": "a", "cell": Vector2i(1, 0), "tool": "stove"}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["patty", "patty"]}],
		"items": [{"id": 1, "kind": "patty", "cell": Vector2i(0, 0), "state": "raw"},
			{"id": 2, "kind": "patty", "cell": Vector2i(0, 0), "state": "raw"}],
	})
	var helpers := [{"id": 1, "cell": Vector2i(0, 0), "idle": 5.0}, {"id": 2, "cell": Vector2i(0, 0), "idle": 5.0}]
	var got := b.assign(s, helpers, 1, 0.0, 100.0)
	assert_eq(got.size(), 1, "one stove, one cook at it")
	assert_eq(got[1].station, "a")
	b.done(1)
	got = b.assign(s, helpers, 1, 0.0, 100.0)
	assert_true(got.has(1) or got.has(2), "the stove is free again")


func test_a_chef_doing_a_task_takes_it_off_the_board():
	var s := _crew({1: ["carry_trays"]})
	var b := _board({"trays": [{"id": 3, "cell": Vector2i(1, 0)}]})
	assert_eq(b.chef_takes("carry:3"), -1, "no helper held it")
	assert_eq(b.assign(s, [{"id": 1, "cell": Vector2i(0, 0), "idle": 5.0}], 1, 0.0, 100.0), {})
	b.rebuild({"trays": [{"id": 3, "cell": Vector2i(1, 0)}]})
	assert_true(b.chef_keys.has("carry:3"), "the claim lasts while the task does")
	b.rebuild({})
	assert_false(b.chef_keys.has("carry:3"))


func test_a_chef_takes_what_a_helper_holds_and_the_helper_moves_on():
	var s := _crew({1: ["carry_trays"]})
	var b := _board({"trays": [{"id": 3, "cell": Vector2i(1, 0)}, {"id": 4, "cell": Vector2i(5, 0)}]})
	var h := [{"id": 1, "cell": Vector2i(0, 0), "idle": 5.0}]
	assert_eq(b.assign(s, h, 1, 0.0, 100.0)[1].key, "carry:3")
	assert_eq(b.chef_takes("carry:3"), 1)
	assert_true(b.task_of(1).is_empty())
	assert_eq(b.assign(s, h, 1, 0.0, 100.0)[1].key, "carry:4")


func test_breaks_days_off_and_falls_take_a_helper_off_the_board():
	var s := _staff()
	_hire(s, 1, ["carry_trays"], EVEN, 3, 1)
	var b := _board({"trays": [{"id": 3, "cell": Vector2i(1, 0)}]})
	var h := [{"id": 1, "cell": Vector2i(0, 0), "idle": 5.0}]
	assert_eq(b.assign(s, h, 1, 0.0, 100.0).size(), 1)
	var brk: float = Staff.break_starts(1, 100.0)[0]
	assert_eq(b.assign(s, h, 1, brk + 1.0, 100.0), {}, "on a break")
	assert_false(b.reserved.has("carry:3"), "their task goes back")
	assert_eq(b.assign(s, [{"id": 1, "cell": Vector2i(0, 0), "idle": 5.0, "down": true}], 1, 0.0, 100.0), {})
	var e := s.employee(1)
	e.week_start = 1
	e.week_off = [Staff.week_day(2)] as Array[int]
	assert_eq(b.assign(s, h, 2, 0.0, 100.0), {}, "a day off")
	assert_eq(b.assign(s, h, 1, 0.0, 100.0).size(), 1)


func test_an_unhappy_helper_reacts_slower():
	var s := _crew({1: ["carry_trays"]})
	var b := _board({"trays": [{"id": 3, "cell": Vector2i(1, 0)}]})
	s.employee(1).satisfaction = 0.0
	assert_almost_eq(JobBoard.reaction(0.0), JobBoard.REACT_BASE * (1.0 + Staff.SLOW_MAX), 0.001)
	var wait := JobBoard.REACT_BASE * 1.2
	assert_eq(b.assign(s, [{"id": 1, "cell": Vector2i(0, 0), "idle": wait}], 1, 0.0, 100.0), {})
	s.employee(1).satisfaction = 1.0
	assert_eq(b.assign(s, [{"id": 1, "cell": Vector2i(0, 0), "idle": wait}], 1, 0.0, 100.0).size(), 1)


func test_prep_odds_rise_with_skill_and_tool_quality():
	var low := JobBoard.prep_odds(1.0, Kitchen.STAND_IN)
	var mid := JobBoard.prep_odds(3.0, Kitchen.BASE)
	var high := JobBoard.prep_odds(5.0, Kitchen.SPECIALIST)
	assert_lt(low.good, mid.good)
	assert_lt(mid.good, high.good)
	assert_gt(low.bad, mid.bad)
	assert_eq(high.bad, 0.0)
	assert_lte(high.good, JobBoard.GOOD_MAX)


func test_helper_preps_roll_from_skill_and_satisfaction():
	var skilled := _crew({1: ["grill"]}, {"food": 1, "service": 3, "clean": 3})
	skilled.employee(1).satisfaction = 1.0
	var weak := _crew({1: ["grill"]}, {"food": 5, "service": 3, "clean": 3})
	weak.employee(1).satisfaction = 1.0
	var sour := _crew({1: ["grill"]}, {"food": 1, "service": 3, "clean": 3})
	sour.employee(1).satisfaction = 0.0
	var bad := {"skilled": 0, "weak": 0, "sour": 0}
	for i in 400:
		bad.skilled += int(JobBoard.roll_prep(skilled, 1, Kitchen.BASE).result == "bad")
		bad.weak += int(JobBoard.roll_prep(weak, 1, Kitchen.BASE).result == "bad")
		bad.sour += int(JobBoard.roll_prep(sour, 1, Kitchen.BASE).result == "bad")
	assert_eq(bad.skilled, 0, "a content five-star cook at a base tool never botches")
	assert_gt(bad.weak, 100)
	assert_gt(bad.sour, 60, "low satisfaction makes mistakes")
	var r := JobBoard.roll_prep(skilled, 1, Kitchen.BASE)
	assert_almost_eq(float(r.quality), Prep.quality_of(r.result), 0.0001)


func test_a_bad_helper_prep_drops_grease_by_the_floor_s_rules():
	var hits := {"bad": 0, "good": 0}
	for result in hits:
		var mess := FloorMess.new([Vector2i(0, 0)], 3)
		for i in 300:
			if JobBoard.drop_grease(mess, "fry", result, [Vector2i(0, 0)]) != null:
				hits[result] += 1
			mess.dirt.clear()
	assert_gt(hits.bad, hits.good * 2)


func test_other_tasks_roll_mistakes_from_satisfaction():
	var s := _crew({1: ["carry_trays"]})
	s.employee(1).satisfaction = 1.0
	for i in 50:
		assert_true(JobBoard.roll_task(s, 1).ok)
	s.employee(1).satisfaction = 0.0
	var slips := 0
	for i in 400:
		slips += int(not JobBoard.roll_task(s, 1).ok)
	assert_gt(slips, 60)


# ---------- The all-staff run's duties (PRD 10.7) ----------

func test_a_kind_made_from_another_s_stock_is_fetched_as_its_source():
	var b := _board({
		"stations": [{"id": "j", "cell": Vector2i(1, 0), "tool": "juicer"},
			{"id": "bl", "cell": Vector2i(2, 0), "tool": "blender"}],
		"storage": [{"cell": Vector2i(0, 0), "kinds": ["lemon", "ice_cream"]}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["lemonade", "milkshake"]}],
	})
	var lemonade: Dictionary = b.tasks["fetch:1:0"]
	assert_eq(lemonade.source, "lemon", "lemonade has no box: a lemon is fetched")
	assert_eq(lemonade.dest, Vector2i(1, 0), "to the juicer")
	assert_eq(b.tasks["fetch:1:1"].dest, Vector2i(2, 0), "ice cream to the blender")
	var steps := HelperWork.steps(lemonade, ["fetch", "juicer"], "juicer")
	assert_eq(steps[0].kind, "lemon", "the lemon's box")
	assert_eq(steps[1].hold, "raw:lemon")
	assert_eq(steps[1].kind, "lemonade")
	assert_eq(HelperWork.hold_for("milkshake"), "prep:ice_cream", "ice cream needs no prep of its own")
	assert_eq(HelperWork.hold_for("steamed_corn"), "raw:corn")
	assert_eq(HelperWork.hold_for("patty"), "raw:patty")


func test_a_source_on_its_tool_or_lying_loose_is_worked_into_the_kind():
	var b := _board({
		"stations": [{"id": Vector2i(1, 0), "cell": Vector2i(1, 0), "tool": "juicer"}],
		"items": [{"id": 4, "kind": "lemon", "cell": Vector2i(5, 0), "state": "raw"}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["lemonade"]}],
	})
	var prep: Dictionary = b.tasks["prep:4"]
	assert_eq(prep.hold, "raw:lemon")
	assert_eq(prep.duties, ["juicer"])
	var steps := HelperWork.steps(b.best_for(["juicer"], Vector2i(0, 0)), ["juicer"])
	assert_eq(steps.map(func(s: Dictionary) -> String: return str(s.do)), ["pick", "cook", "deliver"])
	assert_eq(steps[0].hold, "raw:lemon")


func test_a_ready_made_box_needs_no_tool():
	var b := _board({
		"stations": [{"id": "b", "cell": Vector2i(1, 0), "tool": "board"}],
		"storage": [{"cell": Vector2i(0, 0), "kinds": [], "ready": ["onion"]}],
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["onion"]}],
	})
	var f: Dictionary = b.tasks["fetch:1:0"]
	assert_true(f.ready)
	assert_eq(f.dest, Vector2i(3, 0), "straight to the ticket, not the board")
	var steps := HelperWork.steps(f, ["fetch", "board"], "board")
	assert_eq(steps.map(func(s: Dictionary) -> String: return str(s.do)), ["take", "deliver"])
	assert_true(steps[0].ready)


func test_a_ticket_s_tray_is_started_first_when_there_is_room():
	var w := {"storage": [{"cell": Vector2i(0, 0), "kinds": ["bun"]}], "tray_room": 1,
		"tickets": [{"id": 1, "cell": Vector2i(3, 0), "lacks": ["bun"], "tray": false},
			{"id": 2, "cell": Vector2i(3, 0), "lacks": ["bun"], "tray": false}]}
	var b := _board(w)
	assert_eq(b.tasks["tray:1"].duties, ["assemble"])
	assert_gt(b.tasks["tray:1"].urgency, b.tasks["fetch:1:0"].urgency, "the tray before its food")
	assert_false(b.tasks.has("tray:2"), "one worktop, one tray")
	assert_false(b.tasks.has("fetch:2:0"), "no tray and nowhere for its food: it waits")
	assert_eq(HelperWork.steps(b.tasks["tray:1"], ["assemble"]), [{"do": "start_tray", "ticket": 1}])
	w.tray_room = 0
	assert_eq(_board(w).tasks.size(), 0)


func test_burnt_food_on_a_tool_is_scraped_by_whoever_works_it():
	var b := _board({"burnt": [{"cell": Vector2i(1, 0), "kind": "patty", "duty": "grill"}]})
	var t: Dictionary = b.tasks["scrap:1,0"]
	assert_eq(t.duties, ["grill"])
	assert_eq(HelperWork.steps(t, ["grill"]).map(func(s: Dictionary) -> String: return str(s.do)), ["pick", "bin"])
	assert_eq(HelperWork.TASK_KIND.scrap, "food")


func test_each_cleaning_tool_takes_the_dirt_it_works_on():
	var b := _board({"dirt": {Vector2i(0, 0): 2, Vector2i(1, 0): 4, Vector2i(2, 0): 3},
		"grease": {Vector2i(2, 0): true}})
	assert_eq(b.tasks["dirt:0,0"].duties, ["mop", "sponge"])
	assert_eq(b.tasks["dirt:1,0"].duties, ["mop", "sponge", "spill_kit"], "the spill kit on a puddle only")
	assert_eq(b.tasks["dirt:2,0"].duties, ["mop", "sponge", "scraper"], "the scraper on grease only")
	assert_eq(b.best_for(["scraper"], Vector2i(0, 0)).key, "dirt:2,0")


func test_the_cleaning_trees_bring_their_line_s_duty():
	assert_eq(Staff.clean_duty("flat_mop"), "mop")
	assert_eq(Staff.clean_duty("wringer_mop"), "mop")
	assert_eq(Staff.clean_duty("scrubber"), "mop")
	assert_eq(Staff.clean_duty("scourer"), "sponge")
	assert_eq(Staff.clean_duty("grease_scraper"), "scraper")
	assert_eq(Staff.clean_duty("spill_kit"), "spill_kit")
	assert_eq(Staff.clean_duty("robot_dock"), "")
	var room := Staff.room_duties([], ["flat_mop", "hook", "scourer", "grease_scraper", "spill_kit", "robot_dock"])
	assert_eq(room.clean, ["mop", "sponge", "scraper", "spill_kit", "wash_up", "empty_bin"] as Array[String])
	assert_eq(Staff.room_duties([], ["wringer_bucket"]).clean, ["mop", "wash_up", "empty_bin"] as Array[String])


func test_a_wipe_clears_what_the_tool_and_a_cleaner_allow():
	assert_eq(HelperWork.wipe_levels(2.0, "mop"), 1)
	assert_eq(HelperWork.wipe_levels(5.0, "mop"), 2, "skill still counts")
	assert_eq(HelperWork.wipe_levels(2.0, "flat_mop"), FloorMess.MAX_LEVEL, "a flat mop clears the cell")
	assert_eq(HelperWork.wipe_levels(2.0, "spill_kit"), 2)
	assert_eq(HelperWork.wipe_levels(2.0, "mop", true), FloorMess.MAX_LEVEL, "laid with cleaner: one press")
	assert_eq(HelperWork.wipe_levels(2.0, "spill_kit", true), 2, "the spill kit's uses are its own")
