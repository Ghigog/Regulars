extends GutTest

func _in_caps(e: Dictionary) -> void:
	assert_between(e.eat, Seating.EAT_RANGE.x, Seating.EAT_RANGE.y)
	assert_between(e.order, Seating.ORDER_RANGE.x, Seating.ORDER_RANGE.y)
	assert_between(e.tip, Seating.TIP_RANGE.x, Seating.TIP_RANGE.y)
	assert_between(e.tolerance, Seating.TOLERANCE_RANGE.x, Seating.TOLERANCE_RANGE.y)


func test_base_piece_is_neutral() -> void:
	assert_eq(Seating.piece_effect("", 0), Seating.neutral())


func test_fast_chair_and_table() -> void:
	var e := Seating.combine(Seating.piece_effect("fast", 2), Seating.piece_effect("fast", 1))
	assert_lt(e.eat, 1.0)
	assert_lt(e.order, 1.0)
	assert_lt(e.tip, 1.0)
	assert_gt(e.tolerance, 1.0)
	assert_eq(e.joy, 0.0)
	_in_caps(e)


func test_booth_and_comfortable_table() -> void:
	var e := Seating.combine(Seating.piece_effect("comfortable", 3), Seating.piece_effect("comfortable", 1))
	assert_gt(e.eat, 1.0)
	assert_gt(e.order, 1.0)
	assert_gt(e.tip, 1.0)
	assert_lt(e.tolerance, 1.0)
	assert_almost_eq(e.joy, 0.15, 0.0001)
	_in_caps(e)


func test_extremes_are_capped() -> void:
	var big := {"eat": 9.0, "order": 9.0, "tip": 9.0, "tolerance": 9.0, "joy": 0.0}
	var small := {"eat": 0.01, "order": 0.01, "tip": 0.01, "tolerance": 0.01, "joy": 0.0}
	_in_caps(Seating.combine(big, big))
	_in_caps(Seating.combine(small, small))
	assert_eq(Seating.combine(big, big).eat, Seating.EAT_RANGE.y)
	assert_eq(Seating.combine(small, small).tolerance, Seating.TOLERANCE_RANGE.x)


func test_reading_time_grows_and_caps() -> void:
	assert_gt(Seating.reading_time(8, 1.0), Seating.reading_time(2, 1.0))
	assert_almost_eq(Seating.reading_time(100, 0.8), Seating.READ_CAP * 0.8, 0.0001)
	assert_eq(Seating.reading_time(0, 1.0), Seating.READ_BASE)


func test_order_scale_multiplies_and_clamps() -> void:
	assert_eq(Seating.order_scale([] as Array[float]), 1.0)
	assert_almost_eq(Seating.order_scale([0.9, 0.9] as Array[float]), 0.81, 0.0001)
	assert_eq(Seating.order_scale([0.1] as Array[float]), Seating.ORDER_SCALE_RANGE.x)
	assert_eq(Seating.order_scale([5.0] as Array[float]), Seating.ORDER_SCALE_RANGE.y)
