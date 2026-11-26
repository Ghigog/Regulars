extends "res://test/helpers/game_case.gd"
## The desk on a pad: the d-pad walks the CV pile, the right stick steps the highlight.

var desk: DeskScreen


func _open_with_three() -> void:
	game.arrivals.clear()
	for i in 20:
		game.step(0.1)
	game.session.open_build()
	game.world.add_station("desk", Vector2i(8, 6))
	game.player.position = Grid.center(Vector2i(7, 6))
	game.player.look(Vector2i(1, 0))
	game.desk.desk_post("Grill cook", ["grill"], 1, 1)
	for p in game.town.people:
		p.affinity = 0.5
	for id in game.staff.posts:
		game.staff.posts[id].opened = 0  # as if put up on an earlier night
	for tries in 10:
		if not game.desk.roll_applicants().is_empty():
			break
	var base: Array = game.staff.cvs.duplicate(true)
	assert_false(base.is_empty())
	game.staff.cvs.clear()
	for i in 3:
		var cv: Dictionary = base[0].duplicate(true)
		cv.id = 9000 + i
		game.staff.cvs.append(cv)
	game.desk.open_desk()
	desk = game.hud.desk
	desk.select("tab:cvs")


func _act(a: String) -> void:
	game.coop.act(0, a)


func test_dpad_walks_the_pile_then_reaches_the_buttons():
	_open_with_three()
	for i in 3:
		_act("down")
		assert_eq(desk.selected(), "cv:%d" % i)
		assert_eq(desk._pick, i)
	_act("down")
	assert_eq(desk.selected(), "hire")
	assert_eq(desk._pick, 2)
	_act("up")
	assert_eq(desk.selected(), "cv:2")
	_act("up")
	_act("up")
	_act("up")
	assert_eq(desk.selected(), "tab:cvs")


func test_no_prev_next_buttons():
	_open_with_three()
	assert_false(desk.select("prev"))
	assert_false(desk.select("next"))


func test_a_on_a_cv_chooses_it_and_goes_to_hire():
	_open_with_three()
	_act("down")
	_act("down")
	_act("use")
	assert_eq(desk._pick, 1)
	assert_eq(desk.selected(), "hire")
	_act("use")
	assert_eq(game.staff.employees.size(), 1, "hired the second CV")


func test_right_stick_steps_once_per_flick_and_repeats_held():
	_open_with_three()
	var at: Vector3 = game.player.position
	_axis(JOY_AXIS_RIGHT_Y, 1.0)
	game.controls._process(0.016)
	game.controls._process(0.1)
	assert_eq(desk.selected(), "cv:0", "one step")
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	game.controls._process(0.016)
	_axis(JOY_AXIS_RIGHT_Y, -1.0)
	game.controls._process(0.016)
	assert_eq(desk.selected(), "tab:cvs", "up once")
	game.controls._process(0.3)
	assert_eq(desk.selected(), "tab:cvs", "nothing above the tabs")
	assert_eq(game.player.position, at, "the chef stays")
