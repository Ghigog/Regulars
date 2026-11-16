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
