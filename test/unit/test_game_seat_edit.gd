extends "res://test/helpers/game_case.gd"
## EPIC-85: edit mode with single pieces: lift one, set it down turned to its table,
## the red disc under a seat with no table, the chair bought into a booth seat.


func _room() -> Dictionary:
	for st: Station in game.stations.values().duplicate():
		if Station.is_table(st.type) or Station.is_seat(st.type):
			game.world._unregister(st)
			st.queue_free()
	var out := {"chairs": []}
	out.tile = game.world.add_station("table", Vector2i(7, 3))
	for spot: Array in [[6, 3, 2], [8, 3, 0], [7, 2, 1], [7, 4, 3]]:
		out.chairs.append(game.world.add_station("chair", Vector2i(spot[0], spot[1]), 1, spot[2]))
	game.phase = Game.Phase.BUILD
	game.table_cards.tick()
	return out


func test_lifting_one_chair_leaves_the_rest_and_folds_the_card_to_three():
	var r := _room()
	assert_eq((game.table_cards.card_of(r.tile).get_meta("label") as Label3D).text, "4")
	var c: Station = r.chairs[0]
	assert_true(game.placing.pick_up(Grid.center(c.cell)))
	assert_eq(game.player.hand.id, "chair")
	assert_true(game.stations.has(Vector2i(7, 3)))
	assert_eq(game.stations.values().filter(func(s): return s.type == "chair").size(), 3)
	game.table_cards.tick()
	assert_eq((game.table_cards.card_of(r.tile).get_meta("label") as Label3D).text, "3")


func test_a_chair_set_down_turned_away_turns_to_face_the_tile():
	var r := _room()
	game.ledger.money = 100
	game.player.hand = {"id": "chair", "tier": 1, "price": 10, "facing": 1}
	game.world._unregister(r.chairs[3])
	r.chairs[3].queue_free()
	assert_true(game.placing.place(Vector3i(7, 4, 0)))
	var placed: Station = game.stations[Vector2i(7, 4)]
	assert_eq(placed.facing, 3)
	assert_eq(game.table_cards.discs.size(), 0)


func test_a_chair_with_no_tile_beside_it_gets_a_red_disc_and_is_never_used():
	var r := _room()
	game.ledger.money = 100
	game.player.hand = {"id": "chair", "tier": 1, "price": 10, "facing": 0}
	assert_true(game.placing.place(Vector3i(9, 6, 0)))
	game.table_cards.tick()
	var lone: Station = game.stations[Vector2i(9, 6)]
	assert_true(game.table_cards.discs.has(lone))
	assert_false(game.tables.seats_of(r.tile).has(lone.cell))


func test_buying_the_booth_seat_turns_a_chair_3_in_place():
	var r := _room()
	game.ledger.money = 20
	game.ledger.xp = 100000   # the level the booth seat needs
	var c: Station = r.chairs[1]
	c.tier = 3
	assert_true(game.placing.pick_up(Grid.center(c.cell)))
	assert_true(game.upgrades.buy_upgrade("booth_seat@1"))
	assert_eq(game.ledger.money, 0)
	assert_eq(game.player.hand.id, "booth_seat")
	assert_eq(game.player.hand.node.cell, Vector2i(8, 3))
	assert_eq(game.player.hand.node.facing, 0)


func test_buying_a_fast_table_turns_a_lifted_table_1_in_place_and_it_still_seats():
	var r := _room()
	game.ledger.money = 100
	game.ledger.xp = 100000
	var t: Station = r.tile
	assert_true(game.placing.pick_up(Grid.center(t.cell)))
	assert_true(game.upgrades.buy_upgrade("table_fast@1"))
	var up: Station = game.player.hand.node
	assert_eq(up.type, "table_fast")
	assert_eq(up.cell, Vector2i(7, 3))
	assert_true(Station.is_table(up.type))
	assert_eq(game.paying.dining_tables().size() + (1 if game.stations.get(up.cell) != up else 0), 1)
