extends GutTest


func test_empty_line_always_joins():
	for like in [-1.0, 0.0, 1.0]:
		assert_eq(QueueChoice.join_chance(0, like), 1.0)


func test_longer_line_lowers_chance_but_not_below_floor():
	assert_lt(QueueChoice.join_chance(6, 0.0), QueueChoice.join_chance(3, 0.0))
	assert_eq(QueueChoice.join_chance(500, -1.0), QueueChoice.FLOOR)


func test_higher_affinity_raises_chance_for_same_line():
	assert_gt(QueueChoice.join_chance(5, 0.8), QueueChoice.join_chance(5, -0.8))
