extends GutTest
## PRD 10: staff. Tests for each milestone in their own block.


# ================================================================ 10.1 tolerances
# (keep this block whole and at the top; 10.2 and later go below it)

func test_everyone_has_three_tolerances_from_one_to_five():
	var town := Town.new(7)
	for p in town.people:
		var tol: Dictionary = p.tolerance
		assert_eq(tol.keys().size(), 3)
		for topic in ["food", "service", "clean"]:
			assert_between(int(tol[topic]), 1, 5, "%s %s" % [p.name, topic])


func test_tolerances_are_the_same_for_a_seed_and_vary_between_seeds():
	var a := Town.new(11)
	var b := Town.new(11)
	var c := Town.new(12)
	var same := true
	var differs := false
	for i in a.people.size():
		same = same and a.people[i].tolerance == b.people[i].tolerance
		differs = differs or a.people[i].tolerance != c.people[i].tolerance
	assert_true(same)
	assert_true(differs)


func test_tolerances_leave_tastes_alone():
	var a := Town.new(5)
	var likes: Array = a.people.map(func(p: Dictionary) -> Array: return p.likes)
	a.make_tolerances()
	assert_eq(a.people.map(func(p: Dictionary) -> Array: return p.likes), likes)


func test_town_has_fussy_and_easy_going_people():
	var town := Town.new(3)
	var seen := {}
	for i in town.people.size():
		for topic in GuestMood.TOL_TOPICS:
			seen[town.tolerance(i, topic)] = true
	assert_true(seen.has(3))
	assert_true(seen.keys().any(func(t: int) -> bool: return t < 3))
	assert_true(seen.keys().any(func(t: int) -> bool: return t > 3))


func test_skill_is_six_minus_tolerance():
	assert_eq(Town.skill_for(1), 5)
	assert_eq(Town.skill_for(3), 3)
	assert_eq(Town.skill_for(5), 1)
	var town := Town.new(2)
	town.people[0].tolerance.food = 2
	assert_eq(town.skill(0, "food"), 4)


func test_tolerance_scale_points():
	assert_almost_eq(GuestMood.tolerance_scale(1), 1.6, 0.0001)
	assert_almost_eq(GuestMood.tolerance_scale(2), 1.3, 0.0001)
	assert_almost_eq(GuestMood.tolerance_scale(3), 1.0, 0.0001)
	assert_almost_eq(GuestMood.tolerance_scale(4), 0.7, 0.0001)
	assert_almost_eq(GuestMood.tolerance_scale(5), 0.4, 0.0001)


func test_a_middling_guest_matches_todays_numbers():
	var m := GuestMood.new()
	m.wait(10.0, 40.0)
	assert_almost_eq(m.patience, 0.75, 0.000001)
	m.see_gross(0.1, 2.0, "Ew")
	assert_almost_eq(m.disgust, 0.2, 0.000001)
	m.taste(1.0)
	assert_almost_eq(m.joy, 0.65, 0.000001)
	assert_eq(m.tolerance_hints(), [] as Array[String], "a 3 gives no hint")


func _mood(food: int, service: int, clean: int) -> GuestMood:
	var m := GuestMood.new()
	m.tolerance = {"food": food, "service": service, "clean": clean}
	return m


func test_service_scales_how_fast_patience_drains():
	var fussy := _mood(3, 1, 3)
	var easy := _mood(3, 5, 3)
	fussy.wait(10.0, 40.0)
	easy.wait(10.0, 40.0)
	assert_almost_eq(fussy.patience, 1.0 - 0.25 * 1.6, 0.0001)
	assert_almost_eq(easy.patience, 1.0 - 0.25 * 0.4, 0.0001)


func test_clean_scales_disgust():
	var fussy := _mood(3, 3, 1)
	var easy := _mood(3, 3, 5)
	fussy.see_gross(0.1, 2.0, "Ew")
	easy.see_gross(0.1, 2.0, "Ew")
	assert_almost_eq(fussy.disgust, 0.32, 0.0001)
	assert_almost_eq(easy.disgust, 0.08, 0.0001)


func test_food_scales_the_joy_from_quality():
	var fussy := _mood(1, 3, 3)
	var easy := _mood(5, 3, 3)
	fussy.taste(1.0)
	easy.taste(1.0)
	assert_almost_eq(fussy.joy, 0.5 + 0.15 * 1.6, 0.0001)
	assert_almost_eq(easy.joy, 0.5 + 0.15 * 0.4, 0.0001)


func test_no_hint_until_a_strong_reaction():
	var m := _mood(1, 1, 5)
	m.wait(5.0, 40.0)            # a short wait
	m.taste(0.6)                 # middling food
	m.see_gross(0.001, 1.0, "")  # too faint to notice
	assert_eq(m.tolerance_hints(), [] as Array[String])


func test_strong_reactions_reveal_hints_and_thoughts_once():
	var m := _mood(1, 1, 5)
	m.wait(20.0, 40.0)           # half a bar of waiting
	assert_eq(m.tolerance_hints(), ["Hates to wait"] as Array[String])
	assert_eq(m.latest_thought(), "I hate waiting around")
	m.see_gross(0.05, 1.0, "Ew")  # seen, but shrugged off
	m.taste(0.9)
	assert_eq(m.tolerance_hints(), ["Hates to wait", "Doesn't mind a mess", "Fussy about the food"] as Array[String])
	assert_true(m.thoughts.has("A bit of mess never hurt anyone"))
	assert_true(m.thoughts.has("I'm particular about my food"))
	var n := m.thoughts.size()
	m.wait(20.0, 40.0)
	m.taste(0.2)
	assert_eq(m.thoughts.size(), n, "each hint is thought once")


func test_poor_food_is_a_strong_reaction_too():
	var m := _mood(5, 3, 3)
	m.taste(0.3)
	assert_eq(m.tolerance_hints(), ["Not fussy about food"] as Array[String])


func test_hint_lines_never_show_numbers():
	for topic in GuestMood.TOL_HINTS:
		for line: String in GuestMood.TOL_HINTS[topic]:
			for d in "0123456789":
				assert_false(line.contains(d), line)


# ================================================================ 10.3 the desk and CVs
# These drive the game scene, set up as in test_game.gd (middling tolerances, no dirt).

var game


func _game() -> void:
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	game.test_kitchen()
	for p in game.town.people:
		p.likes = []
		p.dislikes = []
		p.tolerance = {"food": 3, "service": 3, "clean": 3}
	game.floor_dirt.drops = false


## Into the night with `desks` desks along the front wall, the chef at the first.
func _night(desks := 1) -> void:
	_game()
	game.arrivals.clear()
	for i in 20:
		game.step(0.1)
	game.open_build()
	for i in desks:
		game.add_station("desk", Vector2i(8 + i, 6))
	game.player.position = Grid.center(Vector2i(7, 6))
	game.player.look(Vector2i(1, 0))


## Applicants for the open posts, with everyone keen so some come.
func _applicants() -> Array[Dictionary]:
	for p in game.town.people:
		p.affinity = 0.5
	var fresh: Array[Dictionary] = []
	for tries in 10:
		fresh = game.roll_applicants()
		if not fresh.is_empty():
			break
	return fresh


func test_either_chef_opens_the_desk_at_night_only():
	_night()
	assert_eq(game.build_action(), "Use desk")
	game.build_interact()
	assert_true(game.hud.desk_open())
	assert_true(game.hud.card_open())
	game.close_desk()
	assert_false(game.hud.desk_open())
	game.start_day()
	assert_false(game.open_desk(), "not during service")


func test_no_desk_no_desk_screen():
	_night(0)
	assert_false(game.open_desk())


func test_post_duties_come_from_the_room():
	_night()
	var room: Dictionary = game.room_duties()
	assert_true((room.food as Array).has("grill"), "the test kitchen has stoves")
	assert_true((room.food as Array).has("fryer"), "a stove stands in for frying (PRD 8.3)")
	assert_false((room.food as Array).has("board"), "nothing in the room chops")
	assert_true((room.clean as Array).has("wash_up"))
	game.add_station("counter", Vector2i(1, 6))
	game.add_station("board", Vector2i(1, 6))
	assert_true((game.room_duties().food as Array).has("board"))


func test_posts_plus_hires_are_capped_by_desks():
	_night(1)
	assert_eq(game.desk_post("Grill cook", ["grill"], 1, 0), 1)
	assert_eq(game.desk_post("Server", ["take_orders"], 0, 0), -1, "one desk, one opening")
	game.add_station("desk", Vector2i(9, 5))
	assert_ne(game.desk_post("Server", ["take_orders"], 0, 0), -1)


func test_writing_a_post_on_the_desk_screen():
	_night()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	assert_eq(desk.tab, "posts", "an empty pile opens on the posts")
	assert_true(desk.select("write"))
	desk.press()
	assert_false(desk.drafting().is_empty())
	assert_true(desk.select("duty:grill"))
	desk.press()
	assert_true(desk.select("breaks:2"))
	desk.press()
	assert_true(desk.select("days_off:0"))
	desk.press()
	assert_true(desk.select("put_up"))
	desk.press()
	assert_true(desk.drafting().is_empty())
	assert_eq(game.staff.posts.size(), 1)
	var p: Dictionary = game.staff.posts.values()[0]
	assert_eq(p.name, DeskScreen.DEFAULT_NAME)
	assert_eq(p.duties, ["grill"] as Array[String])
	assert_eq(p.breaks, 2)
	assert_eq(p.days_off, 0)
	assert_true(desk.select("write"))
	desk.press()
	assert_true(desk.drafting().is_empty(), "the one desk is taken: Write a post is greyed")


func test_a_post_with_no_duties_cannot_go_up():
	_night()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.draft_post("Nobody", [])
	desk.put_up()
	assert_true(game.staff.posts.is_empty())


func test_applicants_line_up_outside_and_their_cvs_go_in_the_pile():
	_night()
	game.desk_post("Grill cook", ["grill", "fetch"], 1, 1)
	var fresh := _applicants()
	assert_false(fresh.is_empty())
	assert_eq(game.applicants.size(), fresh.size())
	for cv in fresh:
		var rig: Node3D = game.applicants[cv.person]
		assert_gt(rig.position.x, float(game.W), "outside, on the pavement")
	assert_not_null(game.find_station("desk").get_node_or_null("pile"), "the pile on the desk")
	game.start_day()
	assert_true(game.applicants.is_empty(), "the line goes home for the day")
	assert_eq(game.staff.cvs.size(), fresh.size(), "unread CVs stay in the pile")


func test_applicants_come_at_the_start_of_the_build_phase():
	_game()
	game.add_station("desk", Vector2i(8, 6))
	game.staff.add_post("Grill cook", ["grill"], 0, 0, 1)
	for p in game.town.people:
		p.affinity = 1.0
	game.arrivals.clear()
	for i in 20:
		game.step(0.1)
	assert_true(game.staff.cvs.is_empty(), "not on the receipt")
	game.open_build()
	assert_false(game.staff.cvs.is_empty())


func test_swipe_right_hires_at_the_ask():
	_night()
	game.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	assert_eq(desk.tab, "cvs", "a pile opens on the CVs")
	var cv: Dictionary = game.staff.cvs[0]
	desk.drag_to(DeskScreen.SWIPE + 20)
	desk.hire_top()
	var e: Dictionary = game.staff.employee(cv.person)
	assert_false(e.is_empty())
	assert_eq(e.wage, cv.ask)
	assert_eq(e.post_name, "Grill cook")
	assert_true(game.staff.posts.is_empty(), "the opening is filled")
	assert_true(game.staff.cvs.is_empty(), "the post's other CVs go")
	assert_true(game.applicants.is_empty(), "everyone in its line goes")


func test_swipe_left_dismisses_and_a_mouse_drag_swipes():
	_night()
	game.desk_post("Grill cook", ["grill"], 1, 1)
	var fresh := _applicants()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	var first: Dictionary = game.staff.cvs[0]
	desk.dismiss_top()
	assert_true(game.staff.cv(first.id).is_empty())
	assert_false(game.applicants.has(first.person))
	assert_true(game.staff.employees.is_empty())
	if fresh.size() > 1:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.global_position = Vector2(500, 300)
		desk._cv_input(down)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.global_position = Vector2(500 + DeskScreen.SWIPE + 30, 300)
		desk._cv_input(up)
		assert_eq(game.staff.employees.size(), 1, "dragged right: hired")


func test_hire_and_dismiss_buttons_from_keys_or_pad():
	_night()
	game.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	assert_eq(desk.selected(), "hire")
	game.act(0, "use")
	assert_eq(game.staff.employees.size(), 1)


func test_haggling_at_hire():
	_night()
	game.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	var cv: Dictionary = game.staff.cvs[0]
	desk.start_haggle()
	assert_eq(desk.selected(), "offer")
	assert_eq(desk.make_offer(int(cv.ask)), "accept", "the full ask is always taken")
	assert_eq(game.staff.employee(cv.person).wage, cv.ask)


func test_a_haggle_far_below_the_ask_is_refused_then_decided():
	_night()
	game.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	var cv: Dictionary = game.staff.cvs[0]
	desk.start_haggle()
	assert_eq(desk.make_offer(1), "refuse", "a coin a day: never")
	var r := desk.make_offer(1)
	assert_true(r in ["take_last", "walk"], "after two refusals they decide")
	if r == "walk":
		assert_true(game.staff.cv(cv.id).is_empty())
		assert_true(game.staff.employees.is_empty())
	else:
		assert_eq(game.staff.employee(cv.person).wage, 1)


func test_taking_a_post_down_clears_its_cvs_and_line():
	_night()
	var id: int = game.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	game.desk_take_down(id)
	assert_true(game.staff.posts.is_empty())
	assert_true(game.staff.cvs.is_empty())
	assert_true(game.applicants.is_empty())
	assert_null(game.find_station("desk").get_node_or_null("pile"))


func test_a_desk_in_use_cannot_be_sold():
	_night(1)
	game.desk_post("Grill cook", ["grill"], 1, 1)
	assert_true(game.pick_up(Grid.center(Vector2i(8, 6))))
	assert_ne(game.sell_block(), "", "the post needs its desk")
	assert_false(game.sell_hand())


func test_staff_do_not_come_as_guests():
	_night()
	game.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	var person := int(game.staff.cvs[0].person)
	game.desk_hire(int(game.staff.cvs[0].id))
	for p in game.town.people:
		p.affinity = 1.0
	game.start_day()
	for a in game.arrivals:
		if a.has("group"):
			assert_false((a.group as Array).has(person), "they work here now")


# ================================================================ 10.4 the staff list

## A hire straight into the staff, at their ask, as if swiped right.
func _hire_one(person := 3, duties := ["grill", "fetch"], breaks := 1, days_off := 1) -> int:
	var pid: int = game.staff.add_post("Grill cook", duties, breaks, days_off, 99)
	var cv: Dictionary = game.staff._make_cv(person, Staff.skills_from(game.town.people[person].tolerance), 3, 1.0, pid)
	game.staff.cvs.append(cv)
	game.staff.hire(cv.id, -1, game.ledger.day)
	return person


func test_the_staff_tab_lists_each_hire_with_manage():
	_night(2)
	var p := _hire_one()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	assert_eq(desk.tab, "staff", "an empty pile with staff opens on the staff")
	assert_true(desk.select("manage:%d" % p))
	desk.press()
	assert_eq(desk.managing(), p)
	desk.back()
	assert_eq(desk.managing(), -1)
	assert_eq(desk.selected(), "manage:%d" % p)


func test_ticking_a_duty_offers_it_and_unticking_takes_it_off():
	_night()
	var p := _hire_one()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.open_person(p)
	var e: Dictionary = game.staff.employee(p)
	e.satisfaction = 1.0
	game.staff.rng.seed = 1
	assert_true(desk.select("duty:wash_up"))
	desk.press()
	assert_true((e.duties as Array).has("wash_up"), "a happy hire takes it on")
	e.satisfaction = 0.5
	var sat: float = e.satisfaction
	assert_true(desk.select("duty:wash_up"))
	desk.press()
	assert_false((e.duties as Array).has("wash_up"))
	assert_gt(e.satisfaction, sat, "free, and they are glad")


func _refused(p: int) -> Dictionary:
	var e: Dictionary = game.staff.employee(p)
	e.satisfaction = 0.0
	for tries in 20:
		if not game.desk_add_duty(p, "wash_up").ok:
			break
		game.staff.remove_duty(p, "wash_up")
		e.satisfaction = 0.0
	return e


func test_a_refused_duty_names_a_raise_to_approve():
	_night()
	var p := _hire_one()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.open_person(p)
	var e := _refused(p)
	assert_false((e.pending as Dictionary).is_empty())
	desk.render()
	assert_true(desk.select("approve"))
	var wage := int(e.wage) + int(e.pending.raise)
	desk.press()
	assert_eq(int(e.wage), wage)
	assert_true((e.duties as Array).has("wash_up"))


func test_a_raise_can_be_withdrawn_or_denied():
	_night()
	var p := _hire_one()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.open_person(p)
	var e := _refused(p)
	var wage := int(e.wage)
	assert_eq(desk.answer_raise("withdraw"), "withdrawn")
	assert_eq(int(e.wage), wage)
	assert_false((e.duties as Array).has("wash_up"))
	_refused(p)
	assert_eq(desk.answer_raise("deny"), "quit")
	assert_true(game.staff.employee(p).is_empty(), "denied, they quit")
	assert_eq(desk.managing(), -1)


func test_a_raise_haggled_is_refused_then_decided():
	_night()
	var p := _hire_one()
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.open_person(p)
	var e := _refused(p)
	desk.start_raise_haggle(0)
	assert_eq(desk.selected(), "raise_offer")
	var r := desk.answer_raise("haggle", 0)
	if r == "refuse":
		r = desk.answer_raise("haggle", 0)
	assert_true(r in ["added", "quit"], "after two refusals they take it or go")


func test_breaks_and_days_off_are_added_at_the_desk():
	_night()
	var p := _hire_one(3, ["grill"], 0, 0)
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.open_person(p)
	assert_true(desk.select("break"))
	desk.press()
	assert_true(desk.select("day_off"))
	desk.press()
	assert_eq(int(game.staff.employee(p).breaks), 1)
	assert_eq(int(game.staff.employee(p).days_off), 1)


func test_firing_with_severance_pays_a_day_and_without_friends_hear():
	_night(2)
	var a := _hire_one(3)
	var b := _hire_one(4)
	for x in game.town.people:
		x.affinity = 0.5
	game.ledger.money = 100
	var wage := int(game.staff.employee(a).wage)
	game.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.open_person(a)
	assert_true(desk.select("fire"))
	desk.press()
	assert_true(desk.select("fire_pay"))
	desk.press()
	assert_true(game.staff.employee(a).is_empty())
	assert_eq(game.ledger.money, 100 - wage)
	assert_almost_eq(float(game.town.people[a].affinity), 0.5 - Staff.FIRE_DROP, 0.0001)
	assert_true(game.desk_fire(b, false))
	assert_eq(game.ledger.money, 100 - wage, "nothing paid")
	assert_almost_eq(float(game.town.people[b].affinity), 0.5 - Staff.FIRE_DROP_HARSH, 0.0001)
	for f: int in game.town.people[b].friends:
		if f != a:
			assert_lt(float(game.town.people[f].affinity), 0.5, "friends hear it")


func test_severance_needs_the_money():
	_night()
	var p := _hire_one()
	game.ledger.money = 0
	assert_false(game.desk_fire(p, true))
	assert_false(game.staff.employee(p).is_empty())


func test_wages_are_paid_as_the_door_opens_on_the_receipt():
	_night()
	var p := _hire_one()
	var wage := int(game.staff.employee(p).wage)
	game.ledger.money = 500
	assert_eq(game.staff_wages(), wage)
	game.start_day()
	assert_eq(game.ledger.today.staff, wage)
	game.arrivals.clear()
	for i in 20:
		game.step(0.1)
	assert_eq(int(game.last_day.staff), wage)
	var found: bool = game.hud.find_children("*", "Label", true, false).any(
		func(l: Label) -> bool: return l.text == "STAFF:")
	assert_true(found, "a STAFF line on the receipt")


func test_an_unpaid_wage_is_a_hit_not_a_debt():
	_night()
	var p := _hire_one()
	var e: Dictionary = game.staff.employee(p)
	game.ledger.money = game.night_cost()   # the stock, and nothing for wages
	var sat: float = e.satisfaction
	game.start_day()
	assert_eq(game.ledger.today.staff, 0)
	assert_eq(game.ledger.today.unpaid, 1)
	assert_lt(float(e.satisfaction), sat - Staff.UNPAID_HIT + 0.05)


func test_staff_quit_after_nights_at_the_bottom():
	_night()
	var p := _hire_one()
	var e: Dictionary = game.staff.employee(p)
	e.satisfaction = 0.0
	e.bottom_nights = Staff.QUIT_NIGHTS - 1
	e.wage = 999   # far more than there is: unpaid, and at the bottom
	game.ledger.money = game.night_cost()
	game.start_day()
	assert_true(game.staff.employee(p).is_empty(), "they quit")


func test_days_off_are_picked_as_a_week_starts():
	_game()
	game.arrivals.clear()
	_hire_one(3, ["grill"], 0, 2)
	for i in 20:
		game.step(0.1)
	game.ledger.day = 6
	game.open_build()
	assert_true(game.staff.picked_week(3, 6))
	var off: Array = game.staff.week_boxes(3, 6).filter(func(b: Dictionary) -> bool: return b.off)
	assert_eq(off.size(), 2)
