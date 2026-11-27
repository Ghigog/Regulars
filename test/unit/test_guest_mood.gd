extends GutTest
## Disgust fades once nothing gross is in view, down to the Ick floor for a guest who has been Ick.


func test_disgust_halves_in_one_half_life():
	var m := GuestMood.new()
	m.disgust = 0.15
	m.fade(GuestMood.DISGUST_HALF_LIFE)
	assert_almost_eq(m.disgust, 0.075, 0.001)
	m.fade(10 * GuestMood.DISGUST_HALF_LIFE)
	assert_lt(m.disgust, 0.001, "never Ick: it fades towards nothing")


func test_a_guest_who_reached_ick_keeps_at_least_ick():
	var m := GuestMood.new()
	m.see_gross(1.0, 0.5, "x")   # 0.5: past Ick
	assert_true(m.reached_ick)
	for i in 100:
		m.fade(5.0)
	assert_almost_eq(m.disgust, GuestMood.DISGUST_STAGES[0], 0.0001)


func test_a_guest_below_ick_who_never_reached_it_is_not_pinned():
	var m := GuestMood.new()
	m.see_gross(0.1, 1.0, "x")   # 0.1, under Ick
	assert_false(m.reached_ick)
	m.fade(100.0)
	assert_lt(m.disgust, 0.01)


func test_seat_tolerance_scales_anger_and_disgust_only():
	var m := GuestMood.new()
	var service := m.scale_for("service")
	var clean := m.scale_for("clean")
	var food := m.scale_for("food")
	m.seat_tolerance = 1.2
	assert_almost_eq(m.scale_for("service"), service * 1.2, 0.0001)
	assert_almost_eq(m.scale_for("clean"), clean * 1.2, 0.0001)
	assert_eq(m.scale_for("food"), food)


func test_seat_tip_scales_the_tip():
	var m := GuestMood.new()
	m.savour = 1.0
	m.joy = 1.0
	var base := m.tip_for(100)
	m.seat_tip = 1.3
	assert_eq(m.tip_for(100), roundi(base / 1.0 * 1.3), "tip rises with seat_tip")
