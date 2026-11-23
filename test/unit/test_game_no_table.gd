extends "res://test/helpers/game_case.gd"
## A group no table in the room could ever seat turns away at the door.


func _room(cells: Array) -> Array[Station]:
	for st: Station in game.paying.dining_tables():
		game.world._unregister(st)
		st.queue_free()
	var out: Array[Station] = []
	for c in cells:
		out.append(game.world.add_station("table", c))
	return out


func test_four_turn_away_when_only_separate_tables_for_two_exist():
	_room([Vector2i(6, 1), Vector2i(9, 4)])
	var before := float(game.town.people[0].affinity)
	var party: Array[Guest] = game.seating.spawn_group([0, 1, 2, 3])
	assert_eq(party[0].state, "browse")
	assert_false(game.queue.has(party[0]), "they never join the line")
	_run(30.0)
	assert_true(party[0].mood.thoughts.has("No table for the four of us"))
	assert_eq(int(game.ledger.today.no_table), 1, "one group, not four people")
	assert_eq(game.ledger.strikes(), 0, "no walkout")
	assert_eq(int(game.ledger.today.found_nothing), 0)
	assert_eq(game.town.people[0].grudges, 0)
	assert_eq(float(game.town.people[0].affinity), before)
	assert_false(game.guests.has(party[0]), "gone up the street")


func test_four_wait_in_line_for_a_combined_table_that_is_taken():
	_room([Vector2i(6, 1), Vector2i(6, 2)])
	game.seating.spawn_group([0, 1, 2, 3])
	_run(12.0)
	var next: Array[Guest] = game.seating.spawn_group([4, 5, 6, 7])
	assert_eq(next[0].state, "queue", "the table is only taken right now")
	assert_true(game.queue.has(next[0]))
	assert_eq(int(game.ledger.today.no_table), 0)


func test_a_rush_of_turned_away_groups_all_leave_and_each_counts_once():
	_room([Vector2i(6, 1), Vector2i(9, 4)])
	for i in 6:   # fours and threes at once, all at the same door
		game.seating.spawn_group([0, 1, 2, 3])
		_run(0.7)
	_run(60.0)
	assert_eq(game.guests.size(), 0, "nobody is stuck on the pavement")
	assert_eq(int(game.ledger.today.no_table), 6, "one per group")
