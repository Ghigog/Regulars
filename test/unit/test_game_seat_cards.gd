extends "res://test/helpers/game_case.gd"
## EPIC 28: the seat-count card on each table: its numeral, and when it stands or folds.


func _room() -> Dictionary:
	for st: Station in game.paying.dining_tables():
		game.world._unregister(st)
		st.queue_free()
	var out := {}
	out.a = game.world.add_station("table", Vector2i(4, 1))
	out.b = game.world.add_station("table", Vector2i(4, 2))
	out.lone = game.world.add_station("table", Vector2i(4, 5))
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


func test_stool_booth_and_table_for_four_each_get_a_card():
	for st: Station in game.paying.dining_tables():
		game.world._unregister(st)
		st.queue_free()
	var s: Station = game.world.add_station("stool", Vector2i(2, 2))
	var b: Station = game.world.add_station("booth", Vector2i(5, 2))
	var f: Station = game.world.add_station("table4", Vector2i(8, 4))
	game.phase = Game.Phase.BUILD
	game.table_cards.tick()
	assert_eq([_text(s), _text(b), _text(f)], ["1", "2", "4"])


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
