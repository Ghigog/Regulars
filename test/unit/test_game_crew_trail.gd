extends "res://test/helpers/game_case.gd"
## A helper with serving and cleaning duties mops a trail of level 1 dirt that feet tracked
## off a bigger patch (PRD 10.7): level 1 dirt is a task, last in line.

const PERSON := 5


func test_a_helper_mops_the_trail_feet_left_behind_a_patch():
	_to_build()
	game.day.start_day()
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])   # no guests wait, but the day stays open
	game.crew.crew_demos.demo_hire(PERSON, "Server", ["take_orders", "carry_trays", "clear_tables", "mop", "sponge"], Vector2i(5, 3))
	var mess: FloorMess = game.floor_dirt.mess
	var row: Array[Vector2i] = [Vector2i(8, 5), Vector2i(7, 5), Vector2i(7, 4)]
	mess.track_chance = 1.0
	mess.dirt[row[0]] = 3
	assert_true(mess.track(row[0], row[1]), "feet track a level off the patch")
	for i in range(row.size() - 1):   # feet carry the patch along as level 1 trail
		mess.dirt[row[i + 1]] = 1
	var trail: Array[Vector2i] = []
	for c in row:
		if mess.level(c) == 1:
			trail.append(c)
	assert_gt(trail.size(), 1, "the walk left a trail of level 1 cells")
	var mopped := false
	for i in 3000:
		game.step(0.1)
		var task: Dictionary = game.crew.board.task_of(PERSON)
		if task.get("type", "") == "dirt" and trail.has(task.cell):
			mopped = true
		if _clean(mess, trail):
			break
	assert_true(mopped, "the helper took the trail as a dirt task")
	for c in trail:
		assert_eq(mess.level(c), 0, "trail cell %s is mopped" % str(c))


func _clean(mess: FloorMess, cells: Array[Vector2i]) -> bool:
	for c in cells:
		if mess.level(c) > 0:
			return false
	return true
