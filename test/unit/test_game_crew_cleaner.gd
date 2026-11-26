extends "res://test/helpers/game_case.gd"
## A helper with every Cleaning duty cleans the dirt it can reach and is not stuck on dirt
## it cannot (T-69): a cell past the kerb is no task, and a failed task is not retried at once.

const PERSON := 5
const CLEANING := ["mop", "sponge", "scraper", "spill_kit", "wash_up", "empty_bin"]


func _start() -> FloorMess:
	_to_build()
	game.day.start_day()
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	game.crew.crew_demos.demo_hire(PERSON, "Cleaner", CLEANING, Vector2i(5, 3))
	return game.floor_dirt.mess


func _levels(mess: FloorMess, cells: Array) -> int:
	var n := 0
	for c: Vector2i in cells:
		n += mess.level(c)
	return n


func test_a_cleaner_walks_to_each_dirty_cell_and_cleans_it():
	var mess := _start()
	var cells := [Vector2i(8, 5), Vector2i(6, 6), Vector2i(9, 3)]
	for c: Vector2i in cells:
		mess.dirt[c] = 2
	var visited := {}
	for i in 200:
		game.step(0.1)
		visited[game.crew.helpers[0].cell()] = true
	assert_eq(_levels(mess, cells), 0, "all three cells are clean")
	assert_gt(visited.size(), 1, "the helper moved about")


func test_dirt_past_the_kerb_is_not_offered_and_reachable_dirt_is_cleaned():
	var mess := _start()
	var kerb := Vector2i(game.grid.pavement_from, 4)
	var near := Vector2i(7, 5)
	mess.dirt[kerb] = 3
	mess.dirt[near] = 1
	for i in 200:
		game.step(0.1)
	assert_eq(mess.level(near), 0, "the reachable cell is cleaned")
	assert_false(game.crew.board.tasks.has("dirt:%d,%d" % [kerb.x, kerb.y]) and game.crew.board.held_by.get(PERSON, "") == "dirt:%d,%d" % [kerb.x, kerb.y],
		"the helper is not holding the kerb dirt")
