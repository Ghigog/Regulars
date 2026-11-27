extends "res://test/helpers/game_case.gd"
## A picky member of a group of three who orders a main anyway says so, and is not
## counted as having found nothing.


func test_a_guest_who_goes_along_thinks_so_and_is_not_counted_as_finding_nothing():
	var menu_ings: Array = []
	for it: Dictionary in game.menu_stock.tonight_menu():
		if it.course == "main":
			for ing: String in it.ingredients:
				if not menu_ings.has(ing):
					menu_ings.append(ing)
	game.town.people[0].likes = []
	game.town.people[0].dislikes = []
	for i in [1, 2]:
		game.town.people[i].likes = []
		game.town.people[i].dislikes = menu_ings.duplicate()
	var party: Array[Guest] = game.seating.spawn_group([0, 1, 2])
	var found := false
	for seed_ in 50:
		game.order_rng.seed = seed_
		var before := int(game.ledger.today.found_nothing)
		for g in party:
			g.mood.thoughts.clear()
		var plan: Dictionary = game.seating._plan_orders(party)
		if plan.went_along.is_empty():
			continue
		found = true
		var k: int = plan.went_along[0]
		assert_true(party[k].mood.thoughts.has(Menu.GO_ALONG_THOUGHT))
		assert_false(party[k].mood.thoughts.has(Menu.NOTHING_THOUGHT))
		assert_false(plan.found_nothing.has(k))
		var others: int = plan.found_nothing.size()
		assert_eq(int(game.ledger.today.found_nothing) - before, others, "only those who stayed with nothing are counted")
		break
	assert_true(found, "someone went along within 50 seeds")
