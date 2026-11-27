extends "res://test/helpers/game_case.gd"
## EPIC 28: the card of the table a carried one would make, and the squash when tables join or split.


## A lone tile with two chairs, and a spare chair waiting beside the empty cell below it.
func _room() -> Dictionary:
	for st: Station in game.stations.values().duplicate():
		if Station.is_table(st.type) or Station.is_seat(st.type):
			game.world._unregister(st)
			st.queue_free()
	var out := {}
	out.lone = game.world.add_station("table", Vector2i(7, 2))
	for spot: Array in [[6, 2, 2], [8, 2, 0], [6, 3, 2]]:
		game.world.add_station("chair", Vector2i(spot[0], spot[1]), 1, spot[2])
	game.phase = Game.Phase.BUILD
	game.table_cards.tick()
	return out


## The chef carries `id` and its ghost hovers over `cell`.
func _carry_over(cell: Vector2i, facing := 0, id := "table") -> void:
	var ch: Player = game.player
	ch.hand = {"id": id, "tier": 1, "price": 0, "facing": facing}
	ch.ghost = autofree(Node3D.new())
	ch.ghost.position = Grid.center(cell)
	ch.ghost.visible = true
	game.table_cards.tick()


func _text(card: Node3D) -> String:
	return (card.get_meta("label") as Label3D).text


func test_ghost_that_would_join_shows_the_new_seat_count_beside_the_other_table():
	var r := _room()
	_carry_over(Vector2i(7, 3))
	var pv: Node3D = game.table_cards.previews[game.player].node
	assert_eq(_text(pv), "3", "the spare chair beside the new tile joins in")
	assert_almost_eq(pv.position.z, (Grid.center(Vector2i(7, 3)).z + r.lone.position.z) / 2.0, 0.001)
	assert_false(game.table_cards.is_up(r.lone), "the two card gives way to the three")


func test_preview_goes_away_when_the_ghost_moves_off():
	var r := _room()
	_carry_over(Vector2i(7, 3))
	game.player.ghost.position = Grid.center(Vector2i(8, 5))
	game.table_cards.tick()
	assert_true(game.table_cards.previews.is_empty())
	assert_true(game.table_cards.is_up(r.lone))


func test_a_carried_chair_facing_a_table_previews_the_seats_it_would_make():
	var r := _room()
	_carry_over(Vector2i(7, 1), 1, "chair")   # above the tile, facing it
	assert_eq(_text(game.table_cards.previews[game.player].node), "3")
	_carry_over(Vector2i(7, 1), 3, "chair")   # turned away
	assert_true(game.table_cards.previews.is_empty())
	assert_true(game.table_cards.is_up(r.lone))


func test_putting_down_joins_into_one_card_with_a_clack_and_lifting_splits():
	var r := _room()
	_carry_over(Vector2i(7, 3))
	game.player.hand = {}
	game.player.ghost = null
	var b: Station = game.world.add_station("table", Vector2i(7, 3))
	game.table_cards.tick()
	assert_true(game.table_cards.previews.is_empty())
	assert_eq(game.table_cards.cards.size(), 1)
	var joined: Node3D = game.table_cards.card_of(r.lone)
	assert_eq(_text(joined), "3")
	assert_true(game.table_cards.cards[r.lone].has("tween"), "squashed up")
	game._sfx["clack"].stop()
	game.world._unregister(b)
	game.table_cards.tick()
	assert_eq(game.table_cards.cards.size(), 1)
	assert_eq(_text(game.table_cards.card_of(r.lone)), "2")
	assert_true(game.table_cards.cards[r.lone].has("tween"), "squashed back")
