extends "res://test/helpers/game_case.gd"
## A helper may work a station from a diagonal cell when no side is open (T-84).

const PERSON := 5


func _helper() -> Helper:
	_to_build()
	game.day.start_day()
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	return game.crew.crew_demos.demo_hire(PERSON, "Cook", ["fetch"], Vector2i(5, 3))


func _station_at(at: Vector2i, shut: Array[Vector2i]) -> void:
	game.world.add_station("fridge", at)
	for d: Vector2i in shut:
		game.grid.blocked[at + d] = true


func test_stand_for_picks_the_diagonal_cell_when_every_side_is_shut():
	var h := _helper()
	var at := Vector2i(7, 5)
	_station_at(at, Grid.DIRS)
	var stand: Variant = game.crew.task_run._stand_for(h, {"do": "take", "at": at})
	assert_not_null(stand)
	assert_eq(absi(stand.x - at.x), 1)
	assert_eq(absi(stand.y - at.y), 1)


func test_stand_for_prefers_an_orthogonal_cell():
	var h := _helper()
	var at := Vector2i(7, 5)
	_station_at(at, [] as Array[Vector2i])
	var stand: Variant = game.crew.task_run._stand_for(h, {"do": "take", "at": at})
	assert_not_null(stand)
	assert_eq(absi(stand.x - at.x) + absi(stand.y - at.y), 1, "a side, not a corner")
