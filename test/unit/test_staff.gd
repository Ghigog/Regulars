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
