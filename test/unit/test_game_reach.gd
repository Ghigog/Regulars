extends "res://test/helpers/game_case.gd"
## The E target is the nearest thing within reach: a wall stops a hand, so the door card
## beats a rug or station on the far side of the front wall.


func before_each():
	super.before_each()
	game.arrivals.clear()
	game.step(0.1)
	game.step(0.1)


func _stand(cell: Vector2i, off := Vector3.ZERO, face := Vector2i(0, 1)) -> Player:
	var ch: Player = game.player
	ch.position = Grid.center(cell) + off
	ch.look(face)
	return ch


func _clear_rugs() -> void:
	for a: Vector2i in game.rugs:
		game.rugs[a].queue_free()
	game.rugs.clear()


func test_the_door_beats_a_rug_behind_the_front_wall():
	game.session.open_build()
	game.player.hand = {}
	_clear_rugs()
	game.placing.add_rug(Vector2i(Game.W - 2, Game.DOOR.y - 3))   # covers (9, 1) and (9, 2)
	var ch := _stand(Vector2i(Game.W, Game.DOOR.y - 1), Vector3(0, 0, 0.4), Vector2i(-1, 0))
	assert_true(game.day.at_door(ch), "set-up: at the door")
	assert_eq(game.room_edit._piece_in_front(ch), Vector3.INF)
	assert_eq(game.room_edit.build_action(ch), "Open up")


func test_a_nearer_rug_beats_the_door_until_the_doorway_is_nearer():
	game.session.open_build()
	game.player.hand = {}
	_clear_rugs()
	game.placing.add_rug(Vector2i(Game.W - 2, Game.DOOR.y - 1))   # covers (9, 3) and (9, 4)
	var ch := _stand(Vector2i(Game.W - 1, Game.DOOR.y + 1), Vector3(0, 0, -0.5))
	assert_true(game.day.at_door(ch), "set-up: at the door")
	assert_eq(game.room_edit.build_action(ch), "Pick up", "the rug is nearer")
	ch.position = Game.DOORWAY + Vector3(-0.05, 0, 0.55)
	assert_eq(game.room_edit.build_action(ch), "Open up", "the doorway is nearer")


func test_a_piece_through_the_doorway_is_still_reached():
	game.session.open_build()
	game.player.hand = {}
	_clear_rugs()
	game.placing.add_rug(Vector2i(Game.W - 2, Game.DOOR.y))
	var ch := _stand(Vector2i(Game.W, Game.DOOR.y), Vector3.ZERO, Vector2i(-1, 0))
	assert_ne(game.room_edit._piece_in_front(ch), Vector3.INF)


func test_a_station_through_the_wall_is_not_targeted():
	var st: Station = game.menu_stock.storage_of("patty")
	game.player.position = Grid.center(st.cell + Vector2i(0, 0))
	assert_eq(game.player.target_cell(), st.cell, "set-up: reachable inside")
	var wall := Grid.edge_between(st.cell, st.cell + Vector2i(1, 0))
	game.grid.walls[wall] = true
	game.grid.walls[Grid.edge_between(st.cell + Vector2i(0, 1), st.cell + Vector2i(1, 1))] = true
	game.player.position = Grid.center(st.cell + Vector2i(1, 1))
	assert_ne(game.player.target_cell(), st.cell, "diagonal through the wall")
