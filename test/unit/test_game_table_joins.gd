extends "res://test/helpers/game_case.gd"
## Groups at combined tables: the smallest table that fits, a pushed-together pair for four.


## Clears the room's dining tables, then puts a table for two at each cell (all facing 0, so
## two tables one cell apart along z are pushed together).
func _room(cells: Array) -> Array[Station]:
	for st: Station in game.paying.dining_tables():
		game.world._unregister(st)
		st.queue_free()
	var out: Array[Station] = []
	for c in cells:
		out.append(game.world.add_station("table", c))
	return out


func test_a_pair_of_two_takes_the_lone_table_before_a_joined_pair():
	var t := _room([Vector2i(6, 1), Vector2i(6, 2), Vector2i(9, 4)])
	var party: Array[Guest] = game.seating.spawn_group([0, 1])
	_run(14.0)
	assert_eq(party[0].table, t[2], "the lone table, not the pushed-together pair")
	assert_eq(party[1].table, t[2])


func test_a_pair_of_two_takes_a_joined_pair_when_nothing_else_is_free_and_it_is_all_theirs():
	var t := _room([Vector2i(6, 1), Vector2i(6, 2)])
	var party: Array[Guest] = game.seating.spawn_group([0, 1])
	var next: Guest = game.seating.spawn_guest(5)
	_run(14.0)
	assert_eq(party[0].table, t[0], "the lead half")
	assert_eq(next.state, "queue", "nobody else sits at either half")
	assert_true(game.seat_taken.has(t[0].seats[0]))
	assert_false(game.seat_taken.has(t[1].seats[0]))


func test_a_group_of_four_fills_a_joined_pair_two_chairs_each_half_with_own_tier():
	var t := _room([Vector2i(6, 1), Vector2i(6, 2)])
	t[1].tier = 3
	var party: Array[Guest] = game.seating.spawn_group([0, 1, 2, 3])
	_run(14.0)
	var on_lead := 0
	for g in party:
		assert_eq(g.table, t[0])
		on_lead += 1 if g.seat in t[0].seats else 0
	assert_eq(on_lead, 2, "two chairs on each half")
	assert_eq(game.tables.half_of_seat(t[0], t[1].seats[0]), t[1])


func test_a_run_of_three_seats_four_at_its_pair_and_two_at_the_leftover():
	var t := _room([Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3)])
	var four: Array[Guest] = game.seating.spawn_group([0, 1, 2, 3])
	var two: Array[Guest] = game.seating.spawn_group([4, 5])
	_run(16.0)
	assert_eq(four[0].table, t[0])
	assert_eq(two[0].table, t[2])


func test_the_critic_never_takes_a_joined_pair_while_a_single_seat_is_free():
	var t := _room([Vector2i(6, 1), Vector2i(6, 2), Vector2i(9, 4)])
	var party: Array[Guest] = game.seating.spawn_group([6], true)
	_run(14.0)
	assert_eq(party[0].table, t[2])


func test_joins_split_after_a_table_is_lifted_or_sold():
	var t := _room([Vector2i(6, 1), Vector2i(6, 2)])
	assert_eq(game.tables.seats_of(t[0]).size(), 4)
	game.world._unregister(t[1])
	assert_eq(game.tables.seats_of(t[0]).size(), 2, "the other table seats 2 on its own")
	assert_eq(game.tables.halves(t[0]).size(), 1)


func test_a_group_of_four_turns_away_when_no_table_could_ever_seat_them():
	_room([Vector2i(6, 1), Vector2i(9, 4)])
	var party: Array[Guest] = game.seating.spawn_group([0, 1, 2, 3])
	_run(14.0)
	for g in party:
		assert_false(game.queue.has(g), "out of the line")
		assert_true(g.state == "browse" or g.state == "leaving", "turned away at the door")
