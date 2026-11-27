extends "res://test/helpers/game_case.gd"
## Groups at tables built of tiles: the smallest table that fits, the whole table theirs.

const PAIR := [Vector2i(6, 1), Vector2i(6, 2)]
const PAIR_CHAIRS := [Vector2i(5, 1), Vector2i(5, 2), Vector2i(7, 1), Vector2i(7, 2)]
const LONE := [Vector2i(8, 5)]
const LONE_CHAIRS := [Vector2i(7, 5), Vector2i(9, 5)]


## A table of two tiles with four chairs, and a lone tile with two when `lone`.
func _room(lone := true) -> Array[Station]:
	_clear_dining()
	var out := _add_table(PAIR, PAIR_CHAIRS)
	if lone:
		out.append_array(_add_table(LONE, LONE_CHAIRS))
	return out


func test_a_pair_of_two_takes_the_lone_table_before_the_big_one():
	var t := _room()
	var party: Array[Guest] = game.seating.spawn_group([0, 1])
	_run(14.0)
	assert_eq(party[0].table, t[2], "the lone tile, not the table of four")
	assert_eq(party[1].table, t[2])


func test_a_pair_of_two_takes_the_big_table_when_nothing_else_is_free_and_it_is_all_theirs():
	var t := _room(false)
	var party: Array[Guest] = game.seating.spawn_group([0, 1])
	var next: Guest = _spawn_joining(5)   # the line is not empty: pin its roll to "joins"
	_run(14.0)
	assert_eq(party[0].table, t[0], "the lead tile")
	assert_eq(next.state, "queue", "nobody else sits at either tile")
	assert_true(game.seat_taken.has(t[0].seats[0]))
	assert_false(game.seat_taken.has(t[1].seats[0]))


func test_a_group_of_four_fills_the_table_two_chairs_each_tile_with_own_tier():
	var t := _room(false)
	game.stations[Vector2i(5, 2)].tier = 3
	var party: Array[Guest] = game.seating.spawn_group([0, 1, 2, 3])
	_run(14.0)
	var on_lead := 0
	for g in party:
		assert_eq(g.table, t[0])
		on_lead += 1 if g.seat in t[0].seats else 0
	assert_eq(on_lead, 2, "two chairs on each tile")
	assert_eq(game.tables.half_of_seat(t[0], Vector2i(5, 2)), t[1])


func test_a_bridging_tile_makes_two_tables_one_and_the_lead_is_the_lowest_tile():
	_clear_dining()
	_add_table([Vector2i(6, 1)], [Vector2i(5, 1), Vector2i(7, 1)])
	_add_table([Vector2i(6, 3)], [Vector2i(5, 3), Vector2i(7, 3)])
	assert_eq(game.tables.list.size(), 2)
	assert_eq(game.tables.lead(game.stations[Vector2i(6, 3)]), game.stations[Vector2i(6, 3)], "its own lead while apart")
	game.world.add_station("table", Vector2i(6, 2))
	assert_eq(game.tables.list.size(), 1)
	assert_eq(game.tables.list[0].seats, 4)
	assert_eq(game.tables.lead(game.stations[Vector2i(6, 3)]), game.stations[Vector2i(6, 1)], "the lead is the first tile down the room")


func test_the_critic_never_takes_the_big_table_while_a_single_seat_is_free():
	var t := _room()
	var party: Array[Guest] = game.seating.spawn_group([6], true)
	_run(14.0)
	assert_eq(party[0].table, t[2])


func test_a_table_splits_after_a_tile_is_lifted_or_sold():
	var t := _room(false)
	assert_eq(game.tables.seats_of(t[0]).size(), 4)
	game.world._unregister(t[1])
	assert_eq(game.tables.seats_of(t[0]).size(), 2, "the other tile seats the chairs beside it alone")
	assert_eq(game.tables.halves(t[0]).size(), 1)


func test_a_chair_lifted_takes_its_seat_off_the_table():
	var t := _room(false)
	game.world._unregister(game.stations[Vector2i(7, 2)])
	assert_eq(game.tables.seats_of(t[0]).size(), 3)
	assert_eq(game.seating.max_party(), 3)


func test_a_group_of_four_turns_away_when_no_table_could_ever_seat_them():
	_clear_dining()
	_add_table([Vector2i(6, 1)], [Vector2i(5, 1), Vector2i(7, 1)])
	_add_table(LONE, LONE_CHAIRS)
	var party: Array[Guest] = game.seating.spawn_group([0, 1, 2, 3])
	_run(14.0)
	for g in party:
		assert_false(game.queue.has(g), "out of the line")
		assert_true(g.state == "browse" or g.state == "leaving", "turned away at the door")


func test_each_table_shows_its_seat_count_at_its_centre():
	var t := _room()
	var shown := {}
	for c: Label3D in game.tables.cards:
		shown[c.text] = c.position
	assert_eq(game.tables.cards.size(), 2, "a card per table, not per tile")
	assert_true(shown.has("4") and shown.has("2"))
	var mid: Vector3 = (t[0].position + t[1].position) / 2.0
	assert_almost_eq(shown["4"].x, mid.x, 0.01)
	assert_almost_eq(shown["4"].z, mid.z, 0.01)
	game.world._unregister(t[1])
	assert_eq(game.tables.cards.size(), 2)
	for c: Label3D in game.tables.cards:
		assert_eq(c.text, "2", "pulled apart, both tables seat two")
