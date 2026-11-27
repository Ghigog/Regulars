extends "res://test/helpers/game_case.gd"
## EPIC 28: the seat-count card on each table: its numeral, and when it stands or folds.


func _clear() -> void:
	for st: Station in game.stations.values().duplicate():
		if Station.is_table(st.type) or Station.is_seat(st.type):
			game.world._unregister(st)
			st.queue_free()


## A pair of tiles with four chairs, and a lone tile with two.
func _room() -> Dictionary:
	_clear()
	var out := {}
	out.a = game.world.add_station("table", Vector2i(7, 1))
	out.b = game.world.add_station("table", Vector2i(7, 2))
	out.lone = game.world.add_station("table", Vector2i(7, 5))
	for spot: Array in [[6, 1, 2], [6, 2, 2], [8, 1, 0], [8, 2, 0], [6, 5, 2], [8, 5, 0]]:
		game.world.add_station("chair", Vector2i(spot[0], spot[1]), 1, spot[2])
	game.phase = Game.Phase.BUILD
	game.table_cards.tick()
	return out


func _text(lead: Station) -> String:
	return (game.table_cards.card_of(lead).get_meta("label") as Label3D).text


func test_pair_shows_four_at_the_seam_and_lone_table_two():
	var r := _room()
	assert_eq(game.table_cards.cards.size(), 2)
	assert_eq(_text(r.a), "4")
	assert_eq(_text(r.lone), "2")
	var seam: Vector3 = (r.a.position + r.b.position) / 2.0
	assert_almost_eq(game.table_cards.card_of(r.a).position.x, seam.x, 0.001)
	assert_almost_eq(game.table_cards.card_of(r.a).position.z, seam.z, 0.001)


func test_a_tile_with_one_chair_a_booth_seat_and_four_chairs_each_get_a_card():
	_clear()
	var one: Station = game.world.add_station("table", Vector2i(7, 0))
	game.world.add_station("chair", Vector2i(8, 0), 1, 0)
	var two: Station = game.world.add_station("table", Vector2i(6, 3))
	game.world.add_station("booth_seat", Vector2i(5, 3), 1, 2)
	game.world.add_station("chair", Vector2i(7, 3), 1, 0)
	var four: Station = game.world.add_station("table", Vector2i(8, 5))
	for spot: Array in [[7, 5, 2], [9, 5, 0], [8, 4, 1], [8, 6, 3]]:
		game.world.add_station("chair", Vector2i(spot[0], spot[1]), 1, spot[2])
	game.phase = Game.Phase.BUILD
	game.table_cards.tick()
	assert_eq([_text(one), _text(two), _text(four)], ["1", "2", "4"])


func test_card_hidden_while_a_group_sits_and_back_when_free():
	var r := _room()
	assert_true(game.table_cards.is_up(r.lone))
	game.seat_taken[r.lone.seats[0]] = autofree(Guest.new())
	game.table_cards.tick()
	assert_false(game.table_cards.is_up(r.lone))
	assert_true(game.table_cards.is_up(r.a))
	game.seat_taken.clear()
	game.table_cards.tick()
	assert_true(game.table_cards.is_up(r.lone))


func test_card_stays_down_while_plates_are_left_on_any_half():
	var r := _room()
	r.b.dirty = 1
	game.table_cards.tick()
	assert_false(game.table_cards.is_up(r.a))
	r.b.dirty = 0
	game.table_cards.tick()
	assert_true(game.table_cards.is_up(r.a))


func test_cards_follow_a_split_table():
	var r := _room()
	game.world._unregister(r.b)
	r.b.queue_free()
	game.table_cards.tick()
	assert_eq(_text(r.a), "2")
