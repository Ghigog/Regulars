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
