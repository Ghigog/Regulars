extends GutTest
## The job board keeps a task a helper failed from that helper for a while, so a task
## they cannot reach is not handed straight back (T-69).

const KEY := "dirt:3,0"


func _staff() -> Staff:
	var s := Staff.new(7)
	for p in [1, 2]:
		var pid := s.add_post("Cleaner", ["mop"], 0, 0, 99)
		var cv := s._make_cv(p, Staff.skills_from({"food": 3, "service": 3, "clean": 3}), 3, 1.0, pid)
		s.cvs.append(cv)
		s.hire(cv.id, -1, 1)
	return s


func _board() -> JobBoard:
	var b := JobBoard.new()
	b.rebuild({"dirt": {Vector2i(3, 0): 2, Vector2i(9, 0): 2}})
	return b


func _helper(id: int) -> Array:
	return [{"id": id, "cell": Vector2i(3, 1), "idle": 5.0}]


func test_a_failed_task_is_skipped_for_that_helper_only():
	var s := _staff()
	var b := _board()
	assert_eq(b.assign(s, _helper(1), 1, 0.0, 100.0)[1].key, KEY, "the near one first")
	b.fail(1, KEY)
	b.release(1)
	assert_ne(b.assign(s, _helper(1), 1, 0.0, 100.0)[1].key, KEY, "A is given another")
	b.release(1)
	assert_eq(b.assign(s, _helper(2), 1, 0.0, 100.0)[2].key, KEY, "B may still take it")


func test_a_failed_task_is_offered_again_after_the_cooldown():
	var s := _staff()
	var b := _board()
	b.fail(1, KEY)
	b.cool(JobBoard.FAILED_COOLDOWN + 0.1)
	assert_eq(b.assign(s, _helper(1), 1, 0.0, 100.0)[1].key, KEY)


func test_a_failure_is_forgotten_when_the_task_leaves_the_board():
	var b := _board()
	b.fail(1, KEY)
	b.rebuild({})
	b.cool(0.1)
	assert_true(b.failed.is_empty())
