extends "res://test/helpers/game_case.gd"

# The build-phase mouse reads the worktop of a counter, not the floor behind it.


func _settle() -> void:
	_to_build()
	game.cam.position = game._frame[0] + game.CAM_OFFSET
	game.cam.size = game._frame[1]


func _counter_cell() -> Vector2i:
	for c in game.stations:
		if game.world._bare_counter(c) != null:
			return c
	return Vector2i(-99, -99)


func _screen_of(cell: Vector2i, y: float) -> Vector2:
	return game.cam.unproject_position(Grid.center(cell) + Vector3(0, y, 0))


func test_worktop_aims_at_the_counter_under_the_cursor():
	_settle()
	var c := _counter_cell()
	assert_ne(c, Vector2i(-99, -99), "the kitchen has a bare counter")
	var s: Vector2 = _screen_of(c, 0.9)
	assert_ne(Grid.to_cell(game.room_edit.floor_point(s)), c, "the floor projection misses it")
	assert_eq(Grid.to_cell(game.room_edit.aim_point(s)), c)
	assert_eq(game.room_edit.aim_point(s).y, 0.0)


func test_front_face_aims_at_the_counter():
	_settle()
	var c := _counter_cell()
	# Below the worktop, on the counter's front face.
	var front: Vector2 = _screen_of(c, 0.45)
	assert_eq(Grid.to_cell(game.room_edit.aim_point(front)), c)


func test_open_floor_is_the_floor_projection():
	_settle()
	var f := Vector2i(-99, -99)
	for x in range(0, 12):
		for y in range(0, 8):
			var c := Vector2i(x, y)
			if game.plan.has_floor(c) and not game.stations.has(c):
				f = c
	var s: Vector2 = _screen_of(f, 0.0)
	assert_eq(game.room_edit.aim_point(s), game.room_edit.floor_point(s))


func test_a_wall_in_hand_aims_at_the_floor():
	_settle()
	game.ledger.money = 100
	game.placing.pick_catalog("wall")
	var s: Vector2 = _screen_of(_counter_cell(), 0.9)
	assert_eq(game.room_edit.aim_point(s), game.room_edit.floor_point(s))
