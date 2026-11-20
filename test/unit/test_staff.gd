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
	game.menu_stock.test_kitchen()
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
	game.session.open_build()
	for i in desks:
		game.world.add_station("desk", Vector2i(8 + i, 6))
	game.player.position = Grid.center(Vector2i(7, 6))
	game.player.look(Vector2i(1, 0))


## Applicants for the open posts, with everyone keen so some come.
func _applicants() -> Array[Dictionary]:
	for p in game.town.people:
		p.affinity = 0.5
	var fresh: Array[Dictionary] = []
	for tries in 10:
		fresh = game.desk.roll_applicants()
		if not fresh.is_empty():
			break
	return fresh


func test_either_chef_opens_the_desk_at_night_only():
	_night()
	assert_eq(game.room_edit.build_action(), "Use desk")
	game.room_edit.build_interact()
	assert_true(game.hud.desk_open())
	assert_true(game.hud.card_open())
	game.desk.close_desk()
	assert_false(game.hud.desk_open())
	game.day.start_day()
	assert_false(game.desk.open_desk(), "not during service")


func test_no_desk_no_desk_screen():
	_night(0)
	assert_false(game.desk.open_desk())


func test_post_duties_come_from_the_room():
	_night()
	var room: Dictionary = game.desk.room_duties()
	assert_true((room.food as Array).has("grill"), "the test kitchen has stoves")
	assert_true((room.food as Array).has("fryer"), "a stove stands in for frying (PRD 8.3)")
	assert_false((room.food as Array).has("board"), "nothing in the room chops")
	assert_true((room.clean as Array).has("wash_up"))
	game.world.add_station("counter", Vector2i(1, 6))
	game.world.add_station("board", Vector2i(1, 6))
	assert_true((game.desk.room_duties().food as Array).has("board"))


func test_posts_plus_hires_are_capped_by_desks():
	_night(1)
	assert_eq(game.desk.desk_post("Grill cook", ["grill"], 1, 0), 1)
	assert_eq(game.desk.desk_post("Server", ["take_orders"], 0, 0), -1, "one desk, one opening")
	game.world.add_station("desk", Vector2i(9, 5))
	assert_ne(game.desk.desk_post("Server", ["take_orders"], 0, 0), -1)


func test_writing_a_post_on_the_desk_screen():
	_night()
	game.desk.open_desk()
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
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.draft_post("Nobody", [])
	desk.put_up()
	assert_true(game.staff.posts.is_empty())


func test_applicants_line_up_outside_and_their_cvs_go_in_the_pile():
	_night()
	game.desk.desk_post("Grill cook", ["grill", "fetch"], 1, 1)
	var fresh := _applicants()
	assert_false(fresh.is_empty())
	assert_eq(game.applicants.size(), fresh.size())
	for cv in fresh:
		var rig: Node3D = game.applicants[cv.person]
		assert_gt(rig.position.x, float(game.W), "outside, on the pavement")
	assert_not_null(game.world.find_station("desk").get_node_or_null("pile"), "the pile on the desk")
	game.day.start_day()
	assert_true(game.applicants.is_empty(), "the line goes home for the day")
	assert_eq(game.staff.cvs.size(), fresh.size(), "unread CVs stay in the pile")


func test_applicants_come_at_the_start_of_the_build_phase():
	_game()
	game.world.add_station("desk", Vector2i(8, 6))
	game.staff.add_post("Grill cook", ["grill"], 0, 0, 1)
	for p in game.town.people:
		p.affinity = 1.0
	game.arrivals.clear()
	for i in 20:
		game.step(0.1)
	assert_true(game.staff.cvs.is_empty(), "not on the receipt")
	game.session.open_build()
	assert_false(game.staff.cvs.is_empty())


func test_swipe_right_hires_at_the_ask():
	_night()
	game.desk.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	assert_eq(desk.tab, "cvs", "a pile opens on the CVs")
	var cv: Dictionary = game.staff.cvs[0]
	desk.drag_to(DeskScreen.SWIPE + 20)
	desk.posting.hire_top()
	var e: Dictionary = game.staff.employee(cv.person)
	assert_false(e.is_empty())
	assert_eq(e.wage, cv.ask)
	assert_eq(e.post_name, "Grill cook")
	assert_true(game.staff.posts.is_empty(), "the opening is filled")
	assert_true(game.staff.cvs.is_empty(), "the post's other CVs go")
	assert_true(game.applicants.is_empty(), "everyone in its line goes")


func test_swipe_left_dismisses_and_a_mouse_drag_swipes():
	_night()
	game.desk.desk_post("Grill cook", ["grill"], 1, 1)
	var fresh := _applicants()
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	var first: Dictionary = game.staff.cvs[0]
	desk.posting.dismiss_top()
	assert_true(game.staff.cv(first.id).is_empty())
	assert_false(game.applicants.has(first.person))
	assert_true(game.staff.employees.is_empty())
	if fresh.size() > 1:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.global_position = Vector2(500, 300)
		desk._cv_input(down, desk._cv_card, 0)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.global_position = Vector2(500 + DeskScreen.SWIPE + 30, 300)
		desk._cv_input(up, desk._cv_card, 0)
		assert_eq(game.staff.employees.size(), 1, "dragged right: hired")


func test_hire_and_dismiss_buttons_from_keys_or_pad():
	_night()
	game.desk.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	assert_eq(desk.selected(), "hire")
	game.coop.act(0, "use")
	assert_eq(game.staff.employees.size(), 1)


func test_haggling_at_hire():
	_night()
	game.desk.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	var cv: Dictionary = game.staff.cvs[0]
	desk.start_haggle()
	assert_eq(desk.selected(), "offer")
	assert_eq(desk.posting.make_offer(int(cv.ask)), "accept", "the full ask is always taken")
	assert_eq(game.staff.employee(cv.person).wage, cv.ask)


func test_a_haggle_far_below_the_ask_is_refused_then_decided():
	_night()
	game.desk.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	var cv: Dictionary = game.staff.cvs[0]
	desk.start_haggle()
	assert_eq(desk.posting.make_offer(1), "refuse", "a coin a day: never")
	var r := desk.posting.make_offer(1)
	assert_true(r in ["take_last", "walk"], "after two refusals they decide")
	if r == "walk":
		assert_true(game.staff.cv(cv.id).is_empty())
		assert_true(game.staff.employees.is_empty())
	else:
		assert_eq(game.staff.employee(cv.person).wage, 1)


func test_taking_a_post_down_clears_its_cvs_and_line():
	_night()
	var id: int = game.desk.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	game.desk.desk_take_down(id)
	assert_true(game.staff.posts.is_empty())
	assert_true(game.staff.cvs.is_empty())
	assert_true(game.applicants.is_empty())
	assert_null(game.world.find_station("desk").get_node_or_null("pile"))


func test_a_desk_in_use_cannot_be_sold():
	_night(1)
	game.desk.desk_post("Grill cook", ["grill"], 1, 1)
	assert_true(game.placing.pick_up(Grid.center(Vector2i(8, 6))))
	assert_ne(game.placing.sell_block(), "", "the post needs its desk")
	assert_false(game.placing.sell_hand())


func test_staff_do_not_come_as_guests():
	_night()
	game.desk.desk_post("Grill cook", ["grill"], 1, 1)
	_applicants()
	var person := int(game.staff.cvs[0].person)
	game.desk.desk_hire(int(game.staff.cvs[0].id))
	for p in game.town.people:
		p.affinity = 1.0
	game.day.start_day()
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
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	assert_eq(desk.tab, "staff", "an empty pile with staff opens on the staff")
	assert_true(desk.select("manage:%d" % p))
	desk.press()
	assert_eq(desk.staff_ui.managing(), p)
	desk.back()
	assert_eq(desk.staff_ui.managing(), -1)
	assert_eq(desk.selected(), "manage:%d" % p)


func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		out.append_array(_texts(c))
	return out


func test_the_staff_tab_shows_total_wages_big_and_no_footer_text():
	_night(2)
	var a := _hire_one(3)
	var b := _hire_one(4)
	game.staff.employees[a].wage = 27
	game.staff.employees[b].wage = 20
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	var wages := desk._content.find_child("Wages", true, false) as Label
	assert_not_null(wages)
	assert_eq(wages.text, "$47")
	for t in _texts(desk._content):
		assert_false("Wages tonight" in t)
		assert_false("Arrows choose" in t)
	game.staff.employees[a].wage = 30
	desk.pages.render()
	assert_eq((desk._content.find_child("Wages", true, false) as Label).text, "$50")


func test_no_wages_figure_without_hires():
	_night()
	game.desk.open_desk()
	assert_null(game.hud.desk._content.find_child("Wages", true, false))


func test_ticking_a_duty_offers_it_and_unticking_takes_it_off():
	_night()
	var p := _hire_one()
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.staff_ui.open_person(p)
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
		if not game.desk.desk_add_duty(p, "wash_up").ok:
			break
		game.staff.remove_duty(p, "wash_up")
		e.satisfaction = 0.0
	return e


func test_a_refused_duty_names_a_raise_to_approve():
	_night()
	var p := _hire_one()
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.staff_ui.open_person(p)
	var e := _refused(p)
	assert_false((e.pending as Dictionary).is_empty())
	desk.pages.render()
	assert_true(desk.select("approve"))
	var wage := int(e.wage) + int(e.pending.raise)
	desk.press()
	assert_eq(int(e.wage), wage)
	assert_true((e.duties as Array).has("wash_up"))


func test_a_raise_can_be_withdrawn_or_denied():
	_night()
	var p := _hire_one()
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.staff_ui.open_person(p)
	var e := _refused(p)
	var wage := int(e.wage)
	assert_eq(desk.staff_ui.answer_raise("withdraw"), "withdrawn")
	assert_eq(int(e.wage), wage)
	assert_false((e.duties as Array).has("wash_up"))
	_refused(p)
	assert_eq(desk.staff_ui.answer_raise("deny"), "quit")
	assert_true(game.staff.employee(p).is_empty(), "denied, they quit")
	assert_eq(desk.staff_ui.managing(), -1)


func test_a_raise_haggled_is_refused_then_decided():
	_night()
	var p := _hire_one()
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.staff_ui.open_person(p)
	var e := _refused(p)
	desk.staff_ui.start_raise_haggle(0)
	assert_eq(desk.selected(), "raise_offer")
	var r := desk.staff_ui.answer_raise("haggle", 0)
	if r == "refuse":
		r = desk.staff_ui.answer_raise("haggle", 0)
	assert_true(r in ["added", "quit"], "after two refusals they take it or go")


func test_breaks_and_days_off_are_added_at_the_desk():
	_night()
	var p := _hire_one(3, ["grill"], 0, 0)
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.staff_ui.open_person(p)
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
	game.desk.open_desk()
	var desk: DeskScreen = game.hud.desk
	desk.staff_ui.open_person(a)
	assert_true(desk.select("fire"))
	desk.press()
	assert_true(desk.select("fire_pay"))
	desk.press()
	assert_true(game.staff.employee(a).is_empty())
	assert_eq(game.ledger.money, 100 - wage)
	assert_almost_eq(float(game.town.people[a].affinity), 0.5 - Staff.FIRE_DROP, 0.0001)
	assert_true(game.desk.desk_fire(b, false))
	assert_eq(game.ledger.money, 100 - wage, "nothing paid")
	assert_almost_eq(float(game.town.people[b].affinity), 0.5 - Staff.FIRE_DROP_HARSH, 0.0001)
	for f: int in game.town.people[b].friends:
		if f != a:
			assert_lt(float(game.town.people[f].affinity), 0.5, "friends hear it")


func test_severance_needs_the_money():
	_night()
	var p := _hire_one()
	game.ledger.money = 0
	assert_false(game.desk.desk_fire(p, true))
	assert_false(game.staff.employee(p).is_empty())


func test_wages_are_paid_as_the_door_opens_on_the_receipt():
	_night()
	var p := _hire_one()
	var wage := int(game.staff.employee(p).wage)
	game.ledger.money = 500
	assert_eq(game.desk.staff_wages(), wage)
	game.day.start_day()
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
	game.ledger.money = game.menu_stock.night_cost()   # the stock, and nothing for wages
	var sat: float = e.satisfaction
	game.day.start_day()
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
	game.ledger.money = game.menu_stock.night_cost()
	game.day.start_day()
	assert_true(game.staff.employee(p).is_empty(), "they quit")


func test_days_off_are_picked_as_a_week_starts():
	_game()
	game.arrivals.clear()
	_hire_one(3, ["grill"], 0, 2)
	for i in 20:
		game.step(0.1)
	game.ledger.day = 6
	game.session.open_build()
	assert_true(game.staff.picked_week(3, 6))
	var off: Array = game.staff.week_boxes(3, 6).filter(func(b: Dictionary) -> bool: return b.off)
	assert_eq(off.size(), 2)


# ================================================================ 10.6 helpers in the room

# ---------- How a helper works (sim/helper_work.gd) ----------

func test_better_rated_helpers_walk_and_work_faster():
	assert_lt(HelperWork.walk_speed(1), HelperWork.walk_speed(5))
	assert_lt(HelperWork.walk_speed(5), Player.SPEED, "no helper outruns a chef")
	assert_gt(HelperWork.work_time(1.0, 1, 1.0), HelperWork.work_time(1.0, 5, 1.0))
	assert_almost_eq(HelperWork.work_time(1.0, 5, 1.0), 1.0, 0.0001)


func test_low_satisfaction_slows_their_work():
	assert_gt(HelperWork.work_time(1.0, 3, 0.0), HelperWork.work_time(1.0, 3, 0.9))
	assert_almost_eq(HelperWork.work_time(1.0, 3, 0.0) / HelperWork.work_time(1.0, 3, 0.9), 1.0 + Staff.SLOW_MAX, 0.0001)


func test_a_fetch_is_cooked_by_a_cook_and_left_for_one_otherwise():
	var task := {"type": "fetch", "cell": Vector2i(0, 2), "kind": "patty", "job": "grill", "dest": Vector2i(0, 3), "ticket": 4}
	var cook := HelperWork.steps(task, ["fetch", "grill", "assemble"], "grill")
	assert_eq(cook.map(func(s: Dictionary) -> String: return s.do), ["take", "cook", "deliver"])
	assert_eq(cook[1].at, Vector2i(0, 3))
	assert_true(cook[2].assemble, "with the assemble duty it goes on the plate")
	var runner := HelperWork.steps(task, ["fetch"], "grill")
	assert_eq(runner.map(func(s: Dictionary) -> String: return s.do), ["take", "leave"])
	var bun := HelperWork.steps({"type": "fetch", "cell": Vector2i(0, 6), "kind": "bun", "job": "none", "dest": Vector2i(4, 4), "ticket": 4}, ["fetch"])
	assert_eq(bun.map(func(s: Dictionary) -> String: return s.do), ["take", "deliver"])
	assert_false(bun[1].assemble)


func test_prep_steps_pick_up_cook_in_place_or_pour():
	var moved := HelperWork.steps({"type": "prep", "cell": Vector2i(4, 3), "station": Vector2i(0, 3), "kind": "patty",
		"job": "grill", "item": "c:4,3", "ticket": 1}, ["grill"])
	assert_eq(moved.map(func(s: Dictionary) -> String: return s.do), ["pick", "cook", "deliver"])
	var here := HelperWork.steps({"type": "prep", "cell": Vector2i(5, 2), "station": Vector2i(5, 2), "kind": "lettuce",
		"job": "chop", "item": "c:5,2", "ticket": 1}, ["board"])
	assert_eq(here.map(func(s: Dictionary) -> String: return s.do), ["cook", "deliver"])
	assert_true(here[0].in_place)
	var pour := HelperWork.steps({"type": "prep", "cell": Vector2i(1, 2), "station": Vector2i(1, 2), "kind": "soda",
		"job": "pour", "item": null, "ticket": 1}, ["tap"])
	assert_eq(pour.map(func(s: Dictionary) -> String: return s.do), ["get_cup", "pour", "set_out"], "into the ticket's cup")


func test_serving_and_cleaning_steps():
	var c := Vector2i(6, 1)
	assert_eq(HelperWork.steps({"type": "carry", "cell": Vector2i(4, 4), "cells": [Vector2i(4, 4), Vector2i(4, 5)], "table": c}, []).map(
		func(s: Dictionary) -> String: return s.do), ["pick_dish", "pick_dish", "serve"], "two plates a trip")
	assert_eq(HelperWork.steps({"type": "tidy", "cell": Vector2i(4, 4)}, []).map(
		func(s: Dictionary) -> String: return s.do), ["pick_dish", "bin", "restack"])
	assert_eq(HelperWork.steps({"type": "order", "cell": c}, [])[0].do, "order")
	assert_eq(HelperWork.steps({"type": "clear", "cell": c}, []).map(func(s: Dictionary) -> String: return s.do), ["clear", "to_sink"])
	assert_eq(HelperWork.steps({"type": "bin", "cell": c}, []).map(func(s: Dictionary) -> String: return s.do), ["empty_bin", "to_outside_bin"])
	assert_eq(HelperWork.steps({"type": "wash", "cell": c}, [])[0].do, "wash")
	assert_eq(HelperWork.steps({"type": "help_up", "cell": c, "person": 7}, [])[0].do, "help")
	var wipe := HelperWork.steps({"type": "dirt", "cell": c}, ["sponge", "mop"])
	assert_eq(wipe[0].tool, "mop", "a mop before a sponge")
	assert_eq(HelperWork.steps({"type": "nothing"}, []), [])


func test_what_is_in_hand_is_put_away_where_it_belongs():
	assert_eq(HelperWork.stash_for(""), "")
	assert_eq(HelperWork.stash_for("dirty_dishes"), "to_sink")
	assert_eq(HelperWork.stash_for("rubbish_bag"), "to_outside_bin")
	assert_eq(HelperWork.stash_for("burnt:patty"), "bin")
	assert_eq(HelperWork.stash_for("tool:mop"), "drop")
	assert_eq(HelperWork.stash_for("prep:patty"), "stash")
	assert_eq(HelperWork.stash_for("dishes"), "stash")


func test_made_food_covers_the_oldest_ticket_first():
	var lacks := HelperWork.ticket_lacks([{"id": 1, "needs": ["bun", "patty"]}, {"id": 2, "needs": ["bun", "patty"]}],
		["patty", "bun", "bun"])
	assert_eq(lacks[1], [])
	assert_eq(lacks[2], ["patty"])


func test_free_helpers_close_together_chat_in_pairs():
	var pairs := HelperWork.chat_pairs([{"id": 1, "cell": Vector2i(0, 0)}, {"id": 2, "cell": Vector2i(1, 0)},
		{"id": 3, "cell": Vector2i(2, 0)}, {"id": 4, "cell": Vector2i(9, 9)}])
	assert_eq(pairs.size(), 1, "three in a row make one pair; the far one is alone")
	assert_eq(pairs[0], [1, 2])
	assert_eq(HelperWork.chat_pairs([{"id": 1, "cell": Vector2i(0, 0)}, {"id": 2, "cell": Vector2i(3, 0)}]), [])


func test_an_idle_helper_waits_beside_a_desk():
	var open := {Vector2i(8, 5): true, Vector2i(7, 6): true}
	assert_eq(HelperWork.wait_cell([Vector2i(8, 6)], open, {}, Vector2i(2, 2)), Vector2i(8, 5))
	assert_eq(HelperWork.wait_cell([Vector2i(8, 6)], open, {Vector2i(8, 5): true}, Vector2i(2, 2)), Vector2i(7, 6))
	assert_null(HelperWork.wait_cell([Vector2i(8, 6)], {}, {}, Vector2i(2, 2)))


func test_dirt_wears_down_a_helper_who_minds_it():
	assert_eq(HelperWork.work_drain(5.0, 4, 1.0), 0.0, "tolerance 5 does not mind")
	assert_eq(HelperWork.work_drain(1.0, 2, 1.0), 0.0, "a little dirt is nothing")
	assert_gt(HelperWork.work_drain(1.0, 3, 1.0), 0.0)
	assert_gt(HelperWork.work_drain(1.0, 4, 1.0), HelperWork.work_drain(1.0, 3, 1.0))


func test_skill_sets_a_wipe_and_how_a_guest_likes_being_served():
	assert_eq(HelperWork.wipe_levels(5.0), 2)
	assert_eq(HelperWork.wipe_levels(2.0), 1)
	assert_gt(HelperWork.serve_joy(5.0), 0.0)
	assert_eq(HelperWork.serve_joy(3.0), 0.0)
	assert_lt(HelperWork.serve_joy(1.0), 0.0)


# ---------- Helpers in the room (game/crew.gd) ----------

func _run(seconds: float) -> void:
	for i in int(seconds / 0.1):
		game.step(0.1)


## A hire at work in the room today, standing at `at`.
func _helper(person: int, duties: Array, at := Vector2i(5, 4), breaks := 0) -> Helper:
	_hire_one(person, duties, breaks, 0)
	game.staff.employee(person).satisfaction = 0.9   # no slips or slowness unless a test wants them
	return game.crew.add_helper(person, at)


func _seated(idx := 0) -> Guest:
	var g: Guest = game.seating.spawn_guest(idx)
	_run(12.0)
	return g


func test_staff_walk_in_as_the_door_opens_and_go_home_as_the_day_ends():
	_game()
	_hire_one(3, ["take_orders"], 0, 0)
	_hire_one(4, ["wash_up"], 0, 1)
	game.staff.employee(4).week_start = game.ledger.day
	game.staff.employee(4).week_off = [Staff.week_day(game.ledger.day)] as Array[int]
	game.crew.start_day()
	assert_eq(game.crew.helpers.size(), 1, "the one with today off stays home")
	var h: Helper = game.crew.helpers[0]
	assert_eq(h.person, 3)
	assert_eq(h.cell(), game.DOOR, "in through the front door")
	assert_true(game.serving.hands().has(h))
	game.arrivals.clear()
	_run(0.5)
	assert_true(game.crew.helpers.is_empty(), "the day ended and they went home")


func test_a_server_takes_a_tables_order():
	_game()
	var g := _seated()
	assert_eq(g.state, "ordering")
	_helper(3, ["take_orders"])
	_run(8.0)
	assert_eq(game.tickets.size(), 1, "the helper took the order")
	assert_eq(g.state, "waiting")


func test_a_grill_cook_and_server_make_and_serve_a_whole_meal():
	_game()
	var g := _seated()
	var h := _helper(3, ["take_orders", "fetch", "grill", "assemble", "carry_trays"])
	var ate := false
	for i in 900:
		game.step(0.1)
		g.mood.patience = 1.0   # one helper doing it all is slow: the guest waits
		if g.state == "eating":
			ate = true
			break
	assert_true(ate, "ordered, grilled, built and carried with no chef")
	assert_eq(h.held, "", "hands free again")
	assert_gt(float(game.staff.employee(3).skills.food), 3.0, "the cooking trained them")


func test_a_helper_with_no_assemble_duty_leaves_the_cooking_for_others():
	_game()
	var g := _seated()
	_order_by_chef(g)
	_helper(3, ["fetch", "grill"])
	_run(30.0)
	var made: Array = game.stations.values().filter(func(st: Station) -> bool: return st.item == "prep:" + game.world.fixed_main().grill)
	assert_eq(made.size(), 1, "the patty is grilled and put down for someone to plate")
	assert_eq(game.crew.task_end._tagged(int(game.tickets[0].id)), [], "nobody set out a plate")


func _order_by_chef(g: Guest) -> void:
	game.cooking.use_station(g.table)
	assert_eq(game.tickets.size(), 1)


func test_a_washer_washes_up_into_the_plate_stack():
	_game()
	var sink: Station = game.world.find_station("sink")
	var stack: Station = game.world.find_station("plates")
	sink.dirty = 2
	var before := stack.count
	_helper(3, ["wash_up"], Vector2i(3, 3))
	_run(10.0)
	assert_eq(sink.dirty, 0)
	assert_eq(stack.count, before + 2)


func test_a_full_bin_is_emptied_and_the_bag_goes_out_the_front():
	_game()
	var bin: Station = game.world.find_station("bin")
	bin.count = Crew.BIN_FULL
	var h := _helper(3, ["empty_bin"], Vector2i(1, 5))
	var carried := false
	for i in 200:
		game.step(0.1)
		carried = carried or h.held == "rubbish_bag"
	assert_eq(bin.count, 0)
	assert_true(carried, "the bag was carried out")
	assert_eq(h.held, "")


func test_a_table_is_cleared_into_the_sink():
	_game()
	var table: Station = game.stations[Vector2i(6, 5)]
	var sink: Station = game.world.find_station("sink")
	table.dirty = 1
	_helper(3, ["clear_tables"])
	_run(15.0)
	assert_eq(table.dirty, 0)
	assert_eq(sink.dirty, 1)


func test_a_cleaner_mops_dirt_off_the_floor():
	_game()
	var c := Vector2i(6, 3)
	var mess: FloorMess = game.floor_dirt.mess
	mess.dirt[c] = 3
	var h := _helper(3, ["mop"], Vector2i(7, 3))
	_run(10.0)
	assert_eq(mess.level(c), 0)
	assert_false(h.held.begins_with(CleanKit.PREFIX), "the mop is put away")


func test_a_helper_helps_someone_up():
	_game()
	var g := _seated()
	game.floor_dirt.slip(g, Grid.to_cell(g.position))
	_helper(3, ["help_up"], Vector2i(5, 3))
	_run(5.0)
	assert_false(game.floor_dirt.is_down(g), "helped up")


func test_on_a_break_they_take_nothing_and_chat_with_another_on_a_break():
	_game()
	var g := _seated()
	var a := _helper(3, ["take_orders"], Vector2i(7, 5), 1)
	var b := _helper(4, ["take_orders"], Vector2i(8, 5), 1)
	game.staff.employee(3).satisfaction = 0.9
	game.staff.employee(4).satisfaction = 0.3
	game.clock = Staff.break_starts(1, game.day.day_length())[0] + 0.1
	_run(3.0)
	assert_true(a.resting and b.resting)
	assert_eq(game.tickets.size(), 0, "nobody takes the order on a break")
	assert_true(a.chatting and b.chatting, "two on a break side by side chat")
	assert_almost_eq(float(game.staff.employee(3).satisfaction), 0.9, 0.001, "chat no longer pulls them together")
	assert_almost_eq(float(game.staff.employee(4).satisfaction), 0.3, 0.001)
	_run(Staff.BREAK_SECONDS)
	assert_false(a.resting)
	_run(6.0)
	assert_eq(g.state, "waiting", "back to work: the order is taken")


func test_a_chef_taking_the_task_sends_the_helper_on():
	_game()
	var g := _seated()
	var h := _helper(3, ["take_orders"], Vector2i(9, 6))
	_run(0.8)
	assert_false(h.task.is_empty(), "the helper set off for the table")
	_order_by_chef(g)
	_run(6.0)
	assert_eq(game.tickets.size(), 1, "one order, taken once")
	assert_true(h.task.is_empty() and h.steps.is_empty(), "the helper moved on")


func test_a_slip_costs_a_helper_some_satisfaction():
	_game()
	var h := _helper(3, ["wash_up"])
	var before := float(game.staff.employee(3).satisfaction)
	game.floor_dirt.slip(h, h.cell())
	assert_almost_eq(float(game.staff.employee(3).satisfaction), before - HelperWork.SLIP_HIT, 0.0001)
	assert_true(game.floor_dirt.is_down(h))


func test_enough_training_changes_a_tolerance_for_good():
	_game()
	var h := _helper(3, ["wash_up"], Vector2i(3, 3))
	game.staff.employee(3).skills.clean = 3.49
	var sink: Station = game.world.find_station("sink")
	sink.dirty = 1
	_run(6.0)
	assert_eq(sink.dirty, 0)
	assert_eq(game.town.tolerance(3, "clean"), 2, "a better cleaner minds dirt more")
	assert_true(h.task.is_empty())


func test_the_desk_is_in_the_shop_now():
	_game()
	var ids: Array = Catalog.search("desk", "", Scenery.theme_id).map(func(bp: Dictionary) -> String: return bp.id)
	assert_true(ids.has("desk"))


func test_a_server_with_take_payment_brings_the_bill_and_the_table_pays():
	_game()
	var g := _seated()
	game.serving.take_orders(g.table)
	game.serving.serve(g, game.serving.full_tray_for(g))
	var h := _helper(3, ["take_payment"])
	var paid := false
	for i in 400:
		game.step(0.1)
		g.mood.patience = maxf(g.mood.patience, 0.5)
		if g.state == "leaving":
			paid = true
			break
	assert_true(paid, "the helper wrote the bill and handed it over")
	assert_gt(int(game.ledger.today.sales), 0)
	assert_eq(h.held, "")
